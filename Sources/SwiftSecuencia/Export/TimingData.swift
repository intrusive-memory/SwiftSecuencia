import Foundation

/// Timing data for audio segments, enabling synchronized transcript display
///
/// Use this structure to export timing information in JSON format for custom
/// parsers or programmatic access. For web player integration, prefer WebVTT
/// format which provides native browser support via the TextTrack API.
///
/// ## Example Usage
///
/// ```swift
/// let timingData = TimingData(
///     audioFile: "screenplay.m4a",
///     duration: 150.5,
///     segments: [
///         TimingSegment(
///             id: "clip-uuid-1",
///             startTime: 0.0,
///             endTime: 3.2,
///             text: "Hello, world!",
///             metadata: TimingMetadata(character: "ALICE", lane: 1)
///         )
///     ]
/// )
///
/// // Write to JSON file
/// try await timingData.write(to: url)
/// ```
public struct TimingData: Codable, Sendable {
    /// Schema version (currently "1.0")
    public let version: String

    /// Audio filename (e.g., "screenplay.m4a")
    public let audioFile: String

    /// Total audio duration in seconds
    public let duration: Double

    /// Array of timed segments
    public let segments: [TimingSegment]

    /// Initialize timing data
    ///
    /// - Parameters:
    ///   - version: Schema version (default: "1.0")
    ///   - audioFile: Audio filename
    ///   - duration: Total audio duration in seconds
    ///   - segments: Array of timed segments
    public init(version: String = "1.0", audioFile: String, duration: Double, segments: [TimingSegment]) {
        self.version = version
        self.audioFile = audioFile
        self.duration = duration
        self.segments = segments
    }

    /// Generate file URL for timing data based on audio URL
    ///
    /// - Parameter audioURL: URL of the audio file
    /// - Returns: URL with `.timing.json` extension
    ///
    /// ## Example
    ///
    /// ```swift
    /// let audioURL = URL(fileURLWithPath: "/path/screenplay.m4a")
    /// let timingURL = TimingData.fileURL(for: audioURL)
    /// // Result: /path/screenplay.m4a.timing.json
    /// ```
    public static func fileURL(for audioURL: URL) -> URL {
        audioURL.appendingPathExtension("timing.json")
    }

    /// Write timing data to JSON file
    ///
    /// - Parameter url: Destination URL for JSON file
    /// - Throws: `EncodingError` if encoding fails, or file system errors
    ///
    /// The JSON is formatted with pretty printing and sorted keys for
    /// better readability and version control diffs.
    public func write(to url: URL) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}

/// A single timed segment (dialogue line or audio clip)
///
/// Represents one discrete audio segment with precise start/end timing
/// and optional metadata for character attribution and clip tracking.
public struct TimingSegment: Codable, Sendable, Equatable, Hashable {
    /// Unique identifier (typically clip UUID)
    public let id: String

    /// Start time in seconds from beginning of audio
    public let startTime: Double

    /// End time in seconds from beginning of audio
    public let endTime: Double

    /// Text content of the segment (if available)
    public let text: String?

    /// Optional metadata (character, lane, etc.)
    public let metadata: TimingMetadata?

    /// Initialize a timing segment
    ///
    /// - Parameters:
    ///   - id: Unique identifier (typically clip UUID)
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    ///   - text: Optional text content
    ///   - metadata: Optional metadata
    public init(id: String, startTime: Double, endTime: Double, text: String? = nil, metadata: TimingMetadata? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.metadata = metadata
    }

    /// Duration of the segment in seconds
    public var duration: Double {
        endTime - startTime
    }
}

/// Optional metadata for timing segments
///
/// Provides additional context for timing segments such as character names
/// from Fountain screenplays, timeline lane numbers, and clip identifiers
/// for correlation with source data.
public struct TimingMetadata: Codable, Sendable, Equatable, Hashable {
    /// Character name (from Fountain screenplay)
    public let character: String?

    /// Timeline lane number (0 = primary, positive/negative = additional lanes)
    public let lane: Int?

    /// Clip UUID for correlation with TimelineClip
    public let clipId: String?

    /// Initialize timing metadata
    ///
    /// - Parameters:
    ///   - character: Optional character name
    ///   - lane: Optional timeline lane number
    ///   - clipId: Optional clip UUID
    public init(character: String? = nil, lane: Int? = nil, clipId: String? = nil) {
        self.character = character
        self.lane = lane
        self.clipId = clipId
    }
}
