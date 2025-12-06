//
//  Timecode.swift
//  SwiftSecuencia
//
//  Rational time representation for FCPXML.
//

import Foundation

/// Represents a point in time or duration using rational numbers.
///
/// FCPXML uses rational time values (numerator/denominator) for frame-accurate timing.
/// This type provides conversions to/from various time representations while maintaining
/// precision for video frame rates.
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

    /// The numerator of the rational time value.
    public let value: Int64

    /// The denominator of the rational time value (ticks per second).
    public let timescale: Int32

    // MARK: - Computed Properties

    /// The time value in seconds.
    public var seconds: Double {
        guard timescale != 0 else { return 0 }
        return Double(value) / Double(timescale)
    }

    /// The FCPXML string representation.
    ///
    /// Returns simplified format when possible:
    /// - `"0s"` for zero
    /// - `"5s"` for whole seconds
    /// - `"1001/30000s"` for fractional values
    public var fcpxmlString: String {
        if value == 0 {
            return "0s"
        }

        // Simplify the fraction
        let (simplifiedValue, simplifiedTimescale) = simplified

        // If timescale is 1, just return the value
        if simplifiedTimescale == 1 {
            return "\(simplifiedValue)s"
        }

        // Check if it represents a whole number of seconds
        if simplifiedValue % Int64(simplifiedTimescale) == 0 {
            return "\(simplifiedValue / Int64(simplifiedTimescale))s"
        }

        return "\(simplifiedValue)/\(simplifiedTimescale)s"
    }

    /// Returns the simplified (reduced) fraction.
    private var simplified: (value: Int64, timescale: Int32) {
        let divisor = gcd(abs(value), Int64(abs(timescale)))
        guard divisor > 0 else { return (value, timescale) }
        return (value / divisor, Int32(Int64(timescale) / divisor))
    }

    // MARK: - Static Properties

    /// Zero timecode.
    public static let zero = Timecode(value: 0, timescale: 1)

    // MARK: - Initialization

    /// Creates a timecode from a rational value.
    ///
    /// - Parameters:
    ///   - value: The numerator (number of ticks).
    ///   - timescale: The denominator (ticks per second).
    public init(value: Int64, timescale: Int32) {
        precondition(timescale > 0, "Timescale must be positive")
        self.value = value
        self.timescale = timescale
    }

    /// Creates a timecode from seconds.
    ///
    /// - Parameters:
    ///   - seconds: The time in seconds.
    ///   - preferredTimescale: The timescale to use (default: 600, divisible by common frame rates).
    public init(seconds: Double, preferredTimescale: Int32 = 600) {
        precondition(preferredTimescale > 0, "Timescale must be positive")
        self.value = Int64(seconds * Double(preferredTimescale))
        self.timescale = preferredTimescale
    }

    /// Creates a timecode from a frame count and frame rate.
    ///
    /// - Parameters:
    ///   - frames: The number of frames.
    ///   - frameRate: The frame rate.
    public init(frames: Int, frameRate: FrameRate) {
        let frameDuration = frameRate.frameDuration
        self.value = Int64(frames) * frameDuration.value
        self.timescale = frameDuration.timescale
    }

    // MARK: - Arithmetic

    /// Adds two timecodes.
    public static func + (lhs: Timecode, rhs: Timecode) -> Timecode {
        // Find common timescale (LCM)
        let commonTimescale = lcm(Int64(lhs.timescale), Int64(rhs.timescale))
        let lhsScaled = lhs.value * (commonTimescale / Int64(lhs.timescale))
        let rhsScaled = rhs.value * (commonTimescale / Int64(rhs.timescale))
        return Timecode(value: lhsScaled + rhsScaled, timescale: Int32(commonTimescale))
    }

    /// Subtracts two timecodes.
    public static func - (lhs: Timecode, rhs: Timecode) -> Timecode {
        let commonTimescale = lcm(Int64(lhs.timescale), Int64(rhs.timescale))
        let lhsScaled = lhs.value * (commonTimescale / Int64(lhs.timescale))
        let rhsScaled = rhs.value * (commonTimescale / Int64(rhs.timescale))
        return Timecode(value: lhsScaled - rhsScaled, timescale: Int32(commonTimescale))
    }

    /// Multiplies a timecode by a scalar.
    public static func * (lhs: Timecode, rhs: Int) -> Timecode {
        Timecode(value: lhs.value * Int64(rhs), timescale: lhs.timescale)
    }

    /// Multiplies a timecode by a scalar.
    public static func * (lhs: Int, rhs: Timecode) -> Timecode {
        rhs * lhs
    }
}

