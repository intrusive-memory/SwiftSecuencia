import Testing
import Foundation
import SwiftData
@testable import SwiftSecuencia

// MARK: - Ripple Insert Basic Tests

@Test func rippleInsertShiftsSubsequentClips() async throws {
    let timeline = Timeline(name: "Test")

    // Add clips at 0s, 10s, 20s
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip3 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.insertClip(clip1, at: Timecode(seconds: 0))
    timeline.insertClip(clip2, at: Timecode(seconds: 10))
    timeline.insertClip(clip3, at: Timecode(seconds: 20))

    // Insert 5s clip at 5s with ripple
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(newClip, at: Timecode(seconds: 5))

    // Verify inserted clip placement
    #expect(result.insertedClip.offset.seconds == 5.0)
    #expect(result.insertedClip.duration.seconds == 5.0)

    // Verify shifts: clip2 and clip3 should be shifted by 5s
    #expect(result.shiftedClips.count == 2)

    // Find clip2's shift
    let clip2Shift = result.shiftedClips.first { $0.clipId == clip2.id }
    #expect(clip2Shift?.originalOffset.seconds == 10.0)
    #expect(clip2Shift?.newOffset.seconds == 15.0)

    // Find clip3's shift
    let clip3Shift = result.shiftedClips.first { $0.clipId == clip3.id }
    #expect(clip3Shift?.originalOffset.seconds == 20.0)
    #expect(clip3Shift?.newOffset.seconds == 25.0)

    // clip1 should NOT be shifted (starts before insert point)
    let clip1Shift = result.shiftedClips.first { $0.clipId == clip1.id }
    #expect(clip1Shift == nil)
}

@Test func rippleInsertDoesNotShiftClipsBeforeInsertPoint() async throws {
    let timeline = Timeline(name: "Test")

    // Add clips
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.insertClip(clip1, at: Timecode(seconds: 0))
    timeline.insertClip(clip2, at: Timecode(seconds: 10))

    // Insert at position 15 (between clip1 end and clip2 end)
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(newClip, at: Timecode(seconds: 15))

    // Only clip2 part that's at/after 15 should be considered
    // But since clip2 starts at 10 (before 15), it won't be shifted
    #expect(result.shiftedClips.isEmpty)
}

@Test func rippleInsertAtTimelineStart() async throws {
    let timeline = Timeline(name: "Test")

    // Add clips
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.insertClip(clip1, at: Timecode(seconds: 0))
    timeline.insertClip(clip2, at: Timecode(seconds: 10))

    // Insert at position 0
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(newClip, at: .zero)

    // Both clips should be shifted
    #expect(result.shiftedClips.count == 2)

    // Verify clip1 was shifted
    let clip1Shift = result.shiftedClips.first { $0.clipId == clip1.id }
    #expect(clip1Shift?.originalOffset == .zero)
    #expect(clip1Shift?.newOffset.seconds == 5.0)
}

@Test func rippleInsertAtEmptyTimeline() async throws {
    let timeline = Timeline(name: "Test")

    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let result = timeline.insertClipWithRipple(newClip, at: Timecode(seconds: 5))

    #expect(result.insertedClip.offset.seconds == 5.0)
    #expect(result.shiftedClips.isEmpty)
}

// MARK: - Ripple Lane Option Tests

@Test func ripplePrimaryOnlyDoesNotShiftOtherLanes() async throws {
    let timeline = Timeline(name: "Test")

    // Add clip on lane 0 at position 10
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip1, at: Timecode(seconds: 10), lane: 0)

    // Add clip on lane 1 at position 10
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip2, at: Timecode(seconds: 10), lane: 1)

    // Add clip on lane -1 at position 10
    let clip3 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip3, at: Timecode(seconds: 10), lane: -1)

    // Insert with ripple on primary only
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(
        newClip,
        at: Timecode(seconds: 5),
        rippleLanes: .primaryOnly
    )

    // Only clip1 (lane 0) should be shifted
    #expect(result.shiftedClips.count == 1)
    #expect(result.shiftedClips[0].clipId == clip1.id)
}

