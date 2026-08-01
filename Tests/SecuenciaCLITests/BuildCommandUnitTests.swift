//
//  BuildCommandUnitTests.swift
//  SecuenciaCLITests
//
//  Unit tests for BuildCommand CLI entry point.
//

#if os(macOS)

  import Foundation
  import SwiftFijos
  import Testing
  @testable import SecuenciaCLICore
  @testable import SwiftSecuencia

  @Suite("BuildCommand Unit Tests")
  struct BuildCommandUnitTests {

    // MARK: - FCPXMLVersion Extension Tests

    @Test("FCPXMLVersion.from parses valid version strings", arguments: [
      ("1.8", FCPXMLVersion.v1_8),
      ("1.9", FCPXMLVersion.v1_9),
      ("1.10", FCPXMLVersion.v1_10),
      ("1.11", FCPXMLVersion.v1_11),
      ("1.12", FCPXMLVersion.v1_12),
      ("1.13", FCPXMLVersion.v1_13),
      ("1.14", FCPXMLVersion.v1_14),
    ])
    func testVersionParsing(versionString: String, expected: FCPXMLVersion) {
      let parsed = FCPXMLVersion.from(string: versionString)
      #expect(parsed == expected)
    }

    @Test("FCPXMLVersion.from returns default for invalid strings")
    func testVersionParsingInvalid() {
      #expect(FCPXMLVersion.from(string: "1.15") == .default)
      #expect(FCPXMLVersion.from(string: "invalid") == .default)
      #expect(FCPXMLVersion.from(string: "") == .default)
      #expect(FCPXMLVersion.from(string: "2.0") == .default)
    }

    // MARK: - Build Command Initialization Tests

    @Test("Build command initializes with defaults")
    func testCommandInitialization() {
      let command = Build()

      #expect(command.bundle == false)
      #expect(command.formatVersion == "1.14")
      #expect(command.strict == false)
    }

    // MARK: - JSON Parsing Tests

    @Test("Build command parses valid JSON timeline")
    @MainActor
    func testValidJSONParsing() async throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      // Create a minimal valid JSON timeline
      let json = """
        {
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
          },
          "clips": []
        }
        """

      let jsonURL = tempDir.appendingPathComponent("test.json")
      try json.write(to: jsonURL, atomically: true, encoding: .utf8)

      // Parse the JSON
      let parser = JSONTimelineParser()
      let definition = try parser.parse(fileAt: jsonURL)

      #expect(definition.timeline.name == "Test Timeline")
      #expect(definition.timeline.format.width == 1920)
      #expect(definition.timeline.format.height == 1080)
      #expect(definition.clips.isEmpty)
    }

    @Test("Build command rejects invalid JSON")
    @MainActor
    func testInvalidJSONRejection() async throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      // Create invalid JSON
      let json = """
        {
          "name": "Incomplete Timeline"
        }
        """

      let jsonURL = tempDir.appendingPathComponent("invalid.json")
      try json.write(to: jsonURL, atomically: true, encoding: .utf8)

      let parser = JSONTimelineParser()

      #expect(throws: ParserError.self) {
        _ = try parser.parse(fileAt: jsonURL)
      }
    }

    // MARK: - File Resolution Tests

    @Test("FileResolver resolves relative paths")
    func testFileResolution() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      // Create a test file
      let testFile = tempDir.appendingPathComponent("test.wav")
      try Data().write(to: testFile)

      // Create definition with relative path
      let definition = TimelineDefinition(
        timeline: TimelineConfig(
          name: "Test",
          format: FormatConfig(
            width: 1920,
            height: 1080,
            frameRate: "23.98",
            colorSpace: "Rec. 709"
          ),
          audio: AudioConfig(layout: "stereo", rate: "48000")
        ),
        clips: [
          ClipDefinition(
            name: "Clip 1",
            file: "test.wav",  // Relative path
            offset: "0",
            duration: "5.0",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
          )
        ]
      )

      let resolver = FileResolver()
      let resolved = try resolver.resolve(definition: definition, relativeTo: tempDir)

      // Path should be resolved to absolute
      #expect(resolved.clips[0].file?.hasPrefix("/") == true)
      #expect(resolved.clips[0].file?.hasSuffix("test.wav") == true)
    }

    @Test("FileResolver detects missing files")
    func testMissingFileDetection() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      let definition = TimelineDefinition(
        timeline: TimelineConfig(
          name: "Test",
          format: FormatConfig(
            width: 1920,
            height: 1080,
            frameRate: "23.98",
            colorSpace: "Rec. 709"
          ),
          audio: AudioConfig(layout: "stereo", rate: "48000")
        ),
        clips: [
          ClipDefinition(
            name: "Clip 1",
            file: "nonexistent.wav",  // File doesn't exist
            offset: "0",
            duration: "5.0",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
          )
        ]
      )

      let resolver = FileResolver()

      #expect(throws: FileResolver.FileResolverError.self) {
        _ = try resolver.resolve(definition: definition, relativeTo: tempDir)
      }
    }

    // MARK: - Asset Deduplication Tests

    @Test("FileResolver deduplicates identical files")
    func testAssetDeduplication() {
      let definition = TimelineDefinition(
        timeline: TimelineConfig(
          name: "Test",
          format: FormatConfig(
            width: 1920,
            height: 1080,
            frameRate: "23.98",
            colorSpace: "Rec. 709"
          ),
          audio: AudioConfig(layout: "stereo", rate: "48000")
        ),
        clips: [
          ClipDefinition(
            name: "Clip 1",
            file: "/path/to/audio.wav",
            offset: "0",
            duration: "5.0",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
          ),
          ClipDefinition(
            name: "Clip 2",
            file: "/path/to/audio.wav",  // Same file
            offset: "5.0",
            duration: "5.0",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
          ),
          ClipDefinition(
            name: "Clip 3",
            file: "/path/to/other.wav",  // Different file
            offset: "10.0",
            duration: "5.0",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
          ),
        ]
      )

      let resolver = FileResolver()
      let assetMap = resolver.deduplicateAssets(in: definition)

      // Should have 2 unique files despite 3 clips
      #expect(assetMap.count == 2)

      // Same file should map to same UUID
      let uuidsForAudioWav = definition.clips
        .filter { $0.file == "/path/to/audio.wav" }
        .compactMap { $0.file.flatMap { assetMap[$0] } }

      #expect(uuidsForAudioWav.count == 2)
      #expect(uuidsForAudioWav[0] == uuidsForAudioWav[1])
    }

    // MARK: - Output Path Tests

    @Test("Build command generates default output path")
    func testDefaultOutputPath() {
      // Input: /path/to/timeline.json
      // Expected output: /path/to/timeline.fcpxml

      let inputPath = "/path/to/timeline.json"
      let expectedOutput = "/path/to/timeline.fcpxml"

      let defaultOutput = inputPath.replacingOccurrences(of: ".json", with: ".fcpxml")
      #expect(defaultOutput == expectedOutput)
    }

    @Test("Build command uses custom output path when provided")
    func testCustomOutputPath() {
      var command = Build()
      command.inputFile = "/path/to/input.json"
      command.output = "/custom/path/output.fcpxml"

      let outputPath = command.output ?? command.inputFile.replacingOccurrences(
        of: ".json", with: ".fcpxml")
      #expect(outputPath == "/custom/path/output.fcpxml")
    }

    // MARK: - Bundle vs Standalone Tests

    @Test("Build command selects bundle output when flag is set")
    func testBundleOutputSelection() {
      var command = Build()
      command.bundle = true

      // When bundle is true, output should be .fcpxmld
      #expect(command.bundle == true)

      // Default output should have .fcpxmld extension
      let inputPath = "/path/to/timeline.json"
      let expectedBundle = "/path/to/timeline.fcpxmld"

      let bundlePath = inputPath.replacingOccurrences(of: ".json", with: ".fcpxmld")
      #expect(bundlePath == expectedBundle)
    }

    @Test("Build command selects standalone output by default")
    func testStandaloneOutputByDefault() {
      let command = Build()

      #expect(command.bundle == false)

      let inputPath = "/path/to/timeline.json"
      let expectedStandalone = "/path/to/timeline.fcpxml"

      let standalonePath = inputPath.replacingOccurrences(of: ".json", with: ".fcpxml")
      #expect(standalonePath == expectedStandalone)
    }

    // MARK: - Strict Mode Tests

    @Test("Build command respects strict flag")
    func testStrictModeFlag() {
      var command = Build()
      #expect(command.strict == false)

      command.strict = true
      #expect(command.strict == true)
    }

    // MARK: - Format Version Tests

    @Test("Build command uses v1.14 by default")
    func testDefaultFormatVersion() {
      let command = Build()
      #expect(command.formatVersion == "1.14")

      let version = FCPXMLVersion.from(string: command.formatVersion)
      #expect(version == .v1_14)
    }

    @Test("Build command accepts custom format version")
    func testCustomFormatVersion() {
      var command = Build()
      command.formatVersion = "1.11"

      let version = FCPXMLVersion.from(string: command.formatVersion)
      #expect(version == .v1_11)
    }
  }

#endif
