import Testing
import Foundation
import SwiftData
@testable import SwiftSecuencia
import SwiftCompartido

/// Unit tests for JSON timing data generation
///
/// Tests cover:
/// - JSON structure generation from Timeline
/// - JSON structure generation from audio elements
/// - Metadata extraction (character, text, lane)
/// - Duration calculations
/// - Edge cases (empty timeline, multiple clips)
@Suite("JSON Generation")
struct JSONGenerationTests {

    @Test("JSON generator creates valid structure")
    func jsonGeneratorCreatesValidStructure() async throws {
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

        // Generate JSON
        let generator = JSONGenerator()
        let json = try await generator.generateJSON(
            from: timeline,
            audioFileName: "test.m4a",
            modelContext: modelContext
        )

        // Verify JSON structure
        #expect(json.contains("\"audioFile\""))
        #expect(json.contains("\"duration\""))
        #expect(json.contains("\"segments\""))
        #expect(json.contains("\"version\""))
        #expect(json.contains("test.m4a"))
    }

    @Test("JSON generator includes metadata")
    func jsonGeneratorIncludesMetadata() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        // Create test asset with character
        let asset = TypedDataStorage(
            providerId: "test-provider",
            requestorID: "test-audio",
            mimeType: "audio/mp4",
            binaryValue: Data([0x00]),
            prompt: "Hello, world!",
            durationSeconds: 3.0,
            voiceName: "ALICE"
        )
        modelContext.insert(asset)

        let timeline = Timeline(
            name: "Test Timeline",
            videoFormat: .hd1080p(frameRate: .fps24),
            audioLayout: .stereo
        )
        modelContext.insert(timeline)

        let clip = TimelineClip(
            assetStorageId: asset.id,
            offset: Timecode(seconds: 0.0),
            duration: Timecode(seconds: 3.0),
            lane: 1
        )
        clip.timeline = timeline
        modelContext.insert(clip)

        try modelContext.save()

        // Generate TimingData (not JSON string)
        let generator = JSONGenerator()
        let timingData = try await generator.generateTimingData(
            from: timeline,
            audioFileName: "test.m4a",
            modelContext: modelContext
        )