@Test func rippleSingleLaneOnlyAffectsThatLane() async throws {
    let timeline = Timeline(name: "Test")

    // Add clips on lanes 0, 1, 2 at position 10
    let clip0 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.insertClip(clip0, at: Timecode(seconds: 10), lane: 0)
    timeline.insertClip(clip1, at: Timecode(seconds: 10), lane: 1)
    timeline.insertClip(clip2, at: Timecode(seconds: 10), lane: 2)

    // Insert with ripple on lane 1 only
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(
        newClip,
        at: Timecode(seconds: 5),
        lane: 1,
        rippleLanes: .single(1)
    )

    // Only clip1 (lane 1) should be shifted
    #expect(result.shiftedClips.count == 1)
    #expect(result.shiftedClips[0].clipId == clip1.id)
}

@Test func rippleRangeAffectsLanesInRange() async throws {
    let timeline = Timeline(name: "Test")

    // Add clips on lanes -1, 0, 1, 2 at position 10
    let clipNeg1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip0 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.insertClip(clipNeg1, at: Timecode(seconds: 10), lane: -1)
    timeline.insertClip(clip0, at: Timecode(seconds: 10), lane: 0)
    timeline.insertClip(clip1, at: Timecode(seconds: 10), lane: 1)
    timeline.insertClip(clip2, at: Timecode(seconds: 10), lane: 2)

    // Insert with ripple on lanes 0...1
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(
        newClip,
        at: Timecode(seconds: 5),
        rippleLanes: .range(0...1)
    )

    // Only clip0 and clip1 should be shifted
    #expect(result.shiftedClips.count == 2)
    let shiftedIds = Set(result.shiftedClips.map { $0.clipId })
    #expect(shiftedIds.contains(clip0.id))
    #expect(shiftedIds.contains(clip1.id))
    #expect(!shiftedIds.contains(clipNeg1.id))
    #expect(!shiftedIds.contains(clip2.id))
}

@Test func rippleAllAffectsAllLanes() async throws {
    let timeline = Timeline(name: "Test")

    // Add clips on lanes -1, 0, 1, 2 at position 10
    let clipNeg1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip0 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.insertClip(clipNeg1, at: Timecode(seconds: 10), lane: -1)
    timeline.insertClip(clip0, at: Timecode(seconds: 10), lane: 0)
    timeline.insertClip(clip1, at: Timecode(seconds: 10), lane: 1)
    timeline.insertClip(clip2, at: Timecode(seconds: 10), lane: 2)

    // Insert with ripple on all lanes
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(
        newClip,
        at: Timecode(seconds: 5),
        rippleLanes: .all
    )

    // All 4 clips should be shifted
    #expect(result.shiftedClips.count == 4)
}

// MARK: - Clip Shift Amount Tests

@Test func clipShiftAmountMatchesInsertDuration() async throws {
    let timeline = Timeline(name: "Test")

    let clip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip, at: Timecode(seconds: 10))

    // Insert 7.5 second clip
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 7.5))
    let result = timeline.insertClipWithRipple(newClip, at: Timecode(seconds: 5))

    #expect(result.shiftedClips.count == 1)
    #expect(abs(result.shiftedClips[0].shiftAmount.seconds - 7.5) < 0.001)
}

// MARK: - Timeline State After Ripple Tests

@Test func timelineDurationUpdatesAfterRipple() async throws {
    let timeline = Timeline(name: "Test")

    let clip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.appendClip(clip)

    #expect(timeline.duration.seconds == 10.0)

    // Insert 5s clip at beginning with ripple
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    _ = timeline.insertClipWithRipple(newClip, at: .zero)

    // Duration should now be 15s (5s new clip + shifted 10s clip)
    #expect(timeline.duration.seconds == 15.0)
}

@Test func clipCountUpdatesAfterRipple() async throws {
    let timeline = Timeline(name: "Test")

    let clip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.appendClip(clip)

    #expect(timeline.clipCount == 1)

    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    _ = timeline.insertClipWithRipple(newClip, at: .zero)

    #expect(timeline.clipCount == 2)
}

// MARK: - Lane Auto-Assignment Tests

@Test func autoLaneAssignmentFindsAvailableLane() async throws {
    let timeline = Timeline(name: "Test")

    // Add clip on lane 0 at 0-10s
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip1, at: .zero, lane: 0)

    // Insert overlapping clip with auto lane
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let placement = try timeline.insertClipAutoLane(clip2, at: Timecode(seconds: 5), preferredLane: 0)

    // Should be placed on lane 1 (first available)
    #expect(placement.lane == 1)
    #expect(placement.offset.seconds == 5.0)
}

