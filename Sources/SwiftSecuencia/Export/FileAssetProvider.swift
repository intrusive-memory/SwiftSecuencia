import Foundation

/// An entry representing a file-based asset.
///
/// This struct holds all the information needed to access and describe a media file,
/// including its location, MIME type, and media characteristics.
public struct FileAssetEntry: Sendable {
  /// The file URL where the asset is located.
  public let fileURL: URL

  /// Display name for the asset.
  public let name: String

  /// MIME type of the asset.
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

  /// Creates a file asset entry.
  ///
  /// - Parameters:
  ///   - fileURL: The file URL where the asset is located.
  ///   - name: Display name for the asset.
  ///   - mimeType: MIME type of the asset.
  ///   - durationSeconds: Duration in seconds. Nil for still images.
  ///   - hasVideo: Whether the asset contains video content.
  ///   - hasAudio: Whether the asset contains audio content.
  ///   - width: Width in pixels. Nil for audio-only assets.
  ///   - height: Height in pixels. Nil for audio-only assets.
  public init(
    fileURL: URL,
    name: String,
    mimeType: String,
    durationSeconds: Double? = nil,
    hasVideo: Bool,
    hasAudio: Bool,
    width: Int? = nil,
    height: Int? = nil
  ) {
    self.fileURL = fileURL
    self.name = name
    self.mimeType = mimeType
    self.durationSeconds = durationSeconds
    self.hasVideo = hasVideo
    self.hasAudio = hasAudio
    self.width = width
    self.height = height
  }
}

/// Asset provider that works with file-based assets.
///
/// This provider manages a registry of file-based media assets, mapping UUIDs to file URLs
/// and their associated metadata. It's useful for CLI tools and batch processing where
/// assets are referenced by file paths rather than stored in a database.
///
/// This provider is `Sendable` because it only holds immutable data structures.
public struct FileAssetProvider: AssetProvider, Sendable {
  private let registry: [UUID: FileAssetEntry]

  /// Creates an empty file asset provider.
  public init() {
    self.registry = [:]
  }

  /// Creates a file asset provider with a pre-populated registry.
  ///
  /// - Parameter registry: A dictionary mapping asset IDs to file asset entries.
  public init(registry: [UUID: FileAssetEntry]) {
    self.registry = registry
  }

  /// Registers a new asset entry.
  ///
  /// - Parameters:
  ///   - entry: The file asset entry to register.
  ///   - id: The UUID to associate with this asset.
  /// - Returns: A new `FileAssetProvider` with the asset registered.
  public func register(_ entry: FileAssetEntry, for id: UUID) -> FileAssetProvider {
    var newRegistry = registry
    newRegistry[id] = entry
    return FileAssetProvider(registry: newRegistry)
  }

  /// Returns all registered asset IDs.
  public var assetIDs: [UUID] {
    Array(registry.keys)
  }

  // MARK: - AssetProvider Implementation

  public func assetMetadata(for id: UUID) throws -> AssetMetadata {
    guard let entry = registry[id] else {
      throw AssetProviderError.assetNotFound(id)
    }

    return AssetMetadata(
      id: id,
      name: entry.name,
      mimeType: entry.mimeType,
      durationSeconds: entry.durationSeconds,
      hasVideo: entry.hasVideo,
      hasAudio: entry.hasAudio,
      width: entry.width,
      height: entry.height
    )
  }

  public func assetFileURL(for id: UUID) throws -> URL {
    guard let entry = registry[id] else {
      throw AssetProviderError.assetNotFound(id)
    }

    let fileURL = entry.fileURL

    // Verify the file exists
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw AssetProviderError.fileNotFound(id, fileURL)
    }

    return fileURL
  }

  public func assetData(for id: UUID) throws -> Data {
    let fileURL = try assetFileURL(for: id)

    // Read the file from disk
    do {
      return try Data(contentsOf: fileURL)
    } catch {
      throw AssetProviderError.fileNotFound(id, fileURL)
    }
  }
}
