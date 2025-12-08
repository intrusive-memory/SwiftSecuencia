//
//  ForegroundAudioExporter.swift
//  SwiftSecuencia
//
//  Foreground audio export that takes over the main thread for maximum performance.
//  Use this when speed matters more than UI responsiveness.
//

import Foundation
import SwiftData
import SwiftCompartido
import AVFoundation

/// Foreground audio exporter that runs on the main thread with maximum priority.
///
/// This exporter sacrifices UI responsiveness for maximum export speed by:
/// - Running all operations on the main thread (no actor context switching)
/// - Using direct ModelContext access (no cross-actor communication)
/// - Parallel file writes with high priority
/// - No progress update overhead
///
/// **When to use:**
/// - Export speed is critical
/// - UI blocking is acceptable
/// - User is actively waiting for export to complete
/// - Small to medium timelines (< 100 clips)
///
/// **When NOT to use:**
/// - User needs to interact with UI during export
/// - Very large timelines (high memory usage)
/// - Background processing is preferred
///
/// ## Usage
///
/// ```swift
/// @MainActor
/// func exportForeground() async {
///     let exporter = ForegroundAudioExporter()
///     let outputURL = try await exporter.exportAudio(
///         timeline: timeline,
///         modelContext: modelContext,
///         to: destinationURL,
///         progress: progress
///     )
/// }
/// ```
@MainActor
public struct ForegroundAudioExporter {

    public init() {}

    /// Exports a timeline's audio to M4A format on the main thread.
    ///
    /// This method blocks the main thread for maximum performance:
    /// 1. Fetches all clips and assets from SwiftData (main thread)
    /// 2. Loads all audio data into memory (main thread)
    /// 3. Writes all files to disk in parallel (high priority tasks)
    /// 4. Builds AVMutableComposition (main thread)
    /// 5. Exports to M4A (Apple encoder)
    ///
    /// **Warning:** This will freeze the UI during export. Use only when
    /// maximum speed is more important than UI responsiveness.
    ///
    /// - Parameters:
    ///   - timeline: The Timeline to export (main thread)
    ///   - modelContext: SwiftData ModelContext (main thread)
    ///   - outputURL: Destination file URL for the M4A file
    ///   - progress: Optional Progress object for tracking
    /// - Returns: URL of the created M4A file
    /// - Throws: AudioExportError if export fails
    public func exportAudio(
        timeline: Timeline,
        modelContext: ModelContext,
        to outputURL: URL,
        progress: Progress? = nil
    ) async throws -> URL {
        // Set up progress tracking
        let exportProgress = progress ?? Progress(totalUnitCount: 100)
        exportProgress.localizedDescription = "Exporting audio (foreground)"

        // Step 1: Filter audio clips (5%)
        exportProgress.localizedAdditionalDescription = "Loading timeline"
        let audioClips = try filterAudioClips(timeline.clips, modelContext: modelContext)

        guard !audioClips.isEmpty else {
            throw AudioExportError.emptyTimeline
        }

        exportProgress.completedUnitCount = 5

        // Check for cancellation
        if exportProgress.isCancelled {
            throw AudioExportError.cancelled
        }

        // Step 2: Build composition (35%)
        exportProgress.localizedAdditionalDescription = "Building composition"
        let (composition, tempFiles) = try await buildComposition(
            from: timeline,
            audioClips: audioClips,
            modelContext: modelContext,
            progress: exportProgress
        )
        exportProgress.completedUnitCount = 40

        // Check for cancellation
        if exportProgress.isCancelled {
            cleanupTempFiles(tempFiles)
            throw AudioExportError.cancelled
        }

        // Step 3: Export composition (60%)
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
        modelContext: ModelContext
    ) throws -> [TimelineClip] {
        var audioClips: [TimelineClip] = []

        for clip in clips {
            guard let asset = clip.fetchAsset(in: modelContext) else {
                throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
            }

            if asset.mimeType.hasPrefix("audio/") {
                audioClips.append(clip)
            }
        }

        return audioClips
    }

    // MARK: - Composition Building

    /// Builds an AVMutableComposition from timeline clips.
    ///
    /// This uses a two-phase approach optimized for main thread:
    /// 1. Load all audio data into memory (main thread - 15% progress)
    /// 2. Write all files to disk in parallel (high priority - 10% progress)
    /// 3. Build composition from files (main thread - 10% progress)
    private func buildComposition(
        from timeline: Timeline,
        audioClips: [TimelineClip],
        modelContext: ModelContext,
        progress: Progress
    ) async throws -> (composition: AVMutableComposition, tempFiles: [URL]) {
        let sortedClips = audioClips.sorted { $0.offset < $1.offset }

        // Phase 1: Load all audio data into memory (15%)
        progress.localizedAdditionalDescription = "Loading audio files"
        let audioData = try loadAllAudioData(
            clips: sortedClips,
            modelContext: modelContext,
            progress: progress
        )
        progress.completedUnitCount = 20

        // Check for cancellation
        if progress.isCancelled {
            throw AudioExportError.cancelled
        }

        // Phase 2: Write all files to disk in parallel (10%)
        progress.localizedAdditionalDescription = "Writing audio files"
        let tempFiles = try await writeAudioFilesToDisk(
            audioData: audioData,
            progress: progress
        )
        progress.completedUnitCount = 30

        // Check for cancellation
        if progress.isCancelled {
            cleanupTempFiles(tempFiles)
            throw AudioExportError.cancelled
        }

        // Phase 3: Build composition (10%)
        progress.localizedAdditionalDescription = "Building audio composition"
        let composition = try await buildCompositionFromFiles(
            clips: sortedClips,
            tempFiles: tempFiles,
            progress: progress
        )

        return (composition, tempFiles)
    }

