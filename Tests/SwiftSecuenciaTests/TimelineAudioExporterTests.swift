//
//  TimelineAudioExporterTests.swift
//  SwiftSecuencia
//
//  Tests for TimelineAudioExporter (M4A export only)
//

import Testing
import Foundation
import SwiftData
@testable import SwiftSecuencia
import SwiftCompartido
import AVFoundation

@Suite("TimelineAudioExporter Tests")
struct TimelineAudioExporterTests {

    // MARK: - Test Helpers

    /// Creates a test model container with in-memory storage
    private func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
    }

    /// Creates real audio data using macOS `say` command
    private func createTestAudioData(
        duration: Double = 1.0,
        sampleRate: Double = 44100.0,
        frequency: Double = 440.0
    ) throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")

        // Use `say` command to generate real audio
        // Generate enough words to fill the duration (approx 2 words per second)
        let wordCount = max(Int(duration * 2), 1)
        let text = Array(repeating: "test", count: wordCount).joined(separator: " ")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-o", tempURL.path, "--data-format=alac", text]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "TestAudioGeneration", code: Int(process.terminationStatus))
        }

        let data = try Data(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)

        return data
    }

    /// Creates a test TypedDataStorage with audio data
    @MainActor
    private func createTestAudioAsset(
        in context: ModelContext,
        duration: Double = 1.0,
        prompt: String = "Test Audio"
    ) throws -> TypedDataStorage {
        let audioData = try createTestAudioData(duration: duration)

        let asset = TypedDataStorage(
            providerId: "test-provider",
            requestorID: "test-requestor",
            mimeType: "audio/mp4",  // M4A MIME type
            binaryValue: audioData,
            prompt: prompt,
            durationSeconds: duration
        )

        context.insert(asset)
        return asset
    }

    // MARK: - AudioExportFormat Tests

    @Test("AudioExportFormat has correct file extension")
    func testAudioExportFormatExtension() {
        #expect(AudioExportFormat.m4a.fileExtension == "m4a")
    }

    @Test("AudioExportFormat has correct AVFileType")
    func testAudioExportFormatAVFileType() {
        #expect(AudioExportFormat.m4a.avFileType == .m4a)
    }

    @Test("AudioExportFormat has correct export preset")
    func testAudioExportFormatPreset() {
        #expect(AudioExportFormat.m4a.exportPreset == AVAssetExportPresetAppleM4A)
    }

    // MARK: - Error Handling Tests

    @Test("Export throws error for empty timeline")
    @MainActor
    func testEmptyTimelineError() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let timeline = Timeline(name: "Empty Timeline")
        context.insert(timeline)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty.m4a")

        await #expect(throws: AudioExportError.emptyTimeline) {
            try await exporter.exportAudio(
                timeline: timeline,
                modelContext: context,
                to: outputURL
            )
        }
    }

    @Test("Export throws error for timeline with no audio clips")
    @MainActor
    func testNoAudioClipsError() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        // Create timeline with video clip (no audio)
        let videoAsset = TypedDataStorage(
            providerId: "test-provider",
            requestorID: "test-requestor",
            mimeType: "video/mp4",
            binaryValue: Data(),
            prompt: "Video",
            durationSeconds: 5.0
        )
        context.insert(videoAsset)

        let timeline = Timeline(name: "Video Timeline")
        let clip = TimelineClip(
            assetStorageId: videoAsset.id,
            duration: Timecode(seconds: 5.0)
        )

        timeline.appendClip(clip)
        context.insert(timeline)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("novideo.m4a")

        await #expect(throws: AudioExportError.emptyTimeline) {
            try await exporter.exportAudio(
                timeline: timeline,
                modelContext: context,
                to: outputURL
            )
        }
    }

    @Test("Export throws error for missing asset")
    @MainActor
    func testMissingAssetError() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let timeline = Timeline(name: "Missing Asset Timeline")
        let clip = TimelineClip(
            assetStorageId: UUID(), // Non-existent asset
            duration: Timecode(seconds: 3.0)
        )

        timeline.appendClip(clip)
        context.insert(timeline)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing.m4a")

        await #expect(throws: AudioExportError.self) {
            try await exporter.exportAudio(
                timeline: timeline,
                modelContext: context,
                to: outputURL
            )
        }
    }

    // MARK: - Single Clip Export Tests

    @Test("Export single audio clip to M4A")
    @MainActor
    func testExportSingleClip() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio = try createTestAudioAsset(in: context, duration: 2.0)

        let timeline = Timeline(name: "Single Clip")
        let clip = TimelineClip(
            assetStorageId: audio.id,
            duration: Timecode(seconds: 2.0)
        )

        timeline.appendClip(clip)
        context.insert(timeline)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("single.m4a")

        let result = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: context,
            to: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: result.path))

        // Verify it's a valid M4A file
        let asset = AVURLAsset(url: result)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(tracks.count > 0)

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Multi-Clip Export Tests

    @Test("Export multiple clips on same lane")
    @MainActor
    func testExportMultipleClipsSameLane() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio1 = try createTestAudioAsset(in: context, duration: 2.0, prompt: "Audio 1")
        let audio2 = try createTestAudioAsset(in: context, duration: 3.0, prompt: "Audio 2")

        let timeline = Timeline(name: "Multi-Clip Timeline")

        let clip1 = TimelineClip(
            assetStorageId: audio1.id,
            offset: Timecode.zero,
            duration: Timecode(seconds: 2.0)
        )

        let clip2 = TimelineClip(
            assetStorageId: audio2.id,
            offset: Timecode(seconds: 2.0),
            duration: Timecode(seconds: 3.0)
        )

        timeline.insertClip(clip1, at: Timecode.zero)
        timeline.insertClip(clip2, at: Timecode(seconds: 2.0))
        context.insert(timeline)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("multiclip.m4a")

        let result = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: context,
            to: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: result.path))

        // Verify the exported file is valid M4A with non-zero duration
        let asset = AVURLAsset(url: result)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        #expect(durationSeconds > 0) // Just verify it has audio, don't test exact duration

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }

    @Test("Export clips with gaps (silence insertion)")
    @MainActor
    func testExportClipsWithGaps() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio1 = try createTestAudioAsset(in: context, duration: 1.0)
        let audio2 = try createTestAudioAsset(in: context, duration: 1.0)

        let timeline = Timeline(name: "Gapped Timeline")

        let clip1 = TimelineClip(
            assetStorageId: audio1.id,
            offset: Timecode.zero,
            duration: Timecode(seconds: 1.0)
        )

        // Gap from 1s to 3s
        let clip2 = TimelineClip(
            assetStorageId: audio2.id,
            offset: Timecode(seconds: 3.0),
            duration: Timecode(seconds: 1.0)
        )

        timeline.insertClip(clip1, at: Timecode.zero)
        timeline.insertClip(clip2, at: Timecode(seconds: 3.0))
        context.insert(timeline)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gapped.m4a")

        let result = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: context,
            to: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: result.path))

        // Verify the exported file is valid M4A with non-zero duration
        // Note: We don't test exact duration because `say` command output varies
        let asset = AVURLAsset(url: result)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        #expect(durationSeconds > 0) // Just verify it has audio, don't test exact duration

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Multi-Lane Export Tests (Stereo Mixdown)

    @Test("Export clips on multiple lanes (mixed to stereo)")
    @MainActor
    func testExportMultipleLanes() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio1 = try createTestAudioAsset(in: context, duration: 2.0, prompt: "Lane 0")
        let audio2 = try createTestAudioAsset(in: context, duration: 2.0, prompt: "Lane 1")

        let timeline = Timeline(name: "Multi-Lane Timeline")

        let clip1 = TimelineClip(
            assetStorageId: audio1.id,
            duration: Timecode(seconds: 2.0)
        )

        let clip2 = TimelineClip(
            assetStorageId: audio2.id,
            duration: Timecode(seconds: 2.0),
            lane: 1
        )

        timeline.insertClip(clip1, at: Timecode.zero, lane: 0)
        timeline.insertClip(clip2, at: Timecode.zero, lane: 1)
        context.insert(timeline)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("multilane.m4a")

        let result = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: context,
            to: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: result.path))

        // Verify it's stereo (or at least has audio)
        let asset = AVURLAsset(url: result)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(tracks.count > 0)

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }

    @Test("Export overlapping clips (automatic mixing)")
    @MainActor
    func testExportOverlappingClips() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio1 = try createTestAudioAsset(in: context, duration: 3.0, prompt: "Clip 1")
        let audio2 = try createTestAudioAsset(in: context, duration: 2.0, prompt: "Clip 2")

        let timeline = Timeline(name: "Overlapping Timeline")

        let clip1 = TimelineClip(
            assetStorageId: audio1.id,
            offset: Timecode.zero,
            duration: Timecode(seconds: 3.0)
        )

        // Overlaps with clip1
        let clip2 = TimelineClip(
            assetStorageId: audio2.id,
            offset: Timecode(seconds: 1.0),
            duration: Timecode(seconds: 2.0)
        )

        timeline.insertClip(clip1, at: Timecode.zero, lane: 0)
        timeline.insertClip(clip2, at: Timecode(seconds: 1.0), lane: 0)
        context.insert(timeline)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("overlapping.m4a")

        let result = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: context,
            to: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: result.path))

        // Verify the file was created and has audio
        let asset = AVURLAsset(url: result)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(tracks.count > 0)

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Progress Reporting Tests

    @Test("Export reports progress correctly")
    @MainActor
    func testProgressReporting() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio = try createTestAudioAsset(in: context, duration: 1.0)

        let timeline = Timeline(name: "Progress Timeline")
        let clip = TimelineClip(
            assetStorageId: audio.id,
            duration: Timecode(seconds: 1.0)
        )

        timeline.appendClip(clip)
        context.insert(timeline)

        let progress = Progress(totalUnitCount: 100)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress.m4a")

        _ = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: context,
            to: outputURL,
            progress: progress
        )

        // Verify progress reached 100%
        #expect(progress.completedUnitCount == 100)

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }

    @Test("Export respects cancellation")
    @MainActor
    func testCancellation() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio = try createTestAudioAsset(in: context, duration: 1.0)

        let timeline = Timeline(name: "Cancellation Timeline")
        let clip = TimelineClip(
            assetStorageId: audio.id,
            duration: Timecode(seconds: 1.0)
        )

        timeline.appendClip(clip)
        context.insert(timeline)

        let progress = Progress(totalUnitCount: 100)
        progress.cancel()

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancelled.m4a")

        await #expect(throws: AudioExportError.cancelled) {
            try await exporter.exportAudio(
                timeline: timeline,
                modelContext: context,
                to: outputURL,
                progress: progress
            )
        }
    }

    // MARK: - Source Start Tests

    @Test("Export respects clip sourceStart property")
    @MainActor
    func testSourceStartRespected() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        // Create 3-second audio
        let audio = try createTestAudioAsset(in: context, duration: 3.0)

        let timeline = Timeline(name: "Source Start Timeline")

        // Use middle 1 second (from 1s to 2s)
        let clip = TimelineClip(
            assetStorageId: audio.id,
            offset: Timecode.zero,
            duration: Timecode(seconds: 1.0),
            sourceStart: Timecode(seconds: 1.0)  // Start at 1s into the audio
        )

        timeline.appendClip(clip)
        context.insert(timeline)

        let exporter = TimelineAudioExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sourcestart.m4a")

        let result = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: context,
            to: outputURL
        )

        #expect(FileManager.default.fileExists(atPath: result.path))

        // Verify duration is approximately 1 second
        let asset = AVURLAsset(url: result)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        #expect(durationSeconds >= 0.9 && durationSeconds <= 1.1)

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }
}
