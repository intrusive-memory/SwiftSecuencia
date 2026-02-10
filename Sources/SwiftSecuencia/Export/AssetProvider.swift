import Foundation

/// Metadata describing a media asset for export.
///
/// This struct provides essential information about media files needed for FCPXML and audio export,
/// including dimensions, duration, and media type flags.
public struct AssetMetadata: Sendable, Codable {
    /// Unique identifier for the asset.
    public let id: UUID

    /// Display name for the asset.
    public let name: String

    /// MIME type of the asset (e.g., "video/quicktime", "audio/mp4", "image/png").
    public let mimeType: String

    /// Duration of the asset in seconds. Nil for still images.
    public let durationSeconds: Double?

    /// Whether the asset contains video content.
    public let hasVideo: Bool

    /// Whether the asset contains audio content.
    public let hasAudio: Bool

    /// Width of video or image content in pixels. Nil for audio-only assets.
    public let width: Int?

    /// Height of video or image content in pixels. Nil for audio-only assets.
    public let height: Int?

    /// Creates an asset metadata instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the asset.
    ///   - name: Display name for the asset.
    ///   - mimeType: MIME type of the asset.
    ///   - durationSeconds: Duration in seconds. Nil for still images.
    ///   - hasVideo: Whether the asset contains video content.
    ///   - hasAudio: Whether the asset contains audio content.
    ///   - width: Width in pixels. Nil for audio-only assets.
    ///   - height: Height in pixels. Nil for audio-only assets.
    public init(
        id: UUID,
        name: String,
        mimeType: String,
        durationSeconds: Double? = nil,
        hasVideo: Bool,
        hasAudio: Bool,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.durationSeconds = durationSeconds
        self.hasVideo = hasVideo
        self.hasAudio = hasAudio
        self.width = width
        self.height = height
    }
}
