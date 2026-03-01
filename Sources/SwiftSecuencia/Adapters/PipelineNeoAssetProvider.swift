//
//  PipelineNeoAssetProvider.swift
//  SwiftSecuencia
//
//  Converts SwiftSecuencia assets to PipelineNeo FCPXMLExportAsset structs
//  using ResourceMap for DTD-compliant r-prefixed resource ID assignment.
//
//  This adapter bridges SwiftSecuencia's AssetProvider protocol (which fetches
//  asset metadata and file URLs from SwiftData or the file system) with
//  PipelineNeo's FCPXMLExportAsset value type (which the exporter consumes).
//
//  ## Architecture
//
//  SwiftSecuencia AssetProvider → PipelineNeoAssetProvider → [FCPXMLExportAsset]
//                                        ↑
//                                   ResourceMap (UUID → "r2", "r3", ...)
//
//  The ResourceMap is injected at construction time and used for all ID conversions.
//  Asset UUIDs MUST be registered in the ResourceMap before calling conversion methods.
//
//  ## macOS Only
//
//  This file is guarded with `#if os(macOS)` because PipelineNeo is a macOS-only
//  dependency. On iOS, FCPXML export is not available.

#if os(macOS)
  import Foundation
  import CoreMedia
  import PipelineNeo

  // MARK: - Asset Conversion Error

  /// Errors that can occur when converting SwiftSecuencia assets to PipelineNeo format.
  public enum AssetConversionError: Error, LocalizedError {
    /// The asset has no file URL and no binary data to resolve.
    case noFileURLOrData(id: UUID)

    /// The referenced media file does not exist at the expected path.
    case fileNotFound(url: URL)

    /// The MIME type is missing or cannot be interpreted.
    case invalidMIMEType(String)

    /// Failed to write binary data to a temporary file.
    case tempFileWriteFailed(id: UUID, underlying: Error)

    /// The resource ID was not found in the ResourceMap.
    case unmappedResourceID(String)

    public var errorDescription: String? {
      switch self {
      case .noFileURLOrData(let id):
        return "Asset \(id.uuidString) has no file URL and no binary data."
      case .fileNotFound(let url):
        return "Media file not found: \(url.path)"
      case .invalidMIMEType(let mime):
        return "Invalid or unknown MIME type: \(mime)"
      case .tempFileWriteFailed(let id, let err):
        return "Failed to write temp file for asset \(id.uuidString): \(err.localizedDescription)"
      case .unmappedResourceID(let rid):
        return "Resource ID '\(rid)' not found in ResourceMap."
      }
    }
  }

  // MARK: - MIME Type Detection

  /// Detects media type flags from a MIME type string.
  ///
  /// - Parameter mimeType: A MIME type string (e.g., "video/mp4", "audio/mpeg").
  /// - Returns: A tuple indicating whether the asset has video and audio content.
  ///
  /// Detection rules:
  /// - `"video/*"` containers typically contain both video and audio tracks.
  /// - `"audio/*"` types contain audio only, no video.
  /// - `"image/*"` types are treated as video (still frame) with no audio.
  /// - Unknown types default to `hasVideo: true, hasAudio: true` as a safe fallback.
  public func detectMediaType(from mimeType: String) -> (hasVideo: Bool, hasAudio: Bool) {
    let lowered = mimeType.lowercased()

    if lowered.hasPrefix("video/") {
      return (hasVideo: true, hasAudio: true)
    } else if lowered.hasPrefix("audio/") {
      return (hasVideo: false, hasAudio: true)
    } else if lowered.hasPrefix("image/") {
      return (hasVideo: true, hasAudio: false)
    } else {
      return (hasVideo: true, hasAudio: true)
    }
  }

  // MARK: - File Extension from MIME Type

  /// Returns an appropriate file extension for the given MIME type.
  ///
  /// - Parameter mimeType: A MIME type string.
  /// - Returns: A file extension without a leading dot (e.g., "m4a", "mov").
  func mimeTypeFileExtension(for mimeType: String) -> String {
    let components = mimeType.lowercased().split(separator: "/")
    guard components.count == 2 else { return "dat" }

    let type = String(components[0])
    let subtype = String(components[1])

    switch subtype {
    case "mp4":
      return type == "audio" ? "m4a" : "mp4"
    case "quicktime":
      return "mov"
    case "mpeg":
      return type == "audio" ? "mp3" : "mpeg"
    case "wav", "x-wav", "vnd.wave":
      return "wav"
    case "aiff", "x-aiff":
      return "aiff"
    case "png":
      return "png"
    case "jpeg":
      return "jpg"
    default:
      return subtype
    }
  }

  // MARK: - PipelineNeoAssetProvider

  /// Provides PipelineNeo `FCPXMLExportAsset` instances from SwiftSecuencia's
  /// `AssetProvider`, using `ResourceMap` for DTD-compliant resource ID assignment.
  ///
  /// This struct wraps any `AssetProvider` implementation (SwiftData-backed or file-based)
  /// and converts assets into the format expected by `PipelineNeo.FCPXMLExporter.export()`.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// var resourceMap = ResourceMap()
  /// resourceMap.registerAssets(assetUUIDs)
  ///
  /// let provider = PipelineNeoAssetProvider(
  ///     assetProvider: swiftDataAssetProvider,
  ///     resourceMap: resourceMap
  /// )
  ///
  /// // Single asset conversion
  /// let exportAsset = try provider.exportAsset(for: someUUID)
  ///
  /// // Batch conversion for a timeline
  /// let exportAssets = try provider.exportAssets(for: timeline)
  /// ```
  ///
  /// ## Error Handling
  ///
  /// - Missing assets: Logged and returned as `nil` from `exportAssetOrNil(for:)`.
  ///   The throwing variant `exportAsset(for:)` propagates the error.
  /// - Invalid resource IDs: Return `nil` from `exportAssetOrNil(forResourceID:)`.
  /// - SwiftData fetch errors: Propagated from the underlying `AssetProvider`.
  public struct PipelineNeoAssetProvider {
    private let assetProvider: any AssetProvider
    private let resourceMap: ResourceMap

    /// Creates a PipelineNeo asset provider.
    ///
    /// - Parameters:
    ///   - assetProvider: The underlying asset provider (SwiftData, file-based, etc.).
    ///   - resourceMap: A pre-populated ResourceMap with all asset UUIDs registered.
    public init(assetProvider: any AssetProvider, resourceMap: ResourceMap) {
      self.assetProvider = assetProvider
      self.resourceMap = resourceMap
    }

    // MARK: - Single Asset Conversion

    /// Converts a single asset to a `PipelineNeo.FCPXMLExportAsset`.
    ///
    /// The asset's UUID is looked up in the ResourceMap to obtain its r-prefixed
    /// resource ID. Metadata and file URL are fetched from the underlying AssetProvider.
    ///
    /// - Parameters:
    ///   - uuid: The asset's UUID.
    ///   - relativePath: Optional relative path for bundle exports (e.g., "Media/clip.mov").
    /// - Returns: A `PipelineNeo.FCPXMLExportAsset` ready for FCPXML export.
    /// - Throws: `AssetProviderError` if the asset cannot be found,
    ///           `AssetConversionError` if conversion fails.
    public func exportAsset(
      for uuid: UUID,
      relativePath: String? = nil
    ) throws -> PipelineNeo.FCPXMLExportAsset {
      // Look up resource ID from ResourceMap
      guard let resourceID = resourceMap.assetResourceID(for: uuid) else {
        assertionFailure(
          "PipelineNeoAssetProvider: UUID \(uuid) not registered in ResourceMap. "
            + "Register all asset UUIDs before converting."
        )
        // Fall back to UUID string (will likely fail DTD validation)
        return try buildExportAsset(
          for: uuid, resourceID: uuid.uuidString, relativePath: relativePath)
      }

      return try buildExportAsset(for: uuid, resourceID: resourceID, relativePath: relativePath)
    }

    /// Converts a single asset, returning `nil` instead of throwing on failure.
    ///
    /// This is the graceful variant used during export when a missing asset should
    /// not abort the entire operation. Errors are logged but not propagated.
    ///
    /// - Parameters:
    ///   - uuid: The asset's UUID.
    ///   - relativePath: Optional relative path for bundle exports.
    /// - Returns: A `PipelineNeo.FCPXMLExportAsset`, or `nil` if the asset could not be resolved.
    public func exportAssetOrNil(
      for uuid: UUID,
      relativePath: String? = nil
    ) -> PipelineNeo.FCPXMLExportAsset? {
      do {
        return try exportAsset(for: uuid, relativePath: relativePath)
      } catch {
        // Log but don't propagate — let export continue with partial data
        print(
          "PipelineNeoAssetProvider: Failed to convert asset \(uuid): \(error.localizedDescription)"
        )
        return nil
      }
    }

    /// Converts an asset identified by its resource ID (e.g., `"r2"`) using reverse lookup.
    ///
    /// This is useful when the caller has a resource ID (from a TimelineClip's assetRef)
    /// and needs to fetch the corresponding asset.
    ///
    /// - Parameters:
    ///   - resourceID: The r-prefixed resource ID (e.g., `"r2"`).
    ///   - relativePath: Optional relative path for bundle exports.
    /// - Returns: A `PipelineNeo.FCPXMLExportAsset`, or `nil` if the resource ID is not mapped.
    public func exportAssetOrNil(
      forResourceID resourceID: String,
      relativePath: String? = nil
    ) -> PipelineNeo.FCPXMLExportAsset? {
      guard let uuid = resourceMap.uuid(for: resourceID) else {
        return nil
      }
      return exportAssetOrNil(for: uuid, relativePath: relativePath)
    }

    // MARK: - Batch Conversion

    /// Converts all unique assets referenced by a timeline's clips.
    ///
    /// This is the primary batch entry point for FCPXML export. It extracts unique
    /// asset UUIDs from the timeline's clips, looks up their resource IDs in the
    /// ResourceMap, and converts each to a `PipelineNeo.FCPXMLExportAsset`.
    ///
    /// - Parameters:
    ///   - timeline: The SwiftSecuencia timeline whose clips reference assets.
    ///   - includeMedia: If true, generates relative paths for bundle export
    ///     (e.g., "Media/filename.ext").
    /// - Returns: An array of `PipelineNeo.FCPXMLExportAsset` structs.
    /// - Throws: If any individual asset conversion fails.
    public func exportAssets(
      for timeline: Timeline,
      includeMedia: Bool = false
    ) throws -> [PipelineNeo.FCPXMLExportAsset] {
      let uniqueAssetIDs = Array(Set(timeline.clips.map { $0.assetStorageId }))
      return try exportAssets(for: uniqueAssetIDs, includeMedia: includeMedia)
    }

    /// Converts multiple assets by UUID.
    ///
    /// - Parameters:
    ///   - uuids: The asset UUIDs to convert.
    ///   - includeMedia: If true, generates relative paths for bundle export.
    /// - Returns: An array of `PipelineNeo.FCPXMLExportAsset` structs.
    /// - Throws: If any individual asset conversion fails.
    public func exportAssets(
      for uuids: [UUID],
      includeMedia: Bool = false
    ) throws -> [PipelineNeo.FCPXMLExportAsset] {
      try uuids.map { uuid in
        let relativePath: String?
        if includeMedia {
          let metadata = try assetProvider.assetMetadata(for: uuid)
          let ext = mimeTypeFileExtension(for: metadata.mimeType)
          relativePath = "Media/\(uuid.uuidString).\(ext)"
        } else {
          relativePath = nil
        }
        return try exportAsset(for: uuid, relativePath: relativePath)
      }
    }

    // MARK: - Private Helpers

    /// Builds a `PipelineNeo.FCPXMLExportAsset` from metadata and file URL.
    private func buildExportAsset(
      for uuid: UUID,
      resourceID: String,
      relativePath: String?
    ) throws -> PipelineNeo.FCPXMLExportAsset {
      let metadata = try assetProvider.assetMetadata(for: uuid)
      let fileURL = try resolveFileURL(for: uuid, mimeType: metadata.mimeType)

      let (hasVideo, hasAudio) = detectMediaType(from: metadata.mimeType)

      let duration: CMTime? = metadata.durationSeconds.map {
        CMTime(seconds: $0, preferredTimescale: 600)
      }

      return PipelineNeo.FCPXMLExportAsset(
        id: resourceID,
        name: metadata.name,
        src: fileURL,
        duration: duration,
        hasVideo: hasVideo,
        hasAudio: hasAudio,
        relativePath: relativePath
      )
    }

    /// Resolves a file URL for the asset, falling back to temp file from binary data.
    private func resolveFileURL(for uuid: UUID, mimeType: String) throws -> URL {
      // Try file URL first
      do {
        let url = try assetProvider.assetFileURL(for: uuid)
        guard FileManager.default.fileExists(atPath: url.path) else {
          throw AssetConversionError.fileNotFound(url: url)
        }
        return url
      } catch is AssetProviderError {
        // File URL not available; try binary data fallback
      }

      // Fallback: write binary data to temp file
      do {
        let data = try assetProvider.assetData(for: uuid)
        let ext = mimeTypeFileExtension(for: mimeType)
        let tempDir = FileManager.default.temporaryDirectory
          .appendingPathComponent("SwiftSecuencia-assets", isDirectory: true)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let tempURL = tempDir.appendingPathComponent("\(uuid.uuidString).\(ext)")

        if !FileManager.default.fileExists(atPath: tempURL.path) {
          try data.write(to: tempURL)
        }

        return tempURL
      } catch let error as AssetConversionError {
        throw error
      } catch {
        throw AssetConversionError.noFileURLOrData(id: uuid)
      }
    }
  }

#endif  // os(macOS)
