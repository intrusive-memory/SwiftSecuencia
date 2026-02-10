import Foundation
import SwiftData
import SwiftSecuencia
import SwiftCompartido

/// Errors that can occur during timeline building.
public enum TimelineBuilderError: Error, Sendable {
    case unsupportedMarkerType(String)
    case invalidFrameRate(String)
    case invalidAudioLayout(String)
    case invalidAudioRate(String)
    case invalidColorSpace(String)
    case missingFile(clipName: String)
    case missingDuration(clipName: String)
    case assetNotFoundInMap(path: String)
}

/// Builds a Timeline from a JSON definition and asset map.
///
/// The builder creates a SwiftData Timeline object with:
/// - Video format configuration mapped from JSON
/// - Audio layout and sample rate
/// - TimelineClip objects for each clip
/// - Markers (standard and chapter)
/// - FileAssetProvider registry with one entry per unique file
///
/// ## Usage
///
/// ```swift
/// let definition = try JSONTimelineParser.parse(from: jsonURL)
/// let assetMap = try FileResolver.resolveAndDeduplicateAssets(in: definition, baseURL: baseURL)
/// let context = SwiftDataBootstrap.createContext(from: container)
///
/// let builder = TimelineBuilder()
/// let (timeline, provider) = try await builder.build(
///     from: definition,
///     assetMap: assetMap,
///     in: context
/// )
/// ```
public struct TimelineBuilder: Sendable {

    public init() {}

    /// Builds a Timeline and FileAssetProvider from a definition.
    ///
    /// - Parameters:
    ///   - definition: The parsed JSON timeline definition.
    ///   - assetMap: Map of absolute file paths to stable UUIDs.
    ///   - context: The SwiftData model context.
    /// - Returns: A tuple of (Timeline, FileAssetProvider).
    /// - Throws: `TimelineBuilderError` if construction fails.
    @MainActor
    public func build(
        from definition: TimelineDefinition,
        assetMap: [String: UUID],
        in context: ModelContext
    ) async throws -> (Timeline, FileAssetProvider) {
        // Create Timeline with name
        let timeline = Timeline(name: definition.timeline.name)

        // Map format configuration
        let videoFormat = try mapVideoFormat(from: definition.timeline.format)
        timeline.videoFormat = videoFormat

        // Map audio configuration
        let (audioLayout, audioRate) = try mapAudioConfig(from: definition.timeline.audio)
        timeline.audioLayout = audioLayout
        timeline.audioRate = audioRate

        // Create FileAssetProvider
        let provider = try await createFileAssetProvider(
            from: definition,
            assetMap: assetMap
        )

        // Process clips (synchronous processing to avoid data races)
        let parser = TimeStringParser()
        let probe = MediaProbe()

        for clip in definition.clips {
            if clip.type == .marker {
                processMarker(clip, timeline: timeline)
            } else {
                // Parse offset and duration
                let offset = try parser.parse(clip.offset)

                guard let durationStr = clip.duration else {
                    throw TimelineBuilderError.missingDuration(clipName: clip.name)
                }
                let duration = try parser.parse(durationStr)

                // Look up asset UUID
                guard let file = clip.file else {
                    throw TimelineBuilderError.missingFile(clipName: clip.name)
                }

                guard let assetUUID = assetMap[file] else {
                    throw TimelineBuilderError.assetNotFoundInMap(path: file)
                }

                // Create TimelineClip
                let timelineClip = TimelineClip(
                    name: clip.name,
                    assetStorageId: assetUUID,
                    offset: offset,
                    duration: duration,
                    lane: clip.lane ?? 0
                )

                // Apply optional properties
                if let volume = clip.volume {
                    timelineClip.volumeDb = volume
                }

                if let opacity = clip.opacity {
                    timelineClip.opacity = opacity
                }

                // Append to timeline
                timeline.clips.append(timelineClip)
            }
        }

        // Insert timeline in context
        context.insert(timeline)

        return (timeline, provider)
    }

    // MARK: - Format Mapping

    /// Maps FormatConfig to VideoFormat.
    private func mapVideoFormat(from config: FormatConfig) throws -> VideoFormat {
        // Parse frame rate
        let parser = FrameRateParser()
        let frameRate = try parser.parse(config.frameRate)

        // Map color space (optional)
        let colorSpace: ColorSpace
        if let colorSpaceStr = config.colorSpace {
            guard let mappedColorSpace = ColorSpace.from(string: colorSpaceStr) else {
                throw TimelineBuilderError.invalidColorSpace(colorSpaceStr)
            }
            colorSpace = mappedColorSpace
        } else {
            colorSpace = .rec709  // Default
        }

        return VideoFormat(
            width: config.width,
            height: config.height,
            frameRate: frameRate,
            colorSpace: colorSpace
        )
    }

