import AVFoundation
import Foundation
import os.log

/// Probes media files for metadata such as MIME type and duration.
public struct MediaProbe: Sendable {

  private static let logger = Logger(subsystem: "com.swiftsecuencia.cli", category: "MediaProbe")

  /// Returns the MIME type for a file based on its extension.
  ///
  /// Uses the MIME type derivation table from the JSON schema.
  /// Unknown extensions return "application/octet-stream" with a warning.
  ///
  /// - Parameter fileURL: The file URL to inspect.
  /// - Returns: The MIME type string (e.g., "video/quicktime", "audio/mp4").
  public func mimeType(of fileURL: URL) -> String {
    let ext = fileURL.pathExtension.lowercased()

    // Video MIME types
    switch ext {
    case "mov":
      return "video/quicktime"
    case "mp4":
      return "video/mp4"
    case "m4v":
      return "video/x-m4v"

    // Audio MIME types
    case "m4a":
      return "audio/mp4"
    case "mp3":
      return "audio/mpeg"
    case "wav":
      return "audio/wav"
    case "aiff", "aif":
      return "audio/aiff"

    // Image MIME types
    case "png":
      return "image/png"
    case "jpg", "jpeg":
      return "image/jpeg"
    case "tiff", "tif":
      return "image/tiff"

    // Unknown extension
    default:
      Self.logger.warning(
        "Unknown file extension '\(ext)' for file '\(fileURL.lastPathComponent)'. Returning application/octet-stream."
      )
      return "application/octet-stream"
    }
  }

  /// Probes the duration of a media file in seconds.
  ///
  /// Uses AVFoundation's modern async API to load the duration.
  ///
  /// - Parameter fileURL: The media file URL to probe.
  /// - Returns: The duration in seconds.
  /// - Throws: If the file cannot be read or has no valid duration.
  public func duration(of fileURL: URL) async throws -> Double {
    let asset = AVAsset(url: fileURL)
    let duration = try await asset.load(.duration)
    return CMTimeGetSeconds(duration)
  }

  /// Probes and fills in missing durations for clips in a timeline definition.
  ///
  /// For each clip where duration is nil and a file path exists,
  /// this method probes the file and sets the duration to "<seconds>s" format.
  ///
  /// - Parameter definition: The timeline definition with potentially missing durations.
  /// - Returns: A new timeline definition with all durations filled in.
  /// - Throws: If any file cannot be probed.
  public func probeMissingDurations(in definition: TimelineDefinition) async throws
    -> TimelineDefinition {
    var updatedClips: [ClipDefinition] = []

    for clip in definition.clips {
      // Skip if duration already specified or no file (e.g., markers)
      if clip.duration != nil || clip.file == nil {
        updatedClips.append(clip)
        continue
      }

      // Probe the file duration
      let fileURL = URL(fileURLWithPath: clip.file!)
      let durationSeconds = try await duration(of: fileURL)

      // Create updated clip with duration in FCPXML format
      var updatedClip = clip
      updatedClip.duration = "\(durationSeconds)s"
      updatedClips.append(updatedClip)
    }

    return TimelineDefinition(
      timeline: definition.timeline,
      clips: updatedClips
    )
  }
}
