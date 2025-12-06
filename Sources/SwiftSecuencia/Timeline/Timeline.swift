//
//  Timeline.swift
//  SwiftSecuencia
//
//  SwiftData model for persisting timeline data.
//

import Foundation
import SwiftData

/// A persisted timeline that holds clips for FCPXML export.
///
/// Timeline is a SwiftData model that stores the structure of a Final Cut Pro
/// timeline, including clips, their placements, and format settings. Clips can
/// be queried and the entire timeline can be exported to FCPXML.
///
/// ## Storage Design
///
/// Timelines are stored in SwiftData and maintain relationships to:
/// - `TimelineClip` records for each clip on the timeline
/// - TypedDataStorage from SwiftCompartido (via clip references)
///
/// ## Usage
///
/// ```swift
/// // Create a timeline
/// let timeline = Timeline(name: "Scene 1 Assembly")
///
/// // Configure format
/// timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
/// timeline.audioLayout = .stereo
///
/// // Insert in context
/// modelContext.insert(timeline)
///
/// // Add clips (see TimelineClip)
/// let clip = TimelineClip(...)
/// timeline.addClip(clip)
/// ```
@Model
public final class Timeline {

    // MARK: - Identity

    /// Unique identifier for this timeline.
    @Attribute(.unique) public var id: UUID

    /// Human-readable name for this timeline.
    public var name: String

    // MARK: - Format Settings

    /// Video format configuration (stored as JSON).
    ///
    /// Stored as codable data since VideoFormat is a value type.
    private var videoFormatData: Data?

    /// Audio layout for the timeline.
    public var audioLayoutRawValue: String

    /// Audio sample rate.
    public var audioRateRawValue: Int

    // MARK: - Computed Format Properties

    /// The video format for this timeline.
    public var videoFormat: VideoFormat? {
        get {
            guard let data = videoFormatData else { return nil }
            return try? JSONDecoder().decode(VideoFormat.self, from: data)
        }
        set {
            videoFormatData = try? JSONEncoder().encode(newValue)
        }
    }

    /// The audio layout for this timeline.
    public var audioLayout: AudioLayout {
        get { AudioLayout(rawValue: audioLayoutRawValue) ?? .stereo }
        set { audioLayoutRawValue = newValue.rawValue }
    }

    /// The audio sample rate for this timeline.
    public var audioRate: AudioRate {
        get { AudioRate(rawValue: audioRateRawValue) ?? .rate48kHz }
        set { audioRateRawValue = newValue.rawValue }
    }

    // MARK: - Clips Relationship

    /// All clips on this timeline.
    ///
    /// Clips are ordered by their placement (offset) and lane.
    /// Use `addClip()`, `insertClip()`, and `removeClip()` for management.
    @Relationship(deleteRule: .cascade, inverse: \TimelineClip.timeline)
    public var clips: [TimelineClip]

    // MARK: - Timeline Properties

    /// The total duration of the timeline.
    ///
    /// Calculated as the maximum end time of all clips on lane 0 (primary storyline).
    public var duration: Timecode {
        // Find the maximum end time on the primary storyline (lane 0)
        clips
            .filter { $0.lane == 0 }
            .map { $0.offset + $0.duration }
            .max() ?? .zero
    }

    /// The end timecode of the last clip on the timeline.
    public var endTime: Timecode {
        duration
    }

    /// The start timecode of the timeline (always zero for now).
    public var startTime: Timecode {
        .zero
    }

    /// The number of clips on the timeline.
    public var clipCount: Int {
        clips.count
    }

    /// Whether the timeline has no clips.
    public var isEmpty: Bool {
        clips.isEmpty
    }

    /// The range of lanes used by clips on this timeline.
    ///
    /// Returns nil if the timeline is empty.
    public var laneRange: ClosedRange<Int>? {
        guard !clips.isEmpty else { return nil }

        var minLane = Int.max
        var maxLane = Int.min

        for clip in clips {
            minLane = min(minLane, clip.lane)
            maxLane = max(maxLane, clip.lane)
        }

        return minLane...maxLane
    }

    // MARK: - Timestamps

