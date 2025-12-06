//
//  VideoFormat.swift
//  SwiftSecuencia
//
//  Video format specification for FCPXML.
//

import Foundation

/// Video format configuration for FCPXML sequences and clips.
///
/// VideoFormat combines resolution, frame rate, and color space to define
/// how video content is rendered in Final Cut Pro.
///
/// ## Common Formats
///
/// | Name | Resolution | Frame Rate | Use Case |
/// |------|------------|------------|----------|
/// | 1080p24 | 1920×1080 | 23.98 fps | Film/Cinema |
/// | 1080p30 | 1920×1080 | 29.97 fps | NTSC Broadcast |
/// | 4K24 | 3840×2160 | 23.98 fps | UHD Film |
/// | 4K30 | 3840×2160 | 29.97 fps | UHD Broadcast |
///
/// ## Usage
///
/// ```swift
/// // Standard HD format
/// let hdFormat = VideoFormat.hd1080p(frameRate: .fps23_98)
///
/// // Custom format
/// let customFormat = VideoFormat(
///     width: 1920,
///     height: 1080,
///     frameRate: .fps24,
///     colorSpace: .rec709
/// )
///
/// // FCPXML format ID
/// let formatId = customFormat.fcpxmlFormatId  // "r1"
/// let formatName = customFormat.fcpxmlFormatName  // "FFVideoFormat1080p24"
/// ```
public struct VideoFormat: Sendable, Equatable, Hashable, Codable {

    // MARK: - Properties

    /// Frame width in pixels.
    public let width: Int

    /// Frame height in pixels.
    public let height: Int

    /// Frame rate.
    public let frameRate: FrameRate

    /// Color space.
    public let colorSpace: ColorSpace

    /// Progressive (false) or interlaced (true) scanning.
    public let interlaced: Bool

    // MARK: - Computed Properties

    /// The aspect ratio as width/height.
    public var aspectRatio: Double {
        guard height > 0 else { return 0 }
        return Double(width) / Double(height)
    }

    /// The frame duration from the frame rate.
    public var frameDuration: Timecode {
        frameRate.frameDuration
    }

    /// Whether this is a standard HD resolution (1920×1080 or 1280×720).
    public var isHD: Bool {
        (width == 1920 && height == 1080) ||
        (width == 1280 && height == 720)
    }

    /// Whether this is a 4K/UHD resolution (3840×2160 or 4096×2160).
    public var isUHD: Bool {
        (width == 3840 && height == 2160) ||
        (width == 4096 && height == 2160)
    }

    /// The FCPXML format name (e.g., "FFVideoFormat1080p2398").
    public var fcpxmlFormatName: String {
        let heightStr: String
        if height == 2160 {
            heightStr = width == 4096 ? "4096x2160" : "2160"
        } else if height == 1080 {
            heightStr = "1080"
        } else if height == 720 {
            heightStr = "720"
        } else {
            heightStr = "\(width)x\(height)"
        }

        let scanType = interlaced ? "i" : "p"
        return "FFVideoFormat\(heightStr)\(scanType)\(frameRate.fcpxmlSuffix)"
    }

    // MARK: - Initialization

    /// Creates a video format with the specified parameters.
    ///
    /// - Parameters:
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    ///   - frameRate: The frame rate.
    ///   - colorSpace: The color space (default: rec709).
    ///   - interlaced: Whether the format is interlaced (default: false).
    public init(
        width: Int,
        height: Int,
        frameRate: FrameRate,
        colorSpace: ColorSpace = .rec709,
        interlaced: Bool = false
    ) {
        precondition(width > 0, "Width must be positive")
        precondition(height > 0, "Height must be positive")
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.colorSpace = colorSpace
        self.interlaced = interlaced
    }
}

// MARK: - Standard Formats

extension VideoFormat {
    /// Creates a 1080p HD format.
    ///
    /// - Parameters:
    ///   - frameRate: The frame rate.
    ///   - colorSpace: The color space (default: rec709).
    /// - Returns: A 1920×1080 progressive format.
    public static func hd1080p(
        frameRate: FrameRate,
        colorSpace: ColorSpace = .rec709
    ) -> VideoFormat {
        VideoFormat(
            width: 1920,
            height: 1080,
            frameRate: frameRate,
            colorSpace: colorSpace
        )
    }

    /// Creates a 720p HD format.
    ///
    /// - Parameters:
    ///   - frameRate: The frame rate.
    ///   - colorSpace: The color space (default: rec709).
    /// - Returns: A 1280×720 progressive format.
    public static func hd720p(
        frameRate: FrameRate,
        colorSpace: ColorSpace = .rec709
    ) -> VideoFormat {
        VideoFormat(
            width: 1280,
            height: 720,
            frameRate: frameRate,
            colorSpace: colorSpace
        )
    }

    /// Creates a 4K UHD format (3840×2160).
    ///
    /// - Parameters:
    ///   - frameRate: The frame rate.
    ///   - colorSpace: The color space (default: rec2020).
    /// - Returns: A 3840×2160 progressive format.
    public static func uhd4K(
        frameRate: FrameRate,
        colorSpace: ColorSpace = .rec2020
    ) -> VideoFormat {
        VideoFormat(
            width: 3840,
            height: 2160,
            frameRate: frameRate,
            colorSpace: colorSpace
        )
    }

    /// Creates a DCI 4K format (4096×2160).
    ///
    /// - Parameters:
    ///   - frameRate: The frame rate.
    ///   - colorSpace: The color space (default: rec2020).
    /// - Returns: A 4096×2160 progressive format.
    public static func dci4K(
        frameRate: FrameRate,
        colorSpace: ColorSpace = .rec2020
    ) -> VideoFormat {
        VideoFormat(
            width: 4096,
            height: 2160,
            frameRate: frameRate,
            colorSpace: colorSpace
        )
    }
}

// MARK: - CustomStringConvertible

extension VideoFormat: CustomStringConvertible {
    public var description: String {
        let scanType = interlaced ? "i" : "p"
        return "\(width)×\(height)\(scanType) @ \(frameRate)"
    }
}
