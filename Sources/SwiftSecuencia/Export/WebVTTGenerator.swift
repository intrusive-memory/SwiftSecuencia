import Foundation
import WebVTT
import SwiftData
import SwiftCompartido
import AVFoundation

/// Generates WebVTT timing data from Timeline or audio elements
///
/// Use this generator to create W3C-compliant WebVTT files for karaoke-style
/// text highlighting in web players. WebVTT provides native browser support
/// via the TextTrack API with ±10ms precision.
///
/// ## Example Usage
///
/// ```swift
/// let generator = WebVTTGenerator()
/// let webvtt = try await generator.generateWebVTT(
///     from: timeline,
///     modelContext: modelContext
/// )
/// ```
public struct WebVTTGenerator: Sendable {

    public init() {}

    /// Generate WebVTT from Timeline
    ///
    /// - Parameters:
    ///   - timeline: Timeline with sorted clips
    ///   - modelContext: SwiftData context for fetching assets
    /// - Returns: WebVTT string with timing cues and voice tags
    /// - Throws: `FCPXMLExportError` if asset fetching fails
    @MainActor
    public func generateWebVTT(from timeline: Timeline, modelContext: ModelContext) async throws -> String {
        var webVTT = WebVTT()

        // Iterate through timeline clips in order
        for clip in timeline.sortedClips {
            // Fetch asset metadata
            guard let asset = clip.fetchAsset(in: modelContext) else {
                continue  // Skip clips without valid assets
            }

            // Extract timing (convert Timecode to seconds)
            let startTime = clip.offset.seconds
            let endTime = (clip.offset + clip.duration).seconds

            // Extract metadata (character, text)
            let character = extractCharacter(from: asset)
            let text = extractText(from: asset)

            // Build cue text with voice tags if needed
            let cueText = buildCueText(text: text, character: character)

            // Create WebVTT cue
            var cue = WebVTT.Cue(
                startTime: WebVTT.Timestamp(totalMilliseconds: Int(startTime * 1000)),
                endTime: WebVTT.Timestamp(totalMilliseconds: Int(endTime * 1000)),
                text: cueText
            )
            cue.id = clip.id.uuidString
            webVTT.cues.append(cue)
        }

        // Serialize to string
        return webVTT.description
    }

    /// Generate WebVTT from audio elements (direct export)
    ///
    /// - Parameters:
    ///   - audioElements: Array of TypedDataStorage elements in timeline order
    ///   - modelContext: SwiftData context for asset operations
    /// - Returns: WebVTT string with timing cues and voice tags
    /// - Throws: Audio processing errors
    @MainActor
    public func generateWebVTT(from audioElements: [TypedDataStorage], modelContext: ModelContext) async throws -> String {
        var webVTT = WebVTT()
        var currentTime = 0.0

        // Build cues sequentially from audio elements
        for element in audioElements {
            // Get duration from audio data
            let duration = try await getAudioDuration(for: element)

            let startTime = currentTime
            let endTime = currentTime + duration

            // Extract metadata
            let character = extractCharacter(from: element)
            let text = extractText(from: element)

            // Build cue text with voice tags if needed
            let cueText = buildCueText(text: text, character: character)

            // Create WebVTT cue
            var cue = WebVTT.Cue(
                startTime: WebVTT.Timestamp(totalMilliseconds: Int(startTime * 1000)),
                endTime: WebVTT.Timestamp(totalMilliseconds: Int(endTime * 1000)),
                text: cueText
            )
            cue.id = element.id.uuidString
            webVTT.cues.append(cue)

            currentTime = endTime
        }

        // Serialize to string
        return webVTT.description
    }

    // MARK: - Private Helpers

    /// Extract character name from asset metadata
    private func extractCharacter(from asset: TypedDataStorage) -> String? {
        asset.voiceName
    }

    /// Extract text content from asset metadata
    private func extractText(from asset: TypedDataStorage) -> String? {
        asset.prompt.isEmpty ? nil : asset.prompt
    }

    /// Build cue text with optional voice tags
    ///
    /// WebVTT voice tags format: `<v VoiceName>text</v>`
    /// See: https://www.w3.org/TR/webvtt1/#webvtt-cue-voice-span
    ///
    /// Per W3C WebVTT spec, special characters (&, <, >) must be escaped in cue text
    /// to prevent malformed WebVTT files and parsing errors.
    private func buildCueText(text: String?, character: String?) -> String {
        let textContent = text ?? ""

        // Per WebVTT spec, '&', '<', and '>' must be escaped in cue text
        let escapedTextContent = textContent
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        if let character = character {
            // Sanitize character name to prevent breaking voice tag structure
            let sanitizedCharacter = character
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "<", with: "")

            // Use voice tag for character attribution
            return "<v \(sanitizedCharacter)>\(escapedTextContent)</v>"
        } else {
            // Plain text without voice tag
            return escapedTextContent
        }
    }

    /// Get audio duration from TypedDataStorage element
    ///
    /// Requires durationSeconds metadata to be set. Timing data generation
    /// requires duration metadata - loading audio files just to get duration
    /// would add significant I/O overhead (>5% performance impact).
    ///
    /// - Parameter element: TypedDataStorage element with durationSeconds set
    /// - Returns: Duration in seconds
    /// - Throws: `MissingDurationMetadataError` if durationSeconds is nil
    @MainActor
    private func getAudioDuration(for element: TypedDataStorage) async throws -> TimeInterval {
        // Require duration metadata for timing data generation
        guard let duration = element.durationSeconds else {
            struct MissingDurationMetadataError: Error, CustomStringConvertible {
                let elementId: UUID
                var description: String {
                    "Timing data generation requires durationSeconds metadata. Element \(elementId) is missing duration. Ensure audio elements have duration set before generating timing data."
                }
            }
            throw MissingDurationMetadataError(elementId: element.id)
        }

        return duration
    }
}
