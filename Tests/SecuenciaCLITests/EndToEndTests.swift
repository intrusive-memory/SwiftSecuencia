import Foundation
import Testing
@testable import SecuenciaCLICore

#if os(macOS)
import SwiftSecuencia
// PipelineNeo types are accessed via SwiftSecuencia re-exports

/// End-to-end tests for the complete CLI pipeline.
///
/// These tests verify the full flow from JSON input to FCPXML output,
/// including file resolution, media probing, timeline building, and export.
@Suite("End-to-End Tests")
struct EndToEndTests {

    // MARK: - Helper Methods

    /// Returns the URL for a fixture file.
    private func fixtureURL(_ filename: String) -> URL {
        let fixturesPath = #filePath
            .replacingOccurrences(of: "EndToEndTests.swift", with: "Fixtures")
        return URL(fileURLWithPath: fixturesPath)
            .appendingPathComponent(filename)
    }

    /// Parses XML string and returns an XMLDocument.
    private func parseXML(_ xmlString: String) throws -> XMLDocument {
        let data = xmlString.data(using: .utf8)!
        return try XMLDocument(data: data, options: [])
    }

    /// Returns XPath query results as XMLNode array.
    private func xpath(_ query: String, in document: XMLDocument) throws -> [XMLNode] {
        return try document.nodes(forXPath: query)
    }

    // MARK: - Task 8.9: Simple Timeline Export

    @Test("Simple timeline export produces valid FCPXML")
    @MainActor
    func simpleTimelineExport() async throws {
        // Given: A JSON file with image, video, and audio clips
        let jsonURL = fixtureURL("simple-timeline.json")

        // When: Parse and build timeline
        let parser = JSONTimelineParser()
        var definition = try parser.parse(fileAt: jsonURL)

        let resolver = FileResolver()
        definition = try resolver.resolve(definition: definition, relativeTo: jsonURL.deletingLastPathComponent())

        let assetMap = resolver.deduplicateAssets(in: definition)

        let probe = MediaProbe()
        definition = try await probe.probeMissingDurations(in: definition)

        // Build timeline
        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let builder = TimelineBuilder()
        let (timeline, assetProvider) = try await builder.build(
            from: definition,
            assetMap: assetMap,
            in: context
        )

        // Export FCPXML
        var exporter = FCPXMLExporter(version: .v1_11)
        let fcpxmlString = try exporter.export(
            timeline: timeline,
            assetProvider: assetProvider,
            libraryName: "Test Library",
            eventName: "Test Event"
        )

        // Then: Verify FCPXML structure
        let document = try parseXML(fcpxmlString)

        // Verify version attribute
        let version = document.rootElement()?.attribute(forName: "version")?.stringValue
        #expect(version == "1.11")

        // Verify 3 asset elements (image, video, audio)
        let assetNodes = try xpath("//asset", in: document)
        #expect(assetNodes.count == 3)

        // Verify format element (1080p)
        let formatNodes = try xpath("//format", in: document)
        #expect(formatNodes.count >= 1)
        let formatElement = formatNodes.first as? XMLElement
        #expect(formatElement?.attribute(forName: "width")?.stringValue == "1920")
        #expect(formatElement?.attribute(forName: "height")?.stringValue == "1080")

        // Verify clip offsets
        let clipNodes = try xpath("//asset-clip", in: document)
        #expect(clipNodes.count == 3)

        // Verify at least one clip has offset="0s" (the image)
        let hasZeroOffset = clipNodes.contains { node in
            (node as? XMLElement)?.attribute(forName: "offset")?.stringValue == "0s"
        }
        #expect(hasZeroOffset)

        // Verify at least one clip has offset="3s" (the video)
        let hasThreeSecondOffset = clipNodes.contains { node in
            (node as? XMLElement)?.attribute(forName: "offset")?.stringValue?.contains("3") == true
        }
        #expect(hasThreeSecondOffset)
    }

    // MARK: - Task 8.10: Multi-Lane Audio

