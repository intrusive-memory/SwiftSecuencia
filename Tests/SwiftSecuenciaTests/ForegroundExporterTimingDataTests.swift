import Testing
import Foundation
import SwiftData
@testable import SwiftSecuencia
import SwiftCompartido

/// Integration tests for timing data export in ForegroundAudioExporter
///
/// Tests cover:
/// - WebVTT file generation (.vtt)
/// - JSON file generation (.timing.json)
/// - Both formats simultaneously
/// - No timing data generation (.none)
/// - Both exportAudio and exportAudioDirect methods
@Suite("ForegroundAudioExporter Timing Data Export")
@MainActor
struct ForegroundExporterTimingDataTests {

    // MARK: - Test Helpers

    /// Creates real audio data using macOS `say` command
    private func createTestAudioData(
        duration: Double = 1.0
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

    // MARK: - Tests


    @Test("Direct export generates WebVTT file")
    func directExportGeneratesWebVTT() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create test audio elements with real audio data
        let audioData1 = try createTestAudioData(duration: 2.0)
        let audioData2 = try createTestAudioData(duration: 3.0)

        let elements = [
            TypedDataStorage(
                providerId: "test",
                requestorID: "line1",
                mimeType: "audio/mp4",
                binaryValue: audioData1,
                prompt: "First line",
                durationSeconds: 2.0,
                voiceName: "ALICE"
            ),
            TypedDataStorage(
                providerId: "test",
                requestorID: "line2",
                mimeType: "audio/mp4",
                binaryValue: audioData2,
                prompt: "Second line",
                durationSeconds: 3.0,
                voiceName: "BOB"
            )
        ]

        for element in elements {
            modelContext.insert(element)
        }
        try modelContext.save()

        // Export with WebVTT
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("test.m4a")

        let exporter = ForegroundAudioExporter()
        _ = try await exporter.exportAudioDirect(
            audioElements: elements,
            modelContext: modelContext,
            to: outputURL,
            timingDataFormat: .webvtt
        )

        // Verify WebVTT file exists
        let vttURL = tempDir.appendingPathComponent("test.vtt")
        #expect(FileManager.default.fileExists(atPath: vttURL.path))

        // Verify WebVTT content
        let webvtt = try String(contentsOf: vttURL, encoding: .utf8)
        #expect(webvtt.contains("WEBVTT"))
    }

    @Test("Direct export generates JSON file")
    func directExportGeneratesJSON() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create test audio element with real audio data
        let audioData = try createTestAudioData(duration: 2.0)

        let element = TypedDataStorage(
            providerId: "test",
            requestorID: "line1",
            mimeType: "audio/mp4",
            binaryValue: audioData,
            prompt: "Test line",
            durationSeconds: 2.0,
            voiceName: "ALICE"
        )

        modelContext.insert(element)
        try modelContext.save()

        // Export with JSON
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("test.m4a")

        let exporter = ForegroundAudioExporter()
        _ = try await exporter.exportAudioDirect(
            audioElements: [element],
            modelContext: modelContext,
            to: outputURL,
            timingDataFormat: .json
        )

