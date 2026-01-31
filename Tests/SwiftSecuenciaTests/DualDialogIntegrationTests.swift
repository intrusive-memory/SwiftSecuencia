//
//  DualDialogIntegrationTests.swift
//  SwiftSecuencia
//
//  Integration tests for dual dialogue support in Timeline generation.
//

import Foundation
import Testing
import SwiftData
import SwiftCompartido
@testable import SwiftSecuencia

@Suite("Dual Dialog Integration Tests")
struct DualDialogIntegrationTests {

    // MARK: - Test Infrastructure

    /// Creates a temporary in-memory model container for testing.
    @MainActor
    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            Timeline.self,
            TimelineClip.self,
            TypedDataStorage.self
        ])

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create test container: \(error)")
        }
    }

    // MARK: - Basic Dual Dialog Tests

    @Test("Basic dual dialogue - two speakers at same offset")
    @MainActor
    func basicDualDialogue() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)

        // Create dual dialog pair
        let (groupId, audioWithMetadata) = DualDialogFixtures.createDualDialogPair(
            character1: "JOHN",
            dialogue1: "Hello there!",
            character2: "MARY",
            dialogue2: "Hi, how are you?",
            duration1: 2.0,
            duration2: 3.0
        )

        // Insert audio storage into context
        for (audio, _) in audioWithMetadata {
            context.insert(audio)
        }
        try context.save()

        // Convert to timeline with metadata
        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Dual Dialog Test",
            audioElements: audioWithMetadata.map { $0.0 },
            audioMetadata: audioWithMetadata.map { $0.1 }
        )

        // Verify timeline structure
        #expect(timeline.clipCount == 2)

        // Both clips should be at offset 0
        let clips = timeline.sortedClips
        #expect(clips[0].offset == .zero)
        #expect(clips[1].offset == .zero)

        // Different lanes
        #expect(clips[0].lane == 0)
        #expect(clips[1].lane == 1)

        // Duration across all lanes should be max of the two
        let maxEndTime = clips.map { $0.offset + $0.duration }.max()!
        #expect(maxEndTime == Timecode(seconds: 3.0))

        // Verify metadata is preserved
        let metadata0 = clips[0].metadata?.screenplayMetadata
        let metadata1 = clips[1].metadata?.screenplayMetadata

        #expect(metadata0?.characterName == "JOHN")
        #expect(metadata1?.characterName == "MARY")
        #expect(metadata0?.dualDialogueGroupId == groupId)
        #expect(metadata1?.dualDialogueGroupId == groupId)
    }

    @Test("Sequential + dual dialog mix")
    @MainActor
    func sequentialPlusDualDialog() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)

        // Create: regular → dual pair → regular
        var allAudio: [(TypedDataStorage, ScreenplayMetadata)] = []

        // Regular clip 1
        let (audio1, meta1) = DualDialogFixtures.createSequentialDialog(
            characterName: "NARRATOR",
            dialogue: "The scene begins.",
            duration: 2.0
        )
        allAudio.append((audio1, meta1))

        // Dual dialog pair
        let (_, dualAudio) = DualDialogFixtures.createDualDialogPair(
            character1: "ALICE",
            dialogue1: "I agree!",
            character2: "BOB",
            dialogue2: "Me too!",
            duration1: 3.0,
            duration2: 2.5
        )
        allAudio.append(contentsOf: dualAudio)

        // Regular clip 2
        let (audio4, meta4) = DualDialogFixtures.createSequentialDialog(
            characterName: "NARRATOR",
            dialogue: "The scene ends.",
            duration: 1.5
        )
        allAudio.append((audio4, meta4))

        // Insert all audio into context
        for (audio, _) in allAudio {
            context.insert(audio)
        }
        try context.save()

        // Convert to timeline
        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Mixed Dialog Test",
            audioElements: allAudio.map { $0.0 },
            audioMetadata: allAudio.map { $0.1 }
        )

        // Verify structure: 4 clips total
        #expect(timeline.clipCount == 4)

        let clips = timeline.sortedClips

        // Clip 0: Regular at offset 0, lane 0, duration 2.0s
        #expect(clips[0].offset == .zero)
        #expect(clips[0].lane == 0)
        #expect(clips[0].metadata?.screenplayMetadata?.characterName == "NARRATOR")

        // Clips 1-2: Dual dialog at offset 2.0s, lanes 0-1
        #expect(clips[1].offset == Timecode(seconds: 2.0))
        #expect(clips[2].offset == Timecode(seconds: 2.0))
        #expect(Set([clips[1].lane, clips[2].lane]) == Set([0, 1]))

        // Clip 3: Regular at offset 5.0s (2.0 + 3.0), lane 0
        #expect(clips[3].offset == Timecode(seconds: 5.0))
        #expect(clips[3].lane == 0)
        #expect(clips[3].metadata?.screenplayMetadata?.characterName == "NARRATOR")

        // Total duration: 2.0 + 3.0 + 1.5 = 6.5s
        #expect(timeline.duration == Timecode(seconds: 6.5))
    }

    @Test("Triple dialogue - three simultaneous speakers")
    @MainActor
    func tripleDialogue() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)

        // Create triple dialog group
        let (groupId, audioWithMetadata) = DualDialogFixtures.createTripleDialogGroup(
            characters: ["ALICE", "BOB", "CHARLIE"],
            dialogues: ["Option A", "Option B", "Option C"],
            durations: [2.0, 3.0, 2.5]
        )

        // Insert audio into context
        for (audio, _) in audioWithMetadata {
            context.insert(audio)
        }
        try context.save()

        // Convert to timeline
        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Triple Dialog Test",
            audioElements: audioWithMetadata.map { $0.0 },
            audioMetadata: audioWithMetadata.map { $0.1 }
        )

        // Verify 3 clips
        #expect(timeline.clipCount == 3)

        let clips = timeline.sortedClips

        // All at offset 0
        #expect(clips.allSatisfy { $0.offset == .zero })

        // Three different lanes (0, 1, 2)
        let lanes = Set(clips.map { $0.lane })
        #expect(lanes == Set([0, 1, 2]))

        // Duration across all lanes is max (3.0s)
        let maxEndTime = clips.map { $0.offset + $0.duration }.max()!
        #expect(maxEndTime == Timecode(seconds: 3.0))

        // All have same group ID
        let groupIds = clips.compactMap { $0.metadata?.screenplayMetadata?.dualDialogueGroupId }
        #expect(Set(groupIds) == Set([groupId]))
    }

    @Test("Different durations in dual dialog uses max")
    @MainActor
    func differentDurationsUsesMax() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)

        // Short + long
        let (_, audioWithMetadata) = DualDialogFixtures.createDualDialogPair(
            character1: "FAST",
            dialogue1: "Quick!",
            character2: "SLOW",
            dialogue2: "I need more time to think about this...",
            duration1: 1.0,
            duration2: 5.0
        )

        for (audio, _) in audioWithMetadata {
            context.insert(audio)
        }
        try context.save()

        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Duration Test",
            audioElements: audioWithMetadata.map { $0.0 },
            audioMetadata: audioWithMetadata.map { $0.1 }
        )

        // Duration across all lanes should be the longer clip (5.0s)
        let maxEndTime = timeline.clips.map { $0.offset + $0.duration }.max()!
        #expect(maxEndTime == Timecode(seconds: 5.0))

        // Both clips at offset 0
        let clips = timeline.sortedClips
        #expect(clips.allSatisfy { $0.offset == .zero })
    }

    @Test("Multiple dual dialog groups in sequence")
    @MainActor
    func multipleDualDialogGroups() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)

        var allAudio: [(TypedDataStorage, ScreenplayMetadata)] = []

        // First dual dialog group
        let (_, group1) = DualDialogFixtures.createDualDialogPair(
            character1: "A1",
            dialogue1: "First group A",
            character2: "B1",
            dialogue2: "First group B",
            duration1: 2.0,
            duration2: 3.0
        )
        allAudio.append(contentsOf: group1)

        // Second dual dialog group
        let (_, group2) = DualDialogFixtures.createDualDialogPair(
            character1: "A2",
            dialogue1: "Second group A",
            character2: "B2",
            dialogue2: "Second group B",
            duration1: 1.5,
            duration2: 2.5
        )
        allAudio.append(contentsOf: group2)

        for (audio, _) in allAudio {
            context.insert(audio)
        }
        try context.save()

        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Multiple Groups Test",
            audioElements: allAudio.map { $0.0 },
            audioMetadata: allAudio.map { $0.1 }
        )

        #expect(timeline.clipCount == 4)

        let clips = timeline.sortedClips

        // First group at offset 0
        #expect(clips[0].offset == .zero)
        #expect(clips[1].offset == .zero)

        // Second group at offset 3.0 (max of first group)
        #expect(clips[2].offset == Timecode(seconds: 3.0))
        #expect(clips[3].offset == Timecode(seconds: 3.0))

        // Total duration across all lanes: 3.0 + 2.5 = 5.5s
        let maxEndTime = clips.map { $0.offset + $0.duration }.max()!
        #expect(maxEndTime == Timecode(seconds: 5.5))
    }

    @Test("Incomplete dual dialog group (single speaker)")
    @MainActor
    func incompleteDualDialogGroup() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)

        // Create a dual dialog group but only include one speaker
        let groupId = UUID()
        let metadata = ScreenplayMetadata(
            elementType: "Dialogue",
            characterName: "ALONE",
            isDualDialogue: true,
            dualDialogueIndex: 0,
            dualDialogueGroupId: groupId
        )

        let audio = DualDialogFixtures.createAudioStorage(
            characterName: "ALONE",
            dialogue: "Where is my partner?",
            duration: 3.0
        )

        context.insert(audio)
        try context.save()

        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Incomplete Group Test",
            audioElements: [audio],
            audioMetadata: [metadata]
        )

        // Should still create a clip
        #expect(timeline.clipCount == 1)

        let clip = timeline.clips[0]
        #expect(clip.offset == .zero)
        #expect(clip.lane == 0)
        #expect(timeline.duration == Timecode(seconds: 3.0))
    }

    @Test("Lane assignment matches dual dialogue index")
    @MainActor
    func laneAssignmentMatchesIndex() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)

        let (_, audioWithMetadata) = DualDialogFixtures.createTripleDialogGroup(
            characters: ["FIRST", "SECOND", "THIRD"],
            dialogues: ["I'm first", "I'm second", "I'm third"],
            durations: [2.0, 2.0, 2.0]
        )

        for (audio, _) in audioWithMetadata {
            context.insert(audio)
        }
        try context.save()

        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Lane Assignment Test",
            audioElements: audioWithMetadata.map { $0.0 },
            audioMetadata: audioWithMetadata.map { $0.1 }
        )

        let clips = timeline.sortedClips

        // Verify lane assignment matches dualDialogueIndex
        for clip in clips {
            let metadata = clip.metadata?.screenplayMetadata
            #expect(clip.lane == metadata?.dualDialogueIndex)
        }
    }

    @Test("Offset calculation with dual dialog")
    @MainActor
    func offsetCalculationWithDualDialog() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)

        var allAudio: [(TypedDataStorage, ScreenplayMetadata)] = []

        // Clip 1: Sequential (2.0s)
        let (audio1, meta1) = DualDialogFixtures.createSequentialDialog(
            characterName: "A",
            dialogue: "First",
            duration: 2.0
        )
        allAudio.append((audio1, meta1))

        // Dual pair: (3.0s max)
        let (_, dual) = DualDialogFixtures.createDualDialogPair(
            character1: "B",
            dialogue1: "Second",
            character2: "C",
            dialogue2: "Third",
            duration1: 3.0,
            duration2: 2.5
        )
        allAudio.append(contentsOf: dual)

        // Clip 4: Sequential (1.5s)
        let (audio4, meta4) = DualDialogFixtures.createSequentialDialog(
            characterName: "D",
            dialogue: "Fourth",
            duration: 1.5
        )
        allAudio.append((audio4, meta4))

        for (audio, _) in allAudio {
            context.insert(audio)
        }
        try context.save()

        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Offset Test",
            audioElements: allAudio.map { $0.0 },
            audioMetadata: allAudio.map { $0.1 }
        )

        let clips = timeline.sortedClips

        // Expected offsets:
        // Clip 0: 0.0s (sequential)
        // Clips 1-2: 2.0s (dual dialog)
        // Clip 3: 5.0s (2.0 + 3.0)

        #expect(clips[0].offset == Timecode(seconds: 0.0))
        #expect(clips[1].offset == Timecode(seconds: 2.0))
        #expect(clips[2].offset == Timecode(seconds: 2.0))
        #expect(clips[3].offset == Timecode(seconds: 5.0))
    }
}
