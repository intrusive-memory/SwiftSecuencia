import Testing
import Foundation
import SwiftData
@testable import SwiftSecuencia

// MARK: - Timeline Initialization Tests

@Test func timelineInit() async throws {
    let timeline = Timeline(name: "Test Timeline")
    #expect(timeline.name == "Test Timeline")
    #expect(timeline.clips.isEmpty)
    #expect(timeline.audioLayout == .stereo)
    #expect(timeline.audioRate == .rate48kHz)
}

@Test func timelineInitWithFormat() async throws {
    let format = VideoFormat.hd1080p(frameRate: .fps24)
    let timeline = Timeline(
        name: "Formatted Timeline",
        videoFormat: format,
        audioLayout: .surround,
        audioRate: .rate96kHz
    )
    #expect(timeline.videoFormat == format)
    #expect(timeline.audioLayout == .surround)
    #expect(timeline.audioRate == .rate96kHz)
}

// MARK: - Clip Placement Tests

@Test func timelineAppendClip() async throws {
    let timeline = Timeline(name: "Test")
    let clipId = UUID()
    let clip = TimelineClip(
        id: clipId,
        assetStorageId: UUID(),
        duration: Timecode(seconds: 10)
    )

    let placement = timeline.appendClip(clip)

    #expect(placement.offset == .zero)
    #expect(placement.duration == Timecode(seconds: 10))
    #expect(placement.lane == 0)
    #expect(timeline.clips.count == 1)
}

@Test func timelineAppendMultipleClips() async throws {
    let timeline = Timeline(name: "Test")

    let clip1 = TimelineClip(
        assetStorageId: UUID(),
        duration: Timecode(seconds: 10)
    )
    let clip2 = TimelineClip(
        assetStorageId: UUID(),
        duration: Timecode(seconds: 5)
    )

    let placement1 = timeline.appendClip(clip1)
    let placement2 = timeline.appendClip(clip2)

    #expect(placement1.offset == .zero)
    #expect(placement2.offset.seconds == 10.0)  // After first clip
    #expect(timeline.duration.seconds == 15.0)
}

@Test func timelineInsertClipAtOffset() async throws {
    let timeline = Timeline(name: "Test")

    let clip = TimelineClip(
        assetStorageId: UUID(),
        duration: Timecode(seconds: 5)
    )

    let placement = timeline.insertClip(clip, at: Timecode(seconds: 10))

    #expect(placement.offset.seconds == 10.0)
    #expect(placement.lane == 0)
}

@Test func timelineInsertClipOnLane() async throws {
    let timeline = Timeline(name: "Test")

    let clip = TimelineClip(
        assetStorageId: UUID(),
        duration: Timecode(seconds: 5)
    )

    let placement = timeline.insertClip(clip, at: Timecode(seconds: 0), lane: 1)

    #expect(placement.lane == 1)
}

// MARK: - Ripple Insert Tests

@Test func timelineRippleInsertShiftsClips() async throws {
    let timeline = Timeline(name: "Test")

    // Add two clips sequentially
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.appendClip(clip1)
    timeline.appendClip(clip2)

    // Insert a 5-second clip at position 5 with ripple
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(newClip, at: Timecode(seconds: 5))

    // New clip at position 5
    #expect(result.insertedClip.offset.seconds == 5.0)

    // Clip2 was at 10s, should now be at 15s (shifted by 5s)
    #expect(result.shiftedClips.count == 1)
    #expect(result.shiftedClips[0].originalOffset.seconds == 10.0)
    #expect(result.shiftedClips[0].newOffset.seconds == 15.0)

    // Clip1 starts at 0, before insert point, should NOT be shifted
    let clip1Placement = timeline.getClipPlacement(id: clip1.id)
    #expect(clip1Placement?.offset == .zero)
}

@Test func timelineRippleInsertPrimaryOnly() async throws {
    let timeline = Timeline(name: "Test")

    // Add clip on lane 0
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.appendClip(clip1)

    // Add clip on lane 1 at same position
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip2, at: Timecode(seconds: 10), lane: 1)

    // Insert with ripple on primary only
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(
        newClip,
        at: Timecode(seconds: 5),
        rippleLanes: .primaryOnly
    )

    // Lane 1 clip should NOT be shifted since we used .primaryOnly
    #expect(result.shiftedClips.isEmpty)
}

@Test func timelineRippleInsertAllLanes() async throws {
    let timeline = Timeline(name: "Test")

    // Add clip on lane 0 at position 10
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip1, at: Timecode(seconds: 10), lane: 0)

    // Add clip on lane 1 at position 10
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.insertClip(clip2, at: Timecode(seconds: 10), lane: 1)

    // Insert with ripple on all lanes at position 5
    let newClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let result = timeline.insertClipWithRipple(
        newClip,
        at: Timecode(seconds: 5),
        rippleLanes: .all
    )

    // Both clips at/after position 5 should be shifted (both start at 10)
    #expect(result.shiftedClips.count == 2)
}

// MARK: - Clip Query Tests

@Test func timelineGetClipPlacement() async throws {
    let timeline = Timeline(name: "Test")
    let clipId = UUID()
    let clip = TimelineClip(
        id: clipId,
        assetStorageId: UUID(),
        duration: Timecode(seconds: 10)
    )
    timeline.appendClip(clip)

    let placement = timeline.getClipPlacement(id: clipId)

    #expect(placement != nil)
    #expect(placement?.clipId == clipId)
    #expect(placement?.duration.seconds == 10.0)
}

