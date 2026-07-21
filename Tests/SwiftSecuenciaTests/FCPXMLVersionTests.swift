//
//  FCPXMLVersionTests.swift
//  SwiftSecuenciaTests
//
//  Tests for FCPXML version compatibility across all supported DTD versions.
//

#if os(macOS)

  import Foundation
  import SwiftData
  import Testing
  @testable import SwiftSecuencia

  @Suite("FCPXML Version Compatibility")
  struct FCPXMLVersionTests {

    // MARK: - Test Helpers

    private static func createTestContainer() throws -> ModelContainer {
      let schema = Schema([
        Timeline.self,
        TimelineClip.self,
        TypedDataStorage.self,
      ])

      let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true
      )

      return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    private func createSimpleTimeline(context: ModelContext) throws -> (
      timeline: Timeline, assetID: UUID
    ) {
      let assetID = UUID()

      let timeline = Timeline(
        name: "Version Test Timeline",
        videoFormat: .hd1080p(frameRate: .fps23_98),
        audioLayout: .stereo,
        audioRate: .rate48k
      )

      let clip = TimelineClip(
        name: "Test Clip",
        assetStorageId: assetID,
        startTime: 0.0,
        duration: 10.0,
        offset: 0.0,
        lane: 0
      )

      timeline.clips.append(clip)
      context.insert(timeline)
      try context.save()

      return (timeline, assetID)
    }

    private func createMockAssetProvider(assetID: UUID) -> FileAssetProvider {
      // Create a mock provider with a placeholder URL
      let mockURL = URL(fileURLWithPath: "/tmp/test.wav")
      return FileAssetProvider(assets: [assetID: mockURL])
    }

    // MARK: - Version String Tests

    @Test("All supported versions have correct string representation", arguments: [
      (FCPXMLVersion.v1_8, "1.8"),
      (FCPXMLVersion.v1_9, "1.9"),
      (FCPXMLVersion.v1_10, "1.10"),
      (FCPXMLVersion.v1_11, "1.11"),
      (FCPXMLVersion.v1_12, "1.12"),
      (FCPXMLVersion.v1_13, "1.13"),
      (FCPXMLVersion.v1_14, "1.14"),
    ])
    func testVersionStringValues(version: FCPXMLVersion, expectedString: String) {
      #expect(version.stringValue == expectedString)
    }

    @Test("Default version is 1.14")
    func testDefaultVersion() {
      #expect(FCPXMLVersion.default == .v1_14)
    }

    // MARK: - XML Document Version Tests

    @Test("Exported XML contains correct version attribute", arguments: [
      FCPXMLVersion.v1_8,
      FCPXMLVersion.v1_9,
      FCPXMLVersion.v1_10,
      FCPXMLVersion.v1_11,
      FCPXMLVersion.v1_12,
      FCPXMLVersion.v1_13,
      FCPXMLVersion.v1_14,
    ])
    @MainActor
    func testExportedVersionAttribute(version: FCPXMLVersion) async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createSimpleTimeline(context: context)
      let provider = createMockAssetProvider(assetID: assetID)

      var exporter = FCPXMLExporter(version: version)

      let xmlString = try exporter.export(
        timeline: timeline,
        assetProvider: provider
      )

      // Parse XML and check version
      guard let xmlData = xmlString.data(using: .utf8) else {
        Issue.record("Failed to convert XML string to data")
        return
      }

      let xmlDoc = try XMLDocument(data: xmlData)
      let rootElement = xmlDoc.rootElement()

      #expect(rootElement?.name == "fcpxml")

      let versionAttr = rootElement?.attribute(forName: "version")?.stringValue
      #expect(versionAttr == version.stringValue)
    }

    // MARK: - DTD Validation Tests

    @Test("All supported versions have DTD files available", arguments: [
      FCPXMLVersion.v1_8,
      FCPXMLVersion.v1_9,
      FCPXMLVersion.v1_10,
      FCPXMLVersion.v1_11,
      FCPXMLVersion.v1_12,
      FCPXMLVersion.v1_13,
      FCPXMLVersion.v1_14,
    ])
    func testDTDAvailability(version: FCPXMLVersion) throws {
      let dtdFilename = version.dtdFilenameWithExtension

      // Check if DTD file exists in test fixtures
      let bundle = Bundle.module
      let dtdURL = bundle.url(forResource: dtdFilename.replacingOccurrences(of: ".dtd", with: ""), withExtension: "dtd")

      #expect(dtdURL != nil, "DTD file \(dtdFilename) should exist in test fixtures")

      if let url = dtdURL {
        let dtdData = try Data(contentsOf: url)
        #expect(dtdData.count > 0, "DTD file \(dtdFilename) should not be empty")
      }
    }

    // MARK: - Version Feature Tests

    @Test("Bundle support is available for v1.10 and later", arguments: [
      (FCPXMLVersion.v1_8, false),
      (FCPXMLVersion.v1_9, false),
      (FCPXMLVersion.v1_10, true),
      (FCPXMLVersion.v1_11, true),
      (FCPXMLVersion.v1_12, true),
      (FCPXMLVersion.v1_13, true),
      (FCPXMLVersion.v1_14, true),
    ])
    func testBundleSupportAvailability(version: FCPXMLVersion, shouldSupport: Bool) {
      // v1.10 introduced bundle support
      let supportsBundles = version.rawValue >= FCPXMLVersion.v1_10.rawValue

      #expect(
        supportsBundles == shouldSupport,
        "Version \(version.stringValue) bundle support should be \(shouldSupport)")
    }

    @Test("Version numbering is sequential")
    func testVersionSequence() {
      // Ensure version enum raw values are in order
      #expect(FCPXMLVersion.v1_8.rawValue < FCPXMLVersion.v1_9.rawValue)
      #expect(FCPXMLVersion.v1_9.rawValue < FCPXMLVersion.v1_10.rawValue)
      #expect(FCPXMLVersion.v1_10.rawValue < FCPXMLVersion.v1_11.rawValue)
      #expect(FCPXMLVersion.v1_11.rawValue < FCPXMLVersion.v1_12.rawValue)
      #expect(FCPXMLVersion.v1_12.rawValue < FCPXMLVersion.v1_13.rawValue)
      #expect(FCPXMLVersion.v1_13.rawValue < FCPXMLVersion.v1_14.rawValue)
    }

    // MARK: - XML Structure Validation

    @Test("All versions produce valid XML with required structure", arguments: [
      FCPXMLVersion.v1_10,
      FCPXMLVersion.v1_11,
      FCPXMLVersion.v1_12,
      FCPXMLVersion.v1_13,
      FCPXMLVersion.v1_14,
    ])
    @MainActor
    func testXMLStructureForVersion(version: FCPXMLVersion) async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createSimpleTimeline(context: context)
      let provider = createMockAssetProvider(assetID: assetID)

      var exporter = FCPXMLExporter(version: version)

      let xmlString = try exporter.export(
        timeline: timeline,
        assetProvider: provider
      )

      guard let xmlData = xmlString.data(using: .utf8) else {
        Issue.record("Failed to convert XML string to data")
        return
      }

      let xmlDoc = try XMLDocument(data: xmlData)

      // Verify root element structure
      guard let root = xmlDoc.rootElement() else {
        Issue.record("No root element found")
        return
      }

      #expect(root.name == "fcpxml")

      // Verify required child elements
      let resources = root.elements(forName: "resources").first
      let library = root.elements(forName: "library").first

      #expect(resources != nil, "resources element should exist")
      #expect(library != nil, "library element should exist")

      // Verify library > event > project structure
      if let lib = library {
        let events = lib.elements(forName: "event")
        #expect(events.count > 0, "library should contain at least one event")

        if let firstEvent = events.first {
          let projects = firstEvent.elements(forName: "project")
          #expect(projects.count > 0, "event should contain at least one project")
        }
      }
    }

    // MARK: - Backward Compatibility Tests

    @Test("Exporter can switch between versions")
    @MainActor
    func testVersionSwitching() async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createSimpleTimeline(context: context)
      let provider = createMockAssetProvider(assetID: assetID)

      // Export with v1.13
      var exporter1 = FCPXMLExporter(version: .v1_13)
      let xml1 = try exporter1.export(timeline: timeline, assetProvider: provider)
      #expect(xml1.contains("version=\"1.13\""))

      // Export same timeline with v1.14
      var exporter2 = FCPXMLExporter(version: .v1_14)
      let xml2 = try exporter2.export(timeline: timeline, assetProvider: provider)
      #expect(xml2.contains("version=\"1.14\""))

      // Verify both exports contain the same clip
      #expect(xml1.contains("Test Clip"))
      #expect(xml2.contains("Test Clip"))
    }

    // MARK: - Version String Parsing Tests

    @Test("Version can be constructed from string", arguments: [
      ("1.8", FCPXMLVersion.v1_8),
      ("1.9", FCPXMLVersion.v1_9),
      ("1.10", FCPXMLVersion.v1_10),
      ("1.11", FCPXMLVersion.v1_11),
      ("1.12", FCPXMLVersion.v1_12),
      ("1.13", FCPXMLVersion.v1_13),
      ("1.14", FCPXMLVersion.v1_14),
    ])
    func testVersionFromString(versionString: String, expectedVersion: FCPXMLVersion) {
      let parsedVersion = FCPXMLVersion(string: versionString)
      #expect(parsedVersion == expectedVersion)
    }

    @Test("Invalid version string returns default")
    func testInvalidVersionString() {
      let invalidVersions = ["1.15", "2.0", "invalid", "", "1.7"]

      for versionString in invalidVersions {
        let parsed = FCPXMLVersion(string: versionString)
        #expect(
          parsed == .default,
          "Invalid version '\(versionString)' should return default (.v1_14)")
      }
    }

    // MARK: - Comprehensive Version Export Test

    @Test("All versions export without errors")
    @MainActor
    func testAllVersionsExport() async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createSimpleTimeline(context: context)
      let provider = createMockAssetProvider(assetID: assetID)

      let allVersions: [FCPXMLVersion] = [
        .v1_8, .v1_9, .v1_10, .v1_11, .v1_12, .v1_13, .v1_14,
      ]

      for version in allVersions {
        var exporter = FCPXMLExporter(version: version)

        // Should not throw
        let xmlString = try exporter.export(
          timeline: timeline,
          assetProvider: provider
        )

        #expect(!xmlString.isEmpty, "Export for version \(version.stringValue) should not be empty")
        #expect(
          xmlString.contains("version=\"\(version.stringValue)\""),
          "Export should contain correct version attribute")
      }
    }
  }

#endif
