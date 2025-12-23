import Foundation

/// Format options for timing data export
///
/// Use this enum to specify which timing data formats should be generated
/// alongside audio exports. WebVTT is recommended for web players with
/// native `<track>` element support, while JSON is available for advanced
/// use cases requiring custom parsing.
public enum TimingDataFormat: Sendable {
    /// No timing data (default)
    ///
    /// Audio export completes without generating timing data files.
    case none

    /// WebVTT format only (recommended for web players)
    ///
    /// Generates a `.vtt` file with W3C-compliant WebVTT timing cues.
    /// Best for karaoke-style text highlighting using the browser's
    /// TextTrack API. Supports voice tags for character attribution.
    ///
    /// Output file: `screenplay.vtt`
    case webvtt

    /// JSON format only (advanced use cases)
    ///
    /// Generates a `.timing.json` file with structured timing segments.
    /// Use this for custom parsers or when WebVTT features are not needed.
    ///
    /// Output file: `screenplay.timing.json`
    case json

    /// Both WebVTT and JSON formats
    ///
    /// Generates both `.vtt` and `.timing.json` files. Use when you need
    /// WebVTT for web player integration and JSON for programmatic access.
    ///
    /// Output files: `screenplay.vtt`, `screenplay.timing.json`
    case both
}
