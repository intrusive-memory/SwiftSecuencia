import CryptoKit
import Foundation

/// Resolves file paths and manages asset deduplication for timeline definitions.
public struct FileResolver: Sendable {

  /// Errors that can occur during file resolution.
  public enum FileResolverError: LocalizedError, Sendable {
    case fileNotFound(String)

    public var errorDescription: String? {
      switch self {
      case .fileNotFound(let path):
        return "File not found: \(path)"
      }
    }
  }

  /// Generates a deterministic UUID from a file path using SHA256.
  ///
  /// This ensures the same file path always produces the same UUID,
  /// enabling stable resource IDs across multiple exports.
  ///
  /// - Parameter path: The absolute file path.
  /// - Returns: A stable UUID derived from the path.
  public static func deterministicUUID(for path: String) -> UUID {
    // Hash the absolute path
    let hash = SHA256.hash(data: Data(path.utf8))

    // Take first 16 bytes (128 bits) for UUID
    let bytes = Array(hash.prefix(16))

    // Construct UUID from bytes
    return UUID(
      uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11],
        bytes[12], bytes[13], bytes[14], bytes[15]
      ))
  }

  /// Resolves all file paths in a timeline definition to absolute paths.
  ///
  /// - Parameters:
  ///   - definition: The timeline definition with relative or absolute file paths.
  ///   - baseURL: The base URL to resolve relative paths against (typically the JSON file's directory).
  /// - Returns: A new timeline definition with all file paths resolved to absolute paths.
  /// - Throws: `FileResolverError.fileNotFound` if any file doesn't exist.
  public func resolve(definition: TimelineDefinition, relativeTo baseURL: URL) throws
    -> TimelineDefinition {
    var resolvedClips: [ClipDefinition] = []

    for clip in definition.clips {
      // Skip clips without files (e.g., markers)
      guard let filePath = clip.file else {
        resolvedClips.append(clip)
        continue
      }

      // Determine if path is absolute or relative
      let resolvedPath: String
      if filePath.hasPrefix("/") {
        // Absolute path - use as-is
        resolvedPath = filePath
      } else {
        // Relative path - resolve against base URL
        let fileURL = baseURL.appendingPathComponent(filePath)
        resolvedPath = fileURL.path
      }

      // Verify file exists
      let fileManager = FileManager.default
      guard fileManager.fileExists(atPath: resolvedPath) else {
        throw FileResolverError.fileNotFound(resolvedPath)
      }

      // Create new clip with resolved path
      var resolvedClip = clip
      resolvedClip.file = resolvedPath
      resolvedClips.append(resolvedClip)
    }

    // Return new definition with resolved clips
    return TimelineDefinition(
      timeline: definition.timeline,
      clips: resolvedClips
    )
  }

  /// Deduplicates assets by assigning one stable UUID per unique file path.
  ///
  /// Multiple clips referencing the same file will share the same UUID,
  /// ensuring efficient asset reuse in the exported timeline.
  ///
  /// - Parameter definition: The timeline definition with resolved absolute file paths.
  /// - Returns: A dictionary mapping absolute file paths to deterministic UUIDs.
  public func deduplicateAssets(in definition: TimelineDefinition) -> [String: UUID] {
    var assetMap: [String: UUID] = [:]

    for clip in definition.clips where clip.file != nil {
      let path = clip.file!  // Already resolved to absolute path
      if assetMap[path] == nil {
        assetMap[path] = FileResolver.deterministicUUID(for: path)
      }
    }

    return assetMap
  }
}
