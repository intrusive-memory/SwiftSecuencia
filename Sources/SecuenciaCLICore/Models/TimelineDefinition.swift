import Foundation

/// Root structure for a JSON timeline definition.
public struct TimelineDefinition: Codable, Sendable {
    public let timeline: TimelineConfig
    public let clips: [ClipDefinition]

    public init(timeline: TimelineConfig, clips: [ClipDefinition]) {
        self.timeline = timeline
        self.clips = clips
    }
}

/// Timeline configuration.
public struct TimelineConfig: Codable, Sendable {
    public let name: String
    public let format: FormatConfig
    public let audio: AudioConfig

    public init(name: String, format: FormatConfig, audio: AudioConfig) {
        self.name = name
        self.format = format
        self.audio = audio
    }
}

/// Video format configuration.
public struct FormatConfig: Codable, Sendable {
    public let width: Int
    public let height: Int
    public let frameRate: String
    public let colorSpace: String?

    public init(width: Int, height: Int, frameRate: String, colorSpace: String?) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.colorSpace = colorSpace
    }
}

/// Audio configuration.
public struct AudioConfig: Codable, Sendable {
    public let layout: String
    public let rate: String

    public init(layout: String, rate: String) {
        self.layout = layout
        self.rate = rate
    }
}

/// Clip definition in the timeline.
public struct ClipDefinition: Codable, Sendable {
    public let name: String
    public var file: String?  // Mutable to allow path resolution
    public let offset: String
    public var duration: String?  // Mutable to allow duration probing
    public let lane: Int?
    public let type: ClipType
    public let markerType: String?
    public let volume: Double?
    public let opacity: Double?

    public init(
        name: String,
        file: String?,
        offset: String,
        duration: String?,
        lane: Int?,
        type: ClipType,
        markerType: String?,
        volume: Double?,
        opacity: Double?
    ) {
        self.name = name
        self.file = file
        self.offset = offset
        self.duration = duration
        self.lane = lane
        self.type = type
        self.markerType = markerType
        self.volume = volume
        self.opacity = opacity
    }
}

/// Type of clip in the timeline.
public enum ClipType: String, Codable, Sendable, CaseIterable {
    case video
    case audio
    case image
    case marker
}
