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

        await updateProgress(exportProgress, completedUnits: 5, description: nil)

        // Check for cancellation
        if exportProgress.isCancelled {
            throw AudioExportError.cancelled
        }

        // Step 2: Filter audio clips (5%)
        await updateProgress(exportProgress, completedUnits: nil, description: "Filtering audio clips")
        let audioClips = try filterAudioClips(timeline.clips)

        guard !audioClips.isEmpty else {
            throw AudioExportError.emptyTimeline
        }

        await updateProgress(exportProgress, completedUnits: 10, description: nil)

        // Check for cancellation
        if exportProgress.isCancelled {
            throw AudioExportError.cancelled
        }

        // Step 3: Build composition (30%)
        await updateProgress(exportProgress, completedUnits: nil, description: "Building composition")
        let (composition, tempFiles) = try await buildComposition(
            from: timeline,
            audioClips: audioClips,
            progress: exportProgress
        )
        await updateProgress(exportProgress, completedUnits: 40, description: nil)

        // Check for cancellation
        if exportProgress.isCancelled {
            cleanupTempFiles(tempFiles)
            throw AudioExportError.cancelled
        }

        // Step 4: Export composition (60%)
        await updateProgress(exportProgress, completedUnits: nil, description: "Exporting audio")
        do {
            try await exportComposition(
                composition,
                to: outputURL,
                progress: exportProgress
            )

            // Clean up temp files after successful export
            cleanupTempFiles(tempFiles)

            await updateProgress(exportProgress, completedUnits: 100, description: "Export complete")

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
    ///
    /// This uses a two-phase approach for better performance:
    /// 1. Write all audio files to disk in parallel (Phase 1: 15% progress)
    /// 2. Build composition from files serially (Phase 2: 15% progress)
    private func buildComposition(
        from timeline: Timeline,
        audioClips: [TimelineClip],
        progress: Progress
    ) async throws -> (composition: AVMutableComposition, tempFiles: [URL]) {
        let sortedClips = audioClips.sorted { $0.offset < $1.offset }

        // Phase 1: Write all audio files to temp storage (in parallel - 15%)
        await updateProgress(progress, completedUnits: nil, description: "Writing audio files to disk")
        let tempFiles = try await writeAudioFilesToDisk(
            clips: sortedClips,
            progress: progress
        )

        // Check for cancellation after file writes
        if progress.isCancelled {
            cleanupTempFiles(tempFiles)
            throw AudioExportError.cancelled
        }

        await updateProgress(progress, completedUnits: 25, description: nil)

        // Phase 2: Build composition from temp files (15%)
        await updateProgress(progress, completedUnits: nil, description: "Building audio composition")
        let composition = try await buildCompositionFromFiles(
            clips: sortedClips,
            tempFiles: tempFiles,
            progress: progress
        )

        return (composition, tempFiles)
    }

    /// Phase 1: Write all audio clips to temp files in parallel.
    /// Returns array of temp file URLs in same order as clips.
    ///
    /// Strategy: Fetch all data on actor thread first, then write in parallel.
    /// This keeps all audio data in memory temporarily for faster parallel writes.
    private func writeAudioFilesToDisk(
        clips: [TimelineClip],
        progress: Progress
    ) async throws -> [URL] {
        // Step 1: Fetch all audio data on actor thread (serial, but fast)
        struct AudioFileData {
            let data: Data
            let fileExtension: String
        }

        var audioFiles: [AudioFileData] = []
        audioFiles.reserveCapacity(clips.count)

        for clip in clips {
            guard let asset = clip.fetchAsset(in: modelContext) else {
                throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
            }

            guard let audioData = asset.binaryValue else {
                throw AudioExportError.invalidAudioData(assetId: asset.id, reason: "No binary data")
            }

            // Compute file extension on actor thread
            let ext = fileExtension(for: asset.mimeType)
            audioFiles.append(AudioFileData(data: audioData, fileExtension: ext))
        }

        // Step 2: Write all files to disk in parallel (I/O heavy)
        return try await withThrowingTaskGroup(of: (Int, URL).self) { group in
            var tempURLs: [Int: URL] = [:]

            for (index, audioFile) in audioFiles.enumerated() {
                group.addTask {
                    // Create temp file URL
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(audioFile.fileExtension)

                    // Write to disk (this is the I/O operation that benefits from parallelization)
                    try audioFile.data.write(to: tempURL)

                    return (index, tempURL)
                }
            }

            // Collect results maintaining order
            for try await (index, url) in group {
                tempURLs[index] = url

                // Update progress for each completed file write
                let completedCount = tempURLs.count
                let progressUnits = Int64(10 + Int((Double(completedCount) / Double(clips.count)) * 15))
                await updateProgress(progress, completedUnits: progressUnits,
                                    description: "Wrote \(completedCount) of \(clips.count) audio files")
            }

            // Return URLs in original clip order
            return clips.indices.compactMap { tempURLs[$0] }
        }
    }

    /// Phase 2: Build AVMutableComposition from pre-written temp files.
    private func buildCompositionFromFiles(
        clips: [TimelineClip],
        tempFiles: [URL],
        progress: Progress
    ) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        let clipProgressIncrement = 15.0 / Double(clips.count)

        for (index, clip) in clips.enumerated() {
            // Check for cancellation
            if progress.isCancelled {
                throw AudioExportError.cancelled
            }

            await updateProgress(progress, completedUnits: nil,
                                description: "Adding clip \(index + 1) of \(clips.count) to composition")

            // Create a new track for each clip
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw AudioExportError.exportFailed(reason: "Failed to create composition track")
            }

            let tempURL = tempFiles[index]

            // Create AVAsset from the temp file (already written)
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
            let progressUnits = Int64(25 + Int((Double(index + 1) * clipProgressIncrement)))
            await updateProgress(progress, completedUnits: progressUnits, description: nil)
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

        await updateProgress(progress, completedUnits: nil, description: "Encoding M4A audio")

        // Export with progress tracking using modern states API
        // AVAssetExportSession takes 60% of total time (from 40% to 100%)
        for await state in exportSession.states(updateInterval: 0.1) {
            if case .exporting(let exportProgressObj) = state {
                // Map exportSession.progress (0.0-1.0) to our progress range (40-100)
                let fractionComplete = exportProgressObj.fractionCompleted
                let progressUnits = Int64(40 + Int(fractionComplete * 60.0))
                await updateProgress(progress, completedUnits: progressUnits,
                                    description: "Encoding M4A audio (\(Int(fractionComplete * 100))%)")
            }
        }

        // Update progress to complete
        await updateProgress(progress, completedUnits: 100, description: "Export complete")
    }

    // MARK: - Helpers

    /// Updates progress on the main actor to ensure UI updates are triggered.
    ///
    /// Foundation.Progress is thread-safe, but SwiftUI's observation system works best
    /// when updates are dispatched explicitly to the main actor. This ensures progress
    /// bar updates are visible in the UI.
    ///
    /// This method uses `await MainActor.run` to immediately update progress,
    /// ensuring the UI reflects the current state without delay.
    ///
    /// - Parameters:
    ///   - progress: The Progress object to update
    ///   - completedUnits: Optional new completedUnitCount value
    ///   - description: Optional new localizedAdditionalDescription value
    private func updateProgress(
        _ progress: Progress,
        completedUnits: Int64? = nil,
        description: String? = nil
    ) async {
        // Immediate dispatch to MainActor - blocks until update is complete
        // This ensures UI updates are visible immediately
        await MainActor.run {
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
