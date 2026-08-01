//
//  FCPXMLBundleExporterTests.swift
//  SwiftSecuenciaTests
//
//  Tests for FCPXML bundle (.fcpxmld) export functionality.
//

#if os(macOS)

  import Foundation
  import SwiftCompartido
  import SwiftData
  import SwiftTimecode
  import Testing
  @testable import SwiftSecuencia

  @Suite("FCPXML Bundle Exporter")
  struct FCPXMLBundleExporterTests {

    // MARK: - Test Helpers

    /// Creates an in-memory model container for testing.
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

    /// Creates a simple test timeline with one clip.
    @MainActor
    private func createTestTimeline(
      context: ModelContext,
      name: String = "Test Timeline"
    ) throws -> (timeline: Timeline, assetID: UUID) {
      let assetID = UUID()

      let timeline = Timeline(
        name: name,
        videoFormat: .hd1080p(frameRate: .fps23_98),
        audioLayout: .stereo,
        audioRate: .rate48kHz
      )

      let clip = TimelineClip(
        name: "Test Clip",
        assetStorageId: assetID,
        offset: Timecode(seconds: 0.0),
        duration: Timecode(seconds: 5.0),
        sourceStart: Timecode(seconds: 0.0),
        lane: 0
      )

      timeline.clips.append(clip)
      context.insert(timeline)
      try context.save()

      return (timeline, assetID)
    }

    /// Creates a test asset provider with mock media files.
    private func createTestAssetProvider(assetID: UUID, tempDir: URL) throws
      -> FileAssetProvider {
      // Create a test audio file (silent WAV)
      let audioData = createSilentWAVData(duration: 5.0, sampleRate: 48000)
      let audioURL = tempDir.appendingPathComponent("\(assetID.uuidString).wav")
      try audioData.write(to: audioURL)

      // Create FileAssetProvider with the test file
      let entry = FileAssetEntry(
        fileURL: audioURL,
        name: "Test Audio",
        mimeType: "audio/wav",
        durationSeconds: 5.0,
        hasVideo: false,
        hasAudio: true
      )
      let provider = FileAssetProvider(registry: [assetID: entry])
      return provider
    }

    /// Creates silent WAV audio data for testing.
    private func createSilentWAVData(duration: Double, sampleRate: Int) -> Data {
      let numSamples = Int(duration * Double(sampleRate))
      let dataSize = numSamples * 2  // 16-bit samples

      var data = Data()

      // WAV header
      data.append("RIFF".data(using: .ascii)!)  // ChunkID
      let fileSize = UInt32(dataSize + 36).littleEndian
      data.append(contentsOf: withUnsafeBytes(of: fileSize) { Data($0) })
      data.append("WAVE".data(using: .ascii)!)  // Format

      // fmt subchunk
      data.append("fmt ".data(using: .ascii)!)  // Subchunk1ID
      let fmtSize = UInt32(16).littleEndian
      data.append(contentsOf: withUnsafeBytes(of: fmtSize) { Data($0) })
      let audioFormat = UInt16(1).littleEndian  // PCM
      data.append(contentsOf: withUnsafeBytes(of: audioFormat) { Data($0) })
      let numChannels = UInt16(2).littleEndian  // Stereo
      data.append(contentsOf: withUnsafeBytes(of: numChannels) { Data($0) })
      let rate = UInt32(sampleRate).littleEndian
      data.append(contentsOf: withUnsafeBytes(of: rate) { Data($0) })
      let byteRate = UInt32(sampleRate * 2 * 2).littleEndian
      data.append(contentsOf: withUnsafeBytes(of: byteRate) { Data($0) })
      let blockAlign = UInt16(4).littleEndian
      data.append(contentsOf: withUnsafeBytes(of: blockAlign) { Data($0) })
      let bitsPerSample = UInt16(16).littleEndian
      data.append(contentsOf: withUnsafeBytes(of: bitsPerSample) { Data($0) })

      // data subchunk
      data.append("data".data(using: .ascii)!)  // Subchunk2ID
      let dataChunkSize = UInt32(dataSize).littleEndian
      data.append(contentsOf: withUnsafeBytes(of: dataChunkSize) { Data($0) })

      // Append silent audio (zeros)
      data.append(Data(count: dataSize))

      return data
    }

    // MARK: - Bundle Structure Tests

    @Test("Bundle directory structure is created correctly")
    @MainActor
    func testBundleStructure() async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createTestTimeline(context: context)

      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(
        at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      let provider = try createTestAssetProvider(assetID: assetID, tempDir: tempDir)

      var exporter = FCPXMLBundleExporter(version: .v1_14, includeMedia: true)

      let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        assetProvider: provider,
        to: tempDir,
        bundleName: "TestBundle"
      )

      // Verify bundle exists
      #expect(FileManager.default.fileExists(atPath: bundleURL.path))

      // Verify bundle structure
      let infoPlistURL = bundleURL.appendingPathComponent("Info.plist")
      let infoFCPXMLURL = bundleURL.appendingPathComponent("Info.fcpxml")
      let mediaURL = bundleURL.appendingPathComponent("Media")

      #expect(FileManager.default.fileExists(atPath: infoPlistURL.path))
      #expect(FileManager.default.fileExists(atPath: infoFCPXMLURL.path))
      #expect(FileManager.default.fileExists(atPath: mediaURL.path))

      // Verify bundle has correct extension
      #expect(bundleURL.pathExtension == "fcpxmld")
    }

    @Test("Info.plist contains required metadata")
    @MainActor
    func testInfoPlistFormat() async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createTestTimeline(
        context: context, name: "Test Project")

      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(
        at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      let provider = try createTestAssetProvider(assetID: assetID, tempDir: tempDir)

      var exporter = FCPXMLBundleExporter(version: .v1_14, includeMedia: true)

      let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        assetProvider: provider,
        to: tempDir,
        bundleName: "TestProject"
      )

      let infoPlistURL = bundleURL.appendingPathComponent("Info.plist")
      let plistData = try Data(contentsOf: infoPlistURL)

      let plist = try PropertyListSerialization.propertyList(
        from: plistData, format: nil) as? [String: Any]

      #expect(plist != nil)
      #expect(plist?["CFBundleName"] as? String == "TestProject")
      #expect(plist?["CFBundleIdentifier"] != nil)
    }

    @Test("Media files are copied to Media/ directory")
    @MainActor
    func testMediaFileCopying() async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createTestTimeline(context: context)

      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(
        at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      let provider = try createTestAssetProvider(assetID: assetID, tempDir: tempDir)

      var exporter = FCPXMLBundleExporter(version: .v1_14, includeMedia: true)

      let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        assetProvider: provider,
        to: tempDir,
        bundleName: "TestBundle"
      )

      let mediaURL = bundleURL.appendingPathComponent("Media")

      // Verify at least one media file was copied
      let mediaFiles = try FileManager.default.contentsOfDirectory(atPath: mediaURL.path)
      #expect(mediaFiles.count > 0)

      // Verify media file is readable
      let firstMediaFile = mediaURL.appendingPathComponent(mediaFiles[0])
      let mediaData = try Data(contentsOf: firstMediaFile)
      #expect(mediaData.count > 0)
    }

    @Test("Info.fcpxml is valid XML document")
    @MainActor
    func testInfoFCPXMLValidity() async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createTestTimeline(context: context)

      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(
        at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      let provider = try createTestAssetProvider(assetID: assetID, tempDir: tempDir)

      var exporter = FCPXMLBundleExporter(version: .v1_14, includeMedia: true)

      let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        assetProvider: provider,
        to: tempDir,
        bundleName: "TestBundle"
      )

      let infoFCPXMLURL = bundleURL.appendingPathComponent("Info.fcpxml")
      let xmlData = try Data(contentsOf: infoFCPXMLURL)

      // Verify XML can be parsed
      let xmlDoc = try XMLDocument(data: xmlData)
      let rootElement = xmlDoc.rootElement()

      #expect(rootElement?.name == "fcpxml")
      #expect(rootElement?.attribute(forName: "version") != nil)
    }

    // MARK: - Progress Tracking Tests

    @Test("Progress reports accurate completion percentage")
    @MainActor
    func testProgressTracking() async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createTestTimeline(context: context)

      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(
        at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      let provider = try createTestAssetProvider(assetID: assetID, tempDir: tempDir)

      let progress = Progress(totalUnitCount: 100)
      var progressValues: [Int64] = []

      let observation = progress.observe(\.completedUnitCount) { prog, _ in
        progressValues.append(prog.completedUnitCount)
      }

      var exporter = FCPXMLBundleExporter(version: .v1_14, includeMedia: true)

      _ = try await exporter.exportBundle(
        timeline: timeline,
        assetProvider: provider,
        to: tempDir,
        bundleName: "TestBundle",
        progress: progress
      )

      observation.invalidate()

      // Verify progress reached 100%
      #expect(progress.completedUnitCount == 100)

      // Verify progress increased monotonically
      for i in 1..<progressValues.count {
        #expect(progressValues[i] >= progressValues[i - 1])
      }
    }

    @Test("Cancellation stops export and throws cancelled error")
    @MainActor
    func testCancellation() async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createTestTimeline(context: context)

      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(
        at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      let provider = try createTestAssetProvider(assetID: assetID, tempDir: tempDir)

      let progress = Progress(totalUnitCount: 100)

      // Cancel after a short delay
      Task {
        try? await Task.sleep(for: .milliseconds(10))
        progress.cancel()
      }

      var exporter = FCPXMLBundleExporter(version: .v1_14, includeMedia: true)

      await #expect(performing: {
        _ = try await exporter.exportBundle(
          timeline: timeline,
          assetProvider: provider,
          to: tempDir,
          bundleName: "TestBundle",
          progress: progress
        )
      }, throws: { error in
        // Verify it throws a cancellation-related error
        return error is CancellationError || "\(error)".contains("cancel")
      })
    }

    // MARK: - Version Tests

    @Test("Bundle export works with different FCPXML versions", arguments: [
      FCPXMLVersion.v1_10,
      FCPXMLVersion.v1_11,
      FCPXMLVersion.v1_12,
      FCPXMLVersion.v1_13,
      FCPXMLVersion.v1_14,
    ])
    @MainActor
    func testDifferentVersions(version: FCPXMLVersion) async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, assetID) = try createTestTimeline(context: context)

      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(
        at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      let provider = try createTestAssetProvider(assetID: assetID, tempDir: tempDir)

      var exporter = FCPXMLBundleExporter(version: version, includeMedia: true)

      let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        assetProvider: provider,
        to: tempDir,
        bundleName: "TestBundle"
      )

      // Verify version in Info.fcpxml
      let infoFCPXMLURL = bundleURL.appendingPathComponent("Info.fcpxml")
      let xmlData = try Data(contentsOf: infoFCPXMLURL)
      let xmlDoc = try XMLDocument(data: xmlData)
      let rootElement = xmlDoc.rootElement()

      let versionAttr = rootElement?.attribute(forName: "version")?.stringValue
      #expect(versionAttr == version.stringValue)
    }

    // MARK: - Error Handling Tests

    @Test("Export fails gracefully when asset is missing")
    @MainActor
    func testMissingAssetHandling() async throws {
      let container = try Self.createTestContainer()
      let context = container.mainContext

      let (timeline, _) = try createTestTimeline(context: context)

      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      try FileManager.default.createDirectory(
        at: tempDir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempDir) }

      // Create provider with no assets (will cause missing asset error)
      let provider = FileAssetProvider(registry: [:])

      var exporter = FCPXMLBundleExporter(version: .v1_14, includeMedia: true)

      await #expect(performing: {
        _ = try await exporter.exportBundle(
          timeline: timeline,
          assetProvider: provider,
          to: tempDir,
          bundleName: "TestBundle"
        )
      }, throws: { error in
        return "\(error)".contains("asset") || "\(error)".contains("missing")
      })
    }
  }

#endif
