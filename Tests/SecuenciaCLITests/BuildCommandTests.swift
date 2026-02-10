import Testing
import Foundation
@testable import SecuenciaCLI

#if os(macOS)
import SwiftSecuencia
import Pipeline

/// Tests for the BuildCommand end-to-end pipeline.
///
/// These tests verify that BuildCommand correctly:
/// 1. Parses JSON timeline definitions
/// 2. Resolves file paths relative to JSON location
/// 3. Deduplicates assets and probes durations
/// 4. Bootstraps SwiftData and builds timelines
/// 5. Exports FCPXML (standalone or bundle)
/// 6. Produces well-formed XML output
@Suite("BuildCommand Tests")
struct BuildCommandTests {

    // MARK: - Standalone FCPXML Export

    @Test("Export standalone FCPXML from valid JSON")
    @MainActor
    func testStandaloneFCPXMLExport() async throws {
        // Create test JSON file
        let tempDir = FileManager.default.temporaryDirectory
        let jsonURL = tempDir.appendingPathComponent("test_timeline.json")
        let outputURL = tempDir.appendingPathComponent("test_output.fcpxml")

        // Create placeholder media files
        let audioURL = tempDir.appendingPathComponent("audio1.wav")
        try Data().write(to: audioURL)

        let jsonContent = """
        {
          "timeline": {
            "name": "Test Timeline",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "23.98",
              "colorSpace": "Rec. 709"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48000"
            }
          },
          "clips": [
            {
              "name": "Audio Clip 1",
              "type": "audio",
              "file": "audio1.wav",
              "offset": "0s",
              "duration": "5s",
              "lane": 0
            }
          ]
        }
        """
        try jsonContent.write(to: jsonURL, atomically: true, encoding: .utf8)

        // Parse JSON
        let parser = JSONTimelineParser()
        var definition = try parser.parse(fileAt: jsonURL)

        // Resolve paths
        let resolver = FileResolver()
        definition = try resolver.resolve(definition: definition, relativeTo: tempDir)

        // Deduplicate assets
        let assetMap = resolver.deduplicateAssets(in: definition)

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
        let xmlString = try exporter.export(
            timeline: timeline,
            assetProvider: assetProvider,
            libraryName: "Test Library",
            eventName: "Test Event"
        )

        // Write output
        try xmlString.write(to: outputURL, atomically: true, encoding: .utf8)

        // Verify output file exists
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify XML is well-formed
        let xmlData = try Data(contentsOf: outputURL)
        let xmlDoc = try XMLDocument(data: xmlData)
        #expect(xmlDoc.rootElement()?.name == "fcpxml")

        // Verify version
        let version = xmlDoc.rootElement()?.attribute(forName: "version")?.stringValue
        #expect(version == "1.11")

        // Verify structure
        let resources = try #require(xmlDoc.rootElement()?.elements(forName: "resources").first)
        #expect(resources.children?.count ?? 0 > 0)

        let library = try #require(xmlDoc.rootElement()?.elements(forName: "library").first)
        #expect(library.name == "library")

        // Cleanup
        try? FileManager.default.removeItem(at: jsonURL)
        try? FileManager.default.removeItem(at: outputURL)
        try? FileManager.default.removeItem(at: audioURL)
    }

    // MARK: - Bundle Export

