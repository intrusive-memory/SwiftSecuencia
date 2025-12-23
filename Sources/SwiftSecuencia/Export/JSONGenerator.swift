import Foundation
import SwiftData
import SwiftCompartido
import AVFoundation

/// Generates JSON timing data from Timeline or audio elements
///
/// Use this generator to create structured JSON files for custom parsers
/// or programmatic access. For web player integration, prefer WebVTT format
/// which provides native browser support via the TextTrack API.
///
/// ## Example Usage
///
/// ```swift
/// let generator = JSONGenerator()
/// let timingData = try await generator.generateTimingData(
///     from: timeline,
///     audioFileName: "screenplay.m4a",
///     modelContext: modelContext
/// )
/// ```
public struct JSONGenerator: Sendable {

    public init() {}

    /// Generate TimingData from Timeline
    ///
    /// - Parameters:
    ///   - timeline: Timeline with sorted clips
    ///   - audioFileName: Name of the audio file this timing data corresponds to
    ///   - modelContext: SwiftData context for fetching assets
    /// - Returns: TimingData structure ready for JSON serialization
    /// - Throws: Asset fetching errors
    public func generateTimingData(
        from timeline: Timeline,
        audioFileName: String,
        modelContext: ModelContext
    ) async throws -> TimingData {
        var segments: [TimingSegment] = []

        // Calculate total duration from timeline clips
        let totalDuration = timeline.clips.map { ($0.offset + $0.duration).seconds }
            .max() ?? 0.0

        // Iterate through timeline clips in order
        for clip in timeline.clips {
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

            // Build TimingMetadata
            let metadata = TimingMetadata(
                character: character,
                lane: clip.lane,
                clipId: clip.id.uuidString
            )

            // Create TimingSegment
            let segment = TimingSegment(
                id: clip.id.uuidString,
                startTime: startTime,
                endTime: endTime,
                text: text,
                metadata: metadata
            )
            segments.append(segment)
        }

        // Build TimingData
        return TimingData(
            audioFile: audioFileName,
            duration: totalDuration,
            segments: segments
        )
    }

    /// Generate TimingData from audio elements (direct export)
    ///
    /// - Parameters:
    ///   - audioElements: Array of TypedDataStorage elements in timeline order
    ///   - audioFileName: Name of the audio file this timing data corresponds to
    ///   - modelContext: SwiftData context for asset operations
    /// - Returns: TimingData structure ready for JSON serialization
    /// - Throws: Audio processing errors
    public func generateTimingData(
        from audioElements: [TypedDataStorage],
        audioFileName: String,
        modelContext: ModelContext
    ) async throws -> TimingData {
        var segments: [TimingSegment] = []
        var currentTime = 0.0

        // Build segments sequentially from audio elements
        for element in audioElements {
            // Get duration from audio data
            let duration = try await getAudioDuration(for: element)

            let startTime = currentTime
            let endTime = currentTime + duration

            // Extract metadata
            let character = extractCharacter(from: element)
            let text = extractText(from: element)

            // Build TimingMetadata
            let metadata = TimingMetadata(
                character: character,
                lane: nil,  // No lane concept in direct export
                clipId: element.id.uuidString
            )

            // Create TimingSegment
            let segment = TimingSegment(
                id: element.id.uuidString,
                startTime: startTime,
                endTime: endTime,
                text: text,
                metadata: metadata
            )
            segments.append(segment)

            currentTime = endTime
        }

        // Build TimingData
        return TimingData(
            audioFile: audioFileName,
            duration: currentTime,
            segments: segments
        )
    }

    /// Generate JSON string from Timeline
    ///
    /// - Parameters:
    ///   - timeline: Timeline with sorted clips
    ///   - audioFileName: Name of the audio file this timing data corresponds to
    ///   - modelContext: SwiftData context for fetching assets
    /// - Returns: JSON string with pretty-printed, sorted keys
    /// - Throws: Encoding or asset fetching errors
    public func generateJSON(
        from timeline: Timeline,
        audioFileName: String,
        modelContext: ModelContext
    ) async throws -> String {
        let timingData = try await generateTimingData(
            from: timeline,
            audioFileName: audioFileName,
            modelContext: modelContext
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(timingData)

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            struct JSONEncodingError: Error {}
            throw JSONEncodingError()
        }

        return jsonString
    }

    /// Generate JSON string from audio elements (direct export)
    ///
    /// - Parameters:
    ///   - audioElements: Array of TypedDataStorage elements in timeline order
    ///   - audioFileName: Name of the audio file this timing data corresponds to
    ///   - modelContext: SwiftData context for asset operations
    /// - Returns: JSON string with pretty-printed, sorted keys
    /// - Throws: Encoding or audio processing errors
    public func generateJSON(
        from audioElements: [TypedDataStorage],
        audioFileName: String,
        modelContext: ModelContext
    ) async throws -> String {
        let timingData = try await generateTimingData(
            from: audioElements,
            audioFileName: audioFileName,
            modelContext: modelContext
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(timingData)

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            struct JSONEncodingError: Error {}
            throw JSONEncodingError()
        }

        return jsonString
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

    /// Get audio duration from TypedDataStorage element
    ///
    /// Uses durationSeconds if available, otherwise loads and analyzes audio data.
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
