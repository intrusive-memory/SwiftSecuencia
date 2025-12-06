import Testing
import Foundation
import SwiftData
import SwiftCompartido
@testable import SwiftSecuencia

// MARK: - DTD Validation Tests

/// Tests that validate generated FCPXML against official DTD files.
///
/// These tests ensure that SwiftSecuencia generates valid FCPXML that conforms
/// to Apple's FCPXML specification. DTD validation is performed using xmllint
/// against official DTD files from Apple/CommandPost.

@Test func emptyTimelinePassesDTDValidation() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Empty Timeline")
    context.insert(timeline)

    var exporter = FCPXMLExporter(version: "1.11")
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context
    )

    // Validate against DTD
    let validator = FCPXMLDTDValidator()
    let result = try validator.validate(xmlContent: xml, version: "1.11")

    if !result.isValid {
        Issue.record("DTD validation failed:\n\(result.errors.joined(separator: "\n"))")
    }
    #expect(result.isValid, "Generated FCPXML must pass DTD validation")
}

@Test func singleClipTimelinePassesDTDValidation() async throws {
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
    var exporter = FCPXMLExporter(version: "1.11")
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context
    )

    // Validate against DTD
    let validator = FCPXMLDTDValidator()
    let result = try validator.validate(xmlContent: xml, version: "1.11")

    if !result.isValid {
        Issue.record("DTD validation failed:\n\(result.errors.joined(separator: "\n"))")
    }
    #expect(result.isValid, "Generated FCPXML must pass DTD validation")
}

@Test func multiClipTimelinePassesDTDValidation() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create multiple assets
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

    let asset3 = TypedDataStorage(
        providerId: "test",
        requestorID: "v3",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 20.0
    )
    asset3.prompt = "Clip 3"
    context.insert(asset3)

    // Create timeline with clips
    let timeline = Timeline(name: "Multi Clip Timeline")
    context.insert(timeline)

    timeline.appendClip(TimelineClip(assetStorageId: asset1.id, duration: Timecode(seconds: 10)))
    timeline.appendClip(TimelineClip(assetStorageId: asset2.id, duration: Timecode(seconds: 15)))
    timeline.appendClip(TimelineClip(assetStorageId: asset3.id, duration: Timecode(seconds: 20)))

    // Export
    var exporter = FCPXMLExporter(version: "1.11")
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context
    )

    // Validate against DTD
    let validator = FCPXMLDTDValidator()
    let result = try validator.validate(xmlContent: xml, version: "1.11")

    if !result.isValid {
        Issue.record("DTD validation failed:\n\(result.errors.joined(separator: "\n"))")
    }
    #expect(result.isValid, "Generated FCPXML must pass DTD validation")
}

@Test func multiLaneTimelinePassesDTDValidation() async throws {
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

    // Create timeline with multi-lane clips
    let timeline = Timeline(name: "Multi-Lane Timeline")
    context.insert(timeline)

    // Lane 0 (primary)
    timeline.appendClip(TimelineClip(assetStorageId: videoAsset.id, duration: Timecode(seconds: 60)))

    // Lane -1 (audio below)
    timeline.insertClip(TimelineClip(assetStorageId: audioAsset.id, duration: Timecode(seconds: 30)), at: .zero, lane: -1)

    // Lane 1 (connected above)
    timeline.insertClip(TimelineClip(assetStorageId: videoAsset.id, duration: Timecode(seconds: 20)), at: Timecode(seconds: 10), lane: 1)

    // Export
    var exporter = FCPXMLExporter(version: "1.11")
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context
    )

    // Validate against DTD
    let validator = FCPXMLDTDValidator()
    let result = try validator.validate(xmlContent: xml, version: "1.11")

    if !result.isValid {
        Issue.record("DTD validation failed:\n\(result.errors.joined(separator: "\n"))")
    }
    #expect(result.isValid, "Generated FCPXML must pass DTD validation")
}

@Test func timelineWithSourceStartPassesDTDValidation() async throws {
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
    let timeline = Timeline(name: "Source Start Timeline")
    context.insert(timeline)

    let clip = TimelineClip(
        assetStorageId: asset.id,
        offset: .zero,
        duration: Timecode(seconds: 10),
        sourceStart: Timecode(seconds: 5)
    )
    timeline.insertClip(clip, at: .zero, lane: 0)

    // Export
    var exporter = FCPXMLExporter(version: "1.11")
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context
    )

    // Validate against DTD
    let validator = FCPXMLDTDValidator()
    let result = try validator.validate(xmlContent: xml, version: "1.11")

    if !result.isValid {
        Issue.record("DTD validation failed:\n\(result.errors.joined(separator: "\n"))")
    }
    #expect(result.isValid, "Generated FCPXML must pass DTD validation")
}

