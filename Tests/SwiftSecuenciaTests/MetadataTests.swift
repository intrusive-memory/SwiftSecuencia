//
//  MetadataTests.swift
//  SwiftSecuencia
//
//  Tests for metadata types (Marker, ChapterMarker, Keyword, Rating, Metadata).
//

import Testing
import Foundation
@testable import SwiftSecuencia

// MARK: - Marker Tests

@Test func markerCreatesCorrectXML() async throws {
    let marker = Marker(
        start: Timecode(seconds: 10),
        duration: Timecode(value: 1, timescale: 24),
        value: "Review this section",
        note: "Needs color correction"
    )

    let xml = marker.xmlElement()

    #expect(xml.name == "marker")
    #expect(xml.attribute(forName: "start")?.stringValue == "10s")
    #expect(xml.attribute(forName: "duration")?.stringValue == "1/24s")
    #expect(xml.attribute(forName: "value")?.stringValue == "Review this section")
    #expect(xml.attribute(forName: "note")?.stringValue == "Needs color correction")
}

@Test func markerWithoutNoteOmitsNoteAttribute() async throws {
    let marker = Marker(
        start: Timecode(seconds: 5),
        value: "Simple marker"
    )

    let xml = marker.xmlElement()

    #expect(xml.attribute(forName: "note") == nil)
}

@Test func completedMarkerHasCompletedAttribute() async throws {
    let marker = Marker(
        start: Timecode.zero,
        value: "TODO item",
        completed: true
    )

    let xml = marker.xmlElement()

    #expect(xml.attribute(forName: "completed")?.stringValue == "1")
}

@Test func markerEquality() async throws {
    let marker1 = Marker(start: Timecode(seconds: 10), value: "Test")
    let marker2 = Marker(start: Timecode(seconds: 10), value: "Test")
    let marker3 = Marker(start: Timecode(seconds: 20), value: "Test")

    #expect(marker1 == marker2)
    #expect(marker1 != marker3)
}

// MARK: - ChapterMarker Tests

@Test func chapterMarkerCreatesCorrectXML() async throws {
    let chapter = ChapterMarker(
        start: Timecode(seconds: 60),
        value: "Chapter 1",
        posterOffset: Timecode(seconds: 5)
    )

    let xml = chapter.xmlElement()

    #expect(xml.name == "chapter-marker")
    #expect(xml.attribute(forName: "start")?.stringValue == "60s")
    #expect(xml.attribute(forName: "value")?.stringValue == "Chapter 1")
    #expect(xml.attribute(forName: "posterOffset")?.stringValue == "5s")
}

@Test func chapterMarkerWithoutPosterOffsetOmitsAttribute() async throws {
    let chapter = ChapterMarker(
        start: Timecode.zero,
        value: "Introduction"
    )

    let xml = chapter.xmlElement()

    #expect(xml.attribute(forName: "posterOffset") == nil)
}

@Test func chapterMarkerWithNote() async throws {
    let chapter = ChapterMarker(
        start: Timecode(seconds: 120),
        value: "Chapter 2",
        note: "Main content starts here"
    )

    let xml = chapter.xmlElement()

    #expect(xml.attribute(forName: "note")?.stringValue == "Main content starts here")
}

// MARK: - Keyword Tests

@Test func keywordCreatesCorrectXML() async throws {
    let keyword = Keyword(
        start: Timecode.zero,
        duration: Timecode(seconds: 300),
        value: "Interview"
    )

    let xml = keyword.xmlElement()

    #expect(xml.name == "keyword")
    #expect(xml.attribute(forName: "start")?.stringValue == "0s")
    #expect(xml.attribute(forName: "duration")?.stringValue == "300s")
    #expect(xml.attribute(forName: "value")?.stringValue == "Interview")
}

@Test func keywordWithNote() async throws {
    let keyword = Keyword(
        start: Timecode(seconds: 10),
        duration: Timecode(seconds: 20),
        value: "B-Roll",
        note: "Exterior shots"
    )

    let xml = keyword.xmlElement()

    #expect(xml.attribute(forName: "note")?.stringValue == "Exterior shots")
}

// MARK: - Rating Tests

@Test func favoriteRatingCreatesCorrectXML() async throws {
    let rating = Rating(
        start: Timecode.zero,
        duration: Timecode(seconds: 300),
        value: .favorite,
        note: "Best take"
    )

    let xml = rating.xmlElement()

    #expect(xml.name == "rating")
    #expect(xml.attribute(forName: "start")?.stringValue == "0s")
    #expect(xml.attribute(forName: "duration")?.stringValue == "300s")
    #expect(xml.attribute(forName: "value")?.stringValue == "favorite")
    #expect(xml.attribute(forName: "note")?.stringValue == "Best take")
}