    /// Maps AudioConfig to AudioLayout and AudioRate.
    private func mapAudioConfig(from config: AudioConfig) throws -> (AudioLayout, AudioRate) {
        // Map layout
        guard let layout = AudioLayout(rawValue: config.layout.lowercased()) else {
            throw TimelineBuilderError.invalidAudioLayout(config.layout)
        }

        // Map rate
        let rateStr = config.rate.replacingOccurrences(of: "kHz", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")

        let rateInt: Int
        if let parsed = Int(rateStr) {
            rateInt = parsed
        } else if let parsed = Double(rateStr) {
            rateInt = Int(parsed * 1000)
        } else {
            throw TimelineBuilderError.invalidAudioRate(config.rate)
        }

        guard let rate = AudioRate(sampleRate: rateInt) else {
            throw TimelineBuilderError.invalidAudioRate(config.rate)
        }

        return (layout, rate)
    }

    // MARK: - Asset Provider Creation

    /// Creates a FileAssetProvider with one entry per unique file.
    private func createFileAssetProvider(
        from definition: TimelineDefinition,
        assetMap: [String: UUID]
    ) async throws -> FileAssetProvider {
        var registry: [UUID: FileAssetEntry] = [:]

        // Group clips by file path
        var fileToClips: [String: [ClipDefinition]] = [:]
        for clip in definition.clips where clip.file != nil {
            let filePath = clip.file!
            fileToClips[filePath, default: []].append(clip)
        }

        // Create one entry per unique file
        for (filePath, clips) in fileToClips {
            guard let uuid = assetMap[filePath] else {
                throw TimelineBuilderError.assetNotFoundInMap(path: filePath)
            }

            // Use first clip for metadata
            let firstClip = clips[0]

            // Derive metadata from clip
            let entry = try await deriveFileAssetEntry(
                from: firstClip,
                filePath: filePath
            )

            registry[uuid] = entry
        }

        return FileAssetProvider(registry: registry)
    }

    /// Derives a FileAssetEntry from a clip and file path.
    private func deriveFileAssetEntry(
        from clip: ClipDefinition,
        filePath: String
    ) async throws -> FileAssetEntry {
        guard let file = clip.file else {
            throw TimelineBuilderError.missingFile(clipName: clip.name)
        }

        let fileURL = URL(fileURLWithPath: file)

        // Probe file for metadata
        let probe = MediaProbe()
        let mimeType = probe.mimeType(of: fileURL)
        let duration = try? await probe.duration(of: fileURL)

        // Determine content type
        let hasVideo: Bool
        let hasAudio: Bool
        switch clip.type {
        case .video:
            hasVideo = true
            hasAudio = true  // Video files typically have audio
        case .audio:
            hasVideo = false
            hasAudio = true
        case .image:
            hasVideo = false
            hasAudio = false
        case .marker:
            hasVideo = false
            hasAudio = false
        }

        return FileAssetEntry(
            fileURL: fileURL,
            name: clip.name,
            mimeType: mimeType,
            durationSeconds: duration,
            hasVideo: hasVideo,
            hasAudio: hasAudio
        )
    }

    // MARK: - Marker Processing

    /// Processes a marker clip and adds to timeline.
    private func processMarker(
        _ clip: ClipDefinition,
        timeline: Timeline
    ) {
        let parser = TimeStringParser()
        guard let offset = try? parser.parse(clip.offset) else {
            return  // Skip invalid markers
        }

        switch clip.markerType {
        case "chapter":
            let marker = ChapterMarker(
                start: offset,
                value: clip.name
            )
            timeline.chapterMarkers.append(marker)

        case "standard", nil:
            let marker = Marker(
                start: offset,
                value: clip.name
            )
            timeline.markers.append(marker)

        case "todo":
            // Note: Task markers stored as standard markers with completed=false
            let marker = Marker(
                start: offset,
                value: clip.name,
                completed: false
            )
            timeline.markers.append(marker)

        default:
            break  // Skip unsupported marker types
        }
    }
}

// MARK: - ColorSpace Mapping

extension ColorSpace {
    /// Creates a ColorSpace from a string value.
    ///
    /// Supports common color space names:
    /// - "rec709", "Rec. 709" → .rec709
    /// - "rec2020", "Rec. 2020" → .rec2020
    /// - "p3", "Display P3" → .p3d65
    static func from(string: String) -> ColorSpace? {
        let normalized = string.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")

        switch normalized {
        case "rec709", "709":
            return .rec709
        case "rec2020", "2020":
            return .rec2020
        case "srgb":
            return .sRGB
        default:
            return nil
        }
    }
}
