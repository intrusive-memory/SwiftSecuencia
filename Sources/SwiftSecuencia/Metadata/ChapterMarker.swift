//
//  ChapterMarker.swift
//  SwiftSecuencia
//
//  Chapter markers for video chapters and navigation.
//

import Foundation

/// A chapter marker for defining video chapters.
///
/// Chapter markers create navigable chapters in exported videos and are visible
/// in Final Cut Pro's timeline and viewer. They can include custom poster frames.
///
/// ## Basic Usage
///
/// ```swift
/// let intro = ChapterMarker(
///     start: Timecode.zero,
///     value: "Introduction"
/// )
///
/// let withPoster = ChapterMarker(
///     start: Timecode(seconds: 60),
///     value: "Chapter 1",
///     posterOffset: Timecode(seconds: 5)
/// )
/// ```
///
/// ## FCPXML Output
///
/// ```xml
/// <chapter-marker start="0s" value="Introduction"/>
/// <chapter-marker start="60s" value="Chapter 1" posterOffset="5s"/>
/// ```
public struct ChapterMarker: Sendable, Equatable, Hashable, Codable {

    /// The start time of the chapter marker relative to the parent element.
    public let start: Timecode

    /// The chapter title.
    public let value: String

    /// Optional offset for the poster frame (relative to start time).
    /// If nil, the poster frame is taken at the start time.
    public let posterOffset: Timecode?

    /// Optional note for the chapter.
    public let note: String?

    /// Creates a chapter marker.
    ///
    /// - Parameters:
    ///   - start: Start time of the chapter.
    ///   - value: Chapter title.
    ///   - posterOffset: Optional offset for poster frame (relative to start).
    ///   - note: Optional note.
    public init(
        start: Timecode,
        value: String,
        posterOffset: Timecode? = nil,
        note: String? = nil
    ) {
        self.start = start
        self.value = value
        self.posterOffset = posterOffset
        self.note = note
    }

    /// Generates the FCPXML element for this chapter marker.
    public func xmlElement() -> XMLElement {
        let element = XMLElement(name: "chapter-marker")
        element.addAttribute(XMLNode.attribute(withName: "start", stringValue: start.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "value", stringValue: value) as! XMLNode)

        if let posterOffset = posterOffset {
            element.addAttribute(XMLNode.attribute(withName: "posterOffset", stringValue: posterOffset.fcpxmlString) as! XMLNode)
        }

        if let note = note {
            element.addAttribute(XMLNode.attribute(withName: "note", stringValue: note) as! XMLNode)
        }

        return element
    }
}