@Test func rejectedRatingCreatesCorrectXML() async throws {
    let rating = Rating(
        start: Timecode(seconds: 10),
        duration: Timecode(seconds: 5),
        value: .rejected
    )

    let xml = rating.xmlElement()

    #expect(xml.attribute(forName: "value")?.stringValue == "rejected")
    #expect(xml.attribute(forName: "note") == nil)
}

// MARK: - Metadata Tests

@Test func metadataCreatesCorrectXML() async throws {
    var metadata = Metadata()
    metadata["com.apple.proapps.studio.reel"] = "A001"
    metadata["com.apple.proapps.studio.scene"] = "1"
    metadata["com.apple.proapps.studio.take"] = "3"

    let xml = metadata.xmlElement()

    #expect(xml.name == "metadata")
    #expect(xml.childCount == 3)

    // Check that all md elements are present
    let mdElements = xml.children?.compactMap { $0 as? XMLElement } ?? []
    #expect(mdElements.count == 3)

    // Verify one of the entries
    let reelElement = mdElements.first { elem in
        elem.attribute(forName: "key")?.stringValue == "com.apple.proapps.studio.reel"
    }
    #expect(reelElement != nil)
    #expect(reelElement?.attribute(forName: "value")?.stringValue == "A001")
}

@Test func metadataSubscriptAccess() async throws {
    var metadata = Metadata()
    metadata["test.key"] = "test value"

    #expect(metadata["test.key"] == "test value")
    #expect(metadata["nonexistent.key"] == nil)

    metadata["test.key"] = nil
    #expect(metadata["test.key"] == nil)
}

@Test func metadataIsEmptyProperty() async throws {
    var metadata = Metadata()
    #expect(metadata.isEmpty == true)

    metadata["key"] = "value"
    #expect(metadata.isEmpty == false)
}

@Test func metadataConvenienceMethods() async throws {
    var metadata = Metadata()

    metadata.setReel("A001")
    metadata.setScene("1")
    metadata.setTake("3")
    metadata.setDescription("Interview with subject")
    metadata.setCameraName("Camera A")
    metadata.setCameraAngle("Wide")
    metadata.setShotType("Master")

    #expect(metadata[Metadata.Key.reel] == "A001")
    #expect(metadata[Metadata.Key.scene] == "1")
    #expect(metadata[Metadata.Key.take] == "3")
    #expect(metadata[Metadata.Key.description] == "Interview with subject")
    #expect(metadata[Metadata.Key.cameraName] == "Camera A")
    #expect(metadata[Metadata.Key.cameraAngle] == "Wide")
    #expect(metadata[Metadata.Key.shotType] == "Master")
}

@Test func metadataXMLSortedKeys() async throws {
    var metadata = Metadata()
    metadata["z.key"] = "z"
    metadata["a.key"] = "a"
    metadata["m.key"] = "m"

    let xml = metadata.xmlElement()
    let mdElements = xml.children?.compactMap { $0 as? XMLElement } ?? []

    // Keys should be sorted alphabetically
    let keys = mdElements.compactMap { $0.attribute(forName: "key")?.stringValue }
    #expect(keys == ["a.key", "m.key", "z.key"])
}

// MARK: - Codable Tests

@Test func markerCodable() async throws {
    let marker = Marker(
        start: Timecode(seconds: 10),
        value: "Test",
        note: "Note"
    )

    let encoded = try JSONEncoder().encode(marker)
    let decoded = try JSONDecoder().decode(Marker.self, from: encoded)

    #expect(decoded == marker)
}

@Test func chapterMarkerCodable() async throws {
    let chapter = ChapterMarker(
        start: Timecode(seconds: 60),
        value: "Chapter 1",
        posterOffset: Timecode(seconds: 5)
    )

    let encoded = try JSONEncoder().encode(chapter)
    let decoded = try JSONDecoder().decode(ChapterMarker.self, from: encoded)

    #expect(decoded == chapter)
}

@Test func keywordCodable() async throws {
    let keyword = Keyword(
        start: Timecode.zero,
        duration: Timecode(seconds: 300),
        value: "Interview"
    )

    let encoded = try JSONEncoder().encode(keyword)
    let decoded = try JSONDecoder().decode(Keyword.self, from: encoded)

    #expect(decoded == keyword)
}

@Test func ratingCodable() async throws {
    let rating = Rating(
        start: Timecode.zero,
        duration: Timecode(seconds: 300),
        value: .favorite
    )

    let encoded = try JSONEncoder().encode(rating)
    let decoded = try JSONDecoder().decode(Rating.self, from: encoded)

    #expect(decoded == rating)
}

@Test func metadataCodable() async throws {
    var metadata = Metadata()
    metadata["key1"] = "value1"
    metadata["key2"] = "value2"

    let encoded = try JSONEncoder().encode(metadata)
    let decoded = try JSONDecoder().decode(Metadata.self, from: encoded)

    #expect(decoded == metadata)
}
