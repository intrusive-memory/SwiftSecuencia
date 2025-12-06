import Testing
import Foundation
import SwiftData
import SwiftCompartido
@testable import SwiftSecuencia

// MARK: - Bundle Structure Tests

@Test @MainActor func exportBundleCreatesCorrectStructure() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Test Timeline")
    context.insert(timeline)

    // Create temporary directory
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // Export bundle
    var exporter = FCPXMLBundleExporter()
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir
    )

    // Verify bundle exists
    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: bundleURL.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue == true)

    // Verify bundle name
    #expect(bundleURL.lastPathComponent == "Test Timeline.fcpxmld")

    // Verify Info.plist exists
    let plistURL = bundleURL.appendingPathComponent("Info.plist")
    #expect(FileManager.default.fileExists(atPath: plistURL.path))

    // Verify Info.fcpxml exists
    let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
    #expect(FileManager.default.fileExists(atPath: fcpxmlURL.path))

    // Verify Media directory exists
    let mediaURL = bundleURL.appendingPathComponent("Media")
    var isMediaDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: mediaURL.path, isDirectory: &isMediaDirectory))
    #expect(isMediaDirectory.boolValue == true)
}

@Test @MainActor func exportBundleWithCustomName() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Original Name")
    context.insert(timeline)

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    var exporter = FCPXMLBundleExporter()
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir,
        bundleName: "Custom Bundle Name"
    )

    #expect(bundleURL.lastPathComponent == "Custom Bundle Name.fcpxmld")
}

// MARK: - Info.plist Tests

@Test @MainActor func exportBundleGeneratesValidInfoPlist() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "My Project")
    context.insert(timeline)

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    var exporter = FCPXMLBundleExporter()
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir
    )

    // Read Info.plist
    let plistURL = bundleURL.appendingPathComponent("Info.plist")
    let plistData = try Data(contentsOf: plistURL)
    let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]

    // Verify required keys
    #expect(plist["CFBundleName"] as? String == "My Project")
    #expect(plist["CFBundleIdentifier"] as? String == "com.swiftsecuencia.my-project")
    #expect(plist["CFBundleVersion"] as? String == "1.0")
    #expect(plist["CFBundlePackageType"] as? String == "FCPB")
    #expect(plist["CFBundleShortVersionString"] as? String == "1.0")
    #expect(plist["CFBundleInfoDictionaryVersion"] as? String == "6.0")
    #expect(plist["NSHumanReadableCopyright"] as? String == "Generated with SwiftSecuencia")
}

// MARK: - Media Export Tests

@Test @MainActor func exportBundleIncludesMediaFiles() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create assets with binary data
    let videoData = Data("mock video data".utf8)
    let videoAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "v1",
        mimeType: "video/mp4",
        binaryValue: videoData,
        durationSeconds: 30.0
    )
    videoAsset.prompt = "Video Clip"
    context.insert(videoAsset)

    let audioData = Data("mock audio data".utf8)
    let audioAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "a1",
        mimeType: "audio/mpeg",
        binaryValue: audioData,
        durationSeconds: 60.0
    )
    audioAsset.prompt = "Audio Track"
    context.insert(audioAsset)

    // Create timeline with clips
    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    timeline.appendClip(TimelineClip(assetStorageId: videoAsset.id, duration: Timecode(seconds: 30)))
    timeline.appendClip(TimelineClip(assetStorageId: audioAsset.id, duration: Timecode(seconds: 60)))

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // Export bundle
    var exporter = FCPXMLBundleExporter(includeMedia: true)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir
    )

    // Verify media files exist
    let mediaURL = bundleURL.appendingPathComponent("Media")
    let mediaFiles = try FileManager.default.contentsOfDirectory(at: mediaURL, includingPropertiesForKeys: nil)

    #expect(mediaFiles.count == 2)

    // Verify file extensions
    let extensions = mediaFiles.map { $0.pathExtension }.sorted()
    #expect(extensions.contains("mp4"))
    #expect(extensions.contains("mp3"))

    // Verify file contents
    for fileURL in mediaFiles {
        let data = try Data(contentsOf: fileURL)
        #expect(data.count > 0)

        if fileURL.pathExtension == "mp4" {
            #expect(data == videoData)
        } else if fileURL.pathExtension == "mp3" {
            #expect(data == audioData)
        }
    }
}

