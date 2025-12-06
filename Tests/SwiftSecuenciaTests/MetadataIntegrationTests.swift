//
//  MetadataIntegrationTests.swift
//  SwiftSecuencia
//
//  Integration tests for metadata export in FCPXML bundles.
//

import Testing
import Foundation
import SwiftData
import SwiftCompartido
@testable import SwiftSecuencia

@MainActor
@Test func timelineWithMarkersExportsCorrectly() async throws {
    // Create timeline with markers
    var timeline = Timeline(name: "Test Timeline")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)

    // Add timeline-level markers
    timeline.markers.append(Marker(
        start: Timecode(seconds: 10),
        value: "Scene transition",
        note: "Add dissolve here"
    ))

    timeline.chapterMarkers.append(ChapterMarker(
        start: Timecode.zero,
        value: "Introduction"
    ))

    timeline.chapterMarkers.append(ChapterMarker(
        start: Timecode(seconds: 60),
        value: "Chapter 1",
        posterOffset: Timecode(seconds: 5)
    ))

    // Create model container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    // Create sample audio asset
    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-requestor",
        mimeType: "audio/x-aiff",
        binaryValue: try TestUtilities.generateAudioData(text: "Test audio for markers"),
        prompt: "Test audio"
    )
    asset.durationSeconds = 30.0
    context.insert(asset)

    // Add a clip with metadata
    var clip = TimelineClip(
        assetStorageId: asset.id,
        offset: Timecode.zero,
        duration: Timecode(seconds: 30)
    )

    clip.markers.append(Marker(
        start: Timecode(seconds: 5),
        value: "Peak moment"
    ))

    clip.keywords.append(Keyword(
        start: Timecode.zero,
        duration: Timecode(seconds: 30),
        value: "Dialogue"
    ))

    timeline.clips.append(clip)
    context.insert(timeline)
    try context.save()

    // Export to bundle
    let tempDir = FileManager.default.temporaryDirectory
    var exporter = FCPXMLBundleExporter(includeMedia: true)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir,
        bundleName: "MetadataTest"
    )

    // Read generated FCPXML
    let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
    let fcpxmlString = try String(contentsOf: fcpxmlURL, encoding: .utf8)

    // Verify timeline-level markers are present
    #expect(fcpxmlString.contains("<marker"))
    #expect(fcpxmlString.contains("Scene transition"))
    #expect(fcpxmlString.contains("Add dissolve here"))

    // Verify chapter markers
    #expect(fcpxmlString.contains("<chapter-marker"))
    #expect(fcpxmlString.contains("Introduction"))
    #expect(fcpxmlString.contains("Chapter 1"))
    #expect(fcpxmlString.contains("posterOffset=\"5s\""))

    // Verify clip-level markers
    #expect(fcpxmlString.contains("Peak moment"))

    // Verify keywords
    #expect(fcpxmlString.contains("<keyword"))
    #expect(fcpxmlString.contains("Dialogue"))

    // Cleanup
    try? FileManager.default.removeItem(at: bundleURL)
}

@MainActor
@Test func clipWithRatingsAndMetadataExportsCorrectly() async throws {
    // Create timeline
    let timeline = Timeline(name: "Rated Timeline")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps24)

    // Create model container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    // Create sample asset
    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-requestor",
        mimeType: "audio/x-aiff",
        binaryValue: try TestUtilities.generateAudioData(text: "Best take"),
        prompt: "Best take"
    )
    asset.durationSeconds = 60.0
    context.insert(asset)

    // Add clip with rating and metadata
    var clip = TimelineClip(
        assetStorageId: asset.id,
        offset: Timecode.zero,
        duration: Timecode(seconds: 60)
    )

    // Add favorite rating
    clip.ratings.append(Rating(
        start: Timecode.zero,
        duration: Timecode(seconds: 60),
        value: .favorite,
        note: "Best take"
    ))

    // Add custom metadata
    var metadata = Metadata()
    metadata.setReel("A001")
    metadata.setScene("1")
    metadata.setTake("3")
    metadata.setDescription("Interview with subject")
    clip.metadata = metadata

    timeline.clips.append(clip)
    context.insert(timeline)
    try context.save()

    // Export to bundle
    let tempDir = FileManager.default.temporaryDirectory
    var exporter = FCPXMLBundleExporter(includeMedia: true)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir,
        bundleName: "RatingsTest"
    )

    // Read generated FCPXML
    let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
    let fcpxmlString = try String(contentsOf: fcpxmlURL, encoding: .utf8)

    // Verify rating
    #expect(fcpxmlString.contains("<rating"))
    #expect(fcpxmlString.contains("value=\"favorite\""))
    #expect(fcpxmlString.contains("Best take"))

    // Verify metadata
    #expect(fcpxmlString.contains("<metadata>"))
    #expect(fcpxmlString.contains("<md"))
    #expect(fcpxmlString.contains("com.apple.proapps.studio.reel"))
    #expect(fcpxmlString.contains("A001"))
    #expect(fcpxmlString.contains("com.apple.proapps.studio.scene"))
    #expect(fcpxmlString.contains("com.apple.proapps.studio.take"))
    #expect(fcpxmlString.contains("Interview with subject"))

    // Cleanup
    try? FileManager.default.removeItem(at: bundleURL)
}

