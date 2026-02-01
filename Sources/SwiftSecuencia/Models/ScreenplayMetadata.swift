//
//  ScreenplayMetadata.swift
//  SwiftSecuencia
//
//  Screenplay-specific metadata for timeline clips generated from screenplay elements.
//

import Foundation

/// Screenplay-specific metadata for timeline clips.
///
/// This structure carries information about the original screenplay element
/// that generated audio for a timeline clip. It enables advanced features like:
/// - Dual dialogue detection and placement
/// - Character-based filtering
/// - Scene organization
/// - Element type tracking
///
/// ## Usage
///
/// ```swift
/// let metadata = ScreenplayMetadata(
///     elementType: "Dialogue",
///     characterName: "JOHN",
///     isDualDialogue: true,
///     dualDialogueIndex: 0,
///     dualDialogueGroupId: groupId,
///     sceneId: "INT. COFFEE SHOP - DAY"
/// )
///
/// // Convert to Timeline metadata
/// let timelineMetadata = metadata.toMetadata()
/// clip.metadata = timelineMetadata
///
/// // Restore from Timeline metadata
/// if let restored = ScreenplayMetadata.from(timelineMetadata) {
///     print("Character: \(restored.characterName ?? "Unknown")")
/// }
/// ```
public struct ScreenplayMetadata: Codable, Sendable, Equatable, Hashable {

    // MARK: - Element Information

    /// The type of screenplay element (e.g., "Dialogue", "Action", "Transition").
    public let elementType: String

    /// The character name for dialogue elements.
    public let characterName: String?

    // MARK: - Dual Dialogue Support

    /// Whether this element is part of a dual dialogue group.
    public let isDualDialogue: Bool

    /// The speaker index within a dual dialogue group (0, 1, 2...).
    ///
    /// Used to assign lanes:
    /// - 0 → lane 0 (first speaker)
    /// - 1 → lane 1 (second speaker)
    /// - 2 → lane 2 (third speaker)
    /// - etc.
    public let dualDialogueIndex: Int?

    /// Unique identifier for the dual dialogue group.
    ///
    /// All elements with the same groupId are placed at the same offset on different lanes.
    public let dualDialogueGroupId: UUID?

    // MARK: - Scene Organization

    /// Optional scene identifier for organizing clips by scene.
    public let sceneId: String?

    // MARK: - Initialization

    /// Creates screenplay metadata.
    ///
    /// - Parameters:
    ///   - elementType: Type of screenplay element (e.g., "Dialogue", "Action").
    ///   - characterName: Character name for dialogue elements (optional).
    ///   - isDualDialogue: Whether this is part of a dual dialogue group (default: false).
    ///   - dualDialogueIndex: Speaker index in dual dialogue (0, 1, 2...).
    ///   - dualDialogueGroupId: UUID grouping dual dialogue elements.
    ///   - sceneId: Optional scene identifier.
    public init(
        elementType: String,
        characterName: String? = nil,
        isDualDialogue: Bool = false,
        dualDialogueIndex: Int? = nil,
        dualDialogueGroupId: UUID? = nil,
        sceneId: String? = nil
    ) {
        self.elementType = elementType
        self.characterName = characterName
        self.isDualDialogue = isDualDialogue
        self.dualDialogueIndex = dualDialogueIndex
        self.dualDialogueGroupId = dualDialogueGroupId
        self.sceneId = sceneId
    }
}

// MARK: - Metadata Conversion

extension ScreenplayMetadata {

    /// Metadata key constants for screenplay-specific fields.
    private enum MetadataKey {
        static let elementType = "com.swiftsecuencia.screenplay.element-type"
        static let characterName = "com.swiftsecuencia.screenplay.character-name"
        static let isDualDialogue = "com.swiftsecuencia.screenplay.is-dual-dialogue"
        static let dualDialogueIndex = "com.swiftsecuencia.screenplay.dual-dialogue-index"
        static let dualDialogueGroupId = "com.swiftsecuencia.screenplay.dual-dialogue-group-id"
        static let sceneId = "com.swiftsecuencia.screenplay.scene-id"
    }

    /// Converts screenplay metadata to Timeline metadata format.
    ///
    /// The resulting Metadata object can be stored in `TimelineClip.metadata`.
    ///
    /// - Returns: Metadata object with screenplay-specific keys.
    public func toMetadata() -> Metadata {
        var entries: [String: String] = [:]

        entries[MetadataKey.elementType] = elementType

        if let characterName = characterName {
            entries[MetadataKey.characterName] = characterName
        }

        entries[MetadataKey.isDualDialogue] = isDualDialogue ? "true" : "false"

        if let index = dualDialogueIndex {
            entries[MetadataKey.dualDialogueIndex] = String(index)
        }

        if let groupId = dualDialogueGroupId {
            entries[MetadataKey.dualDialogueGroupId] = groupId.uuidString
        }

        if let sceneId = sceneId {
            entries[MetadataKey.sceneId] = sceneId
        }

        return Metadata(entries: entries)
    }

    /// Restores screenplay metadata from Timeline metadata format.
    ///
    /// - Parameter metadata: Metadata object from a TimelineClip.
    /// - Returns: ScreenplayMetadata if valid screenplay metadata is found, nil otherwise.
    public static func from(_ metadata: Metadata?) -> ScreenplayMetadata? {
        guard let metadata = metadata,
              let elementType = metadata[MetadataKey.elementType] else {
            return nil
        }

        let characterName = metadata[MetadataKey.characterName]

        let isDualDialogue = metadata[MetadataKey.isDualDialogue] == "true"

        let dualDialogueIndex: Int? = {
            guard let indexStr = metadata[MetadataKey.dualDialogueIndex],
                  let index = Int(indexStr) else {
                return nil
            }
            return index
        }()

        let dualDialogueGroupId: UUID? = {
            guard let uuidStr = metadata[MetadataKey.dualDialogueGroupId],
                  let uuid = UUID(uuidString: uuidStr) else {
                return nil
            }
            return uuid
        }()

        let sceneId = metadata[MetadataKey.sceneId]

        return ScreenplayMetadata(
            elementType: elementType,
            characterName: characterName,
            isDualDialogue: isDualDialogue,
            dualDialogueIndex: dualDialogueIndex,
            dualDialogueGroupId: dualDialogueGroupId,
            sceneId: sceneId
        )
    }
}

// MARK: - Metadata Extension

extension Metadata {

    /// Extracts screenplay metadata from this metadata container.
    ///
    /// - Returns: ScreenplayMetadata if valid screenplay metadata is present, nil otherwise.
    public var screenplayMetadata: ScreenplayMetadata? {
        ScreenplayMetadata.from(self)
    }
}
