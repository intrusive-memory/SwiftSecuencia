import Testing
import Foundation
@testable import SwiftSecuencia

/// Unit tests for TimingData JSON models
///
/// Tests cover:
/// - UT-2.1: Codable serialization and deserialization
/// - UT-2.2: Optional metadata handling
/// - UT-2.3: JSON schema validation
/// - UT-5.1: JSON file creation and I/O
/// - UT-5.3: File naming conventions
@Suite("TimingData JSON Models")
struct TimingDataModelTests {

    // MARK: - UT-2.1: Codable Serialization

    @Test("TimingData encodes to JSON correctly")
    func timingDataEncodesToJSON() async throws {
        let segment = TimingSegment(
            id: "line-1",
            startTime: 0.0,
            endTime: 3.2,
            text: "Hello, world!",
            metadata: TimingMetadata(character: "ALICE", lane: 1, clipId: "clip-uuid-1234")
        )

        let timingData = TimingData(
            version: "1.0",
            audioFile: "test.m4a",
            duration: 10.0,
            segments: [segment]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(timingData)

        #expect(jsonData.count > 0)

        // Verify round-trip
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TimingData.self, from: jsonData)
        #expect(decoded.version == "1.0")
        #expect(decoded.audioFile == "test.m4a")
        #expect(decoded.duration == 10.0)
        #expect(decoded.segments.count == 1)
        #expect(decoded.segments[0].id == "line-1")
        #expect(decoded.segments[0].startTime == 0.0)
        #expect(decoded.segments[0].endTime == 3.2)
        #expect(decoded.segments[0].text == "Hello, world!")
    }

    @Test("TimingData default version is 1.0")
    func timingDataDefaultVersion() async throws {
        let timingData = TimingData(
            audioFile: "test.m4a",
            duration: 10.0,
            segments: []
        )

        #expect(timingData.version == "1.0")
    }

    // MARK: - UT-2.2: Optional Metadata

    @Test("TimingSegment supports optional metadata")
    func timingSegmentSupportsOptionalMetadata() async throws {
        let segment1 = TimingSegment(
            id: "line-1",
            startTime: 0.0,
            endTime: 3.0,
            text: "Hello",
            metadata: nil  // No metadata
        )

        let segment2 = TimingSegment(
            id: "line-2",
            startTime: 3.0,
            endTime: 6.0,
            text: "World",
            metadata: TimingMetadata(character: "BOB", lane: nil, clipId: nil)  // Partial metadata
        )

        #expect(segment1.metadata == nil)
        #expect(segment2.metadata?.character == "BOB")
        #expect(segment2.metadata?.lane == nil)
        #expect(segment2.metadata?.clipId == nil)
    }

    @Test("TimingSegment supports optional text")
    func timingSegmentSupportsOptionalText() async throws {
        let segment = TimingSegment(
            id: "line-1",
            startTime: 0.0,
            endTime: 3.0,
            text: nil  // No text content
        )

        #expect(segment.text == nil)
        #expect(segment.id == "line-1")
    }

    @Test("TimingMetadata all fields optional")
    func timingMetadataAllFieldsOptional() async throws {
        let metadata = TimingMetadata()

        #expect(metadata.character == nil)
        #expect(metadata.lane == nil)
        #expect(metadata.clipId == nil)
    }

    // MARK: - UT-2.3: Schema Validation

    @Test("TimingData JSON matches expected schema")
    func timingDataJSONMatchesExpectedSchema() async throws {
        let timingData = TimingData(
            version: "1.0",
            audioFile: "test.m4a",
            duration: 10.0,
            segments: [
                TimingSegment(
                    id: "line-1",
                    startTime: 0.0,
                    endTime: 3.0,
                    text: "Test",
                    metadata: TimingMetadata(character: "ALICE", lane: 1, clipId: "clip-123")
                )
            ]
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(timingData)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        #expect(json?["version"] as? String == "1.0")
        #expect(json?["audioFile"] as? String == "test.m4a")
        #expect(json?["duration"] as? Double == 10.0)

        let segments = json?["segments"] as? [[String: Any]]
        #expect(segments?.count == 1)
        #expect(segments?[0]["id"] as? String == "line-1")
        #expect(segments?[0]["startTime"] as? Double == 0.0)
        #expect(segments?[0]["endTime"] as? Double == 3.0)
        #expect(segments?[0]["text"] as? String == "Test")

        let metadata = segments?[0]["metadata"] as? [String: Any]
        #expect(metadata?["character"] as? String == "ALICE")
        #expect(metadata?["lane"] as? Int == 1)
        #expect(metadata?["clipId"] as? String == "clip-123")
    }

    @Test("TimingData JSON omits null values for optional fields")
    func timingDataJSONOmitsNullValues() async throws {
        let segment = TimingSegment(
            id: "line-1",
            startTime: 0.0,
            endTime: 3.0,
            text: nil,  // Will be omitted from JSON
            metadata: nil  // Will be omitted from JSON
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(segment)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        // Swift's Codable default behavior: optional nil values are omitted from JSON
        #expect(json?["id"] as? String == "line-1")
        #expect(json?["startTime"] as? Double == 0.0)
        #expect(json?["endTime"] as? Double == 3.0)
        // text and metadata keys should not exist in JSON when nil
        #expect(json?["text"] == nil)
        #expect(json?["metadata"] == nil)
    }

    // MARK: - UT-5.1: File Creation

    @Test("Export TimingData to JSON file")
    func exportTimingDataToJSONFile() async throws {
        let timingData = TimingData(
            version: "1.0",
            audioFile: "test.m4a",
            duration: 10.0,
            segments: [
                TimingSegment(
                    id: "line-1",
                    startTime: 0.0,
                    endTime: 5.0,
                    text: "Test line",
                    metadata: nil
                )
            ]
        )

        let tempDir = FileManager.default.temporaryDirectory
        let timingURL = tempDir.appendingPathComponent("test-\(UUID()).timing.json")

        // Write to file
        try await timingData.write(to: timingURL)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: timingURL.path))

        // Verify contents
        let data = try Data(contentsOf: timingURL)
        let decoded = try JSONDecoder().decode(TimingData.self, from: data)
        #expect(decoded.segments.count == 1)
        #expect(decoded.audioFile == "test.m4a")
        #expect(decoded.duration == 10.0)

        // Verify JSON is pretty-printed and sorted
        let jsonString = String(data: data, encoding: .utf8)!
        #expect(jsonString.contains("\n"))  // Pretty-printed
        #expect(jsonString.contains("  "))  // Indented

        // Cleanup
        try? FileManager.default.removeItem(at: timingURL)
    }

