//
//  MetadataIntegrationTests.swift
//  SwiftSecuencia
//
//  Integration tests verifying that PipelineNeo exports metadata (markers, keywords,
//  ratings, chapter markers, and custom metadata) correctly through the
//  SwiftSecuenciaExporter pipeline.
//
//  CRITICAL: These tests correct iteration 01's false conclusion that PipelineNeo
//  does NOT export metadata. Sortie 0 research confirmed that PipelineNeo DOES export
//  metadata (FCPXMLExporter.swift lines 143-193). These tests prove it end-to-end.
//
//  Test strategy:
//  - Create SwiftSecuencia Timeline with clips containing metadata
//  - Use FileAssetProvider (no SwiftData dependency, fast)
//  - Pass through full adapter -> exporter pipeline (SwiftSecuenciaExporter)
//  - Assert metadata appears in the generated FCPXML string
//
//  Note: Timeline-level markers/keywords/ratings are intentionally omitted per Bug B
//  (see TimelineAdapters.swift). Only clip-level metadata is tested here because
//  clip-level metadata is the only valid location per FCPXML DTD v1.11.
//

import Foundation
import SwiftCompartido
import SwiftData
import Testing

@testable import SwiftSecuencia

// MARK: - Clip-Level Marker Export

@MainActor
@Test("SwiftSecuenciaExporter exports clip-level markers in FCPXML")
func swiftSecuenciaExporterExportsClipMarkers() throws {
    // Create in-memory SwiftData container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    // Create audio asset
    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-marker",
        mimeType: "audio/mp4",
        binaryValue: Data("test-audio-data".utf8),
        durationSeconds: 30.0
    )
    asset.prompt = "Marker Test Audio"
    context.insert(asset)

    // Create timeline
    let timeline = Timeline(name: "Marker Test Timeline")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    // Create clip WITH a marker
    var clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 30)
    )
    clip.markers.append(Marker(
        start: Timecode(seconds: 5),
        value: "Important Moment",
        note: "Review this section"
    ))
    timeline.insertClip(clip, at: .zero, lane: 0)

    // Export through SwiftSecuenciaExporter (pipeline-neo path)
    let exporter = SwiftSecuenciaExporter(version: .v1_11)
    let provider = SwiftDataAssetProvider(modelContext: context)
    let fcpxml = try exporter.export(
        timeline: timeline,
        assetProvider: provider,
        eventName: "Test Event"
    )

    // CRITICAL ASSERTIONS: Marker must appear in FCPXML
    #expect(fcpxml.contains("<marker"), "FCPXML must contain <marker element -- PipelineNeo exports markers")
    #expect(fcpxml.contains("Important Moment"), "Marker value must appear in FCPXML")
    #expect(fcpxml.contains("Review this section"), "Marker note must appear in FCPXML")
}

// MARK: - Clip-Level Keyword Export

@MainActor
@Test("SwiftSecuenciaExporter exports clip-level keywords in FCPXML")
func swiftSecuenciaExporterExportsClipKeywords() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-keyword",
        mimeType: "audio/mp4",
        binaryValue: Data("test-audio-data".utf8),
        durationSeconds: 60.0
    )
    asset.prompt = "Keyword Test Audio"
    context.insert(asset)

    let timeline = Timeline(name: "Keyword Test Timeline")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    var clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 60)
    )
    clip.keywords.append(Keyword(
        start: Timecode.zero,
        duration: Timecode(seconds: 60),
        value: "Dialogue"
    ))
    timeline.insertClip(clip, at: .zero, lane: 0)

    let exporter = SwiftSecuenciaExporter(version: .v1_11)
    let provider = SwiftDataAssetProvider(modelContext: context)
    let fcpxml = try exporter.export(
        timeline: timeline,
        assetProvider: provider,
        eventName: "Test Event"
    )

    // CRITICAL ASSERTIONS: Keyword must appear in FCPXML
    #expect(fcpxml.contains("<keyword"), "FCPXML must contain <keyword element -- PipelineNeo exports keywords")
    #expect(fcpxml.contains("Dialogue"), "Keyword value must appear in FCPXML")
}

