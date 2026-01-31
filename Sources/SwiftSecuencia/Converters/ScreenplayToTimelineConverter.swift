//
//  ScreenplayToTimelineConverter.swift
//  SwiftSecuencia
//
//  Converts screenplay elements to Timeline with proper timing and progress tracking.
//

import Foundation
import SwiftData
import SwiftCompartido

/// Converts screenplay elements with generated audio into a Timeline.
///
/// ScreenplayToTimelineConverter takes a `ScreenplayElementsReference` (or direct access to elements)
/// and creates a properly-timed Timeline with clips sequenced based on audio durations.
///
/// ## Basic Usage
///
/// ```swift
/// let converter = ScreenplayToTimelineConverter()
/// let progress = Progress(totalUnitCount: 100)
///
/// let timeline = try await converter.convertToTimeline(
///     screenplayName: "My Script",
///     elements: screenplayElements,
///     modelContext: context,
///     progress: progress
/// )
/// ```
///
/// ## Progress Tracking
///
/// The converter reports progress in phases:
/// - 10%: Validating screenplay elements
/// - 80%: Creating timeline clips (proportional per clip)
/// - 10%: Finalizing timeline
///
/// ## Features
///
/// - Automatically sequences clips based on audio duration
/// - Handles missing durations with sensible defaults
/// - Filters for audio-only elements
/// - Supports progress cancellation
/// - Works on both macOS and iOS
public struct ScreenplayToTimelineConverter {

    /// Default duration for clips without duration metadata (3 seconds)
    private static let defaultClipDuration: Double = 3.0

    /// Creates a new screenplay to timeline converter.
    public init() {}

    /// Converts screenplay elements to a Timeline with sequenced audio clips (direct element access).
    ///
    /// Use this variant when you already have direct access to TypedDataStorage elements.
    ///
    /// ## Dual Dialogue Support
    ///
    /// When `audioMetadata` is provided with dual dialogue information, clips are automatically
    /// placed on different lanes at the same offset. Clips with the same `dualDialogueGroupId`
    /// are placed simultaneously, with lane assignment based on `dualDialogueIndex`.
    ///
    /// - Parameters:
    ///   - screenplayName: Name for the timeline
    ///   - audioElements: Array of TypedDataStorage with audio content
    ///   - audioMetadata: Optional array of ScreenplayMetadata (same length as audioElements)
    ///   - videoFormat: Video format for the timeline (default: HD 1080p @ 24fps)
    ///   - audioLayout: Audio layout (default: stereo)
    ///   - audioRate: Audio sample rate (default: 48kHz)
    ///   - lane: Default timeline lane for non-dual-dialog clips (default: 0 for primary)
    ///   - progress: Optional Progress object for tracking
    /// - Returns: A Timeline with sequenced audio clips
    /// - Throws: ConverterError if conversion fails
    @MainActor
    public func convertToTimeline(
        screenplayName: String,
        audioElements: [TypedDataStorage],
        audioMetadata: [ScreenplayMetadata]? = nil,
        videoFormat: VideoFormat = .hd1080p(frameRate: .fps24),
        audioLayout: AudioLayout = .stereo,
        audioRate: AudioRate = .rate48kHz,
        lane: Int = 0,
        progress: Progress? = nil
    ) async throws -> Timeline {
        // Set up progress tracking
        let conversionProgress = progress ?? Progress(totalUnitCount: 100)
        conversionProgress.localizedDescription = "Converting audio to timeline"

        // Phase 1: Validate elements (10%)
        conversionProgress.localizedAdditionalDescription = "Validating audio elements"

        guard !audioElements.isEmpty else {
            throw ConverterError.noAudioElements
        }

        // Filter for audio only
        let audioFiles = audioElements.filter { $0.mimeType.hasPrefix("audio/") }

        guard !audioFiles.isEmpty else {
            throw ConverterError.noAudioElements
        }

        // Validate metadata length if provided
        if let metadata = audioMetadata {
            guard metadata.count == audioElements.count else {
                throw ConverterError.metadataMismatch(
                    audioCount: audioElements.count,
                    metadataCount: metadata.count
                )
            }
        }

        conversionProgress.completedUnitCount = 10

        // Check for cancellation
        if conversionProgress.isCancelled {
            throw ConverterError.cancelled
        }

        // Phase 2: Create timeline and clips (80%)
        conversionProgress.localizedAdditionalDescription = "Creating timeline clips"

        let timeline = Timeline(
            name: screenplayName,
            videoFormat: videoFormat,
            audioLayout: audioLayout,
            audioRate: audioRate
        )

        // Process with dual dialogue support if metadata is provided
        if let metadata = audioMetadata {
            try processWithDualDialogue(
                timeline: timeline,
                audioFiles: audioFiles,
                audioMetadata: metadata,
                audioElements: audioElements,
                defaultLane: lane,
                progress: conversionProgress
            )
        } else {
            // Legacy sequential processing (backward compatible)
            processSequential(
                timeline: timeline,
                audioFiles: audioFiles,
                defaultLane: lane,
                progress: conversionProgress
            )
        }

        // Phase 3: Finalize (10%)
        conversionProgress.localizedAdditionalDescription = "Finalizing timeline"
        conversionProgress.completedUnitCount = 100

        return timeline
    }

    // MARK: - Dual Dialogue Processing

