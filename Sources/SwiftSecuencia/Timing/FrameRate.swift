//
//  FrameRate.swift
//  SwiftSecuencia
//
//  Common video frame rates with precise timing.
//

import Foundation

/// Video frame rate with precise frame duration.
///
/// Frame rates in video production often use non-integer values (like 29.97fps for NTSC).
/// This enum provides accurate frame durations as rational numbers to maintain
/// frame-accurate timing in FCPXML.
///
/// ## Common Frame Rates
///
/// | Rate | Use Case | Frame Duration |
/// |------|----------|----------------|
/// | 23.98 | NTSC Film | 1001/24000s |
/// | 24 | Film | 100/2400s |
/// | 25 | PAL | 100/2500s |
/// | 29.97 | NTSC Video | 1001/30000s |
/// | 30 | Web/Digital | 100/3000s |
///
/// ## Usage
///
/// ```swift
/// let rate = FrameRate.fps23_98
/// let frameDuration = rate.frameDuration  // Timecode(value: 1001, timescale: 24000)
/// let tenFrames = Timecode(frames: 10, frameRate: rate)
/// ```
public enum FrameRate: Sendable, Equatable, Hashable, Codable {

    // MARK: - Standard Frame Rates

    /// 23.976 fps (NTSC film, "24p").
    ///
    /// Frame duration: 1001/24000s
    case fps23_98

    /// 24 fps (true film rate).
    ///
    /// Frame duration: 1/24s (100/2400s)
    case fps24

    /// 25 fps (PAL standard).
    ///
    /// Frame duration: 1/25s (100/2500s)
    case fps25

    /// 29.97 fps (NTSC video).
    ///
    /// Frame duration: 1001/30000s
    case fps29_97

    /// 30 fps (web/digital).
    ///
    /// Frame duration: 1/30s (100/3000s)
    case fps30

    /// 50 fps (PAL high frame rate).
    ///
    /// Frame duration: 1/50s (100/5000s)
    case fps50

    /// 59.94 fps (NTSC high frame rate).
    ///
    /// Frame duration: 1001/60000s
    case fps59_94

    /// 60 fps (high frame rate).
    ///
    /// Frame duration: 1/60s (100/6000s)
    case fps60

    /// Custom frame rate defined by frame duration.
    case custom(frameDuration: Timecode)

    // MARK: - Properties

    /// The duration of a single frame.
    public var frameDuration: Timecode {
        switch self {
        case .fps23_98:
            return Timecode(value: 1001, timescale: 24000)
        case .fps24:
            return Timecode(value: 100, timescale: 2400)
        case .fps25:
            return Timecode(value: 100, timescale: 2500)
        case .fps29_97:
            return Timecode(value: 1001, timescale: 30000)
        case .fps30:
            return Timecode(value: 100, timescale: 3000)
        case .fps50:
            return Timecode(value: 100, timescale: 5000)
        case .fps59_94:
            return Timecode(value: 1001, timescale: 60000)
        case .fps60:
            return Timecode(value: 100, timescale: 6000)
        case .custom(let frameDuration):
            return frameDuration
        }
    }

    /// Frames per second as a floating point value.
    public var framesPerSecond: Double {
        1.0 / frameDuration.seconds
    }

    /// Whether this is a drop-frame rate (29.97 or 59.94).
    public var isDropFrame: Bool {
        switch self {
        case .fps29_97, .fps59_94:
            return true
        default:
            return false
        }
    }

    /// The FCPXML format name suffix for this frame rate.
    ///
    /// Used in format names like "FFVideoFormat1080p2398".
    public var fcpxmlSuffix: String {
        switch self {
        case .fps23_98:
            return "2398"
        case .fps24:
            return "24"
        case .fps25:
            return "25"
        case .fps29_97:
            return "2997"
        case .fps30:
            return "30"
        case .fps50:
            return "50"
        case .fps59_94:
            return "5994"
        case .fps60:
            return "60"
        case .custom:
            // Generate from actual fps
            let fps = framesPerSecond
            if fps.truncatingRemainder(dividingBy: 1) < 0.01 {
                return String(Int(fps))
            } else {
                return String(format: "%.2f", fps).replacingOccurrences(of: ".", with: "")
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension FrameRate: CustomStringConvertible {
    public var description: String {
        switch self {
        case .fps23_98:
            return "23.98 fps"
        case .fps24:
            return "24 fps"
        case .fps25:
            return "25 fps"
        case .fps29_97:
            return "29.97 fps"
        case .fps30:
            return "30 fps"
        case .fps50:
            return "50 fps"
        case .fps59_94:
            return "59.94 fps"
        case .fps60:
            return "60 fps"
        case .custom(let frameDuration):
            return String(format: "%.3f fps", 1.0 / frameDuration.seconds)
        }
    }
}

// MARK: - Convenience Initializers

extension FrameRate {
    /// Creates a frame rate from an approximate frames-per-second value.
    ///
    /// Matches to the nearest standard frame rate if within 0.5% tolerance.
    /// If multiple rates match, returns the closest one.
    ///
    /// - Parameter fps: Approximate frames per second.
    /// - Returns: The matching standard frame rate, or a custom rate.
    public static func from(fps: Double) -> FrameRate {
        let standardRates: [FrameRate] = [
            .fps23_98, .fps24, .fps25, .fps29_97, .fps30,
            .fps50, .fps59_94, .fps60
        ]

        var bestMatch: FrameRate?
        var bestDifference = Double.infinity

        for rate in standardRates {
            let rateFps = rate.framesPerSecond
            let difference = abs(fps - rateFps)
            let tolerance = rateFps * 0.005  // 0.5% tolerance

            if difference < tolerance && difference < bestDifference {
                bestMatch = rate
                bestDifference = difference
            }
        }

        if let match = bestMatch {
            return match
        }

        // Create custom rate
        let frameDuration = Timecode(seconds: 1.0 / fps, preferredTimescale: 600000)
        return .custom(frameDuration: frameDuration)
    }
}