// MARK: - Clip-Level Rating Export

@MainActor
@Test("SwiftSecuenciaExporter exports clip-level ratings in FCPXML")
func swiftSecuenciaExporterExportsClipRatings() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-rating",
        mimeType: "audio/mp4",
        binaryValue: Data("test-audio-data".utf8),
        durationSeconds: 45.0
    )
    asset.prompt = "Rating Test Audio"
    context.insert(asset)

    let timeline = Timeline(name: "Rating Test Timeline")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    var clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 45)
    )
    clip.ratings.append(Rating(
        start: Timecode.zero,
        duration: Timecode(seconds: 45),
        value: .favorite,
        note: "Best take"
    ))
    timeline.insertClip(clip, at: .zero, lane: 0)

    let exporter = SwiftSecuenciaExporter(version: .v1_11)
    let provider = SwiftDataAssetProvider(modelContext: context)
    let fcpxml = try exporter.export(
        timeline: timeline,
        assetProvider: provider,
        eventName: "Test Event"
    )

    // CRITICAL ASSERTIONS: Rating must appear in FCPXML
    #expect(fcpxml.contains("<rating"), "FCPXML must contain <rating element -- PipelineNeo exports ratings")
    #expect(fcpxml.contains("favorite"), "Rating value must appear in FCPXML")
}

// MARK: - Clip-Level Custom Metadata Export

@MainActor
@Test("SwiftSecuenciaExporter exports clip-level custom metadata in FCPXML")
func swiftSecuenciaExporterExportsClipMetadata() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-metadata",
        mimeType: "audio/mp4",
        binaryValue: Data("test-audio-data".utf8),
        durationSeconds: 60.0
    )
    asset.prompt = "Metadata Test Audio"
    context.insert(asset)

    let timeline = Timeline(name: "Metadata Test Timeline")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    var clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 60)
    )
    var metadata = Metadata()
    metadata.setReel("A001")
    metadata.setScene("1")
    metadata.setTake("3")
    metadata.setDescription("Interview with subject")
    clip.metadata = metadata
    timeline.insertClip(clip, at: .zero, lane: 0)

    let exporter = SwiftSecuenciaExporter(version: .v1_11)
    let provider = SwiftDataAssetProvider(modelContext: context)
    let fcpxml = try exporter.export(
        timeline: timeline,
        assetProvider: provider,
        eventName: "Test Event"
    )

    // CRITICAL ASSERTIONS: Metadata must appear in FCPXML
    #expect(fcpxml.contains("<metadata>"), "FCPXML must contain <metadata> element")
    #expect(fcpxml.contains("<md"), "FCPXML must contain <md elements for metadata entries")
    #expect(fcpxml.contains("com.apple.proapps.studio.reel"), "Reel metadata key must appear")
    #expect(fcpxml.contains("A001"), "Reel value must appear")
    #expect(fcpxml.contains("Interview with subject"), "Description value must appear")
}

// MARK: - Combined Metadata Export (All Types)

