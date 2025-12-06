//
//  Marker.swift
//  SwiftSecuencia
//
//  Standard timeline markers for annotations and notes.
//

import Foundation
import FoundationXML

/// A standard marker that annotates a specific point or range in the timeline.
///
/// Markers are used to add notes, reminders, or annotations to clips and timelines.
/// They appear as colored flags in Final Cut Pro's timeline.
///
/// ## Basic Usage
///
/// ```swift
/// // Point marker (1-frame duration)
/// let reviewMarker = Marker(
///     start: Timecode(seconds: 10),
///     value: "Review this section",
///     note: "Needs color correction"
/// )
///
/// // Range marker
/// let rangeMarker = Marker(
///     start: Timecode(seconds: 5),
///     duration: Timecode(seconds: 10),
///     value: "Interview segment",
///     completed: false
/// )
/// ```
///
/// ## FCPXML Output
///
/// ```xml
/// <marker start="10s" duration="1/24s" value="Review this section" note="Needs color correction"/>
/// ```
public struct Marker: Sendable, Equatable, Hashable, Codable {

    /// The start time of the marker relative to the parent element.
    public let start: Timecode

    /// The duration of the marker (default: 1 frame).
    /// For point markers, use a 1-frame duration.
    public let duration: Timecode

    /// The marker's display text.
    public let value: String

    /// Optional detailed note for the marker.
    public let note: String?

    /// Whether the marker is marked as completed (to-do markers).
    public let completed: Bool

    /// Creates a standard marker.
    ///
    /// - Parameters:
    ///   - start: Start time relative to parent element.
    ///   - duration: Duration of the marker (default: 1 frame at 24fps).
    ///   - value: Display text for the marker.
    ///   - note: Optional detailed note.
    ///   - completed: Whether marker is completed (default: false).
    public init(
        start: Timecode,
        duration: Timecode = Timecode(value: 1, timescale: 24),
        value: String,
        note: String? = nil,
        completed: Bool = false
    ) {
        self.start = start
        self.duration = duration
        self.value = value
        self.note = note
        self.completed = completed
    }

    /// Generates the FCPXML element for this marker.
    public func xmlElement() -> XMLElement {
        let element = XMLElement(name: "marker")
        element.addAttribute(XMLNode.attribute(withName: "start", stringValue: start.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: duration.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "value", stringValue: value) as! XMLNode)

        if let note = note {
            element.addAttribute(XMLNode.attribute(withName: "note", stringValue: note) as! XMLNode)
        }

        if completed {
            element.addAttribute(XMLNode.attribute(withName: "completed", stringValue: "1") as! XMLNode)
        }

        return element
    }
}