// MARK: - Equatable & Hashable

extension Timecode {
    public static func == (lhs: Timecode, rhs: Timecode) -> Bool {
        // Compare semantically: two timecodes are equal if they represent the same time
        // Separate integer and fractional parts to avoid overflow in cross-multiplication.
        let lhsQuotient = lhs.value / Int64(lhs.timescale)
        let lhsRemainder = lhs.value % Int64(lhs.timescale)

        let rhsQuotient = rhs.value / Int64(rhs.timescale)
        let rhsRemainder = rhs.value % Int64(rhs.timescale)

        if lhsQuotient != rhsQuotient {
            return false
        }

        // Integer parts are equal, so compare fractional parts.
        // This cross-multiplication is safe from overflow because remainders are smaller than timescales.
        return lhsRemainder * Int64(rhs.timescale) == rhsRemainder * Int64(lhs.timescale)
    }

    public func hash(into hasher: inout Hasher) {
        // Hash the simplified form to ensure equal timecodes have equal hashes
        let (simplifiedValue, simplifiedTimescale) = simplified
        hasher.combine(simplifiedValue)
        hasher.combine(simplifiedTimescale)
    }
}

// MARK: - Comparable

extension Timecode: Comparable {
    public static func < (lhs: Timecode, rhs: Timecode) -> Bool {
        // Separate integer and fractional parts to avoid overflow in cross-multiplication.
        let lhsQuotient = lhs.value / Int64(lhs.timescale)
        let lhsRemainder = lhs.value % Int64(lhs.timescale)

        let rhsQuotient = rhs.value / Int64(rhs.timescale)
        let rhsRemainder = rhs.value % Int64(rhs.timescale)

        if lhsQuotient != rhsQuotient {
            return lhsQuotient < rhsQuotient
        }

        // Integer parts are equal, so compare fractional parts.
        // This cross-multiplication is safe from overflow because remainders are smaller than timescales.
        return lhsRemainder * Int64(rhs.timescale) < rhsRemainder * Int64(lhs.timescale)
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
        var str = fcpxmlString.trimmingCharacters(in: .whitespaces)

        // Must end with 's'
        guard str.hasSuffix("s") else { return nil }
        str.removeLast()

        // Check for fraction
        if let slashIndex = str.firstIndex(of: "/") {
            let valueStr = String(str[..<slashIndex])
            let timescaleStr = String(str[str.index(after: slashIndex)...])

            guard let value = Int64(valueStr),
                  let timescale = Int32(timescaleStr),
                  timescale > 0 else {
                return nil
            }

            self.value = value
            self.timescale = timescale
        } else {
            // Whole seconds
            guard let seconds = Int64(str) else { return nil }
            self.value = seconds
            self.timescale = 1
        }
    }
}

// MARK: - Math Helpers

/// Greatest common divisor using Euclidean algorithm.
private func gcd(_ a: Int64, _ b: Int64) -> Int64 {
    var a = a
    var b = b
    while b != 0 {
        let temp = b
        b = a % b
        a = temp
    }
    return a
}

/// Least common multiple.
private func lcm(_ a: Int64, _ b: Int64) -> Int64 {
    guard a != 0 && b != 0 else { return 0 }
    return abs(a * b) / gcd(a, b)
}
