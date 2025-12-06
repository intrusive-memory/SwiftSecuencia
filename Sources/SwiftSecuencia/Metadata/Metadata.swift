//
//  Metadata.swift
//  SwiftSecuencia
//
//  Custom metadata container for clips and projects.
//

import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

/// A container for custom metadata key-value pairs.
///
/// The Metadata type stores arbitrary key-value metadata that can be attached
/// to clips, projects, and other timeline elements. Common keys include:
/// - `com.apple.proapps.studio.reel` - Reel number
/// - `com.apple.proapps.studio.scene` - Scene number
/// - `com.apple.proapps.studio.take` - Take number
/// - `com.apple.proapps.spotlight.kMDItemDescription` - Description
///
/// ## Basic Usage
///
/// ```swift
/// var metadata = Metadata()
/// metadata["com.apple.proapps.studio.reel"] = "A001"
/// metadata["com.apple.proapps.studio.scene"] = "1"
/// metadata["com.apple.proapps.studio.take"] = "3"
/// metadata["com.apple.proapps.spotlight.kMDItemDescription"] = "Interview with subject"
/// ```
///
/// ## FCPXML Output
///
/// ```xml
/// <metadata>
///     <md key="com.apple.proapps.studio.reel" value="A001"/>
///     <md key="com.apple.proapps.studio.scene" value="1"/>
///     <md key="com.apple.proapps.studio.take" value="3"/>
///     <md key="com.apple.proapps.spotlight.kMDItemDescription" value="Interview with subject"/>
/// </metadata>
/// ```
public struct Metadata: Sendable, Equatable, Hashable, Codable {

    /// The metadata key-value pairs.
    public var entries: [String: String]

    /// Creates an empty metadata container.
    public init() {
        self.entries = [:]
    }

    /// Creates a metadata container with the given entries.
    ///
    /// - Parameter entries: Dictionary of metadata key-value pairs.
    public init(entries: [String: String]) {
        self.entries = entries
    }

    /// Accesses metadata values by key.
    public subscript(key: String) -> String? {
        get { entries[key] }
        set { entries[key] = newValue }
    }

    /// Whether the metadata container is empty.
    public var isEmpty: Bool {
        entries.isEmpty
    }

    /// Generates the FCPXML element for this metadata container.
    public func xmlElement() -> XMLElement {
        let element = XMLElement(name: "metadata")

        // Sort keys for deterministic output
        let sortedKeys = entries.keys.sorted()

        for key in sortedKeys {
            guard let value = entries[key] else { continue }

            let mdElement = XMLElement(name: "md")
            mdElement.addAttribute(XMLNode.attribute(withName: "key", stringValue: key) as! XMLNode)
            mdElement.addAttribute(XMLNode.attribute(withName: "value", stringValue: value) as! XMLNode)
            element.addChild(mdElement)
        }

        return element
    }
}

// MARK: - Common Metadata Keys

extension Metadata {

    /// Common metadata key constants.
    public enum Key {
        /// Reel number (e.g., "A001").
        public static let reel = "com.apple.proapps.studio.reel"

        /// Scene number (e.g., "1").
        public static let scene = "com.apple.proapps.studio.scene"

        /// Take number (e.g., "3").
        public static let take = "com.apple.proapps.studio.take"

        /// Description.
        public static let description = "com.apple.proapps.spotlight.kMDItemDescription"

        /// Camera name.
        public static let cameraName = "com.apple.proapps.studio.cameraName"

        /// Camera angle.
        public static let cameraAngle = "com.apple.proapps.studio.cameraAngle"

        /// Shot type.
        public static let shotType = "com.apple.proapps.studio.shotType"
    }

    /// Sets the reel number.
    public mutating func setReel(_ value: String) {
        self[Key.reel] = value
    }

    /// Sets the scene number.
    public mutating func setScene(_ value: String) {
        self[Key.scene] = value
    }

    /// Sets the take number.
    public mutating func setTake(_ value: String) {
        self[Key.take] = value
    }

    /// Sets the description.
    public mutating func setDescription(_ value: String) {
        self[Key.description] = value
    }

    /// Sets the camera name.
    public mutating func setCameraName(_ value: String) {
        self[Key.cameraName] = value
    }

    /// Sets the camera angle.
    public mutating func setCameraAngle(_ value: String) {
        self[Key.cameraAngle] = value
    }

    /// Sets the shot type.
    public mutating func setShotType(_ value: String) {
        self[Key.shotType] = value
    }
}