    @Test("Multi-lane audio on lane -1 works")
    @MainActor
    func multiLaneAudio() async throws {
        // Given: A JSON file with audio on lane -1
        let jsonURL = fixtureURL("multi-lane-timeline.json")

        // When: Parse and build timeline
        let parser = JSONTimelineParser()
        var definition = try parser.parse(fileAt: jsonURL)

        let resolver = FileResolver()
        definition = try resolver.resolve(definition: definition, relativeTo: jsonURL.deletingLastPathComponent())

        let assetMap = resolver.deduplicateAssets(in: definition)

        let probe = MediaProbe()
        definition = try await probe.probeMissingDurations(in: definition)

        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let builder = TimelineBuilder()
        let (timeline, assetProvider) = try await builder.build(
            from: definition,
            assetMap: assetMap,
            in: context
        )

        // Export FCPXML
        var exporter = FCPXMLExporter(version: .v1_11)
        let fcpxmlString = try exporter.export(
            timeline: timeline,
            assetProvider: assetProvider,
            libraryName: "Test Library",
            eventName: "Test Event"
        )

        // Then: Verify lane -1 in spine structure
        let document = try parseXML(fcpxmlString)

        // Check for lane attribute in clips
        let clipNodes = try xpath("//asset-clip", in: document)

        // At least one clip should have lane attribute
        let hasLaneAttribute = clipNodes.contains { node in
            (node as? XMLElement)?.attribute(forName: "lane") != nil
        }

        // If we have multi-lane structure, verify it
        if hasLaneAttribute {
            // Check that lane -1 exists
            let hasNegativeLane = clipNodes.contains { node in
                let laneValue = (node as? XMLElement)?.attribute(forName: "lane")?.stringValue
                return laneValue == "-1"
            }
            #expect(hasNegativeLane)
        }

        // Verify timeline has correct clip count
        #expect(timeline.clips.count == 3)

        // Verify at least one clip is on lane -1
        let hasAudioOnNegativeLane = timeline.clips.contains { $0.lane == -1 }
        #expect(hasAudioOnNegativeLane)
    }

    // MARK: - Task 8.11: Marker Export

    @Test("Chapter markers stored in timeline")
    @MainActor
    func markerExport() async throws {
        // Given: A JSON file with chapter markers
        let jsonURL = fixtureURL("markers-timeline.json")

        // When: Parse and build timeline
        let parser = JSONTimelineParser()
        var definition = try parser.parse(fileAt: jsonURL)

        let resolver = FileResolver()
        definition = try resolver.resolve(definition: definition, relativeTo: jsonURL.deletingLastPathComponent())

        let assetMap = resolver.deduplicateAssets(in: definition)

        let probe = MediaProbe()
        definition = try await probe.probeMissingDurations(in: definition)

        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let builder = TimelineBuilder()
        let (timeline, assetProvider) = try await builder.build(
            from: definition,
            assetMap: assetMap,
            in: context
        )

        // Then: Verify chapter markers stored in timeline
        #expect(timeline.chapterMarkers.count == 2)

        // Verify markers are at correct offsets
        let marker1 = timeline.chapterMarkers[0]
        let offset1Seconds = Double(marker1.start.value) / Double(marker1.start.timescale)
        #expect(abs(offset1Seconds - 0.0) < 0.01)

        let marker2 = timeline.chapterMarkers[1]
        let offset2Seconds = Double(marker2.start.value) / Double(marker2.start.timescale)
        #expect(abs(offset2Seconds - 3.0) < 0.01)

        // Note: FCPXMLExporter does not yet export chapter markers to FCPXML.
        // Chapter markers are stored in the Timeline model and will be exported
        // by FCPXMLBundleExporter in Task 8.12.
    }

    // MARK: - Task 8.13: Auto-Duration Probing

    @Test("Auto-duration probing within tolerance")
    @MainActor
    func autoDurationProbing() async throws {
        // Given: A JSON file with clips WITHOUT explicit duration
        let jsonURL = fixtureURL("auto-duration.json")

        // When: Parse and probe durations
        let parser = JSONTimelineParser()
        var definition = try parser.parse(fileAt: jsonURL)

        let resolver = FileResolver()
        definition = try resolver.resolve(definition: definition, relativeTo: jsonURL.deletingLastPathComponent())

        let probe = MediaProbe()
        definition = try await probe.probeMissingDurations(in: definition)

        // Then: Verify durations were probed
        #expect(definition.clips.count == 2)

        // Video clip should have ~1.0s duration
        let videoClip = definition.clips.first { $0.type == .video }
        #expect(videoClip != nil)
        #expect(videoClip!.duration != nil)

        // Parse duration and verify within tolerance
        let videoParser = TimeStringParser()
        let videoDuration = try videoParser.parse(videoClip!.duration!)
        let videoSeconds = Double(videoDuration.value) / Double(videoDuration.timescale)
        #expect(abs(videoSeconds - 1.0) < 0.1) // Within ±0.1s

        // Audio clip should have ~2.0s duration
        let audioClip = definition.clips.first { $0.type == .audio }
        #expect(audioClip != nil)
        #expect(audioClip!.duration != nil)

        let audioDuration = try videoParser.parse(audioClip!.duration!)
        let audioSeconds = Double(audioDuration.value) / Double(audioDuration.timescale)
        #expect(abs(audioSeconds - 2.0) < 0.1) // Within ±0.1s
    }

