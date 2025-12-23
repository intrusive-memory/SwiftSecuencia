import Foundation
import WebVTTParser
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
        var elements: [WebVTT.Element] = []

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

            // Build cue payload
            let payload = buildCuePayload(text: text, character: character)

            // Create WebVTT cue
            let metadata = WebVTT.CueMetadata(
                identifier: clip.id.uuidString,
                timing: startTime...endTime
            )
            let cue = WebVTT.Cue(metadata: metadata, payload: payload)
            elements.append(.cue(cue))
        }

        // Build WebVTT document
        let webvtt = WebVTT(elements: elements)

        // Serialize to string
        let parser = WebVTTParser()
        return try parser.print(webvtt)
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
        var elements: [WebVTT.Element] = []
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

            // Build cue payload
            let payload = buildCuePayload(text: text, character: character)

            // Create WebVTT cue
            let metadata = WebVTT.CueMetadata(
                identifier: element.id.uuidString,
                timing: startTime...endTime
            )
            let cue = WebVTT.Cue(metadata: metadata, payload: payload)
            elements.append(.cue(cue))

            currentTime = endTime
        }

        // Build WebVTT document
        let webvtt = WebVTT(elements: elements)

        // Serialize to string
        let parser = WebVTTParser()
        return try parser.print(webvtt)
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

    /// Build cue payload with optional voice tags
    private func buildCuePayload(text: String?, character: String?) -> WebVTT.CuePayload {
        let textContent = text ?? ""

        if let character = character {
            // Use voice tag for character attribution
            return WebVTT.CuePayload(components: [
                .voice(name: character, children: [
                    .plain(text: textContent)
                ])
            ])
        } else {
            // Plain text without voice tag
            return WebVTT.CuePayload(components: [
                .plain(text: textContent)
            ])
        }
    }

    /// Get audio duration from TypedDataStorage element
    ///
    /// Uses durationSeconds if available, otherwise loads and analyzes audio data.
    @MainActor
    private func getAudioDuration(for element: TypedDataStorage) async throws -> TimeInterval {
        // Use stored duration if available
        if let duration = element.durationSeconds {
            return duration
        }

        // Fall back to analyzing audio data
        guard let audioData = element.binaryValue else {
            struct MissingAudioDataError: Error {}
            throw MissingAudioDataError()
        }

        // Write to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        try audioData.write(to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Create AVAsset and get duration
        let asset = AVURLAsset(url: tempURL)
        let duration = try await asset.load(.duration)

        return duration.seconds
    }
}
