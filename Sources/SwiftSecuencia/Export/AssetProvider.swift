import Foundation

// MARK: - AssetProvider Protocol

/// Protocol for providing access to media assets during export.
///
/// Asset providers abstract the storage mechanism for media files, allowing exporters
/// to work with assets from different sources (SwiftData, file system, etc.).
///
/// This protocol is NOT `Sendable` because implementations may hold non-Sendable resources
/// like `ModelContext`. Implementations should use appropriate isolation (e.g., `@MainActor`).
public protocol AssetProvider {
  /// Retrieves metadata for an asset.
  ///
  /// - Parameter id: The unique identifier of the asset.
  /// - Returns: Metadata describing the asset.
  /// - Throws: `AssetProviderError.assetNotFound` if the asset does not exist.
  func assetMetadata(for id: UUID) throws -> AssetMetadata

  /// Retrieves the file URL for an asset.
  ///
  /// - Parameter id: The unique identifier of the asset.
  /// - Returns: A file URL pointing to the asset's media file.
  /// - Throws: `AssetProviderError.assetNotFound` if the asset does not exist,
  ///           or `AssetProviderError.fileNotFound` if the asset has no file URL.
  func assetFileURL(for id: UUID) throws -> URL

  /// Retrieves the binary data for an asset.
  ///
  /// - Parameter id: The unique identifier of the asset.
  /// - Returns: The asset's binary data.
  /// - Throws: `AssetProviderError.assetNotFound` if the asset does not exist,
  ///           or `AssetProviderError.dataNotSupported` if the provider does not support data access.
  func assetData(for id: UUID) throws -> Data
}

// MARK: - Default Implementation

extension AssetProvider {
  /// Default implementation throws `dataNotSupported` error.
  ///
  /// Most asset providers work with file URLs rather than in-memory data.
  /// Override this method only if your provider supports direct data access.
  public func assetData(for id: UUID) throws -> Data {
    throw AssetProviderError.dataNotSupported
  }
}

// MARK: - AssetProviderError

/// Errors that can occur when accessing assets through an AssetProvider.
public enum AssetProviderError: LocalizedError {
  /// The requested asset was not found.
  case assetNotFound(UUID)

  /// The asset provider does not support data access (only file URL access).
  case dataNotSupported

  /// The asset exists but its file was not found at the expected URL.
  case fileNotFound(UUID, URL)

  public var errorDescription: String? {
    switch self {
    case .assetNotFound(let id):
      return "Asset not found: \(id.uuidString)"
    case .dataNotSupported:
      return
        "This asset provider does not support direct data access. Use assetFileURL(for:) instead."
    case .fileNotFound(let id, let url):
      return "File not found for asset \(id.uuidString) at path: \(url.path)"
    }
  }
}

// MARK: - AssetMetadata

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