    /// Processes audio elements with dual dialogue support.
    ///
    /// Groups clips by dual dialogue group ID and places them at the same offset on different lanes.
    private func processWithDualDialogue(
        timeline: Timeline,
        audioFiles: [TypedDataStorage],
        audioMetadata: [ScreenplayMetadata],
        audioElements: [TypedDataStorage],
        defaultLane: Int,
        progress: Progress
    ) throws {
        // Track dual dialogue groups
        struct DualDialogGroup {
            var clips: [(TypedDataStorage, ScreenplayMetadata)]
            var maxDuration: Double
        }

        var dualDialogGroups: [UUID: DualDialogGroup] = [:]
        var sequentialElements: [(TypedDataStorage, ScreenplayMetadata)] = []

        // Build mapping from audio storage ID to metadata
        var metadataMap: [UUID: ScreenplayMetadata] = [:]
        for (audio, meta) in zip(audioElements, audioMetadata) {
            metadataMap[audio.id] = meta
        }

        // Group elements
        for audioStorage in audioFiles {
            guard let metadata = metadataMap[audioStorage.id] else {
                // No metadata: treat as sequential
                let defaultMetadata = ScreenplayMetadata(elementType: "Audio")
                sequentialElements.append((audioStorage, defaultMetadata))
                continue
            }

            if metadata.isDualDialogue, let groupId = metadata.dualDialogueGroupId {
                // Part of dual dialogue group
                let duration = audioStorage.durationSeconds ?? Self.defaultClipDuration

                if dualDialogGroups[groupId] == nil {
                    dualDialogGroups[groupId] = DualDialogGroup(clips: [], maxDuration: 0.0)
                }

                // Copy to local variable to avoid exclusive access violation
                var group = dualDialogGroups[groupId]!
                group.clips.append((audioStorage, metadata))
                group.maxDuration = max(group.maxDuration, duration)
                dualDialogGroups[groupId] = group
            } else {
                // Sequential element
                sequentialElements.append((audioStorage, metadata))
            }
        }

        // Process elements in order
        var currentOffset = Timecode.zero
        var processedGroups: Set<UUID> = []
        let totalElements = audioFiles.count
        let clipProgressIncrement = 80.0 / Double(totalElements)
        var processedCount = 0

        // Iterate through audio files to preserve order
        for audioStorage in audioFiles {
            // Check for cancellation
            if progress.isCancelled {
                throw ConverterError.cancelled
            }

            guard let metadata = metadataMap[audioStorage.id] else { continue }

            if metadata.isDualDialogue, let groupId = metadata.dualDialogueGroupId {
                // Skip if already processed
                guard !processedGroups.contains(groupId) else { continue }

                // Process entire dual dialogue group
                if let group = dualDialogGroups[groupId] {
                    for (audio, meta) in group.clips {
                        let duration = audio.durationSeconds ?? Self.defaultClipDuration
                        let clipLane = meta.dualDialogueIndex ?? defaultLane

                        let clipName = audio.prompt
                            .prefix(50)
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        let clip = TimelineClip(
                            name: clipName,
                            assetStorageId: audio.id,
                            offset: currentOffset,
                            duration: Timecode(seconds: duration),
                            sourceStart: .zero,
                            lane: clipLane
                        )

                        // Store metadata in clip
                        clip.metadata = meta.toMetadata()

                        timeline.insertClip(clip, at: currentOffset, lane: clipLane)
                        processedCount += 1
                    }

                    // Advance offset by max duration
                    currentOffset = currentOffset + Timecode(seconds: group.maxDuration)
                    processedGroups.insert(groupId)
                }
            } else {
                // Sequential element
                let duration = audioStorage.durationSeconds ?? Self.defaultClipDuration

                let clipName = audioStorage.prompt
                    .prefix(50)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let clip = TimelineClip(
                    name: clipName,
                    assetStorageId: audioStorage.id,
                    offset: currentOffset,
                    duration: Timecode(seconds: duration),
                    sourceStart: .zero,
                    lane: defaultLane
                )

                // Store metadata in clip
                clip.metadata = metadata.toMetadata()

                timeline.insertClip(clip, at: currentOffset, lane: defaultLane)

                // Advance offset
                currentOffset = currentOffset + Timecode(seconds: duration)
                processedCount += 1
            }

            // Update progress
            progress.completedUnitCount = Int64(10 + Int((Double(processedCount) * clipProgressIncrement)))
        }
    }

    /// Processes audio elements sequentially (legacy mode, no dual dialogue).
    private func processSequential(
        timeline: Timeline,
        audioFiles: [TypedDataStorage],
        defaultLane: Int,
        progress: Progress
    ) {
        var currentOffset = Timecode.zero
        let clipProgressIncrement = 80.0 / Double(audioFiles.count)

        for (index, audioStorage) in audioFiles.enumerated() {
            // Get duration from metadata or use default
            let durationSeconds = audioStorage.durationSeconds ?? Self.defaultClipDuration
            let duration = Timecode(seconds: durationSeconds)

            // Create clip with truncated name
            let clipName = audioStorage.prompt
                .prefix(50)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let clip = TimelineClip(
                name: clipName,
                assetStorageId: audioStorage.id,
                duration: duration,
                sourceStart: .zero
            )

            // Insert clip at current offset
            timeline.insertClip(clip, at: currentOffset, lane: defaultLane)

            // Advance offset
            currentOffset = currentOffset + duration

            // Update progress
            progress.completedUnitCount = Int64(10 + Int((Double(index + 1) * clipProgressIncrement)))
        }
    }

}

// MARK: - Errors

/// Errors that can occur during screenplay to timeline conversion.
public enum ConverterError: Error, LocalizedError, Equatable {
    case noAudioElements
    case cancelled
    case metadataMismatch(audioCount: Int, metadataCount: Int)

    public var errorDescription: String? {
        switch self {
        case .noAudioElements:
            return "No audio elements found in screenplay"
        case .cancelled:
            return "Conversion was cancelled"
        case .metadataMismatch(let audioCount, let metadataCount):
            return "Metadata count (\(metadataCount)) does not match audio count (\(audioCount))"
        }
    }
}
