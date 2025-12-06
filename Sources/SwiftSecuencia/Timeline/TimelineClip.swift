//
//  TimelineClip.swift
//  SwiftSecuencia
//
//  SwiftData model for persisting timeline clip data.
//

import Foundation
import SwiftData
import SwiftCompartido

/// A persisted clip on a timeline, linked to TypedDataStorage content.
///
/// TimelineClip is a SwiftData model that represents a single clip placed
/// on a timeline. Each clip references a TypedDataStorage record from
/// SwiftCompartido that contains the actual media content.
///
/// ## Relationship to TypedDataStorage
///
/// Each TimelineClip has a 1:1 relationship with a TypedDataStorage record.
/// The TypedDataStorage stores the actual media (audio, video, image) while
/// TimelineClip stores the timeline placement (offset, duration, lane).
///
/// ## Usage
///
/// ```swift
/// // Create a clip from TypedDataStorage
/// let clip = TimelineClip(
///     assetStorage: audioRecord,
///     duration: Timecode(seconds: 30)
/// )
///
/// // Add to timeline (offset is set automatically)
/// timeline.appendClip(clip)
///
/// // Or insert at specific position
/// timeline.insertClip(clip, at: Timecode(seconds: 10), lane: 1)
/// ```
@Model
public final class TimelineClip {

    // MARK: - Identity

    /// Unique identifier for this clip.
    @Attribute(.unique) public var id: UUID

    /// Optional human-readable name for the clip.
    public var name: String?

    // MARK: - Timeline Placement

    /// The start position of this clip on the timeline.
    ///
    /// Stored as rational time components for precision.
    public var offsetValue: Int64

    /// The timescale for the offset.
    public var offsetTimescale: Int32

    /// The duration of this clip.
    ///
    /// Stored as rational time components for precision.
    public var durationValue: Int64

    /// The timescale for the duration.
    public var durationTimescale: Int32

    /// The source start time within the asset.
    ///
    /// Used when the clip starts at a point other than the beginning of the source media.
    public var sourceStartValue: Int64

    /// The timescale for the source start.
    public var sourceStartTimescale: Int32

    /// The lane this clip is placed on.
    ///
    /// - Lane 0: Primary storyline (main video track)
    /// - Positive lanes: Above the primary storyline (B-roll, titles, etc.)
    /// - Negative lanes: Below the primary storyline (additional audio)
    public var lane: Int

    // MARK: - Computed Timecode Properties

    /// The clip's offset as a Timecode value.
    public var offset: Timecode {
        get { Timecode(value: offsetValue, timescale: offsetTimescale) }
        set {
            offsetValue = newValue.value
            offsetTimescale = newValue.timescale
        }
    }

    /// The clip's duration as a Timecode value.
    public var duration: Timecode {
        get { Timecode(value: durationValue, timescale: durationTimescale) }
        set {
            durationValue = newValue.value
            durationTimescale = newValue.timescale
        }
    }

    /// The source start time as a Timecode value.
    public var sourceStart: Timecode {
        get { Timecode(value: sourceStartValue, timescale: sourceStartTimescale) }
        set {
            sourceStartValue = newValue.value
            sourceStartTimescale = newValue.timescale
        }
    }

    /// The clip's end time on the timeline.
    public var endTime: Timecode {
        offset + duration
    }

    // MARK: - Asset Reference

    /// The TypedDataStorage ID this clip references.
    ///
    /// This links to the actual media content in SwiftCompartido.
    public var assetStorageId: UUID

    /// The owning timeline.
    public var timeline: Timeline?

    // MARK: - Audio Properties

    /// Volume adjustment in decibels (0.0 = unity, -∞ = silent).
    public var volumeDb: Double?

    /// Whether this clip's audio is muted.
    public var isMuted: Bool

    // MARK: - Video Properties

    /// Opacity (0.0 to 1.0).
    public var opacity: Double

    /// Whether this clip's video is disabled (audio only).
    public var isVideoDisabled: Bool

    // MARK: - Metadata

    /// Markers attached to this clip.
    public var markers: [Marker]

    /// Chapter markers attached to this clip.
    public var chapterMarkers: [ChapterMarker]

    /// Keywords tagging this clip.
    public var keywords: [Keyword]

    /// Ratings for this clip.
    public var ratings: [Rating]

    /// Custom metadata key-value pairs (stored as JSON Data).
    private var metadataJSON: Data?

