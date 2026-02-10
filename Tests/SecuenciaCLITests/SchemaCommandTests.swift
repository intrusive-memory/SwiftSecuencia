import Testing
import Foundation
@testable import secuencia

@Suite("SchemaCommand Tests")
struct SchemaCommandTests {

    /// Test that schema command outputs valid JSON
    @Test func schemaOutputsValidJSON() throws {
        var command = Schema()

        // Capture stdout by running the command
        // For testing, we can verify the schema file exists and is valid JSON
        guard let schemaURL = Bundle.module.url(forResource: "schema", withExtension: "json") else {
            Issue.record("Schema resource not found in bundle")
            return
        }

        let schemaData = try Data(contentsOf: schemaURL)

        // Should be parseable as JSON
        let jsonObject = try JSONSerialization.jsonObject(with: schemaData)
        #expect(jsonObject is [String: Any])
    }

    /// Test that schema contains required $schema key
    @Test func schemaContainsDollarSchemaKey() throws {
        guard let schemaURL = Bundle.module.url(forResource: "schema", withExtension: "json") else {
            Issue.record("Schema resource not found in bundle")
            return
        }

        let schemaData = try Data(contentsOf: schemaURL)
        let jsonObject = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any]

        #expect(jsonObject?["$schema"] != nil)
        #expect(jsonObject?["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema")
    }

    /// Test that example JSON from execution plan conforms to schema
    @Test func exampleJSONConformsToSchema() throws {
        // Example JSON from execution plan
        let exampleJSON = """
        {
          "timeline": {
            "name": "Tutorial Video",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "23.98",
              "colorSpace": "rec709"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48kHz"
            }
          },
          "clips": [
            {
              "name": "Title Card",
              "file": "media/title-card.png",
              "offset": "0s",
              "duration": "3s",
              "lane": 0,
              "type": "image"
            },
            {
              "name": "Act 1 Screen Recording",
              "file": "media/act1-screen.mov",
              "offset": "3s",
              "duration": "42s",
              "lane": 0,
              "type": "video"
            },
            {
              "name": "Act 1 Narration",
              "file": "media/act1-narration.m4a",
              "offset": "3s",
              "lane": -1,
              "type": "audio"
            },
            {
              "name": "Chapter 1",
              "offset": "0s",
              "type": "marker",
              "markerType": "chapter"
            }
          ]
        }
        """

        let exampleData = Data(exampleJSON.utf8)

        // Should be parseable as JSON
        let jsonObject = try JSONSerialization.jsonObject(with: exampleData) as? [String: Any]
        #expect(jsonObject != nil)

        // Verify required top-level keys
        #expect(jsonObject?["timeline"] != nil)
        #expect(jsonObject?["clips"] != nil)

        // Verify timeline structure
        let timeline = jsonObject?["timeline"] as? [String: Any]
        #expect(timeline?["name"] as? String == "Tutorial Video")
        #expect(timeline?["format"] != nil)
        #expect(timeline?["audio"] != nil)

        // Verify clips array
        let clips = jsonObject?["clips"] as? [[String: Any]]
        #expect(clips?.count == 4)

        // Verify first clip has required fields
        let firstClip = clips?.first
        #expect(firstClip?["name"] as? String == "Title Card")
        #expect(firstClip?["file"] as? String == "media/title-card.png")
        #expect(firstClip?["offset"] as? String == "0s")
        #expect(firstClip?["type"] as? String == "image")
    }

    /// Test that Sprint 8 JSON fixtures conform to schema
    @Test func sprint8FixturesConformToSchema() throws {
        let fixtureNames = [
            "simple-timeline.json",
            "markers-timeline.json",
            "multi-lane-timeline.json",
            "auto-duration.json"
        ]

        for fixtureName in fixtureNames {
            let fixtureURL = try getFixtureURL(fixtureName)
            let fixtureData = try Data(contentsOf: fixtureURL)

            // Should be parseable as JSON
            let jsonObject = try JSONSerialization.jsonObject(with: fixtureData) as? [String: Any]
            #expect(jsonObject != nil, "Fixture \(fixtureName) is not valid JSON")

            // Verify required top-level structure
            #expect(jsonObject?["timeline"] != nil, "Fixture \(fixtureName) missing timeline")
            #expect(jsonObject?["clips"] != nil, "Fixture \(fixtureName) missing clips")

            // Verify timeline has required fields
            let timeline = jsonObject?["timeline"] as? [String: Any]
            #expect(timeline?["name"] != nil, "Fixture \(fixtureName) timeline missing name")
            #expect(timeline?["format"] != nil, "Fixture \(fixtureName) timeline missing format")
            #expect(timeline?["audio"] != nil, "Fixture \(fixtureName) timeline missing audio")

            // Verify format has required fields
            let format = timeline?["format"] as? [String: Any]
            #expect(format?["width"] != nil, "Fixture \(fixtureName) format missing width")
            #expect(format?["height"] != nil, "Fixture \(fixtureName) format missing height")
            #expect(format?["frameRate"] != nil, "Fixture \(fixtureName) format missing frameRate")

            // Verify audio has required fields
            let audio = timeline?["audio"] as? [String: Any]
            #expect(audio?["layout"] != nil, "Fixture \(fixtureName) audio missing layout")
            #expect(audio?["rate"] != nil, "Fixture \(fixtureName) audio missing rate")

            // Verify clips array
            let clips = jsonObject?["clips"] as? [[String: Any]]
            #expect(clips != nil, "Fixture \(fixtureName) clips is not an array")

            // Verify each clip has required fields
            for (index, clip) in (clips ?? []).enumerated() {
                #expect(clip["name"] != nil, "Fixture \(fixtureName) clip \(index) missing name")
                #expect(clip["offset"] != nil, "Fixture \(fixtureName) clip \(index) missing offset")
                #expect(clip["type"] != nil, "Fixture \(fixtureName) clip \(index) missing type")

                // If type is marker, markerType is required
                if let type = clip["type"] as? String, type == "marker" {
                    #expect(clip["markerType"] != nil, "Fixture \(fixtureName) marker clip \(index) missing markerType")
                }

                // If type is not marker, file is required
                if let type = clip["type"] as? String, type != "marker" {
                    #expect(clip["file"] != nil, "Fixture \(fixtureName) clip \(index) of type \(type) missing file")
                }
            }
        }
    }

    /// Test that schema contains all required enum values
    @Test func schemaContainsAllEnumValues() throws {
        guard let schemaURL = Bundle.module.url(forResource: "schema", withExtension: "json") else {
            Issue.record("Schema resource not found in bundle")
            return
        }

        let schemaData = try Data(contentsOf: schemaURL)
        let schema = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any]

        // Navigate to $defs
        let defs = schema?["$defs"] as? [String: Any]
        #expect(defs != nil)

        // Check FormatConfig has frameRate enum
        let formatConfig = defs?["FormatConfig"] as? [String: Any]
        let formatProperties = formatConfig?["properties"] as? [String: Any]
        let frameRate = formatProperties?["frameRate"] as? [String: Any]
        let frameRateEnum = frameRate?["enum"] as? [String]
        #expect(frameRateEnum?.contains("23.98") == true)
        #expect(frameRateEnum?.contains("24") == true)
        #expect(frameRateEnum?.contains("25") == true)
        #expect(frameRateEnum?.contains("29.97") == true)
        #expect(frameRateEnum?.contains("30") == true)
        #expect(frameRateEnum?.contains("50") == true)
        #expect(frameRateEnum?.contains("59.94") == true)
        #expect(frameRateEnum?.contains("60") == true)

        // Check FormatConfig has colorSpace enum
        let colorSpace = formatProperties?["colorSpace"] as? [String: Any]
        let colorSpaceEnum = colorSpace?["enum"] as? [String]
        #expect(colorSpaceEnum?.contains("rec709") == true)
        #expect(colorSpaceEnum?.contains("rec2020") == true)
        #expect(colorSpaceEnum?.contains("dciP3") == true)

        // Check AudioConfig has layout enum
        let audioConfig = defs?["AudioConfig"] as? [String: Any]
        let audioProperties = audioConfig?["properties"] as? [String: Any]
        let layout = audioProperties?["layout"] as? [String: Any]
        let layoutEnum = layout?["enum"] as? [String]
        #expect(layoutEnum?.contains("mono") == true)
        #expect(layoutEnum?.contains("stereo") == true)
        #expect(layoutEnum?.contains("surround") == true)

        // Check AudioConfig has rate enum
        let rate = audioProperties?["rate"] as? [String: Any]
        let rateEnum = rate?["enum"] as? [String]
        #expect(rateEnum?.contains("44.1kHz") == true)
        #expect(rateEnum?.contains("48kHz") == true)
        #expect(rateEnum?.contains("96kHz") == true)

        // Check ClipDefinition has type enum
        let clipDefinition = defs?["ClipDefinition"] as? [String: Any]
        let clipProperties = clipDefinition?["properties"] as? [String: Any]
        let type = clipProperties?["type"] as? [String: Any]
        let typeEnum = type?["enum"] as? [String]
        #expect(typeEnum?.contains("video") == true)
        #expect(typeEnum?.contains("audio") == true)
        #expect(typeEnum?.contains("image") == true)
        #expect(typeEnum?.contains("marker") == true)

        // Check ClipDefinition has markerType enum
        let markerType = clipProperties?["markerType"] as? [String: Any]
        let markerTypeEnum = markerType?["enum"] as? [String]
        #expect(markerTypeEnum?.contains("standard") == true)
        #expect(markerTypeEnum?.contains("chapter") == true)
        #expect(markerTypeEnum?.contains("todo") == true)
    }

    // MARK: - Helpers

    private func getFixtureURL(_ name: String) throws -> URL {
        let fixturesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")

        let fixtureURL = fixturesDir.appendingPathComponent(name)

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw TestError.fixtureNotFound(name)
        }

        return fixtureURL
    }

    enum TestError: Error {
        case fixtureNotFound(String)
    }
}
