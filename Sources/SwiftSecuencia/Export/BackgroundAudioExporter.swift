//
//  BackgroundAudioExporter.swift
//  SwiftSecuencia
//
//  Background audio export using @ModelActor for safe SwiftData access.
//

import Foundation
import SwiftData
import SwiftCompartido
import AVFoundation

/// Background audio exporter using @ModelActor for safe SwiftData concurrency.
///
/// This actor performs audio export on a background thread, safely reading from SwiftData
/// without blocking the main thread. It uses read-only SwiftData access and streams
/// audio data from assets one at a time to minimize memory usage.
///
/// ## Usage
///
/// ```swift
/// let exporter = BackgroundAudioExporter(modelContainer: container)
/// let outputURL = try await exporter.exportAudio(
///     timelineID: timeline.persistentModelID,
///     to: destinationURL,
///     progress: progress
/// )
/// ```
///
/// ## Thread Safety
///
/// - Initialization on background thread ensures all operations stay off main thread
/// - Read-only SwiftData access via actor-isolated ModelContext
/// - Audio data loaded one asset at a time, written to temp files, then released
/// - Progress updates are thread-safe by Foundation design
@ModelActor
public actor BackgroundAudioExporter {

    /// Exports a timeline's audio to M4A format.
    ///
    /// This method:
    /// 1. Fetches the Timeline by ID (read-only)
    /// 2. Iterates through audio clips
    /// 3. Loads each asset's binary data one at a time
    /// 4. Writes to temp files for AVFoundation
    /// 5. Builds AVMutableComposition
    /// 6. Exports to M4A
    /// 7. Cleans up temp files
    ///
    /// - Parameters:
    ///   - timelineID: Persistent identifier of the Timeline to export
    ///   - outputURL: Destination file URL for the M4A file
    ///   - progress: Optional Progress object for tracking
    /// - Returns: URL of the created M4A file
    /// - Throws: AudioExportError if export fails
    public func exportAudio(
        timelineID: PersistentIdentifier,
        to outputURL: URL,
        progress: Progress? = nil
    ) async throws -> URL {
        // Set up progress tracking
        let exportProgress = progress ?? Progress(totalUnitCount: 100)
        exportProgress.localizedDescription = "Exporting audio"

        // Step 1: Fetch Timeline (5%)
        exportProgress.localizedAdditionalDescription = "Loading timeline"

        guard let timeline = self[timelineID, as: Timeline.self] else {
            throw AudioExportError.exportFailed(reason: "Timeline not found")
        }

        guard !timeline.clips.isEmpty else {
            throw AudioExportError.emptyTimeline
        }

        updateProgress(exportProgress, completedUnits: 5, description: nil)

        // Check for cancellation
        if exportProgress.isCancelled {
            throw AudioExportError.cancelled
        }

        // Step 2: Filter audio clips (5%)
        updateProgress(exportProgress, completedUnits: nil, description: "Filtering audio clips")
        let audioClips = try filterAudioClips(timeline.clips)

        guard !audioClips.isEmpty else {
            throw AudioExportError.emptyTimeline
        }

        updateProgress(exportProgress, completedUnits: 10, description: nil)

        // Check for cancellation
        if exportProgress.isCancelled {
            throw AudioExportError.cancelled
        }

        // Step 3: Build composition (30%)
        updateProgress(exportProgress, completedUnits: nil, description: "Building composition")
        let (composition, tempFiles) = try await buildComposition(
            from: timeline,
            audioClips: audioClips,
            progress: exportProgress
        )
        updateProgress(exportProgress, completedUnits: 40, description: nil)

        // Check for cancellation
        if exportProgress.isCancelled {
            cleanupTempFiles(tempFiles)
            throw AudioExportError.cancelled
        }

        // Step 4: Export composition (60%)
        updateProgress(exportProgress, completedUnits: nil, description: "Exporting audio")
        do {
            try await exportComposition(
                composition,
                to: outputURL,
                progress: exportProgress
            )

            // Clean up temp files after successful export
            cleanupTempFiles(tempFiles)

            updateProgress(exportProgress, completedUnits: 100, description: "Export complete")

            return outputURL
        } catch {
            // Clean up temp files on error
            cleanupTempFiles(tempFiles)
            throw error
        }
    }

    // MARK: - Audio Clip Filtering

    /// Filters timeline clips to include only audio clips.
    private func filterAudioClips(_ clips: [TimelineClip]) throws -> [TimelineClip] {
        var audioClips: [TimelineClip] = []

        for clip in clips {
            // Fetch the asset using actor-isolated modelContext
            guard let asset = clip.fetchAsset(in: modelContext) else {
                throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
            }

            // Check if it's audio
            if asset.mimeType.hasPrefix("audio/") {
                audioClips.append(clip)
            }
            // Skip video/image clips
        }

        return audioClips
    }

    // MARK: - Composition Building

    /// Builds an AVMutableComposition from timeline clips for stereo mixdown.
    /// Returns both the composition and temporary file URLs that must be kept until export completes.
    private func buildComposition(
        from timeline: Timeline,
        audioClips: [TimelineClip],
        progress: Progress
    ) async throws -> (composition: AVMutableComposition, tempFiles: [URL]) {
        let composition = AVMutableComposition()
        var tempFiles: [URL] = []

        // Sort all clips by offset
        let sortedClips = audioClips.sorted { $0.offset < $1.offset }

        let clipProgressIncrement = 30.0 / Double(sortedClips.count)

        // Insert each clip into its own track to avoid conflicts
        // AVMutableComposition will automatically mix multiple tracks
        for (index, clip) in sortedClips.enumerated() {
            // Check for cancellation
            if progress.isCancelled {
                cleanupTempFiles(tempFiles)
                throw AudioExportError.cancelled
            }

            // Update progress with detailed description
            updateProgress(progress, completedUnits: nil, description: "Loading audio clip \(index + 1) of \(sortedClips.count)")

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
                progress: progress,
                index: index + 1,
                total: sortedClips.count
            )
            tempFiles.append(tempURL)

            // Update progress
            updateProgress(progress, completedUnits: Int64(10 + Int((Double(index + 1) * clipProgressIncrement))), description: nil)
        }

        return (composition, tempFiles)
    }

    /// Inserts a timeline clip into a composition track.
    /// Returns the temporary file URL that must be kept until export completes.
    ///
    /// IMPORTANT: Loads audio data into memory only for this clip, writes to temp file,
    /// then releases. AVFoundation will stream from temp files.
    private func insertClipIntoTrack(
        clip: TimelineClip,
        track: AVMutableCompositionTrack,
        progress: Progress,
        index: Int,
        total: Int
    ) async throws -> URL {
        // Fetch the asset using actor-isolated modelContext
        updateProgress(progress, completedUnits: nil, description: "Fetching clip \(index) of \(total) from storage")
        guard let asset = clip.fetchAsset(in: modelContext) else {
            throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
        }

        guard let audioData = asset.binaryValue else {
            throw AudioExportError.invalidAudioData(assetId: asset.id, reason: "No binary data")
        }

        // Create temporary file for the audio
        // IMPORTANT: Do NOT delete this file until after export completes!
        // AVMutableComposition references the file by URL, not by loading it into memory
        updateProgress(progress, completedUnits: nil, description: "Writing clip \(index) of \(total) to temp file")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension(for: asset.mimeType))

        try audioData.write(to: tempURL)

        // Release the audio data from memory now that it's written to disk
        // (Swift will handle this, but being explicit about the pattern)

        // Create AVAsset from the audio file
        updateProgress(progress, completedUnits: nil, description: "Processing clip \(index) of \(total)")
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
        updateProgress(progress, completedUnits: nil, description: "Adding clip \(index) of \(total) to composition")
        try track.insertTimeRange(timeRange, of: sourceTrack, at: insertTime)

        // Return the temp URL so caller can keep it alive until export completes
        return tempURL
    }

    // MARK: - Composition Export

    /// Exports the composition to an M4A file.
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

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Use modern async API for export
        // Note: AVAssetExportSession internally updates its progress property,
        // but we can't easily observe it from an actor context without complexity.
        // The export will report completion when done.
        updateProgress(progress, completedUnits: nil, description: "Encoding M4A audio")

        try await exportSession.export(to: outputURL, as: .m4a)

        // Update progress to complete
        updateProgress(progress, completedUnits: 100, description: "Export complete")
    }

    // MARK: - Helpers

    /// Updates progress on the main actor to ensure UI updates are triggered.
    ///
    /// Foundation.Progress is thread-safe, but SwiftUI's observation system works best
    /// when updates are dispatched explicitly to the main actor. This ensures progress
    /// bar updates are visible in the UI.
    ///
    /// This method uses `Task.detached` to avoid blocking the background export thread
    /// waiting for MainActor availability. Updates happen asynchronously.
    ///
    /// - Parameters:
    ///   - progress: The Progress object to update
    ///   - completedUnits: Optional new completedUnitCount value
    ///   - description: Optional new localizedAdditionalDescription value
    private func updateProgress(
        _ progress: Progress,
        completedUnits: Int64? = nil,
        description: String? = nil
    ) {
        // Fire-and-forget dispatch to MainActor
        // Don't await - this prevents blocking the export thread
        Task { @MainActor in
            if let completedUnits = completedUnits {
                progress.completedUnitCount = completedUnits
            }
            if let description = description {
                progress.localizedAdditionalDescription = description
            }
        }
    }

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
