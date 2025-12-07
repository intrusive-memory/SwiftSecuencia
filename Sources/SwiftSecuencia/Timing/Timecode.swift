//
//  Timecode.swift
//  SwiftSecuencia
//
//  Rational time representation for FCPXML using TimecodeKit.
//

import Foundation
import SwiftTimecode

/// Represents a point in time or duration using rational numbers.
///
/// FCPXML uses rational time values (numerator/denominator) for frame-accurate timing.
/// This type wraps TimecodeKit's `Fraction` type to provide SMPTE-compliant timing.
///
/// ## FCPXML Format
///
/// Time values in FCPXML are expressed as rational numbers with an 's' suffix:
/// - `"1001/30000s"` - One frame at 29.97fps
/// - `"100/2400s"` - One frame at 24fps
/// - `"5s"` - Five seconds (simplified)
///
/// ## Usage
///
/// ```swift
/// // From seconds
/// let fiveSeconds = Timecode(seconds: 5.0)
///
/// // From rational value
/// let oneFrame = Timecode(value: 1001, timescale: 30000)
///
/// // From frame count
/// let tenFrames = Timecode(frames: 10, frameRate: .fps24)
///
/// // Arithmetic
/// let total = clipA.duration + clipB.duration
/// ```
public struct Timecode: Sendable, Equatable, Hashable, Codable {

    // MARK: - Properties

    /// The underlying rational time value.
    internal let fraction: Fraction

    /// The numerator of the rational time value.
    public var value: Int64 {
        Int64(fraction.numerator)
    }

    /// The denominator of the rational time value (ticks per second).
    public var timescale: Int32 {
        Int32(fraction.denominator)
    }

    // MARK: - Computed Properties

    /// The time value in seconds.
    public var seconds: Double {
        fraction.doubleValue
    }

    /// The FCPXML string representation.
    ///
    /// Returns simplified format when possible:
    /// - `"0s"` for zero
    /// - `"5s"` for whole seconds
    /// - `"1001/30000s"` for fractional values
    public var fcpxmlString: String {
        fraction.fcpxmlStringValue
    }

    // MARK: - Static Properties

    /// Zero timecode.
    public static let zero = Timecode(value: 0, timescale: 1)

    // MARK: - Initialization

    /// Creates a timecode from a `Fraction`.
    ///
    /// - Parameter fraction: The rational time value.
    internal init(fraction: Fraction) {
        self.fraction = fraction
    }

    /// Creates a timecode from a rational value.
    ///
    /// - Parameters:
    ///   - value: The numerator (number of ticks).
    ///   - timescale: The denominator (ticks per second).
    public init(value: Int64, timescale: Int32) {
        precondition(timescale > 0, "Timescale must be positive")
        self.fraction = Fraction(Int(value), Int(timescale))
    }

    /// Creates a timecode from seconds.
    ///
    /// - Parameters:
    ///   - seconds: The time in seconds.
    ///   - preferredTimescale: The timescale to use (default: 600, divisible by common frame rates).
    public init(seconds: Double, preferredTimescale: Int32 = 600) {
        precondition(preferredTimescale > 0, "Timescale must be positive")
        let value = Int(seconds * Double(preferredTimescale))
        self.fraction = Fraction(value, Int(preferredTimescale))
    }

    /// Creates a timecode from a frame count and frame rate.
    ///
    /// - Parameters:
    ///   - frames: The number of frames.
    ///   - frameRate: The frame rate.
    public init(frames: Int, frameRate: FrameRate) {
        let frameDuration = frameRate.frameDuration
        self.fraction = Fraction(frames * Int(frameDuration.value), Int(frameDuration.timescale))
    }

    // MARK: - Arithmetic

    /// Adds two timecodes.
    public static func + (lhs: Timecode, rhs: Timecode) -> Timecode {
        Timecode(fraction: lhs.fraction + rhs.fraction)
    }

    /// Subtracts two timecodes.
    public static func - (lhs: Timecode, rhs: Timecode) -> Timecode {
        Timecode(fraction: lhs.fraction - rhs.fraction)
    }

    /// Multiplies a timecode by a scalar.
    public static func * (lhs: Timecode, rhs: Int) -> Timecode {
        Timecode(fraction: lhs.fraction * Fraction(rhs, 1))
    }

    /// Multiplies a timecode by a scalar.
    public static func * (lhs: Int, rhs: Timecode) -> Timecode {
        rhs * lhs
    }
}

// MARK: - Equatable & Hashable

extension Timecode {
    public static func == (lhs: Timecode, rhs: Timecode) -> Bool {
        lhs.fraction == rhs.fraction
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(fraction)
    }
}

// MARK: - Comparable

extension Timecode: Comparable {
    public static func < (lhs: Timecode, rhs: Timecode) -> Bool {
        lhs.fraction < rhs.fraction
    }
}

// MARK: - CustomStringConvertible

extension Timecode: CustomStringConvertible {
    public var description: String {
        fcpxmlString
    }
}

// MARK: - Parsing

extension Timecode {
    /// Creates a timecode from an FCPXML string.
    ///
    /// - Parameter fcpxmlString: A string like "1001/30000s" or "5s".
    /// - Returns: The parsed timecode, or nil if parsing fails.
    public init?(fcpxmlString: String) {
        guard let frac = Fraction(fcpxmlString: fcpxmlString) else {
            return nil
        }
        self.fraction = frac
    }
}

// MARK: - Frame Alignment

extension Timecode {
    /// Creates a frame-aligned timecode from seconds using a specific frame rate.
    ///
    /// This ensures the resulting timecode aligns with frame boundaries, which is required
    /// for FCPXML export. The timecode is rounded to the nearest frame.
    ///
    /// - Parameters:
    ///   - seconds: The time in seconds.
    ///   - frameRate: The frame rate to align to.
    /// - Returns: A timecode aligned to frame boundaries.
    public static func frameAligned(seconds: Double, frameRate: FrameRate) -> Timecode {
        // Calculate the number of frames (rounded to nearest)
        let fps = frameRate.framesPerSecond
        let frameCount = Int((seconds * fps).rounded())

        // Create timecode from frame count
        return Timecode(frames: frameCount, frameRate: frameRate)
    }

    /// Converts this timecode to a frame-aligned timecode for the given frame rate.
    ///
    /// This rounds the timecode to the nearest frame boundary.
    ///
    /// - Parameter frameRate: The frame rate to align to.
    /// - Returns: A frame-aligned timecode.
    public func aligned(to frameRate: FrameRate) -> Timecode {
        Timecode.frameAligned(seconds: self.seconds, frameRate: frameRate)
    }
}

// MARK: - Codable

extension Timecode {
    enum CodingKeys: String, CodingKey {
        case value
        case timescale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int64.self, forKey: .value)
        let timescale = try container.decode(Int32.self, forKey: .timescale)
        self.fraction = Fraction(Int(value), Int(timescale))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(timescale, forKey: .timescale)
    }
}