@Test func timelineGetClipPlacementNotFound() async throws {
    let timeline = Timeline(name: "Test")
    let placement = timeline.getClipPlacement(id: UUID())
    #expect(placement == nil)
}

@Test func timelineClipsOnLane() async throws {
    let timeline = Timeline(name: "Test")

    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.appendClip(clip1)  // Lane 0
    timeline.insertClip(clip2, at: .zero, lane: 1)

    let lane0Clips = timeline.clips(onLane: 0)
    let lane1Clips = timeline.clips(onLane: 1)

    #expect(lane0Clips.count == 1)
    #expect(lane1Clips.count == 1)
    #expect(lane0Clips[0].id == clip1.id)
    #expect(lane1Clips[0].id == clip2.id)
}

@Test func timelineClipsInRange() async throws {
    let timeline = Timeline(name: "Test")

    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip3 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.appendClip(clip1)  // 0-10s
    timeline.appendClip(clip2)  // 10-20s
    timeline.appendClip(clip3)  // 20-30s

    // Query clips that overlap with 5-15s
    let rangeClips = timeline.clips(
        inRange: Timecode(seconds: 5),
        end: Timecode(seconds: 15)
    )

    #expect(rangeClips.count == 2)  // clip1 and clip2 overlap
}

@Test func timelineSortedClips() async throws {
    let timeline = Timeline(name: "Test")

    // Add clips out of order
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))

    timeline.insertClip(clip2, at: Timecode(seconds: 10))
    timeline.insertClip(clip1, at: Timecode(seconds: 0))

    let sorted = timeline.sortedClips

    #expect(sorted[0].id == clip1.id)
    #expect(sorted[1].id == clip2.id)
}

// MARK: - Remove Clip Tests

@Test func timelineRemoveClip() async throws {
    let timeline = Timeline(name: "Test")
    let clipId = UUID()
    let clip = TimelineClip(
        id: clipId,
        assetStorageId: UUID(),
        duration: Timecode(seconds: 10)
    )
    timeline.appendClip(clip)

    let removed = timeline.removeClip(id: clipId)

    #expect(removed == true)
    #expect(timeline.clips.isEmpty)
}

@Test func timelineRemoveClipNotFound() async throws {
    let timeline = Timeline(name: "Test")
    let removed = timeline.removeClip(id: UUID())
    #expect(removed == false)
}

// MARK: - Duration Tests

@Test func timelineDurationEmpty() async throws {
    let timeline = Timeline(name: "Test")
    #expect(timeline.duration == .zero)
}

@Test func timelineDurationWithClips() async throws {
    let timeline = Timeline(name: "Test")

    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))

    timeline.appendClip(clip1)
    timeline.appendClip(clip2)

    #expect(timeline.duration.seconds == 15.0)
}

@Test func timelineDurationOnlyPrimaryStoryline() async throws {
    let timeline = Timeline(name: "Test")

    // Primary storyline: 10 seconds
    let clip1 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))
    timeline.appendClip(clip1)

    // Lane 1: extends beyond primary (but shouldn't affect duration calculation)
    let clip2 = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 20))
    timeline.insertClip(clip2, at: .zero, lane: 1)

    // Duration is based on lane 0 only
    #expect(timeline.duration.seconds == 10.0)
}

// MARK: - TimelineClip Tests

@Test func timelineClipInit() async throws {
    let assetId = UUID()
    let clip = TimelineClip(
        assetStorageId: assetId,
        offset: Timecode(seconds: 5),
        duration: Timecode(seconds: 10),
        sourceStart: Timecode(seconds: 2),
        lane: 1
    )

    #expect(clip.assetStorageId == assetId)
    #expect(clip.offset.seconds == 5.0)
    #expect(clip.duration.seconds == 10.0)
    #expect(clip.sourceStart.seconds == 2.0)
    #expect(clip.lane == 1)
}

@Test func timelineClipEndTime() async throws {
    let clip = TimelineClip(
        assetStorageId: UUID(),
        offset: Timecode(seconds: 5),
        duration: Timecode(seconds: 10)
    )

    #expect(clip.endTime.seconds == 15.0)
}

@Test func timelineClipPlacement() async throws {
    let clipId = UUID()
    let clip = TimelineClip(
        id: clipId,
        assetStorageId: UUID(),
        offset: Timecode(seconds: 5),
        duration: Timecode(seconds: 10),
        lane: 1
    )

    let placement = clip.placement

    #expect(placement.clipId == clipId)
    #expect(placement.offset.seconds == 5.0)
    #expect(placement.duration.seconds == 10.0)
    #expect(placement.lane == 1)
}

@Test func timelineClipExpectedContentType() async throws {
    let videoClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    videoClip.lane = 0
    #expect(videoClip.expectedContentType == "video")

    let bRollClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    bRollClip.lane = 1
    #expect(bRollClip.expectedContentType == "video")

    let audioClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 5))
    audioClip.lane = -1
    #expect(audioClip.expectedContentType == "audio")
}

// MARK: - ClipPlacement Tests

@Test func clipPlacementEndTime() async throws {
    let placement = ClipPlacement(
        clipId: UUID(),
        offset: Timecode(seconds: 5),
        duration: Timecode(seconds: 10),
        lane: 0
    )

    #expect(placement.endTime.seconds == 15.0)
}

// MARK: - ClipShift Tests

@Test func clipShiftAmount() async throws {
    let shift = ClipShift(
        clipId: UUID(),
        originalOffset: Timecode(seconds: 10),
        newOffset: Timecode(seconds: 15)
    )

    #expect(shift.shiftAmount.seconds == 5.0)
}
