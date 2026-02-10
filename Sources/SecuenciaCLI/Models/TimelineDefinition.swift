import Foundation

/// Root structure for a JSON timeline definition.
struct TimelineDefinition: Codable, Sendable {
    let timeline: TimelineConfig
    let clips: [ClipDefinition]
}

/// Timeline configuration.
struct TimelineConfig: Codable, Sendable {
    let name: String
    let format: FormatConfig
    let audio: AudioConfig
}

/// Video format configuration.
struct FormatConfig: Codable, Sendable {
    let width: Int
    let height: Int
    let frameRate: String
    let colorSpace: String?
}

/// Audio configuration.
struct AudioConfig: Codable, Sendable {
    let layout: String
    let rate: String
}

/// Type of clip in the timeline.
enum ClipType: String, Codable, Sendable {
    case video
    case audio
    case image
    case marker
}