    // MARK: - UT-5.3: File Naming

    @Test("JSON file URL follows naming convention")
    func timingDataFileURLFollowsNamingConvention() async throws {
        let audioURL1 = URL(fileURLWithPath: "/path/screenplay.m4a")
        let timingURL1 = TimingData.fileURL(for: audioURL1)
        #expect(timingURL1.lastPathComponent == "screenplay.m4a.timing.json")
        #expect(timingURL1.path == "/path/screenplay.m4a.timing.json")

        let audioURL2 = URL(fileURLWithPath: "/path/My Audio.m4a")
        let timingURL2 = TimingData.fileURL(for: audioURL2)
        #expect(timingURL2.lastPathComponent == "My Audio.m4a.timing.json")
    }

    // MARK: - Additional Tests

    @Test("TimingSegment calculates duration correctly")
    func timingSegmentDurationCalculation() async throws {
        let segment = TimingSegment(
            id: "line-1",
            startTime: 2.5,
            endTime: 7.8,
            text: "Test"
        )

        #expect(segment.duration == 5.3)
    }

    @Test("TimingSegment Equatable conformance")
    func timingSegmentEquatable() async throws {
        let segment1 = TimingSegment(
            id: "line-1",
            startTime: 0.0,
            endTime: 3.0,
            text: "Hello",
            metadata: TimingMetadata(character: "ALICE")
        )

        let segment2 = TimingSegment(
            id: "line-1",
            startTime: 0.0,
            endTime: 3.0,
            text: "Hello",
            metadata: TimingMetadata(character: "ALICE")
        )

        let segment3 = TimingSegment(
            id: "line-2",
            startTime: 0.0,
            endTime: 3.0,
            text: "Hello",
            metadata: TimingMetadata(character: "ALICE")
        )

        #expect(segment1 == segment2)
        #expect(segment1 != segment3)
    }

    @Test("TimingSegment Hashable conformance")
    func timingSegmentHashable() async throws {
        let segment1 = TimingSegment(
            id: "line-1",
            startTime: 0.0,
            endTime: 3.0,
            text: "Hello"
        )

        let segment2 = TimingSegment(
            id: "line-1",
            startTime: 0.0,
            endTime: 3.0,
            text: "Hello"
        )

        var set = Set<TimingSegment>()
        set.insert(segment1)
        set.insert(segment2)

        // Same segments should only appear once
        #expect(set.count == 1)
    }

    @Test("Empty segments array")
    func emptySegmentsArray() async throws {
        let timingData = TimingData(
            audioFile: "test.m4a",
            duration: 0.0,
            segments: []
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(timingData)
        let decoded = try JSONDecoder().decode(TimingData.self, from: jsonData)

        #expect(decoded.segments.isEmpty)
        #expect(decoded.duration == 0.0)
    }

    @Test("Multiple segments maintain order")
    func multipleSegmentsMaintainOrder() async throws {
        let segments = [
            TimingSegment(id: "1", startTime: 0.0, endTime: 1.0, text: "First"),
            TimingSegment(id: "2", startTime: 1.0, endTime: 2.0, text: "Second"),
            TimingSegment(id: "3", startTime: 2.0, endTime: 3.0, text: "Third")
        ]

        let timingData = TimingData(
            audioFile: "test.m4a",
            duration: 3.0,
            segments: segments
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(timingData)
        let decoded = try JSONDecoder().decode(TimingData.self, from: jsonData)

        #expect(decoded.segments.count == 3)
        #expect(decoded.segments[0].text == "First")
        #expect(decoded.segments[1].text == "Second")
        #expect(decoded.segments[2].text == "Third")
    }

    @Test("Large duration values")
    func largeDurationValues() async throws {
        let timingData = TimingData(
            audioFile: "long-audio.m4a",
            duration: 7200.0,  // 2 hours
            segments: [
                TimingSegment(id: "1", startTime: 0.0, endTime: 7200.0)
            ]
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(timingData)
        let decoded = try JSONDecoder().decode(TimingData.self, from: jsonData)

        #expect(decoded.duration == 7200.0)
        #expect(decoded.segments[0].duration == 7200.0)
    }

    @Test("Special characters in text and metadata")
    func specialCharactersInTextAndMetadata() async throws {
        let segment = TimingSegment(
            id: "line-1",
            startTime: 0.0,
            endTime: 3.0,
            text: "Hello, \"world\"! How's it going? 你好",
            metadata: TimingMetadata(
                character: "O'Brien",
                lane: 1,
                clipId: "clip-{123}"
            )
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(segment)
        let decoded = try JSONDecoder().decode(TimingSegment.self, from: jsonData)

        #expect(decoded.text == "Hello, \"world\"! How's it going? 你好")
        #expect(decoded.metadata?.character == "O'Brien")
        #expect(decoded.metadata?.clipId == "clip-{123}")
    }
}