@Test @MainActor func exportBundleWithoutMediaDoesNotCopyFiles() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "v1",
        mimeType: "video/mp4",
        binaryValue: Data("test".utf8),
        durationSeconds: 10.0
    )
    context.insert(asset)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)
    timeline.appendClip(TimelineClip(assetStorageId: asset.id, duration: Timecode(seconds: 10)))

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // Export without media
    var exporter = FCPXMLBundleExporter(includeMedia: false)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir
    )

    // Verify Media directory is empty
    let mediaURL = bundleURL.appendingPathComponent("Media")
    let mediaFiles = try FileManager.default.contentsOfDirectory(at: mediaURL, includingPropertiesForKeys: nil)
    #expect(mediaFiles.isEmpty)
}

// MARK: - FCPXML Content Tests

@Test @MainActor func exportBundleGeneratesValidFCPXML() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "v1",
        mimeType: "video/mp4",
        binaryValue: Data("test".utf8),
        durationSeconds: 30.0
    )
    asset.prompt = "Test Video"
    context.insert(asset)

    let timeline = Timeline(name: "Test Timeline")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    timeline.appendClip(TimelineClip(assetStorageId: asset.id, duration: Timecode(seconds: 30)))

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    var exporter = FCPXMLBundleExporter()
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir,
        libraryName: "Test Library",
        eventName: "Test Event"
    )

    // Read FCPXML
    let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
    let xmlString = try String(contentsOf: fcpxmlURL, encoding: .utf8)

    // Verify structure
    #expect(xmlString.contains("<fcpxml version=\"1.11\">"))
    #expect(xmlString.contains("<resources>"))
    #expect(xmlString.contains("<library>"))
    #expect(xmlString.contains("<event name=\"Test Event\">"))
    #expect(xmlString.contains("<project name=\"Test Timeline\">"))
    #expect(xmlString.contains("<sequence"))
    #expect(xmlString.contains("<spine>"))
    #expect(xmlString.contains("<asset-clip"))
}

@Test @MainActor func exportBundleUsesRelativeMediaPaths() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "v1",
        mimeType: "video/mp4",
        binaryValue: Data("test".utf8),
        durationSeconds: 30.0
    )
    context.insert(asset)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)
    timeline.appendClip(TimelineClip(assetStorageId: asset.id, duration: Timecode(seconds: 30)))

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    var exporter = FCPXMLBundleExporter(includeMedia: true)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir
    )

    // Read FCPXML
    let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
    let xmlString = try String(contentsOf: fcpxmlURL, encoding: .utf8)

    // Verify relative paths (Media/filename)
    #expect(xmlString.contains("src=\"Media/"))
    #expect(!xmlString.contains("file:///"))
    #expect(!xmlString.contains("placeholder"))
}

// MARK: - File Extension Tests