    @Test("Export FCPXML bundle with embedded media")
    @MainActor
    func testBundleExport() async throws {
        // Create test JSON file
        let tempDir = FileManager.default.temporaryDirectory
        let jsonURL = tempDir.appendingPathComponent("test_bundle_timeline.json")

        // Create placeholder media files
        let audioURL = tempDir.appendingPathComponent("audio_bundle.wav")
        try Data(repeating: 0, count: 1024).write(to: audioURL)

        let jsonContent = """
        {
          "timeline": {
            "name": "Bundle Timeline",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "24"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48000"
            }
          },
          "clips": [
            {
              "name": "Audio Clip",
              "type": "audio",
              "file": "audio_bundle.wav",
              "offset": "0s",
              "duration": "3s"
            }
          ]
        }
        """
        try jsonContent.write(to: jsonURL, atomically: true, encoding: .utf8)

        // Parse and build pipeline
        let parser = JSONTimelineParser()
        var definition = try parser.parse(fileAt: jsonURL)

        let resolver = FileResolver()
        definition = try resolver.resolve(definition: definition, relativeTo: tempDir)
        let assetMap = resolver.deduplicateAssets(in: definition)

        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let builder = TimelineBuilder()
        let (timeline, assetProvider) = try await builder.build(
            from: definition,
            assetMap: assetMap,
            in: context
        )

        // Export bundle
        var bundleExporter = FCPXMLBundleExporter(
            version: .v1_11,
            includeMedia: true
        )

        let bundleURL = try await bundleExporter.exportBundle(
            timeline: timeline,
            assetProvider: assetProvider,
            to: tempDir,
            bundleName: "TestBundle",
            libraryName: "Test Library",
            eventName: "Test Event"
        )

        // Verify bundle structure
        #expect(FileManager.default.fileExists(atPath: bundleURL.path))
        #expect(bundleURL.pathExtension == "fcpxmld")

        let infoPlistURL = bundleURL.appendingPathComponent("Info.plist")
        #expect(FileManager.default.fileExists(atPath: infoPlistURL.path))

        let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
        #expect(FileManager.default.fileExists(atPath: fcpxmlURL.path))

        let mediaDir = bundleURL.appendingPathComponent("Media")
        #expect(FileManager.default.fileExists(atPath: mediaDir.path))

        // Verify FCPXML is well-formed
        let xmlData = try Data(contentsOf: fcpxmlURL)
        let xmlDoc = try XMLDocument(data: xmlData)
        #expect(xmlDoc.rootElement()?.name == "fcpxml")

        // Cleanup
        try? FileManager.default.removeItem(at: jsonURL)
        try? FileManager.default.removeItem(at: bundleURL)
        try? FileManager.default.removeItem(at: audioURL)
    }

    // MARK: - Multi-Lane Support

    @Test("Export timeline with multiple lanes")
    @MainActor
    func testMultiLaneExport() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let jsonURL = tempDir.appendingPathComponent("multilane_timeline.json")

        // Create placeholder media
        let audio1URL = tempDir.appendingPathComponent("lane0.wav")
        let audio2URL = tempDir.appendingPathComponent("lane1.wav")
        try Data().write(to: audio1URL)
        try Data().write(to: audio2URL)

        let jsonContent = """
        {
          "timeline": {
            "name": "Multi-Lane Timeline",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "30"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48000"
            }
          },
          "clips": [
            {
              "name": "Lane 0 Clip",
              "type": "audio",
              "file": "lane0.wav",
              "offset": "0s",
              "duration": "5s",
              "lane": 0
            },
            {
              "name": "Lane 1 Clip",
              "type": "audio",
              "file": "lane1.wav",
              "offset": "0s",
              "duration": "5s",
              "lane": 1
            }
          ]
        }
        """
        try jsonContent.write(to: jsonURL, atomically: true, encoding: .utf8)

        // Build timeline
        let parser = JSONTimelineParser()
        var definition = try parser.parse(fileAt: jsonURL)

        let resolver = FileResolver()
        definition = try resolver.resolve(definition: definition, relativeTo: tempDir)
        let assetMap = resolver.deduplicateAssets(in: definition)

        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let builder = TimelineBuilder()
        let (timeline, assetProvider) = try await builder.build(
            from: definition,
            assetMap: assetMap,
            in: context
        )

        // Export
        var exporter = FCPXMLExporter(version: .v1_11)
        let xmlString = try exporter.export(
            timeline: timeline,
            assetProvider: assetProvider
        )

        // Verify XML contains both clips
        #expect(xmlString.contains("Lane 0 Clip"))
        #expect(xmlString.contains("Lane 1 Clip"))

        // Verify XML is well-formed
        let xmlData = xmlString.data(using: .utf8)!
        let xmlDoc = try XMLDocument(data: xmlData)
        #expect(xmlDoc.rootElement()?.name == "fcpxml")