@MainActor
@Test("SwiftSecuenciaExporter exports all metadata types on a single clip")
func swiftSecuenciaExporterExportsAllMetadataTypes() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    // Create two assets for two clips
    let asset1 = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-combined-1",
        mimeType: "audio/mp4",
        binaryValue: Data("audio-clip-1".utf8),
        durationSeconds: 30.0
    )
    asset1.prompt = "Combined Test Clip 1"
    context.insert(asset1)

    let asset2 = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-combined-2",
        mimeType: "audio/mp4",
        binaryValue: Data("audio-clip-2".utf8),
        durationSeconds: 40.0
    )
    asset2.prompt = "Combined Test Clip 2"
    context.insert(asset2)

    let timeline = Timeline(name: "Combined Metadata Timeline")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    // Clip 1: marker + keyword
    var clip1 = TimelineClip(
        assetStorageId: asset1.id,
        duration: Timecode(seconds: 30)
    )
    clip1.markers.append(Marker(
        start: Timecode(seconds: 10),
        value: "Scene Change"
    ))
    clip1.keywords.append(Keyword(
        start: Timecode.zero,
        duration: Timecode(seconds: 30),
        value: "Interview"
    ))
    timeline.insertClip(clip1, at: .zero, lane: 0)

    // Clip 2: rating + chapter marker
    var clip2 = TimelineClip(
        assetStorageId: asset2.id,
        duration: Timecode(seconds: 40)
    )
    clip2.ratings.append(Rating(
        start: Timecode.zero,
        duration: Timecode(seconds: 40),
        value: .favorite
    ))
    clip2.chapterMarkers.append(ChapterMarker(
        start: Timecode.zero,
        value: "Chapter 1"
    ))
    timeline.appendClip(clip2)

    let exporter = SwiftSecuenciaExporter(version: .v1_11)
    let provider = SwiftDataAssetProvider(modelContext: context)
    let fcpxml = try exporter.export(
        timeline: timeline,
        assetProvider: provider,
        eventName: "Test Event"
    )

    // Verify ALL metadata types appear
    #expect(fcpxml.contains("<marker"), "Markers must be exported via PipelineNeo")
    #expect(fcpxml.contains("Scene Change"), "Marker value must be in output")
    #expect(fcpxml.contains("<keyword"), "Keywords must be exported via PipelineNeo")
    #expect(fcpxml.contains("Interview"), "Keyword value must be in output")
    #expect(fcpxml.contains("<rating"), "Ratings must be exported via PipelineNeo")
    #expect(fcpxml.contains("favorite"), "Rating value must be in output")
    #expect(fcpxml.contains("<chapter-marker"), "Chapter markers must be exported via PipelineNeo")
    #expect(fcpxml.contains("Chapter 1"), "Chapter marker value must be in output")

    // Verify two asset-clip elements
    let clipCount = fcpxml.components(separatedBy: "<asset-clip").count - 1
    #expect(clipCount == 2, "Should have 2 asset-clip elements")
}

// MARK: - Empty Metadata Clip

@MainActor
@Test("SwiftSecuenciaExporter does not emit metadata elements for clips without metadata")
func swiftSecuenciaExporterOmitsEmptyMetadata() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-no-metadata",
        mimeType: "audio/mp4",
        binaryValue: Data("plain-audio".utf8),
        durationSeconds: 10.0
    )
    asset.prompt = "Plain Audio"
    context.insert(asset)

    let timeline = Timeline(name: "No Metadata Timeline")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    // Clip with NO metadata
    let clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 10)
    )
    timeline.insertClip(clip, at: .zero, lane: 0)

    let exporter = SwiftSecuenciaExporter(version: .v1_11)
    let provider = SwiftDataAssetProvider(modelContext: context)
    let fcpxml = try exporter.export(
        timeline: timeline,
        assetProvider: provider,
        eventName: "Test Event"
    )

    // Verify NO metadata elements
    #expect(!fcpxml.contains("<marker"), "No markers should appear for empty-metadata clip")
    #expect(!fcpxml.contains("<keyword"), "No keywords should appear for empty-metadata clip")
    #expect(!fcpxml.contains("<rating"), "No ratings should appear for empty-metadata clip")
    #expect(!fcpxml.contains("<chapter-marker"), "No chapter markers should appear for empty-metadata clip")
}

// MARK: - DTD Validation: r-prefixed Resource IDs