    /// Phase 1: Load all audio data into memory.
    private func loadAllAudioData(
        clips: [TimelineClip],
        modelContext: ModelContext,
        progress: Progress
    ) throws -> [(data: Data, fileExtension: String)] {
        var audioData: [(data: Data, fileExtension: String)] = []
        audioData.reserveCapacity(clips.count)

        for (index, clip) in clips.enumerated() {
            guard let asset = clip.fetchAsset(in: modelContext) else {
                throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
            }

            guard let data = asset.binaryValue else {
                throw AudioExportError.invalidAudioData(assetId: asset.id, reason: "No binary data")
            }

            let ext = fileExtension(for: asset.mimeType)
            audioData.append((data: data, fileExtension: ext))

            // Update progress
            let progressUnits = Int64(5 + Int((Double(index + 1) / Double(clips.count)) * 15))
            progress.completedUnitCount = progressUnits
            progress.localizedAdditionalDescription = "Loaded \(index + 1) of \(clips.count) audio files"
        }

        return audioData
    }

    /// Phase 2: Write all audio files to disk in parallel.
    private func writeAudioFilesToDisk(
        audioData: [(data: Data, fileExtension: String)],
        progress: Progress
    ) async throws -> [URL] {
        // Write files in parallel using TaskGroup with high priority
        return try await withThrowingTaskGroup(of: (Int, URL).self) { group in
            var tempURLs: [Int: URL] = [:]

            for (index, audio) in audioData.enumerated() {
                // Each write task runs with high priority
                group.addTask(priority: .high) {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(audio.fileExtension)

                    try audio.data.write(to: tempURL)

                    return (index, tempURL)
                }
            }

            // Collect results maintaining order
            for try await (index, url) in group {
                tempURLs[index] = url

                let completedCount = tempURLs.count
                let progressUnits = Int64(20 + Int((Double(completedCount) / Double(audioData.count)) * 10))
                progress.completedUnitCount = progressUnits
                progress.localizedAdditionalDescription = "Wrote \(completedCount) of \(audioData.count) files"
            }

            // Return URLs in original order
            return audioData.indices.compactMap { tempURLs[$0] }
        }
    }

    /// Phase 3: Build AVMutableComposition from pre-written temp files.
    private func buildCompositionFromFiles(
        clips: [TimelineClip],
        tempFiles: [URL],
        progress: Progress
    ) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        let clipProgressIncrement = 10.0 / Double(clips.count)

        for (index, clip) in clips.enumerated() {
            // Check for cancellation
            if progress.isCancelled {
                throw AudioExportError.cancelled
            }

            progress.localizedAdditionalDescription = "Adding clip \(index + 1) of \(clips.count)"

            // Create a new track for each clip
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw AudioExportError.exportFailed(reason: "Failed to create composition track")
            }

            let tempURL = tempFiles[index]

            // Create AVAsset from the temp file
            let avAsset = AVURLAsset(url: tempURL)

            // Get the audio track
            guard let sourceTrack = try await avAsset.loadTracks(withMediaType: .audio).first else {
                throw AudioExportError.invalidAudioData(assetId: clip.assetStorageId, reason: "No audio track found")
            }

            // Calculate time ranges
            let startTime = CMTime(seconds: clip.sourceStart.seconds, preferredTimescale: 600)
            let duration = CMTime(seconds: clip.duration.seconds, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, duration: duration)
            let insertTime = CMTime(seconds: clip.offset.seconds, preferredTimescale: 600)

            // Insert into composition
            try compositionTrack.insertTimeRange(timeRange, of: sourceTrack, at: insertTime)

            // Update progress
            let progressUnits = Int64(30 + Int((Double(index + 1) * clipProgressIncrement)))
            progress.completedUnitCount = progressUnits
        }

        return composition
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

        progress.localizedAdditionalDescription = "Encoding M4A audio"

        // Export (Apple's encoder)
        try await exportSession.export(to: outputURL, as: .m4a)

        progress.completedUnitCount = 100
        progress.localizedAdditionalDescription = "Export complete"
    }

    // MARK: - Helpers

    /// Cleans up temporary files.
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
