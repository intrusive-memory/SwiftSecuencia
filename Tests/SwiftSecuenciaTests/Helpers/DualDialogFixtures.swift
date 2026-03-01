//
//  DualDialogFixtures.swift
//  SwiftSecuencia
//
//  Test fixtures and helpers for dual dialogue testing.
//

import Foundation
import SwiftCompartido
import SwiftData

@testable import SwiftSecuencia

/// Test fixtures for dual dialogue scenarios.
enum DualDialogFixtures {
  /// Helper struct to group audio, metadata, and duration together
  struct AudioMetadataItem {
    let audio: TypedDataStorage
    let metadata: ScreenplayMetadata
    let duration: Double
  }

  // MARK: - Sample Fountain Text

  /// Simple dual dialogue between two characters.
  static let simpleDualDialog = """
    INT. COFFEE SHOP - DAY

    JOHN
    How are you doing today?

    ^MARY ^
    I'm doing great, thanks for asking!

    JOHN
    That's wonderful to hear.
    """

  /// Triple dialogue (three simultaneous speakers).
  static let tripleDialog = """
    INT. CONFERENCE ROOM - DAY

    ALICE
    I think we should proceed with option A.

    ^BOB ^
    Option B makes more financial sense.

    ^^CHARLIE ^^
    What about option C? We haven't considered it.

    ALICE
    Let's discuss each option.
    """

  /// Mixed sequential and dual dialogue.
  static let mixedDialog = """
    INT. RESTAURANT - NIGHT

    WAITER
    Good evening, welcome to our restaurant.

    CUSTOMER 1
    Thank you. What's the special tonight?

    WAITER
    The chef recommends the salmon.

    ^CUSTOMER 1 ^
    That sounds delicious. I'll have that.

    ^CUSTOMER 2 ^
    Make that two, please.

    WAITER
    Excellent choice. I'll place your order.
    """

  // MARK: - Audio Creation Helpers

  /// Creates a TypedDataStorage with audio content for testing.
  ///
  /// - Parameters:
  ///   - characterName: Name of the character speaking
  ///   - dialogue: The dialogue text
  ///   - duration: Audio duration in seconds
  ///   - screenplayMetadata: Optional screenplay metadata
  /// - Returns: TypedDataStorage configured for audio
  static func createAudioStorage(
    characterName: String,
    dialogue: String,
    duration: Double = 3.0,
    screenplayMetadata: ScreenplayMetadata? = nil
  ) -> TypedDataStorage {
    // Generate simple audio data (silence for testing)
    let audioData = Data(count: Int(duration * 44100 * 2 * 2))  // 44.1kHz, stereo, 16-bit

    let storage = TypedDataStorage(
      providerId: "test-provider",
      requestorID: "test-tts",
      mimeType: "audio/mpeg",
      binaryValue: audioData,
      prompt: "\(characterName): \(dialogue)",
      audioFormat: "mp3",
      durationSeconds: duration,
      sampleRate: 44100,
      bitRate: 128000,
      channels: 2
    )

    return storage
  }

  /// Creates a dual dialogue pair with screenplay metadata.
  ///
  /// - Parameters:
  ///   - character1: First character name
  ///   - dialogue1: First character's dialogue
  ///   - character2: Second character name
  ///   - dialogue2: Second character's dialogue
  ///   - duration1: Duration of first clip (default: 3.0s)
  ///   - duration2: Duration of second clip (default: 3.0s)
  ///   - sceneId: Optional scene identifier
  /// - Returns: Tuple of (groupId, [TypedDataStorage with metadata])
  static func createDualDialogPair(
    character1: String,
    dialogue1: String,
    character2: String,
    dialogue2: String,
    duration1: Double = 3.0,
    duration2: Double = 3.0,
    sceneId: String? = nil
  ) -> (groupId: UUID, audio: [(TypedDataStorage, ScreenplayMetadata)]) {
    let groupId = UUID()

    let metadata1 = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: character1,
      isDualDialogue: true,
      dualDialogueIndex: 0,
      dualDialogueGroupId: groupId,
      sceneId: sceneId
    )

