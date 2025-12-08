// SwiftSecuencia - A Swift library for generating Final Cut Pro FCPXML timelines
// Copyright (c) 2024. All rights reserved.

import Foundation

/// SwiftSecuencia: A Swift library for creating and exporting Final Cut Pro X timelines via FCPXML.
///
/// This library provides a type-safe, Swift-native API for constructing FCPXML documents
/// that can be imported into Final Cut Pro X.
///
/// ## Overview
///
/// SwiftSecuencia models the FCPXML document structure using Swift types, allowing you to:
/// - Create timelines programmatically
/// - Define media assets and their properties
/// - Build sequences with clips, transitions, and effects
/// - Export valid FCPXML files for Final Cut Pro import
///
/// ## Basic Usage
///
/// ```swift
/// import SwiftSecuencia
///
/// // Create a new FCPXML document
/// var document = FCPXMLDocument()
///
/// // Define a video format
/// let format = Format(
///     id: "r1",
///     name: "FFVideoFormat1080p2398",
///     frameDuration: CMTime(value: 1001, timescale: 24000),
///     width: 1920,
///     height: 1080
/// )
/// document.resources.formats.append(format)
///
/// // Add an asset
/// let asset = Asset(
///     id: "r2",
///     name: "Interview_A",
///     src: URL(fileURLWithPath: "/path/to/media.mov"),
///     duration: CMTime(seconds: 60, preferredTimescale: 24000),
///     hasVideo: true,
///     hasAudio: true,
///     formatRef: "r1"
/// )
/// document.resources.assets.append(asset)
///
/// // Create a project with a sequence
/// let sequence = Sequence(formatRef: "r1")
/// sequence.spine.append(
///     AssetClip(ref: "r2", duration: CMTime(seconds: 30, preferredTimescale: 24000))
/// )
///
/// let project = Project(name: "My Project", sequence: sequence)
/// let event = Event(name: "My Event", items: [.project(project)])
/// document.library = Library(events: [event])
///
/// // Export to FCPXML
/// let xmlString = try document.fcpxmlString()
/// ```
public struct SwiftSecuencia {
    /// The current version of the SwiftSecuencia library.
    public static let version = "1.0.4"

    /// The default FCPXML version produced by this library.
    public static let defaultFCPXMLVersion = "1.11"

    /// Supported FCPXML versions for export.
    public static let supportedVersions = ["1.8", "1.9", "1.10", "1.11"]
}