    /// When this timeline was created.
    public var createdAt: Date

    /// When this timeline was last modified.
    public var modifiedAt: Date

    // MARK: - Initialization

    /// Creates a new timeline.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided).
    ///   - name: Human-readable name for the timeline.
    ///   - videoFormat: Video format configuration (optional).
    ///   - audioLayout: Audio channel layout (default: stereo).
    ///   - audioRate: Audio sample rate (default: 48kHz).
    public init(
        id: UUID = UUID(),
        name: String,
        videoFormat: VideoFormat? = nil,
        audioLayout: AudioLayout = .stereo,
        audioRate: AudioRate = .rate48kHz
    ) {
        self.id = id
        self.name = name
        self.videoFormatData = try? JSONEncoder().encode(videoFormat)
        self.audioLayoutRawValue = audioLayout.rawValue
        self.audioRateRawValue = audioRate.rawValue
        self.clips = []
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Clip Management

    /// Appends a clip to the end of the primary storyline (lane 0).
    ///
    /// The clip's offset is automatically set to the current end of the timeline.
    ///
    /// - Parameter clip: The clip to append.
    /// - Returns: The placement information for the added clip.
    @discardableResult
    public func appendClip(_ clip: TimelineClip) -> ClipPlacement {
        // Set offset to current end time
        clip.offset = endTime
        clip.lane = 0  // Primary storyline
        clip.timeline = self
        clips.append(clip)
        touch()

        return ClipPlacement(
            clipId: clip.id,
            offset: clip.offset,
            duration: clip.duration,
            lane: clip.lane
        )
    }

    /// Inserts a clip at a specific timecode.
    ///
    /// - Parameters:
    ///   - clip: The clip to insert.
    ///   - offset: The timecode position for insertion.
    ///   - lane: The lane for the clip (default: 0 for primary storyline).
    /// - Returns: The placement information for the inserted clip.
    @discardableResult
    public func insertClip(_ clip: TimelineClip, at offset: Timecode, lane: Int = 0) -> ClipPlacement {
        clip.offset = offset
        clip.lane = lane
        clip.timeline = self
        clips.append(clip)
        touch()

        return ClipPlacement(
            clipId: clip.id,
            offset: clip.offset,
            duration: clip.duration,
            lane: clip.lane
        )
    }

    /// Inserts a clip at a specific timecode, automatically assigning a lane if needed.
    ///
    /// If `autoAssignLane` is true and the clip would overlap with existing clips
    /// on the target lane, a new lane will be automatically assigned.
    ///
    /// - Parameters:
    ///   - clip: The clip to insert.
    ///   - offset: The timecode position for insertion.
    ///   - preferredLane: The preferred lane (default: 0).
    ///   - autoAssignLane: Whether to auto-assign a lane on conflict (default: true).
    /// - Returns: The placement information for the inserted clip.
    /// - Throws: `TimelineError.noAvailableLane` if auto-assign is disabled and there's a conflict.
    @discardableResult
    public func insertClipAutoLane(
        _ clip: TimelineClip,
        at offset: Timecode,
        preferredLane: Int = 0,
        autoAssignLane: Bool = true
    ) throws -> ClipPlacement {
        let clipEnd = offset + clip.duration

        // Check for conflicts on the preferred lane
        let hasConflict = clips.contains { existingClip in
            guard existingClip.lane == preferredLane else { return false }
            let existingEnd = existingClip.offset + existingClip.duration
            // Check for overlap
            return offset < existingEnd && clipEnd > existingClip.offset
        }

        if !hasConflict {
            return insertClip(clip, at: offset, lane: preferredLane)
        }

        guard autoAssignLane else {
            throw TimelineError.noAvailableLane(at: offset, duration: clip.duration)
        }

        // Find an available lane
        let assignedLane = findAvailableLane(at: offset, duration: clip.duration, startingFrom: preferredLane)
        return insertClip(clip, at: offset, lane: assignedLane)
    }

    /// Finds an available lane for a clip at the given position.
    ///
    /// Searches outward from the starting lane (positive lanes first, then negative).
    ///
    /// - Parameters:
    ///   - offset: The clip's start position.
    ///   - duration: The clip's duration.
    ///   - startingFrom: The lane to start searching from.
    /// - Returns: An available lane number.
    public func findAvailableLane(at offset: Timecode, duration: Timecode, startingFrom: Int = 0) -> Int {
        let clipEnd = offset + duration

        // Check if a lane is available
        func isLaneAvailable(_ lane: Int) -> Bool {
            !clips.contains { existingClip in
                guard existingClip.lane == lane else { return false }
                let existingEnd = existingClip.offset + existingClip.duration
                return offset < existingEnd && clipEnd > existingClip.offset
            }
        }

        // Try the starting lane first
        if isLaneAvailable(startingFrom) {
            return startingFrom
        }

        // Search outward from the starting lane
        var distance = 1
        while distance < 1000 { // Reasonable upper limit
            // Try positive lane
            let positiveLane = startingFrom + distance
            if isLaneAvailable(positiveLane) {
                return positiveLane
            }

            // Try negative lane
            let negativeLane = startingFrom - distance
            if isLaneAvailable(negativeLane) {
                return negativeLane
            }

            distance += 1
        }

        // Fallback (should never reach here)
        return startingFrom + 1000
    }

    /// Inserts a clip with ripple effect, shifting subsequent clips forward.
    ///
    /// - Parameters:
    ///   - clip: The clip to insert.
    ///   - offset: The timecode position for insertion.
    ///   - lane: The lane for the clip (default: 0).
    ///   - rippleLanes: Which lanes to ripple (default: primary only).
    /// - Returns: The result containing placement info and shifted clips.
    @discardableResult
    public func insertClipWithRipple(
        _ clip: TimelineClip,
        at offset: Timecode,
        lane: Int = 0,
        rippleLanes: RippleLaneOption = .primaryOnly
    ) -> RippleInsertResult {
        let insertDuration = clip.duration
        var shiftedClips: [ClipShift] = []

        // Find clips that need to be shifted
        let clipsToShift = clips.filter { existingClip in
            // Must start at or after the insertion point
            guard existingClip.offset >= offset else { return false }

            // Check lane filtering
            switch rippleLanes {
            case .all:
                return true
            case .single(let targetLane):
                return existingClip.lane == targetLane
            case .range(let laneRange):
                return laneRange.contains(existingClip.lane)
            case .primaryOnly:
                return existingClip.lane == 0
            }
        }

        // Shift the clips
        for existingClip in clipsToShift {
            let originalOffset = existingClip.offset
            existingClip.offset = existingClip.offset + insertDuration

            shiftedClips.append(ClipShift(
                clipId: existingClip.id,
                originalOffset: originalOffset,
                newOffset: existingClip.offset
            ))
        }

        // Insert the new clip
        clip.offset = offset
        clip.lane = lane
        clip.timeline = self
        clips.append(clip)
        touch()

        let placement = ClipPlacement(
            clipId: clip.id,
            offset: clip.offset,
            duration: clip.duration,
            lane: clip.lane
        )

        return RippleInsertResult(
            insertedClip: placement,
            shiftedClips: shiftedClips
        )
    }

    /// Removes a clip from the timeline.
    ///
    /// - Parameter clipId: The ID of the clip to remove.
    /// - Returns: True if the clip was found and removed.
    @discardableResult
    public func removeClip(id clipId: UUID) -> Bool {
        if let index = clips.firstIndex(where: { $0.id == clipId }) {
            clips.remove(at: index)
            touch()
            return true
        }
        return false
    }

    // MARK: - Clip Queries

    /// Returns the placement information for a specific clip.
    ///
    /// - Parameter clipId: The ID of the clip to find.
    /// - Returns: The clip placement, or nil if not found.
    public func getClipPlacement(id clipId: UUID) -> ClipPlacement? {
        guard let clip = clips.first(where: { $0.id == clipId }) else {
            return nil
        }
        return ClipPlacement(
            clipId: clip.id,
            offset: clip.offset,
            duration: clip.duration,
            lane: clip.lane
        )
    }

    /// Returns all clips on a specific lane.
    ///
    /// - Parameter lane: The lane number to filter by.
    /// - Returns: Array of clips on the specified lane, sorted by offset.
    public func clips(onLane lane: Int) -> [TimelineClip] {
        clips
            .filter { $0.lane == lane }
            .sorted { $0.offset < $1.offset }
    }

    /// Returns all clips that overlap with a time range.
    ///
    /// - Parameters:
    ///   - start: Start of the time range.
    ///   - end: End of the time range.
    /// - Returns: Array of clips that overlap with the range.
    public func clips(inRange start: Timecode, end: Timecode) -> [TimelineClip] {
        clips.filter { clip in
            let clipEnd = clip.offset + clip.duration
            // Overlap: clip starts before range ends AND clip ends after range starts
            return clip.offset < end && clipEnd > start
        }
    }

    /// Returns all clips sorted by their position on the timeline.
    public var sortedClips: [TimelineClip] {
        clips.sorted { lhs, rhs in
            if lhs.offset != rhs.offset {
                return lhs.offset < rhs.offset
            }
            return lhs.lane < rhs.lane
        }
    }

    /// Returns placement information for all clips.
    ///
    /// - Returns: Array of clip placements, sorted by offset then lane.
    public func allPlacements() -> [ClipPlacement] {
        sortedClips.map { clip in
            ClipPlacement(
                clipId: clip.id,
                offset: clip.offset,
                duration: clip.duration,
                lane: clip.lane
            )
        }
    }

    /// Returns placements for clips on a specific lane.
    ///
    /// - Parameter lane: The lane to filter by.
    /// - Returns: Array of clip placements on the specified lane, sorted by offset.
    public func placements(onLane lane: Int) -> [ClipPlacement] {
        clips(onLane: lane).map { clip in
            ClipPlacement(
                clipId: clip.id,
                offset: clip.offset,
                duration: clip.duration,
                lane: clip.lane
            )
        }
    }

    /// Returns placements for clips overlapping a time range.
    ///
    /// - Parameters:
    ///   - start: Start of the time range.
    ///   - end: End of the time range.
    /// - Returns: Array of clip placements overlapping the range.
    public func placements(inRange start: Timecode, end: Timecode) -> [ClipPlacement] {
        clips(inRange: start, end: end).map { clip in
            ClipPlacement(
                clipId: clip.id,
                offset: clip.offset,
                duration: clip.duration,
                lane: clip.lane
            )
        }
    }

    // MARK: - Helpers

    /// Updates the modification timestamp.
    public func touch() {
        modifiedAt = Date()
    }
}

// MARK: - Supporting Types

/// Information about a clip's placement on the timeline.
public struct ClipPlacement: Sendable, Equatable, Codable {
    /// The clip's unique identifier.
    public let clipId: UUID