        // Verify metadata
        #expect(timingData.segments.count == 1)
        #expect(timingData.segments[0].text == "Hello, world!")
        #expect(timingData.segments[0].metadata?.character == "ALICE")
        #expect(timingData.segments[0].metadata?.lane == 1)
    }

    @Test("JSON generator handles empty timeline")
    func jsonGeneratorHandlesEmptyTimeline() async throws {
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

        // Generate JSON
        let generator = JSONGenerator()
        let timingData = try await generator.generateTimingData(
            from: timeline,
            audioFileName: "empty.m4a",
            modelContext: modelContext
        )

        // Verify empty segments
        #expect(timingData.segments.isEmpty)
        #expect(timingData.duration == 0.0)
        #expect(timingData.audioFile == "empty.m4a")
    }

    @Test("JSON direct export from audio elements")
    func jsonDirectExportFromAudioElements() async throws {
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

        // Generate TimingData directly from audio elements
        let generator = JSONGenerator()
        let timingData = try await generator.generateTimingData(
            from: elements,
            audioFileName: "screenplay.m4a",
            modelContext: modelContext
        )

        // Verify sequential timing
        #expect(timingData.segments.count == 2)
        #expect(timingData.segments[0].startTime == 0.0)
        #expect(timingData.segments[0].endTime == 2.0)
        #expect(timingData.segments[1].startTime == 2.0)
        #expect(timingData.segments[1].endTime == 5.0)
        #expect(timingData.duration == 5.0)

        // Verify content
        #expect(timingData.segments[0].text == "First line")
        #expect(timingData.segments[0].metadata?.character == "ALICE")
        #expect(timingData.segments[1].text == "Second line")
        #expect(timingData.segments[1].metadata?.character == "BOB")
    }

    @Test("JSON generator calculates correct total duration")
    func jsonGeneratorCalculatesCorrectTotalDuration() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        let timeline = Timeline(
            name: "Multi-clip Timeline",
            videoFormat: .hd1080p(frameRate: .fps24),
            audioLayout: .stereo
        )
        modelContext.insert(timeline)

        // Create clips at different offsets
        let clipsData = [
            (0.0, 3.0),   // 0-3s
            (3.0, 2.0),   // 3-5s
            (5.0, 4.0)    // 5-9s (total duration should be 9s)
        ]

        for (offset, duration) in clipsData {
            let asset = TypedDataStorage(
                providerId: "test",
                requestorID: UUID().uuidString,
                mimeType: "audio/mp4",
                binaryValue: Data([0x00]),
                prompt: "Clip",
                durationSeconds: duration
            )
            modelContext.insert(asset)

            let clip = TimelineClip(
                assetStorageId: asset.id,
                offset: Timecode(seconds: offset),
                duration: Timecode(seconds: duration),
                lane: 0
            )
            clip.timeline = timeline
            modelContext.insert(clip)
        }

        try modelContext.save()

        // Generate TimingData
        let generator = JSONGenerator()
        let timingData = try await generator.generateTimingData(
            from: timeline,
            audioFileName: "test.m4a",
            modelContext: modelContext
        )

        // Verify total duration
        #expect(timingData.duration == 9.0)
        #expect(timingData.segments.count == 3)
    }

    @Test("JSON generator outputs valid JSON string")
    func jsonGeneratorOutputsValidJSONString() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        let element = TypedDataStorage(
            providerId: "test",
            requestorID: "test",
            mimeType: "audio/mp4",
            binaryValue: Data([0x00]),
            prompt: "Test",
            durationSeconds: 1.0
        )
        modelContext.insert(element)
        try modelContext.save()

        // Generate JSON string
        let generator = JSONGenerator()
        let json = try await generator.generateJSON(
            from: [element],
            audioFileName: "test.m4a",
            modelContext: modelContext
        )

        // Verify valid JSON by parsing it back
        let jsonData = Data(json.utf8)
        let decoded = try JSONDecoder().decode(TimingData.self, from: jsonData)

        #expect(decoded.audioFile == "test.m4a")
        #expect(decoded.segments.count == 1)
        #expect(decoded.segments[0].text == "Test")
    }

    @Test("JSON generator preserves clip order")
    func jsonGeneratorPreservesClipOrder() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
        let modelContext = ModelContext(container)

        let timeline = Timeline(
            name: "Ordered Timeline",
            videoFormat: .hd1080p(frameRate: .fps24),
            audioLayout: .stereo
        )
        modelContext.insert(timeline)

        // Create clips in specific order
        let texts = ["First", "Second", "Third"]
        for (index, text) in texts.enumerated() {
            let asset = TypedDataStorage(
                providerId: "test",
                requestorID: "clip-\(index)",
                mimeType: "audio/mp4",
                binaryValue: Data([0x00]),
                prompt: text,
                durationSeconds: 1.0
            )
            modelContext.insert(asset)

            let clip = TimelineClip(
                assetStorageId: asset.id,
                offset: Timecode(seconds: Double(index)),
                duration: Timecode(seconds: 1.0),
                lane: 0
            )
            clip.timeline = timeline
            modelContext.insert(clip)
        }

        try modelContext.save()

        // Generate TimingData
        let generator = JSONGenerator()
        let timingData = try await generator.generateTimingData(
            from: timeline,
            audioFileName: "test.m4a",
            modelContext: modelContext
        )

        // Verify order is preserved
        #expect(timingData.segments.count == 3)
        #expect(timingData.segments[0].text == "First")
        #expect(timingData.segments[1].text == "Second")
        #expect(timingData.segments[2].text == "Third")
    }
}