@Test func autoLaneAssignmentUsesPreferredWhenAvailable() async throws {
    let timeline = Timeline(name: "Test")

    // Add clip on lane 0 at 0-10s
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip1, at: .zero, lane: 0)

    // Insert non-overlapping clip on lane 0
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let placement = try timeline.insertClipAutoLane(clip2, at: Timecode(seconds: 15), preferredLane: 0)

    // Should use preferred lane 0
    #expect(placement.lane == 0)
}

@Test func autoLaneAssignmentThrowsWhenDisabledAndConflict() async throws {
    let timeline = Timeline(name: "Test")

    // Add clip on lane 0
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip1, at: .zero, lane: 0)

    // Try to insert overlapping clip with auto-assign disabled
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    do {
        _ = try timeline.insertClipAutoLane(clip2, at: Timecode(seconds: 5), preferredLane: 0, autoAssignLane: false)
        Issue.record("Expected TimelineError.noAvailableLane")
    } catch let error as TimelineError {
        if case .noAvailableLane = error {
            // Expected
        } else {
            Issue.record("Wrong error type: \(error)")
        }
    }
}

@Test func findAvailableLaneSearchesOutward() async throws {
    let timeline = Timeline(name: "Test")

    // Fill lanes 0 and 1
    let clip0 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.insertClip(clip0, at: .zero, lane: 0)
    timeline.insertClip(clip1, at: .zero, lane: 1)

    // Find available lane starting from 0
    let availableLane = timeline.findAvailableLane(at: .zero, duration: Timecode(seconds: 10), startingFrom: 0)

    // Should find lane 2 or -1 (prefers positive)
    #expect(availableLane == 2 || availableLane == -1)
}

// MARK: - Timeline Properties Tests

@Test func laneRangeWithMultipleLanes() async throws {
    let timeline = Timeline(name: "Test")

    timeline.insertClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)), at: .zero, lane: -2)
    timeline.insertClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)), at: .zero, lane: 0)
    timeline.insertClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)), at: .zero, lane: 3)

    let range = timeline.laneRange
    #expect(range == -2...3)
}

@Test func laneRangeEmptyTimeline() async throws {
    let timeline = Timeline(name: "Test")
    #expect(timeline.laneRange == nil)
}

@Test func isEmptyProperty() async throws {
    let timeline = Timeline(name: "Test")
    #expect(timeline.isEmpty == true)

    timeline.appendClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)))
    #expect(timeline.isEmpty == false)
}

@Test func clipCountProperty() async throws {
    let timeline = Timeline(name: "Test")
    #expect(timeline.clipCount == 0)

    timeline.appendClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)))
    #expect(timeline.clipCount == 1)

    timeline.appendClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)))
    #expect(timeline.clipCount == 2)
}

@Test func startTimeProperty() async throws {
    let timeline = Timeline(name: "Test")
    #expect(timeline.startTime == .zero)

    // Start time is always zero for now
    timeline.appendClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)))
    #expect(timeline.startTime == .zero)
}

// MARK: - Placement Query Tests

@Test func allPlacementsReturnsAllClips() async throws {
    let timeline = Timeline(name: "Test")

    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let clip3 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))

    timeline.appendClip(clip1)
    timeline.appendClip(clip2)
    timeline.insertClip(clip3, at: .zero, lane: 1)

    let placements = timeline.allPlacements()
    #expect(placements.count == 3)
}

@Test func placementsOnLaneFiltersCorrectly() async throws {
    let timeline = Timeline(name: "Test")

    timeline.insertClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)), at: .zero, lane: 0)
    timeline.insertClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)), at: .zero, lane: 0)
    timeline.insertClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)), at: .zero, lane: 1)

    let lane0Placements = timeline.placements(onLane: 0)
    let lane1Placements = timeline.placements(onLane: 1)

    #expect(lane0Placements.count == 2)
    #expect(lane1Placements.count == 1)
}

@Test func placementsInRangeFiltersCorrectly() async throws {
    let timeline = Timeline(name: "Test")

    // Clips at 0-5, 5-10, 10-15
    timeline.appendClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)))
    timeline.appendClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)))
    timeline.appendClip(TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5)))

    // Query range 3-12 should find clips 1 and 2
    let placements = timeline.placements(inRange: Timecode(seconds: 3), end: Timecode(seconds: 12))

    #expect(placements.count == 3) // All three overlap with 3-12
}