        // Verify JSON file exists
        let jsonURL = TimingData.fileURL(for: outputURL)
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))

        // Verify JSON content can be parsed
        let jsonData = try Data(contentsOf: jsonURL)
        let timingData = try JSONDecoder().decode(TimingData.self, from: jsonData)
        #expect(timingData.audioFile == "test.m4a")
        #expect(timingData.segments.count == 1)
    }

    @Test("Direct export generates both WebVTT and JSON files")
    func directExportGeneratesBothFormats() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create test audio element with real audio data
        let audioData = try createTestAudioData(duration: 2.0)

        let element = TypedDataStorage(
            providerId: "test",
            requestorID: "line1",
            mimeType: "audio/mp4",
            binaryValue: audioData,
            prompt: "Test line",
            durationSeconds: 2.0,
            voiceName: "ALICE"
        )
        modelContext.insert(element)
        try modelContext.save()

        // Export with both formats
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("test.m4a")

        let exporter = ForegroundAudioExporter()
        _ = try await exporter.exportAudioDirect(
            audioElements: [element],
            modelContext: modelContext,
            to: outputURL,
            timingDataFormat: .both
        )

        // Verify both files exist
        let vttURL = tempDir.appendingPathComponent("test.vtt")
        let jsonURL = TimingData.fileURL(for: outputURL)

        #expect(FileManager.default.fileExists(atPath: vttURL.path))
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))
    }

    @Test("Direct export generates no timing data when format is none")
    func directExportGeneratesNoTimingData() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create test audio element with real audio data
        let audioData = try createTestAudioData(duration: 2.0)

        let element = TypedDataStorage(
            providerId: "test",
            requestorID: "line1",
            mimeType: "audio/mp4",
            binaryValue: audioData,
            prompt: "Test line",
            durationSeconds: 2.0
        )
        modelContext.insert(element)
        try modelContext.save()

        // Export with no timing data
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("test.m4a")

        let exporter = ForegroundAudioExporter()
        _ = try await exporter.exportAudioDirect(
            audioElements: [element],
            modelContext: modelContext,
            to: outputURL,
            timingDataFormat: .none
        )

        // Verify no timing data files exist
        let vttURL = tempDir.appendingPathComponent("test.vtt")
        let jsonURL = TimingData.fileURL(for: outputURL)

        #expect(!FileManager.default.fileExists(atPath: vttURL.path))
        #expect(!FileManager.default.fileExists(atPath: jsonURL.path))
    }

    @Test("Timeline-based export generates WebVTT file")
    func timelineExportGeneratesWebVTT() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create test asset with real audio data
        let audioData = try createTestAudioData(duration: 2.0)

        let asset = TypedDataStorage(
            providerId: "test",
            requestorID: "line1",
            mimeType: "audio/mp4",
            binaryValue: audioData,
            prompt: "Test line",
            durationSeconds: 2.0,
            voiceName: "ALICE"
        )
        modelContext.insert(asset)

        // Create timeline with clip
        let timeline = Timeline(
            name: "Test Timeline",
            videoFormat: .hd1080p(frameRate: .fps24),
            audioLayout: .stereo
        )
        modelContext.insert(timeline)

        let clip = TimelineClip(
            assetStorageId: asset.id,
            offset: Timecode(seconds: 0.0),
            duration: Timecode(seconds: 2.0),
            lane: 0
        )
        clip.timeline = timeline
        modelContext.insert(clip)

        try modelContext.save()

        // Export with WebVTT
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("test.m4a")

        let exporter = ForegroundAudioExporter()
        _ = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: modelContext,
            to: outputURL,
            timingDataFormat: .webvtt
        )

        // Verify WebVTT file exists
        let vttURL = tempDir.appendingPathComponent("test.vtt")
        #expect(FileManager.default.fileExists(atPath: vttURL.path))

        // Verify WebVTT content
        let webvtt = try String(contentsOf: vttURL, encoding: .utf8)
        #expect(webvtt.contains("WEBVTT"))
        #expect(webvtt.contains("Test line"))
    }

    @Test("Timeline-based export generates JSON file")
    func timelineExportGeneratesJSON() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create test asset with real audio data
        let audioData = try createTestAudioData(duration: 2.0)

        let asset = TypedDataStorage(
            providerId: "test",
            requestorID: "line1",
            mimeType: "audio/mp4",
            binaryValue: audioData,
            prompt: "Test line",
            durationSeconds: 2.0,
            voiceName: "ALICE"
        )
        modelContext.insert(asset)

        // Create timeline with clip
        let timeline = Timeline(
            name: "Test Timeline",
            videoFormat: .hd1080p(frameRate: .fps24),
            audioLayout: .stereo
        )
        modelContext.insert(timeline)

        let clip = TimelineClip(
            assetStorageId: asset.id,
            offset: Timecode(seconds: 0.0),
            duration: Timecode(seconds: 2.0),
            lane: 0
        )
        clip.timeline = timeline
        modelContext.insert(clip)

        try modelContext.save()

        // Export with JSON
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputURL = tempDir.appendingPathComponent("test.m4a")

        let exporter = ForegroundAudioExporter()
        _ = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: modelContext,
            to: outputURL,
            timingDataFormat: .json
        )

        // Verify JSON file exists
        let jsonURL = TimingData.fileURL(for: outputURL)
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))

        // Verify JSON content
        let jsonData = try Data(contentsOf: jsonURL)
        let timingData = try JSONDecoder().decode(TimingData.self, from: jsonData)
        #expect(timingData.audioFile == "test.m4a")
        #expect(timingData.segments.count == 1)
        #expect(timingData.segments[0].text == "Test line")
    }
}
