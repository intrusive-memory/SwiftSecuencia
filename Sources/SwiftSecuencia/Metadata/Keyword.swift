//
//  Keyword.swift
//  SwiftSecuencia
//
//  Keywords for tagging and organizing timeline content.
//

import Foundation
import FoundationXML

/// A keyword for tagging clips and ranges in the timeline.
///
/// Keywords are used to organize and search content in Final Cut Pro.
/// They can be applied to entire clips or specific ranges within clips.
///
/// ## Basic Usage
///
/// ```swift
/// // Keyword for entire clip
/// let interview = Keyword(
///     start: Timecode.zero,
///     duration: Timecode(seconds: 300),
///     value: "Interview"
/// )
///
/// // Keyword for specific range
/// let bRoll = Keyword(
///     start: Timecode(seconds: 10),
///     duration: Timecode(seconds: 20),
///     value: "B-Roll",
///     note: "Exterior shots"
/// )
/// ```
///
/// ## FCPXML Output
///
/// ```xml
/// <keyword start="0s" duration="300s" value="Interview"/>
/// <keyword start="10s" duration="20s" value="B-Roll" note="Exterior shots"/>
/// ```
public struct Keyword: Sendable, Equatable, Hashable, Codable {

    /// The start time of the keyword relative to the parent element.
    public let start: Timecode

    /// The duration of the keyword range.
    public let duration: Timecode

    /// The keyword value (tag name).
    public let value: String

    /// Optional note for the keyword.
    public let note: String?

    /// Creates a keyword.
    ///
    /// - Parameters:
    ///   - start: Start time of the keyword range.
    ///   - duration: Duration of the keyword range.
    ///   - value: Keyword tag name.
    ///   - note: Optional note.
    public init(
        start: Timecode,
        duration: Timecode,
        value: String,
        note: String? = nil
    ) {
        self.start = start
        self.duration = duration
        self.value = value
        self.note = note
    }

    /// Generates the FCPXML element for this keyword.
    public func xmlElement() -> XMLElement {
        let element = XMLElement(name: "keyword")
        element.addAttribute(XMLNode.attribute(withName: "start", stringValue: start.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: duration.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "value", stringValue: value) as! XMLNode)

        if let note = note {
            element.addAttribute(XMLNode.attribute(withName: "note", stringValue: note) as! XMLNode)
        }

        return element
    }
}
