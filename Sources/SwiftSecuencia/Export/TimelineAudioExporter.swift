//
//  TimelineAudioExporter.swift
//  SwiftSecuencia
//
//  Exports Timeline to multi-track audio files using AVMutableComposition.
//

import Foundation
import SwiftData
import SwiftCompartido
import AVFoundation

/// Audio export format options.
public enum AudioExportFormat: String, Sendable, Codable {
    /// M4A format (stereo mixdown, AAC compressed, 256 kbps high quality)
    case m4a

    /// File extension for this format
    public var fileExtension: String {
        return "m4a"
    }

    /// AVFoundation file type identifier
    public var avFileType: AVFileType {
        return .m4a
    }

    /// Export preset name for AVAssetExportSession
    var exportPreset: String {
        return AVAssetExportPresetAppleM4A
    }
}

/// Errors that can occur during audio export.
public enum AudioExportError: Error, LocalizedError, Equatable {
    case emptyTimeline
    case missingAsset(assetId: UUID)
    case invalidAudioData(assetId: UUID, reason: String)
    case exportFailed(reason: String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .emptyTimeline:
            return "Timeline has no audio clips to export"
        case .missingAsset(let assetId):
            return "Missing asset: \(assetId)"
        case .invalidAudioData(let assetId, let reason):
            return "Invalid audio data for asset \(assetId): \(reason)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .cancelled:
            return "Export operation was cancelled"
        }
    }
}

/// Exports Timeline objects to M4A stereo audio files.
///
/// TimelineAudioExporter creates M4A audio files using AVMutableComposition and AVAssetExportSession.
/// All timeline lanes are mixed down to stereo with AAC compression at 256 kbps.
///
/// ## Basic Usage
///
/// ```swift
/// let exporter = TimelineAudioExporter()
/// try await exporter.exportAudio(
///     timeline: myTimeline,
///     modelContext: context,
///     to: outputURL
/// )
/// ```
///
/// ## Stereo Mixdown
///
/// All timeline lanes are mixed down to a single stereo track with AAC compression:
/// - All clips are layered and mixed automatically
/// - Overlapping clips are summed (mixed together)
/// - Final output is high-quality AAC at 256 kbps
///
/// ## Progress Reporting
///
/// ```swift
/// let progress = Progress(totalUnitCount: 100)
/// try await exporter.exportAudio(
///     timeline: myTimeline,
///     modelContext: context,
///     to: outputURL,
///     progress: progress
/// )
/// ```
///
/// ## Multi-Track Export
///
/// For multi-track uncompressed audio (CAF/WAV), export the timeline to Final Cut Pro
/// using `FCPXMLBundleExporter` instead.
public struct TimelineAudioExporter {

    /// Standard sample rate for export (44.1kHz)
    private static let sampleRate: Double = 44100.0

    /// Creates an audio exporter.
    public init() {}

    /// Exports a timeline to an M4A audio file.
    ///
    /// - Parameters:
    ///   - timeline: The timeline to export.
    ///   - modelContext: The model context to fetch assets from.
    ///   - outputURL: The destination file URL.
    ///   - progress: Optional Progress object for tracking.
    /// - Returns: URL of the created M4A file.
    /// - Throws: AudioExportError if export fails.
    @MainActor
    public func exportAudio(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        to outputURL: URL,
        progress: Progress? = nil
    ) async throws -> URL {
        // Set up progress tracking
        let exportProgress = progress ?? Progress(totalUnitCount: 100)
        exportProgress.localizedDescription = "Exporting audio"

        // Step 1: Validate timeline (5%)
        exportProgress.localizedAdditionalDescription = "Validating timeline"
        guard !timeline.clips.isEmpty else {
            throw AudioExportError.emptyTimeline
        }

        // Filter for audio clips only
        let audioClips = try filterAudioClips(timeline.clips, modelContext: modelContext)
        guard !audioClips.isEmpty else {
            throw AudioExportError.emptyTimeline
        }

        exportProgress.completedUnitCount = 5

        // Check for cancellation
        if exportProgress.isCancelled {
            throw AudioExportError.cancelled
        }

        // Step 2: Build composition (20%)
        exportProgress.localizedAdditionalDescription = "Building composition"
        let (composition, tempFiles) = try await buildComposition(
            from: timeline,
            audioClips: audioClips,
            modelContext: modelContext
        )
        exportProgress.completedUnitCount = 25

        // Check for cancellation
        if exportProgress.isCancelled {
            // Clean up temp files on cancellation
            cleanupTempFiles(tempFiles)
            throw AudioExportError.cancelled
        }

        // Step 3: Export composition (70%)
        exportProgress.localizedAdditionalDescription = "Exporting audio"
        do {
            try await exportComposition(
                composition,
                to: outputURL,
                progress: exportProgress
            )

            // Clean up temp files after successful export
            cleanupTempFiles(tempFiles)

            exportProgress.completedUnitCount = 100
            exportProgress.localizedAdditionalDescription = "Export complete"

            return outputURL
        } catch {
            // Clean up temp files on error
            cleanupTempFiles(tempFiles)
            throw error
        }
    }

