//
//  ScreenplayMetadataTests.swift
//  SwiftSecuencia
//
//  Tests for ScreenplayMetadata model and Metadata conversion.
//

import Foundation
import Testing

@testable import SwiftSecuencia

@Suite("ScreenplayMetadata Tests")
struct ScreenplayMetadataTests {

  // MARK: - Basic Initialization Tests

  @Test("ScreenplayMetadata initializes with all fields")
  func initializeWithAllFields() {
    let groupId = UUID()

    let metadata = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: "JOHN",
      isDualDialogue: true,
      dualDialogueIndex: 0,
      dualDialogueGroupId: groupId,
      sceneId: "INT. COFFEE SHOP - DAY"
    )

    #expect(metadata.elementType == "Dialogue")
    #expect(metadata.characterName == "JOHN")
    #expect(metadata.isDualDialogue == true)
    #expect(metadata.dualDialogueIndex == 0)
    #expect(metadata.dualDialogueGroupId == groupId)
    #expect(metadata.sceneId == "INT. COFFEE SHOP - DAY")
  }

  @Test("ScreenplayMetadata initializes with minimal fields")
  func initializeWithMinimalFields() {
    let metadata = ScreenplayMetadata(elementType: "Action")

    #expect(metadata.elementType == "Action")
    #expect(metadata.characterName == nil)
    #expect(metadata.isDualDialogue == false)
    #expect(metadata.dualDialogueIndex == nil)
    #expect(metadata.dualDialogueGroupId == nil)
    #expect(metadata.sceneId == nil)
  }

  // MARK: - Metadata Conversion Tests

  @Test("Convert to Metadata and back (round-trip)")
  func metadataRoundTrip() {
    let groupId = UUID()

    let original = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: "MARY",
      isDualDialogue: true,
      dualDialogueIndex: 1,
      dualDialogueGroupId: groupId,
      sceneId: "INT. BEDROOM - NIGHT"
    )

    // Convert to Metadata
    let timelineMetadata = original.toMetadata()

    // Verify metadata entries
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.element-type"] == "Dialogue")
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.character-name"] == "MARY")
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.is-dual-dialogue"] == "true")
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.dual-dialogue-index"] == "1")
    #expect(
      timelineMetadata["com.swiftsecuencia.screenplay.dual-dialogue-group-id"] == groupId.uuidString
    )
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.scene-id"] == "INT. BEDROOM - NIGHT")

    // Convert back to ScreenplayMetadata
    let restored = ScreenplayMetadata.from(timelineMetadata)

    #expect(restored == original)
  }

  @Test("Convert minimal ScreenplayMetadata to Metadata")
  func minimalMetadataConversion() {
    let original = ScreenplayMetadata(elementType: "Transition")

    let timelineMetadata = original.toMetadata()

    #expect(timelineMetadata["com.swiftsecuencia.screenplay.element-type"] == "Transition")
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.is-dual-dialogue"] == "false")

    // Optional fields should not be present
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.character-name"] == nil)
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.dual-dialogue-index"] == nil)
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.dual-dialogue-group-id"] == nil)
    #expect(timelineMetadata["com.swiftsecuencia.screenplay.scene-id"] == nil)

    let restored = ScreenplayMetadata.from(timelineMetadata)
    #expect(restored == original)
  }

  @Test("Restore from nil Metadata returns nil")
  func restoreFromNilMetadata() {
    let restored = ScreenplayMetadata.from(nil)
    #expect(restored == nil)
  }

  @Test("Restore from empty Metadata returns nil")
  func restoreFromEmptyMetadata() {
    let emptyMetadata = Metadata(entries: [:])
    let restored = ScreenplayMetadata.from(emptyMetadata)
    #expect(restored == nil)
  }

  @Test("Restore from incomplete Metadata returns nil")
  func restoreFromIncompleteMetadata() {
    var metadata = Metadata()
    metadata["com.swiftsecuencia.screenplay.character-name"] = "JOHN"
    // Missing required element-type

    let restored = ScreenplayMetadata.from(metadata)
    #expect(restored == nil)
  }

  // MARK: - Metadata Extension Tests

  @Test("Metadata extension extracts screenplay metadata")
  func metadataExtensionExtractsScreenplayMetadata() {
    let original = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: "ALICE"
    )

    var timelineMetadata = original.toMetadata()
    // Add some non-screenplay metadata
    timelineMetadata["com.apple.proapps.studio.scene"] = "42"

    let extracted = timelineMetadata.screenplayMetadata
    #expect(extracted?.elementType == "Dialogue")
    #expect(extracted?.characterName == "ALICE")
  }

  @Test("Metadata extension returns nil for non-screenplay metadata")
  func metadataExtensionReturnsNilForNonScreenplay() {
    var metadata = Metadata()
    metadata["com.apple.proapps.studio.scene"] = "42"
    metadata["com.apple.proapps.studio.take"] = "3"

    let extracted = metadata.screenplayMetadata
    #expect(extracted == nil)
  }

  // MARK: - Equatable Conformance Tests

  @Test("ScreenplayMetadata equality works correctly")
  func equalityWorks() {
    let groupId = UUID()

    let metadata1 = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: "BOB",
      isDualDialogue: true,
      dualDialogueIndex: 0,
      dualDialogueGroupId: groupId
    )

    let metadata2 = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: "BOB",
      isDualDialogue: true,
      dualDialogueIndex: 0,
      dualDialogueGroupId: groupId
    )

    #expect(metadata1 == metadata2)
  }

  @Test("ScreenplayMetadata inequality works correctly")
  func inequalityWorks() {
    let metadata1 = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: "CHARLIE"
    )

    let metadata2 = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: "DAVID"
    )

    #expect(metadata1 != metadata2)
  }

  // MARK: - Codable Tests

  @Test("ScreenplayMetadata is Codable (round-trip)")
  func codableRoundTrip() throws {
    let groupId = UUID()

    let original = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: "EVE",
      isDualDialogue: true,
      dualDialogueIndex: 2,
      dualDialogueGroupId: groupId,
      sceneId: "EXT. PARK - DAY"
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ScreenplayMetadata.self, from: data)

    #expect(decoded == original)
  }

  // MARK: - Edge Case Tests

  @Test("Dual dialogue with invalid index is preserved")
  func dualDialogueWithInvalidIndex() {
    let metadata = ScreenplayMetadata(
      elementType: "Dialogue",
      isDualDialogue: true,
      dualDialogueIndex: -1  // Invalid but should be preserved
    )

    let timelineMetadata = metadata.toMetadata()
    let restored = ScreenplayMetadata.from(timelineMetadata)

    #expect(restored?.dualDialogueIndex == -1)
  }

  @Test("Empty character name is preserved")
  func emptyCharacterName() {
    let metadata = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: ""
    )

    let timelineMetadata = metadata.toMetadata()
    let restored = ScreenplayMetadata.from(timelineMetadata)

    #expect(restored?.characterName == "")
  }

  @Test("Very long element type is preserved")
  func veryLongElementType() {
    let longType = String(repeating: "A", count: 1000)

    let metadata = ScreenplayMetadata(elementType: longType)

    let timelineMetadata = metadata.toMetadata()
    let restored = ScreenplayMetadata.from(timelineMetadata)

    #expect(restored?.elementType == longType)
  }

  @Test("Special characters in fields are preserved")
  func specialCharactersPreserved() {
    let metadata = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: "FRANÇOIS (V.O.)",
      sceneId: "INT. CAFÉ - DAY"
    )

    let timelineMetadata = metadata.toMetadata()
    let restored = ScreenplayMetadata.from(timelineMetadata)

    #expect(restored?.characterName == "FRANÇOIS (V.O.)")
    #expect(restored?.sceneId == "INT. CAFÉ - DAY")
  }
}