@Test func timelineWithNamedClipsPassesDTDValidation() async throws {
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

    // Create timeline with named clips
    let timeline = Timeline(name: "Named Clips Timeline")
    context.insert(timeline)

    let clip1 = TimelineClip(
        name: "Opening Shot",
        assetStorageId: asset.id,
        duration: Timecode(seconds: 10)
    )
    timeline.insertClip(clip1, at: .zero, lane: 0)

    let clip2 = TimelineClip(
        name: "B-Roll Overlay",
        assetStorageId: asset.id,
        duration: Timecode(seconds: 5)
    )
    timeline.insertClip(clip2, at: Timecode(seconds: 2), lane: 1)

    // Export
    var exporter = FCPXMLExporter(version: "1.11")
    let xml = try exporter.export(
        timeline: timeline,
        modelContext: context
    )

    // Validate against DTD
    let validator = FCPXMLDTDValidator()
    let result = try validator.validate(xmlContent: xml, version: "1.11")

    if !result.isValid {
        Issue.record("DTD validation failed:\n\(result.errors.joined(separator: "\n"))")
    }
    #expect(result.isValid, "Generated FCPXML must pass DTD validation")
}

@Test func differentVideoFormatsPassDTDValidation() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 10.0
    )
    context.insert(asset)

    // Test different video formats
    let formats: [VideoFormat] = [
        .hd1080p(frameRate: .fps23_98),
        .hd1080p(frameRate: .fps24),
        .hd1080p(frameRate: .fps25),
        .hd1080p(frameRate: .fps29_97),
        .hd1080p(frameRate: .fps30),
        .uhd4K(frameRate: .fps23_98),
        .hd720p(frameRate: .fps30)
    ]

    for format in formats {
        let timeline = Timeline(name: "Timeline \(format.fcpxmlFormatName)")
        timeline.videoFormat = format
        context.insert(timeline)

        timeline.appendClip(TimelineClip(assetStorageId: asset.id, duration: Timecode(seconds: 10)))

        var exporter = FCPXMLExporter(version: "1.11")
        let xml = try exporter.export(timeline: timeline, modelContext: context)

        let validator = FCPXMLDTDValidator()
        let result = try validator.validate(xmlContent: xml, version: "1.11")

        if !result.isValid {
            Issue.record("DTD validation failed for format \(format.fcpxmlFormatName):\n\(result.errors.joined(separator: "\n"))")
        }
        #expect(result.isValid, "Format \(format.fcpxmlFormatName) must pass DTD validation")

        // Clean up for next iteration
        context.delete(timeline)
    }
}

// MARK: - DTD Version Compatibility Tests

@Test func validateAgainstMultipleDTDVersions() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 30.0
    )
    context.insert(asset)

    let timeline = Timeline(name: "Version Test Timeline")
    context.insert(timeline)
    timeline.appendClip(TimelineClip(assetStorageId: asset.id, duration: Timecode(seconds: 30)))

    // Test against multiple DTD versions
    // Note: Only test versions 1.9+ as earlier versions have different DTD requirements
    // (e.g., v1.8 doesn't support media-rep element)
    let versions = ["1.9", "1.10", "1.11", "1.12", "1.13"]

    for version in versions {
        var exporter = FCPXMLExporter(version: version)
        let xml = try exporter.export(timeline: timeline, modelContext: context)

        let validator = FCPXMLDTDValidator()
        let result = try validator.validate(xmlContent: xml, version: version)

        if !result.isValid {
            Issue.record("DTD validation failed for version \(version):\n\(result.errors.joined(separator: "\n"))")
        }
        #expect(result.isValid, "FCPXML version \(version) must pass DTD validation")
    }
}

// MARK: - Error Reporting Tests

@Test func dtdValidationProvidesUsefulErrors() async throws {
    // Create intentionally malformed FCPXML (missing required attributes)
    let malformedXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE fcpxml>
    <fcpxml version="1.11">
        <resources>
            <format id="r1"/>
        </resources>
        <library>
            <event>
                <project name="Test">
                    <sequence>
                        <spine/>
                    </sequence>
                </project>
            </event>
        </library>
    </fcpxml>
    """

    let validator = FCPXMLDTDValidator()
    let result = try validator.validate(xmlContent: malformedXML, version: "1.11")

    #expect(!result.isValid, "Malformed XML should fail validation")
    #expect(!result.errors.isEmpty, "Should provide error messages")
    #expect(!result.rawOutput.isEmpty, "Should provide raw xmllint output")
}
