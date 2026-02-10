import Testing
import Foundation
@testable import SecuenciaCLI

struct JSONTimelineParserTests {
    let parser = JSONTimelineParser()

    // Helper to get fixture URL
    func fixtureURL(named name: String) throws -> URL {
        let fixtureURL = URL(fileURLWithPath: "Fixtures/\(name)")
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "Fixtures"
        ) else {
            throw ParserError.fileNotFound(fixtureURL)
        }
        return url
    }

    // MARK: - Valid Parsing Tests

    @Test func parseValidTimelineWithAllFields() throws {
        let url = try fixtureURL(named: "valid-timeline.json")
        let definition = try parser.parse(fileAt: url)

        // Validate timeline config
        #expect(definition.timeline.name == "Test Timeline")
        #expect(definition.timeline.format.width == 1920)
        #expect(definition.timeline.format.height == 1080)
        #expect(definition.timeline.format.frameRate == "23.98")
        #expect(definition.timeline.format.colorSpace == "rec709")
        #expect(definition.timeline.audio.layout == "stereo")
        #expect(definition.timeline.audio.rate == "48kHz")

        // Validate clips
        #expect(definition.clips.count == 3)

        // First clip (image)
        let clip1 = definition.clips[0]
        #expect(clip1.name == "Title Card")
        #expect(clip1.file == "title.png")
        #expect(clip1.offset == "0s")
        #expect(clip1.duration == "3s")
        #expect(clip1.lane == 0)
        #expect(clip1.type == .image)

        // Second clip (audio)
        let clip2 = definition.clips[1]
        #expect(clip2.name == "Narration")
        #expect(clip2.file == "audio.m4a")
        #expect(clip2.offset == "0s")
        #expect(clip2.lane == -1)
        #expect(clip2.type == .audio)

        // Third clip (marker)
        let clip3 = definition.clips[2]
        #expect(clip3.name == "Chapter 1")
        #expect(clip3.offset == "0s")
        #expect(clip3.type == .marker)
        #expect(clip3.markerType == "chapter")
    }

    @Test func parseTimelineWithMissingOptionalFields() throws {
        // Create a minimal valid JSON
        let jsonString = """
        {
          "timeline": {
            "name": "Minimal",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "24"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48kHz"
            }
          },
          "clips": [
            {
              "name": "Video",
              "file": "video.mov",
              "offset": "0s",
              "type": "video"
            }
          ]
        }
        """

        let data = jsonString.data(using: .utf8)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")

        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let definition = try parser.parse(fileAt: tempURL)
        #expect(definition.timeline.name == "Minimal")
        #expect(definition.timeline.format.colorSpace == nil)
        #expect(definition.clips[0].duration == nil)
        #expect(definition.clips[0].lane == nil)
    }

    // MARK: - Error Cases

    @Test func parseThrowsOnInvalidClipType() throws {
        let url = try fixtureURL(named: "invalid-clip-type.json")
        #expect(throws: Error.self) {
            _ = try parser.parse(fileAt: url)
        }
    }

    @Test func parseThrowsOnMarkerMissingMarkerType() throws {
        let url = try fixtureURL(named: "marker-missing-type.json")
        #expect(throws: ParserError.self) {
            _ = try parser.parse(fileAt: url)
        }
    }

    @Test func parseThrowsOnNonexistentFile() {
        let url = URL(fileURLWithPath: "/nonexistent/path/file.json")
        #expect(throws: ParserError.self) {
            _ = try parser.parse(fileAt: url)
        }
    }

    @Test func parseThrowsOnMalformedJSON() {
        let jsonString = "{ invalid json }"
        let data = jsonString.data(using: .utf8)!
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")

        try? data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        #expect(throws: ParserError.self) {
            _ = try parser.parse(fileAt: tempURL)
        }
    }
}
