//
//  ColorSpace.swift
//  SwiftSecuencia
//
//  Video color space definitions for FCPXML.
//

import Foundation

/// Video color space specification.
///
/// Color spaces define how color values are interpreted and displayed.
/// FCPXML uses specific identifiers for color space in format definitions.
///
/// ## Usage
///
/// ```swift
/// let format = VideoFormat(
///     width: 1920,
///     height: 1080,
///     frameRate: .fps24,
///     colorSpace: .rec709
/// )
/// ```
public enum ColorSpace: String, Sendable, Equatable, Hashable, Codable, CaseIterable {

    /// Rec. 709 (HD standard).
    ///
    /// Standard color space for HD video (1080p and below).
    /// FCPXML value: "1-1-1 (Rec. 709)"
    case rec709 = "rec709"

    /// Rec. 2020 (UHD/4K standard).
    ///
    /// Wide color gamut for UHD content.
    /// FCPXML value: "9-18-9 (Rec. 2020)"
    case rec2020 = "rec2020"

    /// Rec. 2020 HLG (HDR).
    ///
    /// Hybrid Log-Gamma HDR format.
    /// FCPXML value: "9-18-9 (Rec. 2020 HLG)"
    case rec2020HLG = "rec2020hlg"

    /// Rec. 2020 PQ (HDR).
    ///
    /// Perceptual Quantizer (Dolby Vision, HDR10).
    /// FCPXML value: "9-18-9 (Rec. 2020 PQ)"
    case rec2020PQ = "rec2020pq"

    /// sRGB (web standard).
    ///
    /// Standard RGB color space for web content.
    case sRGB = "srgb"

    // MARK: - FCPXML Representation

    /// The FCPXML colorSpace attribute value.
    public var fcpxmlValue: String {
        switch self {
        case .rec709:
            return "1-1-1 (Rec. 709)"
        case .rec2020:
            return "9-18-9 (Rec. 2020)"
        case .rec2020HLG:
            return "9-18-9 (Rec. 2020 HLG)"
        case .rec2020PQ:
            return "9-18-9 (Rec. 2020 PQ)"
        case .sRGB:
            return "sRGB IEC61966-2.1"
        }
    }

    /// Whether this is an HDR color space.
    public var isHDR: Bool {
        switch self {
        case .rec2020HLG, .rec2020PQ:
            return true
        default:
            return false
        }
    }

    /// Whether this is a wide color gamut.
    public var isWideGamut: Bool {
        switch self {
        case .rec2020, .rec2020HLG, .rec2020PQ:
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension ColorSpace: CustomStringConvertible {
    public var description: String {
        switch self {
        case .rec709:
            return "Rec. 709"
        case .rec2020:
            return "Rec. 2020"
        case .rec2020HLG:
            return "Rec. 2020 HLG"
        case .rec2020PQ:
            return "Rec. 2020 PQ"
        case .sRGB:
            return "sRGB"
        }
    }
}