    /// Custom metadata key-value pairs.
    public var metadata: Metadata? {
        get {
            guard let data = metadataJSON else { return nil }
            return try? JSONDecoder().decode(Metadata.self, from: data)
        }
        set {
            metadataJSON = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Timestamps

    /// When this clip was created.
    public var createdAt: Date

    /// When this clip was last modified.
    public var modifiedAt: Date

    // MARK: - Initialization

    /// Creates a new timeline clip.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided).
    ///   - name: Optional human-readable name.
    ///   - assetStorageId: The TypedDataStorage ID containing the media.
    ///   - offset: Start position on timeline (default: zero).
    ///   - duration: Duration of the clip.
    ///   - sourceStart: Start time within the source asset (default: zero).
    ///   - lane: Lane number (default: 0 for primary storyline).
    public init(
        id: UUID = UUID(),
        name: String? = nil,
        assetStorageId: UUID,
        offset: Timecode = .zero,
        duration: Timecode,
        sourceStart: Timecode = .zero,
        lane: Int = 0
    ) {
        self.id = id
        self.name = name
        self.assetStorageId = assetStorageId
        self.offsetValue = offset.value
        self.offsetTimescale = offset.timescale
        self.durationValue = duration.value
        self.durationTimescale = duration.timescale
        self.sourceStartValue = sourceStart.value
        self.sourceStartTimescale = sourceStart.timescale
        self.lane = lane
        self.volumeDb = nil
        self.isMuted = false
        self.opacity = 1.0
        self.isVideoDisabled = false
        self.markers = []
        self.chapterMarkers = []
        self.keywords = []
        self.ratings = []
        self.metadataJSON = nil
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Creates a timeline clip from a TypedDataStorage record.
    ///
    /// The clip name defaults to the asset's prompt if not specified.
    /// Duration is inferred from the asset if available (for audio/video).
    ///
    /// - Parameters:
    ///   - assetStorage: The TypedDataStorage containing the media.
    ///   - name: Optional name override.
    ///   - duration: Clip duration. If nil, inferred from asset's durationSeconds.
    ///   - sourceStart: Start time within source (default: zero).
    ///   - lane: Lane number (default: 0).
    public convenience init(
        assetStorage: TypedDataStorage,
        name: String? = nil,
        duration: Timecode? = nil,
        sourceStart: Timecode = .zero,
        lane: Int = 0
    ) {
        let clipDuration: Timecode
        if let duration = duration {
            clipDuration = duration
        } else if let seconds = assetStorage.durationSeconds {
            clipDuration = Timecode(seconds: seconds)
        } else {
            // Default to 1 second if no duration available
            clipDuration = Timecode(seconds: 1.0)
        }

        self.init(
            name: name ?? assetStorage.prompt,
            assetStorageId: assetStorage.id,
            duration: clipDuration,
            sourceStart: sourceStart,
            lane: lane
        )
    }

    // MARK: - Helpers

    /// Updates the modification timestamp.
    public func touch() {
        modifiedAt = Date()
    }

    /// Returns placement information for this clip.
    public var placement: ClipPlacement {
        ClipPlacement(
            clipId: id,
            offset: offset,
            duration: duration,
            lane: lane
        )
    }
}

// MARK: - Content Type Helpers

extension TimelineClip {
    /// Returns the expected content type based on lane.
    ///
    /// By convention:
    /// - Lane 0: Primary video
    /// - Positive lanes: B-roll, titles, effects
    /// - Negative lanes: Audio tracks
    public var expectedContentType: String {
        if lane < 0 {
            return "audio"
        } else {
            return "video"
        }
    }
}

// MARK: - Asset Validation

extension TimelineClip {
    /// Validates that the referenced asset exists and is compatible with this clip.
    ///
    /// - Parameter modelContext: The model context to fetch the asset from.
    /// - Returns: The validated TypedDataStorage record.
    /// - Throws: `TimelineError` if validation fails.
    public func validateAsset(in modelContext: SwiftData.ModelContext) throws -> TypedDataStorage {
        // Fetch the asset
        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { $0.id == assetStorageId }
        )

        guard let asset = try modelContext.fetch(descriptor).first else {
            throw TimelineError.invalidAssetReference(storageId: assetStorageId, reason: "Asset not found")
        }

        // Validate MIME type
        let mimeType = asset.mimeType

        // Check that MIME type is compatible with lane
        if lane < 0 {
            // Negative lanes should be audio
            guard mimeType.hasPrefix("audio/") else {
                throw TimelineError.invalidFormat(
                    reason: "Clip on lane \(lane) expects audio/* but asset has MIME type '\(mimeType)'"
                )
            }
        } else {
            // Non-negative lanes should be video, image, or audio
            guard mimeType.hasPrefix("video/") ||
                  mimeType.hasPrefix("image/") ||
                  mimeType.hasPrefix("audio/") else {
                throw TimelineError.invalidFormat(
                    reason: "Clip on lane \(lane) expects video/*, image/*, or audio/* but asset has MIME type '\(mimeType)'"
                )
            }
        }

        return asset
    }

    /// Returns the asset if it exists, or nil if not found.
    ///
    /// - Parameter modelContext: The model context to fetch the asset from.
    /// - Returns: The TypedDataStorage record, or nil if not found.
    public func fetchAsset(in modelContext: SwiftData.ModelContext) -> TypedDataStorage? {
        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { $0.id == assetStorageId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// Checks if the referenced asset is audio content.
    ///
    /// - Parameter modelContext: The model context to fetch the asset from.
    /// - Returns: True if the asset has an audio/* MIME type.
    public func isAudioClip(in modelContext: SwiftData.ModelContext) -> Bool {
        guard let asset = fetchAsset(in: modelContext) else {
            return false
        }
        return asset.mimeType.hasPrefix("audio/")
    }

    /// Checks if the referenced asset is video content.
    ///
    /// - Parameter modelContext: The model context to fetch the asset from.
    /// - Returns: True if the asset has a video/* MIME type.
    public func isVideoClip(in modelContext: SwiftData.ModelContext) -> Bool {
        guard let asset = fetchAsset(in: modelContext) else {
            return false
        }
        return asset.mimeType.hasPrefix("video/")
    }

    /// Checks if the referenced asset is image content.
    ///
    /// - Parameter modelContext: The model context to fetch the asset from.
    /// - Returns: True if the asset has an image/* MIME type.
    public func isImageClip(in modelContext: SwiftData.ModelContext) -> Bool {
        guard let asset = fetchAsset(in: modelContext) else {
            return false
        }
        return asset.mimeType.hasPrefix("image/")
    }
}