    /// The clip's start position on the timeline.
    public let offset: Timecode

    /// The clip's duration.
    public let duration: Timecode

    /// The lane the clip is on (0 = primary storyline).
    public let lane: Int

    /// The clip's end position on the timeline.
    public var endTime: Timecode {
        offset + duration
    }
}

/// Options for which lanes to affect during a ripple insert.
public enum RippleLaneOption: Sendable, Equatable {
    /// Ripple all lanes.
    case all

    /// Ripple only a single lane.
    case single(Int)

    /// Ripple a range of lanes.
    case range(ClosedRange<Int>)

    /// Ripple only the primary storyline (lane 0).
    case primaryOnly
}

/// Result of a ripple insert operation.
public struct RippleInsertResult: Sendable, Equatable {
    /// The placement of the newly inserted clip.
    public let insertedClip: ClipPlacement

    /// Information about clips that were shifted.
    public let shiftedClips: [ClipShift]
}

/// Information about a clip that was shifted during ripple.
public struct ClipShift: Sendable, Equatable {
    /// The shifted clip's identifier.
    public let clipId: UUID

    /// The clip's original offset before ripple.
    public let originalOffset: Timecode

    /// The clip's new offset after ripple.
    public let newOffset: Timecode

    /// The amount the clip was shifted.
    public var shiftAmount: Timecode {
        newOffset - originalOffset
    }
}