@Test @MainActor func exportBundleUsesCorrectFileExtensions() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create assets with different MIME types
    let mp4Asset = TypedDataStorage(providerId: "test", requestorID: "1", mimeType: "video/mp4", binaryValue: Data("1".utf8))
    let movAsset = TypedDataStorage(providerId: "test", requestorID: "2", mimeType: "video/quicktime", binaryValue: Data("2".utf8))
    let wavAsset = TypedDataStorage(providerId: "test", requestorID: "3", mimeType: "audio/wav", binaryValue: Data("3".utf8))
    let mp3Asset = TypedDataStorage(providerId: "test", requestorID: "4", mimeType: "audio/mpeg", binaryValue: Data("4".utf8))
    let pngAsset = TypedDataStorage(providerId: "test", requestorID: "5", mimeType: "image/png", binaryValue: Data("5".utf8))

    context.insert(mp4Asset)
    context.insert(movAsset)
    context.insert(wavAsset)
    context.insert(mp3Asset)
    context.insert(pngAsset)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    timeline.appendClip(TimelineClip(assetStorageId: mp4Asset.id, duration: Timecode(seconds: 1)))
    timeline.appendClip(TimelineClip(assetStorageId: movAsset.id, duration: Timecode(seconds: 1)))
    timeline.appendClip(TimelineClip(assetStorageId: wavAsset.id, duration: Timecode(seconds: 1)))
    timeline.appendClip(TimelineClip(assetStorageId: mp3Asset.id, duration: Timecode(seconds: 1)))
    timeline.appendClip(TimelineClip(assetStorageId: pngAsset.id, duration: Timecode(seconds: 1)))

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    var exporter = FCPXMLBundleExporter(includeMedia: true)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir
    )

    // Get media files
    let mediaURL = bundleURL.appendingPathComponent("Media")
    let mediaFiles = try FileManager.default.contentsOfDirectory(at: mediaURL, includingPropertiesForKeys: nil)

    let extensions = Set(mediaFiles.map { $0.pathExtension })

    #expect(extensions.contains("mp4"))
    #expect(extensions.contains("mov"))
    #expect(extensions.contains("wav"))
    #expect(extensions.contains("mp3"))
    #expect(extensions.contains("png"))
}

// MARK: - Overwrite Tests

@Test @MainActor func exportBundleOverwritesExistingBundle() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    var exporter = FCPXMLBundleExporter()

    // Export first time
    let bundle1 = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir
    )

    // Export again - should overwrite
    let bundle2 = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir
    )

    #expect(bundle1.path == bundle2.path)
    #expect(FileManager.default.fileExists(atPath: bundle2.path))
}

// MARK: - Integration Tests

@Test @MainActor func exportBundleWithMultipleClipsAndLanes() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create multiple assets
    let video1 = TypedDataStorage(providerId: "test", requestorID: "v1", mimeType: "video/mp4", binaryValue: Data("v1".utf8), durationSeconds: 30.0)
    let video2 = TypedDataStorage(providerId: "test", requestorID: "v2", mimeType: "video/mp4", binaryValue: Data("v2".utf8), durationSeconds: 20.0)
    let audio = TypedDataStorage(providerId: "test", requestorID: "a1", mimeType: "audio/mpeg", binaryValue: Data("a1".utf8), durationSeconds: 50.0)

    context.insert(video1)
    context.insert(video2)
    context.insert(audio)

    // Create timeline with clips on different lanes
    let timeline = Timeline(name: "Multi-Lane Test")
    context.insert(timeline)

    timeline.insertClip(TimelineClip(assetStorageId: video1.id, duration: Timecode(seconds: 30)), at: .zero, lane: 0)
    timeline.insertClip(TimelineClip(assetStorageId: video2.id, duration: Timecode(seconds: 20)), at: Timecode(seconds: 10), lane: 1)
    timeline.insertClip(TimelineClip(assetStorageId: audio.id, duration: Timecode(seconds: 50)), at: .zero, lane: -1)

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    var exporter = FCPXMLBundleExporter(includeMedia: true)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir
    )

    // Verify 3 media files
    let mediaURL = bundleURL.appendingPathComponent("Media")
    let mediaFiles = try FileManager.default.contentsOfDirectory(at: mediaURL, includingPropertiesForKeys: nil)
    #expect(mediaFiles.count == 3)

    // Verify FCPXML contains all clips
    let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
    let xmlString = try String(contentsOf: fcpxmlURL, encoding: .utf8)

    // Parse XML to count asset-clip elements
    let xmlData = xmlString.data(using: String.Encoding.utf8)!
    let doc = try XMLDocument(data: xmlData)

    let clips = try doc.nodes(forXPath: "//asset-clip")
    #expect(clips.count == 3)

    // Verify lanes are present
    #expect(xmlString.contains("lane=\"1\""))
    #expect(xmlString.contains("lane=\"-1\""))
}
