import Testing
import Foundation
import SwiftData
import SwiftCompartido
@testable import SwiftSecuencia

// MARK: - Basic Export Tests

@Test func exportEmptyTimelineGeneratesValidXML() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Empty Timeline")
    context.insert(timeline)

    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context,
        libraryName: "Test Library",
        eventName: "Test Event"
    )

    // Verify basic structure
    #expect(xml.contains("<fcpxml version=\"1.11\">"))
    #expect(xml.contains("<library>"))
    #expect(xml.contains("<event name=\"Test Event\">"))
    #expect(xml.contains("<project name=\"Empty Timeline\">"))
    #expect(xml.contains("<sequence"))
    #expect(xml.contains("<spine"))
    #expect(xml.contains("</fcpxml>"))
}

@Test func exportTimelineWithSingleClip() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create asset
    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "video-test",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 30.0
    )
    asset.prompt = "Test Video"
    context.insert(asset)

    // Create timeline with clip
    let timeline = Timeline(name: "Single Clip Timeline")
    context.insert(timeline)

    let clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 30)
    )
    timeline.insertClip(clip, at: .zero, lane: 0)

    // Export
    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context
    )

    // Verify asset-clip element
    #expect(xml.contains("<asset-clip"))
    #expect(xml.contains("offset=\"0s\""))
    // Duration is frame-aligned to 23.98fps: 30 seconds = 719 frames = 719719/24000s
    #expect(xml.contains("duration=\"719719/24000s\""))
}

@Test func exportTimelineWithMultipleClips() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create assets
    let asset1 = TypedDataStorage(
        providerId: "test",
        requestorID: "v1",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 10.0
    )
    asset1.prompt = "Clip 1"
    context.insert(asset1)

    let asset2 = TypedDataStorage(
        providerId: "test",
        requestorID: "v2",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 15.0
    )
    asset2.prompt = "Clip 2"
    context.insert(asset2)

    // Create timeline with clips
    let timeline = Timeline(name: "Multi Clip Timeline")
    context.insert(timeline)

    timeline.appendClip(TimelineClip(assetStorageId: asset1.id, duration: Timecode(seconds: 10)))
    timeline.appendClip(TimelineClip(assetStorageId: asset2.id, duration: Timecode(seconds: 15)))

    // Export
    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context
    )

    // Verify structure
    // Total timeline duration is frame-aligned to 23.98fps: ~25 seconds = 599 frames = 599599/24000s
    #expect(xml.contains("duration=\"599599/24000s\""))

    // Should have 2 asset-clip elements
    let clipCount = xml.components(separatedBy: "<asset-clip").count - 1
    #expect(clipCount == 2)
}

// MARK: - Resource Generation Tests

@Test func exportGeneratesFormatResource() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Test")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(timeline: timeline, modelContext: context)

    // Verify format resource
    #expect(xml.contains("<resources>"))
    #expect(xml.contains("<format"))
    #expect(xml.contains("id=\"r1\""))
    #expect(xml.contains("name=\"FFVideoFormat1080p2398\""))
    #expect(xml.contains("width=\"1920\""))
    #expect(xml.contains("height=\"1080\""))
}

@Test func exportGeneratesAssetResources() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create assets
    let videoAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "video",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 60.0
    )
    videoAsset.prompt = "Video Asset"
    context.insert(videoAsset)

    let audioAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "audio",
        mimeType: "audio/mpeg",
        binaryValue: Data(),
        durationSeconds: 30.0
    )
    audioAsset.prompt = "Audio Asset"
    context.insert(audioAsset)

    // Create timeline
    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    timeline.appendClip(TimelineClip(assetStorageId: videoAsset.id, duration: Timecode(seconds: 60)))
    timeline.insertClip(TimelineClip(assetStorageId: audioAsset.id, duration: Timecode(seconds: 30)), at: .zero, lane: -1)

    // Export
    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(timeline: timeline, modelContext: context)

    // Verify asset resources
    #expect(xml.contains("<asset id=\"r2\"")) // Video asset
    #expect(xml.contains("<asset id=\"r3\"")) // Audio asset
    #expect(xml.contains("name=\"Video Asset\""))
    #expect(xml.contains("name=\"Audio Asset\""))
    #expect(xml.contains("hasVideo=\"1\""))
    #expect(xml.contains("hasAudio=\"1\""))
}

// MARK: - Clip Attribute Tests

@Test func exportClipWithSourceStart() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create asset
    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 60.0
    )
    context.insert(asset)

    // Create timeline with clip that has source start
    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    let clip = TimelineClip(
        assetStorageId: asset.id,
        offset: .zero,
        duration: Timecode(seconds: 10),
        sourceStart: Timecode(seconds: 5) // Start 5 seconds into the source
    )
    timeline.insertClip(clip, at: .zero, lane: 0)

    // Export
    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(timeline: timeline, modelContext: context)

    // Verify start attribute (frame-aligned to 23.98fps: 5 seconds = 120 frames = 120120/24000s)
    #expect(xml.contains("start=\"120120/24000s\""))
}

@Test func exportClipWithName() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create asset
    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 30.0
    )
    context.insert(asset)

    // Create timeline with named clip
    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    let clip = TimelineClip(
        name: "My Custom Clip Name",
        assetStorageId: asset.id,
        duration: Timecode(seconds: 30)
    )
    timeline.insertClip(clip, at: .zero, lane: 0)

    // Export
    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(timeline: timeline, modelContext: context)

    // Verify name attribute
    #expect(xml.contains("name=\"My Custom Clip Name\""))
}

@Test func exportClipOnNonZeroLane() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create asset
    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 30.0
    )
    context.insert(asset)

    // Create timeline with clip on lane 2
    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    let clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 30)
    )
    timeline.insertClip(clip, at: Timecode(seconds: 10), lane: 2)

    // Export
    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(timeline: timeline, modelContext: context)

    // Verify lane attribute
    #expect(xml.contains("lane=\"2\""))
}

// MARK: - XML Structure Tests

@Test func exportGeneratesValidXMLStructure() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(timeline: timeline, modelContext: context)

    // Verify XML can be parsed
    let data = xml.data(using: .utf8)!
    let doc = try XMLDocument(data: data)

    // Verify root element
    let root = doc.rootElement()
    #expect(root?.name == "fcpxml")
    #expect(root?.attribute(forName: "version")?.stringValue == "1.11")

    // Verify resources
    let resources = root?.elements(forName: "resources").first
    #expect(resources != nil)

    // Verify library > event > project > sequence > spine hierarchy
    let library = root?.elements(forName: "library").first
    #expect(library != nil)

    let event = library?.elements(forName: "event").first
    #expect(event != nil)

    let project = event?.elements(forName: "project").first
    #expect(project != nil)

    let sequence = project?.elements(forName: "sequence").first
    #expect(sequence != nil)

    let spine = sequence?.elements(forName: "spine").first
    #expect(spine != nil)
}

@Test func exportWithCustomProjectName() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Timeline Name")
    context.insert(timeline)

    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context,
        projectName: "Custom Project Name"
    )

    // Verify custom project name is used
    #expect(xml.contains("<project name=\"Custom Project Name\">"))
    #expect(!xml.contains("<project name=\"Timeline Name\">"))
}

@Test func exportUsesTimelineNameAsDefaultProjectName() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "My Timeline")
    context.insert(timeline)

    var exporter = FCPXMLExporter(version: .v1_11)
    let xml = try exporter.export(timeline: timeline, modelContext: context)

    // Verify timeline name is used as project name
    #expect(xml.contains("<project name=\"My Timeline\">"))
}