@MainActor
@Test func multipleClipsWithDifferentMetadataExportCorrectly() async throws {
    // Create timeline
    let timeline = Timeline(name: "Multi-Clip Metadata")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps29_97)

    // Add timeline keywords
    timeline.keywords.append(Keyword(
        start: Timecode.zero,
        duration: Timecode(seconds: 120),
        value: "Interview"
    ))

    // Create model container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    // Create two assets
    let asset1 = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-requestor",
        mimeType: "audio/x-aiff",
        binaryValue: try TestUtilities.generateAudioData(text: "Question 1"),
        prompt: "Question 1"
    )
    asset1.durationSeconds = 30.0
    context.insert(asset1)

    let asset2 = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-requestor",
        mimeType: "audio/x-aiff",
        binaryValue: try TestUtilities.generateAudioData(text: "Question 2"),
        prompt: "Question 2"
    )
    asset2.durationSeconds = 40.0
    context.insert(asset2)

    // First clip with markers
    var clip1 = TimelineClip(
        name: "Question 1",
        assetStorageId: asset1.id,
        offset: Timecode.zero,
        duration: Timecode(seconds: 30)
    )

    clip1.markers.append(Marker(
        start: Timecode(seconds: 10),
        value: "Interesting point"
    ))

    clip1.keywords.append(Keyword(
        start: Timecode.zero,
        duration: Timecode(seconds: 30),
        value: "Q&A"
    ))

    // Second clip with different metadata
    var clip2 = TimelineClip(
        name: "Question 2",
        assetStorageId: asset2.id,
        offset: Timecode(seconds: 30),
        duration: Timecode(seconds: 40)
    )

    clip2.ratings.append(Rating(
        start: Timecode.zero,
        duration: Timecode(seconds: 40),
        value: .favorite
    ))

    var clip2Meta = Metadata()
    clip2Meta.setTake("2")
    clip2.metadata = clip2Meta

    timeline.clips.append(clip1)
    timeline.clips.append(clip2)
    context.insert(timeline)
    try context.save()

    // Export to bundle
    let tempDir = FileManager.default.temporaryDirectory
    var exporter = FCPXMLBundleExporter(includeMedia: true)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir,
        bundleName: "MultiClipTest"
    )

    // Read generated FCPXML
    let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
    let fcpxmlString = try String(contentsOf: fcpxmlURL, encoding: .utf8)

    // Verify both clips have their metadata
    #expect(fcpxmlString.contains("Interesting point"))
    #expect(fcpxmlString.contains("Q&amp;A"))  // XML encodes & as &amp;
    #expect(fcpxmlString.contains("value=\"favorite\""))
    #expect(fcpxmlString.contains("com.apple.proapps.studio.take"))

    // Cleanup
    try? FileManager.default.removeItem(at: bundleURL)
}

@MainActor
@Test func emptyMetadataIsNotExported() async throws {
    // Create timeline without any metadata
    let timeline = Timeline(name: "No Metadata")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps24)

    // Create model container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    // Create asset
    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-requestor",
        mimeType: "audio/x-aiff",
        binaryValue: try TestUtilities.generateAudioData(text: "Plain audio"),
        prompt: "Plain audio"
    )
    asset.durationSeconds = 10.0
    context.insert(asset)

    // Add clip without metadata
    let clip = TimelineClip(
        assetStorageId: asset.id,
        offset: Timecode.zero,
        duration: Timecode(seconds: 10)
    )

    timeline.clips.append(clip)
    context.insert(timeline)
    try context.save()

    // Export to bundle
    let tempDir = FileManager.default.temporaryDirectory
    var exporter = FCPXMLBundleExporter(includeMedia: true)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: context,
        to: tempDir,
        bundleName: "NoMetadataTest"
    )

    // Read generated FCPXML
    let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
    let fcpxmlString = try String(contentsOf: fcpxmlURL, encoding: .utf8)

    // Verify no metadata elements are present
    #expect(!fcpxmlString.contains("<marker"))
    #expect(!fcpxmlString.contains("<chapter-marker"))
    #expect(!fcpxmlString.contains("<keyword"))
    #expect(!fcpxmlString.contains("<rating"))
    #expect(!fcpxmlString.contains("<metadata>"))

    // Cleanup
    try? FileManager.default.removeItem(at: bundleURL)
}
