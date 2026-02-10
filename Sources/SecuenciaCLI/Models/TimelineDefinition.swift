import Foundation

/// Root structure for a JSON timeline definition.
struct TimelineDefinition: Codable, Sendable {
    let timeline: TimelineConfig
    let clips: [ClipDefinition]
}

/// Type of clip in the timeline.
enum ClipType: String, Codable, Sendable {
    case video
    case audio
    case image
    case marker
}
