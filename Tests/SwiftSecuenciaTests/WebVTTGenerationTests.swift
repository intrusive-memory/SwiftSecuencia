import Testing
import Foundation
import SwiftData
@testable import SwiftSecuencia
import SwiftCompartido

/// Basic WebVTT generation tests
///
/// Tests basic functionality with real TypedDataStorage API
@Suite("WebVTT Generation")
struct WebVTTGenerationTests {

    @Test("WebVTT generator creates valid structure")
    func webvttGeneratorCreatesValidStructure() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create test asset with realistic TypedDataStorage
        let asset = TypedDataStorage(
            providerId: "test-provider",
            requestorID: "test-audio",
            mimeType: "audio/mp4",
            binaryValue: Data([0x00, 0x01, 0x02]),
            prompt: "Test line",
            durationSeconds: 5.0,
            voiceName: "ALICE"
        )
        modelContext.insert(asset)

        // Create timeline with single clip
        let timeline = Timeline(
            name: "Test Timeline",
            videoFormat: .hd1080p(frameRate: .fps24),
            audioLayout: .stereo
        )
        modelContext.insert(timeline)

        let clip = TimelineClip(
            assetStorageId: asset.id,
            offset: Timecode(seconds: 0.0),
            duration: Timecode(seconds: 5.0),
            lane: 0
        )
        clip.timeline = timeline
        modelContext.insert(clip)

        try modelContext.save()

        // Generate WebVTT
        let generator = WebVTTGenerator()
        let webvtt = try await generator.generateWebVTT(from: timeline, modelContext: modelContext)

        // Verify basic structure
        #expect(webvtt.contains("WEBVTT"))
        #expect(!webvtt.isEmpty)
    }

    @Test("WebVTT generator handles empty timeline")
    func webvttGeneratorHandlesEmptyTimeline() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create empty timeline
        let timeline = Timeline(
            name: "Empty Timeline",
            videoFormat: .hd1080p(frameRate: .fps24),
            audioLayout: .stereo
        )
        modelContext.insert(timeline)
        try modelContext.save()

        // Generate WebVTT
        let generator = WebVTTGenerator()
        let webvtt = try await generator.generateWebVTT(from: timeline, modelContext: modelContext)

        // Verify header exists
        #expect(webvtt.contains("WEBVTT"))
    }

    @Test("WebVTT direct export from audio elements")
    func webvttDirectExportFromAudioElements() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create audio elements with durations
        let elements = [
            TypedDataStorage(
                providerId: "test",
                requestorID: "line1",
                mimeType: "audio/mp4",
                binaryValue: Data([0x00]),
                prompt: "First line",
                durationSeconds: 2.0,
                voiceName: "ALICE"
            ),
            TypedDataStorage(
                providerId: "test",
                requestorID: "line2",
                mimeType: "audio/mp4",
                binaryValue: Data([0x00]),
                prompt: "Second line",
                durationSeconds: 3.0,
                voiceName: "BOB"
            )
        ]

        for element in elements {
            modelContext.insert(element)
        }
        try modelContext.save()

        // Generate WebVTT directly from audio elements
        let generator = WebVTTGenerator()
        let webvtt = try await generator.generateWebVTT(from: elements, modelContext: modelContext)

        // Verify structure
        #expect(webvtt.contains("WEBVTT"))
        #expect(!webvtt.isEmpty)
    }
}