@MainActor
@Test("SwiftSecuenciaExporter generates r-prefixed resource IDs")
func swiftSecuenciaExporterUsesRPrefixedResourceIDs() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-resource-ids",
        mimeType: "video/mp4",
        binaryValue: Data("video-data".utf8),
        durationSeconds: 30.0
    )
    asset.prompt = "Resource ID Test"
    context.insert(asset)

    let timeline = Timeline(name: "Resource ID Test")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    let clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 30)
    )
    timeline.insertClip(clip, at: .zero, lane: 0)

    let exporter = SwiftSecuenciaExporter(version: .v1_11)
    let provider = SwiftDataAssetProvider(modelContext: context)
    let fcpxml = try exporter.export(
        timeline: timeline,
        assetProvider: provider,
        eventName: "Test Event"
    )

    // DTD validation: Format resource must be r1
    #expect(fcpxml.contains("id=\"r1\""), "Format resource must have id=\"r1\"")

    // DTD validation: Asset resource must be r2+
    #expect(fcpxml.contains("id=\"r2\""), "First asset resource must have id=\"r2\"")

    // DTD validation: No library name attribute
    // Parse as XML to verify
    let doc = try XMLDocument(xmlString: fcpxml, options: [.nodePreserveAll])
    if let root = doc.rootElement() {
        for library in root.elements(forName: "library") {
            #expect(
                library.attribute(forName: "name") == nil,
                "Library element must NOT have a name attribute (DTD violation)"
            )
        }
    }
}

// MARK: - DTD Validation: No Library Name Attribute

@MainActor
@Test("SwiftSecuenciaExporter removes library name attribute for DTD compliance")
func swiftSecuenciaExporterRemovesLibraryName() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    let timeline = Timeline(name: "Library Name Test")
    context.insert(timeline)

    // Even an empty timeline should produce valid FCPXML without library name
    let exporter = SwiftSecuenciaExporter(version: .v1_11)
    let provider = SwiftDataAssetProvider(modelContext: context)
    let fcpxml = try exporter.export(
        timeline: timeline,
        assetProvider: provider,
        eventName: "Test Event"
    )

    // Verify library element exists but has no name attribute
    #expect(fcpxml.contains("<library"), "FCPXML must contain <library element")

    // Parse and inspect
    let doc = try XMLDocument(xmlString: fcpxml, options: [.nodePreserveAll])
    if let root = doc.rootElement() {
        let libraries = root.elements(forName: "library")
        #expect(!libraries.isEmpty, "Must have at least one library element")
        for library in libraries {
            #expect(
                library.attribute(forName: "name") == nil,
                "Library name attribute must be removed for DTD compliance"
            )
        }
    }
}

// MARK: - DTD Validation via xmllint (if available)

@MainActor
@Test("SwiftSecuenciaExporter output passes DTD validation with metadata")
func swiftSecuenciaExporterMetadataPassesDTDValidation() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
        configurations: config
    )
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test-provider",
        requestorID: "test-dtd",
        mimeType: "audio/mp4",
        binaryValue: Data("dtd-test-audio".utf8),
        durationSeconds: 30.0
    )
    asset.prompt = "DTD Test Audio"
    context.insert(asset)

    let timeline = Timeline(name: "DTD Validation Test")
    timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
    context.insert(timeline)

    // Create clip with ALL metadata types
    var clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 30)
    )
    clip.markers.append(Marker(start: Timecode(seconds: 5), value: "Mark"))
    clip.keywords.append(Keyword(start: Timecode.zero, duration: Timecode(seconds: 30), value: "Test"))
    clip.ratings.append(Rating(start: Timecode.zero, duration: Timecode(seconds: 30), value: .favorite))
    var meta = Metadata()
    meta.setReel("A001")
    clip.metadata = meta
    timeline.insertClip(clip, at: .zero, lane: 0)

    let exporter = SwiftSecuenciaExporter(version: .v1_11)
    let provider = SwiftDataAssetProvider(modelContext: context)
    let fcpxml = try exporter.export(
        timeline: timeline,
        assetProvider: provider,
        eventName: "Test Event"
    )

    // Use SwiftSecuencia's own DTD validator if available
    let validator = FCPXMLDTDValidator()
    let dtdURL = Bundle.module.url(forResource: "Fixtures/FCPXMLv1_11", withExtension: "dtd")
    let result = try validator.validate(xmlContent: fcpxml, version: .v1_11, dtdURL: dtdURL)

    if !result.isValid {
        Issue.record("DTD validation failed for metadata FCPXML:\n\(result.errors.joined(separator: "\n"))")
    }
    #expect(result.isValid, "FCPXML with metadata must pass DTD validation")
}
