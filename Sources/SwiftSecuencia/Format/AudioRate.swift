//
//  AudioRate.swift
//  SwiftSecuencia
//
//  Audio sample rate definitions for FCPXML.
//

import Foundation

/// Audio sample rate for FCPXML assets and sequences.
///
/// Defines the number of audio samples per second.
/// Common rates are 44.1kHz (CD quality) and 48kHz (professional video).
///
/// ## Usage
///
/// ```swift
/// let asset = Asset(
///     id: "r2",
///     name: "Interview",
///     audioChannels: 2,
///     audioRate: .rate48kHz
/// )
/// ```
public enum AudioRate: Int, Sendable, Equatable, Hashable, Codable, CaseIterable {

    /// 44.1 kHz (CD quality, consumer audio).
    case rate44_1kHz = 44100

    /// 48 kHz (professional video standard).
    case rate48kHz = 48000

    /// 88.2 kHz (high-resolution audio).
    case rate88_2kHz = 88200

    /// 96 kHz (high-resolution professional audio).
    case rate96kHz = 96000

    // MARK: - Properties

    /// The sample rate in Hz.
    public var sampleRate: Int {
        rawValue
    }

    /// The FCPXML audioRate attribute value as a string.
    public var fcpxmlValue: String {
        "\(rawValue)"
    }

    /// The sample rate formatted with units (e.g., "48 kHz").
    public var formattedString: String {
        let kHz = Double(rawValue) / 1000.0
        if kHz.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(kHz)) kHz"
        } else {
            return String(format: "%.1f kHz", kHz)
        }
    }
}

// MARK: - CustomStringConvertible

extension AudioRate: CustomStringConvertible {
    public var description: String {
        formattedString
    }
}

// MARK: - Convenience Initializers

extension AudioRate {
    /// Creates an audio rate from a sample rate value.
    ///
    /// - Parameter sampleRate: The sample rate in Hz.
    /// - Returns: The matching standard rate, or nil if not a standard rate.
    public init?(sampleRate: Int) {
        self.init(rawValue: sampleRate)
    }

    /// Creates an audio rate from an approximate sample rate value.
    ///
    /// Matches to the nearest standard rate if within 1% tolerance.
    ///
    /// - Parameter approximateSampleRate: Approximate sample rate in Hz.
    /// - Returns: The matching standard rate, or nil if no match.
    public static func from(approximateSampleRate: Int) -> AudioRate? {
        for rate in AudioRate.allCases {
            let tolerance = rate.sampleRate / 100  // 1% tolerance
            if abs(approximateSampleRate - rate.sampleRate) <= tolerance {
                return rate
            }
        }
        return nil
    }
}