    // MARK: - Task 8.14: Error Handling

    @Test("Missing JSON file produces error with path")
    @MainActor
    func missingJSONFile() async throws {
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).json")

        let parser = JSONTimelineParser()

        do {
            _ = try parser.parse(fileAt: nonexistentURL)
            Issue.record("Expected error for missing file")
        } catch {
            // Error should contain the file path
            let errorDescription = String(describing: error)
            #expect(errorDescription.contains(nonexistentURL.path) || errorDescription.contains("No such file"))
        }
    }

    @Test("Malformed JSON produces parse error")
    @MainActor
    func malformedJSON() async throws {
        // Create temp file with invalid JSON
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("malformed-\(UUID().uuidString).json")

        try "{ invalid json }".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = JSONTimelineParser()

        do {
            _ = try parser.parse(fileAt: tempURL)
            Issue.record("Expected parse error for malformed JSON")
        } catch {
            // Should produce JSON parsing error
            #expect(String(describing: error).contains("parse") || String(describing: error).contains("JSON") || String(describing: error).contains("decode"))
        }
    }

    @Test("Nonexistent media file produces error with resolved path")
    @MainActor
    func nonexistentMediaFile() async throws {
        // Create JSON referencing nonexistent media
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bad-media-\(UUID().uuidString).json")

        let json = """
        {
          "timeline": {
            "name": "Test",
            "format": { "width": 1920, "height": 1080, "frameRate": "24", "colorSpace": "rec709" },
            "audio": { "layout": "stereo", "rate": "48kHz" }
          },
          "clips": [
            {
              "name": "Missing",
              "file": "nonexistent.mov",
              "offset": "0s",
              "duration": "1s",
              "lane": 0,
              "type": "video"
            }
          ]
        }
        """

        try json.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = JSONTimelineParser()
        let definition = try parser.parse(fileAt: tempURL)

        let resolver = FileResolver()

        do {
            _ = try resolver.resolve(definition: definition, relativeTo: tempURL.deletingLastPathComponent())
            Issue.record("Expected error for nonexistent media file")
        } catch {
            // Error should contain the resolved absolute path
            let errorDescription = String(describing: error)
            #expect(errorDescription.contains("nonexistent.mov") || errorDescription.contains("does not exist"))
        }
    }

    @Test("Clip with no duration and no file produces error")
    @MainActor
    func clipNoDurationNoFile() async throws {
        // Create JSON with marker (no file) but also try with audio clip missing both
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-duration-\(UUID().uuidString).json")

        let json = """
        {
          "timeline": {
            "name": "Test",
            "format": { "width": 1920, "height": 1080, "frameRate": "24", "colorSpace": "rec709" },
            "audio": { "layout": "stereo", "rate": "48kHz" }
          },
          "clips": [
            {
              "name": "Bad Clip",
              "offset": "0s",
              "lane": 0,
              "type": "video"
            }
          ]
        }
        """

        try json.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = JSONTimelineParser()

        do {
            _ = try parser.parse(fileAt: tempURL)
            Issue.record("Expected validation error for clip without file")
        } catch {
            // Should fail validation (non-marker clips need file)
            #expect(String(describing: error).contains("file") || String(describing: error).contains("required"))
        }
    }

    @Test("Invalid time string produces error with invalid value")
    @MainActor
    func invalidTimeString() async throws {
        let parser = TimeStringParser()

        do {
            _ = try parser.parse("not-a-time")
            Issue.record("Expected error for invalid time string")
        } catch {
            // Error should mention the invalid value
            let errorDescription = String(describing: error)
            #expect(errorDescription.contains("not-a-time") || errorDescription.contains("invalid") || errorDescription.contains("format"))
        }
    }
}

#endif // os(macOS)