    // MARK: - Audio Clip Filtering

    /// Filters timeline clips to include only audio clips.
    private func filterAudioClips(
        _ clips: [TimelineClip],
        modelContext: SwiftData.ModelContext
    ) throws -> [TimelineClip] {
        var audioClips: [TimelineClip] = []

        for clip in clips {
            // Fetch the asset
            guard let asset = clip.fetchAsset(in: modelContext) else {
                throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
            }

            // Check if it's audio
            if asset.mimeType.hasPrefix("audio/") {
                audioClips.append(clip)
            }
            // Skip video/image clips (out of scope)
        }

        return audioClips
    }

    // MARK: - Composition Building

    /// Builds an AVMutableComposition from timeline clips for stereo mixdown.
    /// Returns both the composition and temporary file URLs that must be kept until export completes.
    @MainActor
    private func buildComposition(
        from timeline: Timeline,
        audioClips: [TimelineClip],
        modelContext: SwiftData.ModelContext
    ) async throws -> (composition: AVMutableComposition, tempFiles: [URL]) {
        let composition = AVMutableComposition()
        var tempFiles: [URL] = []

        // Sort all clips by offset
        let sortedClips = audioClips.sorted { $0.offset < $1.offset }

        // Insert each clip into its own track to avoid conflicts
        // AVMutableComposition will automatically mix multiple tracks
        for clip in sortedClips {
            // Create a new track for each clip
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw AudioExportError.exportFailed(reason: "Failed to create composition track")
            }

            let tempURL = try await insertClipIntoTrack(
                clip: clip,
                track: compositionTrack,
                modelContext: modelContext
            )
            tempFiles.append(tempURL)
        }

        return (composition, tempFiles)
    }

    /// Inserts a timeline clip into a composition track.
    /// Returns the temporary file URL that must be kept until export completes.
    @MainActor
    private func insertClipIntoTrack(
        clip: TimelineClip,
        track: AVMutableCompositionTrack,
        modelContext: SwiftData.ModelContext
    ) async throws -> URL {
        // Fetch the asset
        guard let asset = clip.fetchAsset(in: modelContext) else {
            throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
        }

        guard let audioData = asset.binaryValue else {
            throw AudioExportError.invalidAudioData(assetId: asset.id, reason: "No binary data")
        }

        // Create temporary file for the audio
        // IMPORTANT: Do NOT delete this file until after export completes!
        // AVMutableComposition references the file by URL, not by loading it into memory
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension(for: asset.mimeType))

        try audioData.write(to: tempURL)

        // Create AVAsset from the audio file
        let avAsset = AVURLAsset(url: tempURL)

        // Get the audio track from the asset
        guard let sourceTrack = try await avAsset.loadTracks(withMediaType: .audio).first else {
            throw AudioExportError.invalidAudioData(assetId: asset.id, reason: "No audio track found")
        }

        // Calculate time range for insertion
        let startTime = CMTime(seconds: clip.sourceStart.seconds, preferredTimescale: 600)
        let duration = CMTime(seconds: clip.duration.seconds, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, duration: duration)

        // Calculate insertion time on the composition track
        let insertTime = CMTime(seconds: clip.offset.seconds, preferredTimescale: 600)

        // Insert the audio into the composition track
        try track.insertTimeRange(timeRange, of: sourceTrack, at: insertTime)

        // Return the temp URL so caller can keep it alive until export completes
        return tempURL
    }

    // MARK: - Composition Export

    /// Exports the composition to an M4A file.
    @MainActor
    private func exportComposition(
        _ composition: AVMutableComposition,
        to outputURL: URL,
        progress: Progress
    ) async throws {
        // Validate composition has audio tracks
        let audioTracks = composition.tracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioExportError.exportFailed(reason: "Composition has no audio tracks")
        }

        // Remove existing file if present
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExportError.exportFailed(reason: "Failed to create export session")
        }

        // Output detailed error information
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Start export using older callback-based API for better error reporting
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }

        // Check export status
        switch exportSession.status {
        case .completed:
            break
        case .failed:
            let errorDetail = exportSession.error?.localizedDescription ?? "Unknown error"
            throw AudioExportError.exportFailed(reason: "Export failed: \(errorDetail)")
        case .cancelled:
            throw AudioExportError.cancelled
        default:
            throw AudioExportError.exportFailed(reason: "Export ended with unexpected status: \(exportSession.status.rawValue)")
        }

        // Update progress to complete
        progress.completedUnitCount = 100
    }

    // MARK: - Helpers

    /// Cleans up temporary files created during composition building.
    private func cleanupTempFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Returns file extension for MIME type.
    private func fileExtension(for mimeType: String) -> String {
        let components = mimeType.split(separator: "/")
        guard components.count == 2 else { return "dat" }

        let subtype = String(components[1])

        switch subtype {
        case "mpeg": return "mp3"
        case "wav", "x-wav", "vnd.wave": return "wav"
        case "aiff", "x-aiff": return "aiff"
        case "mp4": return "m4a"
        case "aac": return "aac"
        default: return subtype
        }
    }
}