        // Cleanup
        try? FileManager.default.removeItem(at: jsonURL)
        try? FileManager.default.removeItem(at: audio1URL)
        try? FileManager.default.removeItem(at: audio2URL)
    }

    // MARK: - Error Cases

    @Test("Missing file throws error")
    @MainActor
    func testMissingFileError() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let jsonURL = tempDir.appendingPathComponent("missing_file_timeline.json")

        let jsonContent = """
        {
          "timeline": {
            "name": "Missing File Timeline",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "24"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48000"
            }
          },
          "clips": [
            {
              "name": "Missing Clip",
              "type": "audio",
              "file": "nonexistent.wav",
              "offset": "0s",
              "duration": "5s"
            }
          ]
        }
        """
        try jsonContent.write(to: jsonURL, atomically: true, encoding: .utf8)

        // Parse JSON
        let parser = JSONTimelineParser()
        let definition = try parser.parse(fileAt: jsonURL)

        // Resolve paths - should throw error for missing file
        let resolver = FileResolver()
        #expect(throws: FileResolver.FileResolverError.self) {
            try resolver.resolve(definition: definition, relativeTo: tempDir)
        }

        // Cleanup
        try? FileManager.default.removeItem(at: jsonURL)
    }

    @Test("Invalid frame rate throws error")
    @MainActor
    func testInvalidFrameRateError() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let jsonURL = tempDir.appendingPathComponent("invalid_framerate.json")

        let jsonContent = """
        {
          "timeline": {
            "name": "Invalid Frame Rate",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "999.99"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48000"
            }
          },
          "clips": []
        }
        """
        try jsonContent.write(to: jsonURL, atomically: true, encoding: .utf8)

        // Parse JSON - should succeed
        let parser = JSONTimelineParser()
        let definition = try parser.parse(fileAt: jsonURL)

        // Build timeline - should throw error for invalid frame rate
        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let resolver = FileResolver()
        let assetMap = resolver.deduplicateAssets(in: definition)

        let builder = TimelineBuilder()

        // Verify that build throws an error
        do {
            _ = try await builder.build(from: definition, assetMap: assetMap, in: context)
            Issue.record("Expected FrameRateParserError to be thrown")
        } catch is FrameRateParserError {
            // Expected error
        } catch {
            Issue.record("Expected FrameRateParserError but got \(type(of: error))")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: jsonURL)
    }

    // MARK: - Format Version Support

    @Test("Export with different FCPXML versions")
    @MainActor
    func testVersionSupport() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let jsonURL = tempDir.appendingPathComponent("version_test.json")

        // Create placeholder media
        let audioURL = tempDir.appendingPathComponent("audio_version.wav")
        try Data().write(to: audioURL)

        let jsonContent = """
        {
          "timeline": {
            "name": "Version Test",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "24"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48000"
            }
          },
          "clips": [
            {
              "name": "Test Clip",
              "type": "audio",
              "file": "audio_version.wav",
              "offset": "0s",
              "duration": "2s"
            }
          ]
        }
        """
        try jsonContent.write(to: jsonURL, atomically: true, encoding: .utf8)

        // Build timeline once
        let parser = JSONTimelineParser()
        var definition = try parser.parse(fileAt: jsonURL)

        let resolver = FileResolver()
        definition = try resolver.resolve(definition: definition, relativeTo: tempDir)
        let assetMap = resolver.deduplicateAssets(in: definition)

        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let builder = TimelineBuilder()
        let (timeline, assetProvider) = try await builder.build(
            from: definition,
            assetMap: assetMap,
            in: context
        )

        // Test different versions
        let versions: [(FCPXMLVersion, String)] = [
            (.v1_8, "1.8"),
            (.v1_9, "1.9"),
            (.v1_10, "1.10"),
            (.v1_11, "1.11")
        ]

        for (version, versionString) in versions {
            var exporter = FCPXMLExporter(version: version)
            let xmlString = try exporter.export(
                timeline: timeline,
                assetProvider: assetProvider
            )

            let xmlData = xmlString.data(using: .utf8)!
            let xmlDoc = try XMLDocument(data: xmlData)

            let actualVersion = xmlDoc.rootElement()?.attribute(forName: "version")?.stringValue
            #expect(actualVersion == versionString)
        }

        // Cleanup
        try? FileManager.default.removeItem(at: jsonURL)
        try? FileManager.default.removeItem(at: audioURL)
    }
}

#endif // os(macOS)
