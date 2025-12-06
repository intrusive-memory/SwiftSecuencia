//
//  Rating.swift
//  SwiftSecuencia
//
//  Ratings for marking favorite or rejected content.
//

import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

/// A rating for marking clips as favorites or rejected.
///
/// Ratings are used to mark content quality and organization in Final Cut Pro.
/// Common values are "favorite" and "rejected".
///
/// ## Basic Usage
///
/// ```swift
/// // Mark clip as favorite
/// let favorite = Rating(
///     start: Timecode.zero,
///     duration: Timecode(seconds: 300),
///     value: .favorite,
///     note: "Best take"
/// )
///
/// // Mark section as rejected
/// let rejected = Rating(
///     start: Timecode(seconds: 10),
///     duration: Timecode(seconds: 5),
///     value: .rejected
/// )
/// ```
///
/// ## FCPXML Output
///
/// ```xml
/// <rating start="0s" duration="300s" value="favorite" note="Best take"/>
/// <rating start="10s" duration="5s" value="rejected"/>
/// ```
public struct Rating: Sendable, Equatable, Hashable, Codable {

    /// Rating value types.
    public enum RatingValue: String, Sendable, Equatable, Hashable, Codable {
        case favorite = "favorite"
        case rejected = "rejected"
    }

    /// The start time of the rating relative to the parent element.
    public let start: Timecode

    /// The duration of the rated range.
    public let duration: Timecode

    /// The rating value (favorite or rejected).
    public let value: RatingValue

    /// Optional note for the rating.
    public let note: String?

    /// Creates a rating.
    ///
    /// - Parameters:
    ///   - start: Start time of the rated range.
    ///   - duration: Duration of the rated range.
    ///   - value: Rating value (favorite or rejected).
    ///   - note: Optional note.
    public init(
        start: Timecode,
        duration: Timecode,
        value: RatingValue,
        note: String? = nil
    ) {
        self.start = start
        self.duration = duration
        self.value = value
        self.note = note
    }

    /// Generates the FCPXML element for this rating.
    public func xmlElement() -> XMLElement {
        let element = XMLElement(name: "rating")
        element.addAttribute(XMLNode.attribute(withName: "start", stringValue: start.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: duration.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "value", stringValue: value.rawValue) as! XMLNode)

        if let note = note {
            element.addAttribute(XMLNode.attribute(withName: "note", stringValue: note) as! XMLNode)
        }

        return element
    }
}
