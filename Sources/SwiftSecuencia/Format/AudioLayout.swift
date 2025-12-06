//
//  AudioLayout.swift
//  SwiftSecuencia
//
//  Audio channel layout definitions for FCPXML.
//

import Foundation

/// Audio channel layout for FCPXML sequences.
///
/// Defines the arrangement of audio channels in a sequence or clip.
/// FCPXML uses specific identifiers for audio layout in format definitions.
///
/// ## Usage
///
/// ```swift
/// let sequence = Sequence(
///     formatRef: "r1",
///     audioLayout: .stereo
/// )
/// ```
public enum AudioLayout: String, Sendable, Equatable, Hashable, Codable, CaseIterable {

    /// Mono (single channel).
    case mono = "mono"

    /// Stereo (left/right channels).
    case stereo = "stereo"

    /// Surround 5.1 (L, R, C, LFE, Ls, Rs).
    case surround = "surround"

    /// 7.1 Surround (L, R, C, LFE, Ls, Rs, Lb, Rb).
    case surround7_1 = "7.1 surround"

    // MARK: - Properties

    /// The number of audio channels for this layout.
    public var channelCount: Int {
        switch self {
        case .mono:
            return 1
        case .stereo:
            return 2
        case .surround:
            return 6
        case .surround7_1:
            return 8
        }
    }

    /// The FCPXML audioLayout attribute value.
    public var fcpxmlValue: String {
        rawValue
    }
}

// MARK: - CustomStringConvertible

extension AudioLayout: CustomStringConvertible {
    public var description: String {
        switch self {
        case .mono:
            return "Mono"
        case .stereo:
            return "Stereo"
        case .surround:
            return "5.1 Surround"
        case .surround7_1:
            return "7.1 Surround"
        }
    }
}