    let metadata2 = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: character2,
      isDualDialogue: true,
      dualDialogueIndex: 1,
      dualDialogueGroupId: groupId,
      sceneId: sceneId
    )

    let audio1 = createAudioStorage(
      characterName: character1,
      dialogue: dialogue1,
      duration: duration1,
      screenplayMetadata: metadata1
    )

    let audio2 = createAudioStorage(
      characterName: character2,
      dialogue: dialogue2,
      duration: duration2,
      screenplayMetadata: metadata2
    )

    return (groupId, [(audio1, metadata1), (audio2, metadata2)])
  }

  /// Creates a triple dialogue group with screenplay metadata.
  ///
  /// - Parameters:
  ///   - characters: Array of character names (must be exactly 3)
  ///   - dialogues: Array of dialogue texts (must be exactly 3)
  ///   - durations: Array of durations (default: [3.0, 3.0, 3.0])
  ///   - sceneId: Optional scene identifier
  /// - Returns: Tuple of (groupId, [TypedDataStorage with metadata])
  static func createTripleDialogGroup(
    characters: [String],
    dialogues: [String],
    durations: [Double] = [3.0, 3.0, 3.0],
    sceneId: String? = nil
  ) -> (groupId: UUID, audio: [(TypedDataStorage, ScreenplayMetadata)]) {
    precondition(characters.count == 3, "Triple dialog requires exactly 3 characters")
    precondition(dialogues.count == 3, "Triple dialog requires exactly 3 dialogues")
    precondition(durations.count == 3, "Triple dialog requires exactly 3 durations")

    let groupId = UUID()
    var result: [(TypedDataStorage, ScreenplayMetadata)] = []

    for index in 0..<characters.count {
      let character = characters[index]
      let dialogue = dialogues[index]
      let duration = durations[index]

      let metadata = ScreenplayMetadata(
        elementType: "Dialogue",
        characterName: character,
        isDualDialogue: true,
        dualDialogueIndex: index,
        dualDialogueGroupId: groupId,
        sceneId: sceneId
      )

      let audio = createAudioStorage(
        characterName: character,
        dialogue: dialogue,
        duration: duration,
        screenplayMetadata: metadata
      )

      result.append((audio, metadata))
    }

    return (groupId, result)
  }

  /// Creates a sequential dialogue clip (not dual dialogue).
  ///
  /// - Parameters:
  ///   - characterName: Character name
  ///   - dialogue: Dialogue text
  ///   - duration: Audio duration (default: 3.0s)
  ///   - sceneId: Optional scene identifier
  /// - Returns: Tuple of (TypedDataStorage, ScreenplayMetadata)
  static func createSequentialDialog(
    characterName: String,
    dialogue: String,
    duration: Double = 3.0,
    sceneId: String? = nil
  ) -> (TypedDataStorage, ScreenplayMetadata) {
    let metadata = ScreenplayMetadata(
      elementType: "Dialogue",
      characterName: characterName,
      isDualDialogue: false,
      sceneId: sceneId
    )

    let audio = createAudioStorage(
      characterName: characterName,
      dialogue: dialogue,
      duration: duration,
      screenplayMetadata: metadata
    )

    return (audio, metadata)
  }

  // MARK: - Timeline Creation Helpers

  /// Creates a timeline with dual dialogue clips for testing.
  ///
  /// - Parameters:
  ///   - name: Timeline name
  ///   - audioWithMetadata: Array of (TypedDataStorage, ScreenplayMetadata) tuples
  ///   - modelContext: SwiftData model context
  /// - Returns: Timeline with clips created according to screenplay metadata
  @MainActor
  static func createTimelineWithDualDialog(
    name: String,
    audioWithMetadata: [(TypedDataStorage, ScreenplayMetadata)],
    modelContext: ModelContext
  ) throws -> Timeline {
    let timeline = Timeline(
      name: name,
      videoFormat: .hd1080p(frameRate: .fps24),
      audioLayout: .stereo,
      audioRate: .rate48kHz
    )

    // Track dual dialogue groups
    var dualDialogGroups: [UUID: [AudioMetadataItem]] = [:]
    var currentOffset = Timecode.zero

    // First pass: group dual dialogue elements
    for (audio, metadata) in audioWithMetadata {
      let duration = audio.durationSeconds ?? 3.0

      if metadata.isDualDialogue, let groupId = metadata.dualDialogueGroupId {
        if dualDialogGroups[groupId] == nil {
          dualDialogGroups[groupId] = []
        }
        dualDialogGroups[groupId]?.append(
          AudioMetadataItem(audio: audio, metadata: metadata, duration: duration))
      } else {
        // Sequential clip
        let clip = TimelineClip(
          name: audio.prompt,
          assetStorageId: audio.id,
          offset: currentOffset,
          duration: Timecode(seconds: duration),
          lane: 0
        )
        clip.metadata = metadata.toMetadata()

        timeline.insertClip(clip, at: currentOffset, lane: 0)
        currentOffset = currentOffset + Timecode(seconds: duration)
      }
    }

    // Second pass: place dual dialogue groups
    for (_, group) in dualDialogGroups.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
      // Find max duration for this group
      let maxDuration = group.map { $0.duration }.max() ?? 3.0

      // Place each clip at current offset on its assigned lane
      for item in group {
        let audio = item.audio
        let metadata = item.metadata
        let duration = item.duration
        let lane = metadata.dualDialogueIndex ?? 0

        let clip = TimelineClip(
          name: audio.prompt,
          assetStorageId: audio.id,
          offset: currentOffset,
          duration: Timecode(seconds: duration),
          lane: lane
        )
        clip.metadata = metadata.toMetadata()

        timeline.insertClip(clip, at: currentOffset, lane: lane)
      }

      // Advance offset by max duration
      currentOffset = currentOffset + Timecode(seconds: maxDuration)
    }

    return timeline
  }

  // MARK: - Validation Helpers

  /// Validates that clips in a dual dialogue group are placed correctly.
  ///
  /// - Parameters:
  ///   - timeline: Timeline to validate
  ///   - groupId: Dual dialogue group ID
  /// - Returns: True if all clips in the group have the same offset
  static func validateDualDialogPlacement(
    timeline: Timeline,
    groupId: UUID
  ) -> Bool {
    let groupClips = timeline.clips.filter { clip in
      guard let metadata = clip.metadata?.screenplayMetadata else { return false }
      return metadata.dualDialogueGroupId == groupId
    }

    guard !groupClips.isEmpty else { return false }

    let firstOffset = groupClips[0].offset
    return groupClips.allSatisfy { $0.offset == firstOffset }
  }

  /// Validates that clips in a dual dialogue group use different lanes.
  ///
  /// - Parameters:
  ///   - timeline: Timeline to validate
  ///   - groupId: Dual dialogue group ID
  /// - Returns: True if all clips in the group are on different lanes
  static func validateDualDialogLanes(
    timeline: Timeline,
    groupId: UUID
  ) -> Bool {
    let groupClips = timeline.clips.filter { clip in
      guard let metadata = clip.metadata?.screenplayMetadata else { return false }
      return metadata.dualDialogueGroupId == groupId
    }

    let lanes = Set(groupClips.map { $0.lane })
    return lanes.count == groupClips.count
  }
}
