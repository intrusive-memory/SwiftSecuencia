//
//  FCPXMLExporter.swift
//  SwiftSecuencia
//
//  Exports Timeline to FCPXML format.
//

#if os(macOS)

import Foundation
import SwiftData
import SwiftCompartido
import PipelineNeo

/// Exports Timeline objects to FCPXML XML documents.
///
/// FCPXMLExporter generates valid FCPXML that can be imported into Final Cut Pro.
/// It converts the SwiftData Timeline and TimelineClip models into the hierarchical
/// XML structure required by FCPXML.
///
/// ## Basic Usage
///
/// ```swift
/// let exporter = FCPXMLExporter(version: .v1_13)
/// let xmlString = try await exporter.export(
///     timeline: myTimeline,
///     modelContext: context,
///     libraryName: "My Library",
///     eventName: "My Event"
/// )
/// try xmlString.write(to: fileURL, atomically: true, encoding: .utf8)
/// ```
///
/// ## FCPXML Structure
///
/// The exporter generates the following structure:
/// ```xml
/// <fcpxml version="1.13">
///   <resources>
///     <format id="r1" name="FFVideoFormat1080p2398" .../>
///     <asset id="r2" src="file://..." .../>
///   </resources>
///   <library>
///     <event name="My Event">
///       <project name="My Project">
///         <sequence format="r1">
///           <spine>
///             <asset-clip ref="r2" offset="0s" duration="30s" .../>
///           </spine>
///         </sequence>
///       </project>
///     </event>
///   </library>
/// </fcpxml>
/// ```
public struct FCPXMLExporter {

    /// The FCPXML version to generate.
    public let version: FCPXMLVersion

    /// Counter for generating unique resource IDs.
    private var resourceIDCounter = 0

    /// Creates an FCPXML exporter.
    ///
    /// - Parameter version: FCPXML version (default: .default, which is the latest version).
    public init(version: FCPXMLVersion = .default) {
        self.version = version
    }

    /// Exports a timeline to FCPXML format using an AssetProvider.
    ///
    /// - Parameters:
    ///   - timeline: The timeline to export.
    ///   - assetProvider: Provider for accessing asset metadata and file URLs.
    ///   - libraryName: Name for the library element (default: "Exported Library").
    ///   - eventName: Name for the event element (default: "Exported Event").
    ///   - projectName: Name for the project (default: timeline name).
    /// - Returns: FCPXML string representation.
    /// - Throws: Export errors if timeline is invalid or assets are missing.
    public mutating func export(
        timeline: Timeline,
        assetProvider: AssetProvider,
        libraryName: String = "Exported Library",
        eventName: String = "Exported Event",
        projectName: String? = nil
    ) throws -> String {
        // Task 5.2: Collect unique asset IDs from timeline clips
        let uniqueAssetIDs = Set(timeline.clips.map { $0.assetStorageId })

        // Task 5.3: Fetch metadata for each asset and generate format
        var resourceMap = LegacyResourceMap()
        var resourceElements: [XMLElement] = []

        // Add format resource
        let format = timeline.videoFormat ?? VideoFormat.hd1080p(frameRate: .fps23_98)
        let formatElement = try generateFormatElement(format: format, resourceMap: &resourceMap)
        resourceElements.append(formatElement)

        // Task 5.4 & 5.5: Generate asset elements with file URLs and hasVideo/hasAudio
        for assetID in uniqueAssetIDs {
            let assetElement = try generateAssetElement(
                assetID: assetID,
                assetProvider: assetProvider,
                resourceMap: &resourceMap,
                frameRate: format.frameRate
            )
            resourceElements.append(assetElement)
        }

        // Task 5.6: Complete document structure (library > event > project > sequence > spine)
        let event = XMLElement(name: "event")
        event.addAttribute(XMLNode.attribute(withName: "name", stringValue: eventName) as! XMLNode)

        let project = XMLElement(name: "project")
        let pName = projectName ?? timeline.name
        project.addAttribute(XMLNode.attribute(withName: "name", stringValue: pName) as! XMLNode)

        // Create sequence
        let sequence = try generateSequenceElementWithProvider(
            timeline: timeline,
            resourceMap: resourceMap,
            frameRate: format.frameRate
        )

        project.addChild(sequence)
        event.addChild(project)

        // Create FCPXML document using Pipeline's initializer
        let doc = XMLDocument(
            resources: resourceElements,
            events: [event],
            fcpxmlVersion: version
        )

        // Return formatted XML string
        return doc.fcpxmlString
    }

    /// Exports a timeline to FCPXML format using SwiftData assets (if available as files).
    ///
    /// **Important**: This method requires assets to have file references or creates temporary files
    /// from binary data. For purely in-memory SwiftData assets, use `FCPXMLBundleExporter` instead,
    /// which embeds media into the bundle.
    ///
    /// **CLI Usage**: CLI tools should use `FileAssetProvider` instead of this method.
    ///
    /// - Parameters:
    ///   - timeline: The timeline to export.
    ///   - modelContext: The model context to fetch assets from.
    ///   - libraryName: Name for the library element (default: "Exported Library").
    ///   - eventName: Name for the event element (default: "Exported Event").
    ///   - projectName: Name for the project (default: timeline name).
    /// - Returns: FCPXML string representation.
    /// - Throws: Export errors if timeline is invalid or assets are missing. Throws `AssetProviderError.dataNotSupported`
    ///   if assets don't have file URLs (use `FCPXMLBundleExporter` for embedded media instead).
    @MainActor
    public mutating func export(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        libraryName: String = "Exported Library",
        eventName: String = "Exported Event",
        projectName: String? = nil
    ) throws -> String {
        // Create SwiftDataAssetProvider - will throw if assets don't have file URLs
        let provider = SwiftDataAssetProvider(modelContext: modelContext)
        return try export(
            timeline: timeline,
            assetProvider: provider,
            libraryName: libraryName,
            eventName: eventName,
            projectName: projectName
        )
    }

    // MARK: - Resource Generation

    /// Generates a format XML element.
    private mutating func generateFormatElement(
        format: VideoFormat,
        resourceMap: inout LegacyResourceMap
    ) throws -> XMLElement {
        let formatID = nextResourceID()
        resourceMap.formatID = formatID

        let element = XMLElement(name: "format")
        element.addAttribute(XMLNode.attribute(withName: "id", stringValue: formatID) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "name", stringValue: format.fcpxmlFormatName) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "frameDuration", stringValue: format.frameDuration.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "width", stringValue: "\(format.width)") as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "height", stringValue: "\(format.height)") as! XMLNode)

        // Add colorSpace if not default
        let colorSpaceValue = format.colorSpace.fcpxmlValue
        if colorSpaceValue != "1-1-1 (Rec. 709)" {
            element.addAttribute(XMLNode.attribute(withName: "colorSpace", stringValue: colorSpaceValue) as! XMLNode)
        }

        return element
    }

    /// Generates an asset XML element using AssetProvider.
    private mutating func generateAssetElement(
        assetID: UUID,
        assetProvider: AssetProvider,
        resourceMap: inout LegacyResourceMap,
        frameRate: FrameRate
    ) throws -> XMLElement {
        // Fetch metadata from provider
        let metadata = try assetProvider.assetMetadata(for: assetID)

        let resourceID = nextResourceID()
        resourceMap.assetIDs[assetID] = resourceID

        let element = XMLElement(name: "asset")
        element.addAttribute(XMLNode.attribute(withName: "id", stringValue: resourceID) as! XMLNode)

        // Use metadata name
        if !metadata.name.isEmpty {
            element.addAttribute(XMLNode.attribute(withName: "name", stringValue: metadata.name) as! XMLNode)
        }

        // Add duration if available (frame-aligned)
        if let duration = metadata.durationSeconds {
            let timecode = Timecode.frameAligned(seconds: duration, frameRate: frameRate)
            element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: timecode.fcpxmlString) as! XMLNode)
        }

        // Task 5.5: Set hasVideo/hasAudio from metadata
        if metadata.hasVideo {
            element.addAttribute(XMLNode.attribute(withName: "hasVideo", stringValue: "1") as! XMLNode)
        }
        if metadata.hasAudio {
            element.addAttribute(XMLNode.attribute(withName: "hasAudio", stringValue: "1") as! XMLNode)
        }

        // Task 5.4: Get file URL from provider
        let fileURL = try assetProvider.assetFileURL(for: assetID)
        let srcURL = fileURL.path.hasPrefix("/") ? "file://\(fileURL.path)" : "file:///\(fileURL.path)"

        // Add required media-rep child element
        let mediaRep = XMLElement(name: "media-rep")
        mediaRep.addAttribute(XMLNode.attribute(withName: "kind", stringValue: "original-media") as! XMLNode)
        mediaRep.addAttribute(XMLNode.attribute(withName: "src", stringValue: srcURL) as! XMLNode)
        element.addChild(mediaRep)

        return element
    }

    /// Generates an asset XML element from TypedDataStorage (legacy method).
    /// This is kept for backward compatibility with FCPXMLBundleExporter.
    private mutating func generateAssetElement(
        asset: TypedDataStorage,
        resourceMap: inout LegacyResourceMap,
        frameRate: FrameRate
    ) throws -> XMLElement {
        let assetID = nextResourceID()
        resourceMap.assetIDs[asset.id] = assetID

        let element = XMLElement(name: "asset")
        element.addAttribute(XMLNode.attribute(withName: "id", stringValue: assetID) as! XMLNode)

        // Use prompt as name if available
        let prompt = asset.prompt
        if !prompt.isEmpty {
            element.addAttribute(XMLNode.attribute(withName: "name", stringValue: prompt) as! XMLNode)
        }

        // Add duration if available (frame-aligned)
        if let duration = asset.durationSeconds {
            let timecode = Timecode.frameAligned(seconds: duration, frameRate: frameRate)
            element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: timecode.fcpxmlString) as! XMLNode)
        }

        // Set hasVideo/hasAudio based on MIME type
        let mimeType = asset.mimeType
        if mimeType.hasPrefix("video/") {
            element.addAttribute(XMLNode.attribute(withName: "hasVideo", stringValue: "1") as! XMLNode)
            element.addAttribute(XMLNode.attribute(withName: "hasAudio", stringValue: "1") as! XMLNode)
        } else if mimeType.hasPrefix("audio/") {
            element.addAttribute(XMLNode.attribute(withName: "hasAudio", stringValue: "1") as! XMLNode)
        } else if mimeType.hasPrefix("image/") {
            element.addAttribute(XMLNode.attribute(withName: "hasVideo", stringValue: "1") as! XMLNode)
        }

        // Generate src URL from asset
        // For now, use a placeholder - real implementation would resolve file path from TypedDataStorage
        let srcURL = "file:///placeholder/\(asset.id.uuidString)"

        // Add required media-rep child element
        let mediaRep = XMLElement(name: "media-rep")
        mediaRep.addAttribute(XMLNode.attribute(withName: "kind", stringValue: "original-media") as! XMLNode)
        mediaRep.addAttribute(XMLNode.attribute(withName: "src", stringValue: srcURL) as! XMLNode)
        element.addChild(mediaRep)

        return element
    }

    // MARK: - Sequence Generation

    /// Generates a sequence XML element with spine and clips (AssetProvider version).
    private func generateSequenceElementWithProvider(
        timeline: Timeline,
        resourceMap: LegacyResourceMap,
        frameRate: FrameRate
    ) throws -> XMLElement {
        let element = XMLElement(name: "sequence")

        // Reference the format
        guard let formatID = resourceMap.formatID else {
            throw FCPXMLExportError.missingFormat
        }
        element.addAttribute(XMLNode.attribute(withName: "format", stringValue: formatID) as! XMLNode)

        // Add duration (frame-aligned)
        let alignedDuration = timeline.duration.aligned(to: frameRate)
        element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: alignedDuration.fcpxmlString) as! XMLNode)

        // Add tcStart (always 0 for now)
        element.addAttribute(XMLNode.attribute(withName: "tcStart", stringValue: "0s") as! XMLNode)

        // Generate spine
        let spine = try generateSpineElementWithProvider(timeline: timeline, resourceMap: resourceMap, frameRate: frameRate)
        element.addChild(spine)

        return element
    }

    /// Generates a spine XML element with all storyline clips (AssetProvider version).
    private func generateSpineElementWithProvider(
        timeline: Timeline,
        resourceMap: LegacyResourceMap,
        frameRate: FrameRate
    ) throws -> XMLElement {
        let element = XMLElement(name: "spine")

        // Get all clips sorted by offset then lane
        let allClips = timeline.sortedClips

        for clip in allClips {
            let clipElement = try generateAssetClipElement(clip: clip, resourceMap: resourceMap, frameRate: frameRate)
            element.addChild(clipElement)
        }

        return element
    }

    /// Generates a sequence XML element with spine and clips (legacy with ModelContext).
    private func generateSequenceElement(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        resourceMap: LegacyResourceMap,
        frameRate: FrameRate
    ) throws -> XMLElement {
        let element = XMLElement(name: "sequence")

        // Reference the format
        guard let formatID = resourceMap.formatID else {
            throw FCPXMLExportError.missingFormat
        }
        element.addAttribute(XMLNode.attribute(withName: "format", stringValue: formatID) as! XMLNode)

        // Add duration (frame-aligned)
        let alignedDuration = timeline.duration.aligned(to: frameRate)
        element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: alignedDuration.fcpxmlString) as! XMLNode)

        // Add tcStart (always 0 for now)
        element.addAttribute(XMLNode.attribute(withName: "tcStart", stringValue: "0s") as! XMLNode)

        // Generate spine
        let spine = try generateSpineElement(timeline: timeline, modelContext: modelContext, resourceMap: resourceMap, frameRate: frameRate)
        element.addChild(spine)

        return element
    }

    /// Generates a spine XML element with all storyline clips.
    private func generateSpineElement(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        resourceMap: LegacyResourceMap,
        frameRate: FrameRate
    ) throws -> XMLElement {
        let element = XMLElement(name: "spine")

        // Get all clips sorted by offset then lane
        let allClips = timeline.sortedClips

        for clip in allClips {
            let clipElement = try generateAssetClipElement(clip: clip, resourceMap: resourceMap, frameRate: frameRate)
            element.addChild(clipElement)
        }

        return element
    }

    /// Generates an asset-clip XML element.
    private func generateAssetClipElement(
        clip: TimelineClip,
        resourceMap: LegacyResourceMap,
        frameRate: FrameRate
    ) throws -> XMLElement {
        // Get asset ID
        guard let assetID = resourceMap.assetIDs[clip.assetStorageId] else {
            throw FCPXMLExportError.missingAsset(assetId: clip.assetStorageId)
        }

        let element = XMLElement(name: "asset-clip")
        element.addAttribute(XMLNode.attribute(withName: "ref", stringValue: assetID) as! XMLNode)

        // Add name if available
        if let name = clip.name {
            element.addAttribute(XMLNode.attribute(withName: "name", stringValue: name) as! XMLNode)
        }

        // Add offset (frame-aligned)
        let alignedOffset = clip.offset.aligned(to: frameRate)
        element.addAttribute(XMLNode.attribute(withName: "offset", stringValue: alignedOffset.fcpxmlString) as! XMLNode)

        // Add duration (frame-aligned)
        let alignedDuration = clip.duration.aligned(to: frameRate)
        element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: alignedDuration.fcpxmlString) as! XMLNode)

        // Add start if not zero (frame-aligned)
        if clip.sourceStart != .zero {
            let alignedStart = clip.sourceStart.aligned(to: frameRate)
            element.addAttribute(XMLNode.attribute(withName: "start", stringValue: alignedStart.fcpxmlString) as! XMLNode)
        }

        // Add lane if not 0
        if clip.lane != 0 {
            element.addAttribute(XMLNode.attribute(withName: "lane", stringValue: "\(clip.lane)") as! XMLNode)
        }

        // Add enabled state if disabled
        if clip.isVideoDisabled {
            element.addAttribute(XMLNode.attribute(withName: "enabled", stringValue: "0") as! XMLNode)
        }

        return element
    }

    // MARK: - Helpers

    /// Generates the next resource ID.
    private mutating func nextResourceID() -> String {
        resourceIDCounter += 1
        return "r\(resourceIDCounter)"
    }
}

// MARK: - Supporting Types

/// Maps Timeline objects to FCPXML resource IDs (legacy embedded Pipeline implementation).
/// Note: The Adapters/ResourceMap.swift public struct is the replacement for pipeline-neo migration.
struct LegacyResourceMap {
    var formatID: String?
    var assetIDs: [UUID: String] = [:]
    var audioTiming: [UUID: FCPXMLBundleExporter.AudioTiming] = [:]
}

/// Errors that can occur during FCPXML export.
public enum FCPXMLExportError: Error, LocalizedError, Equatable {
    case xmlGenerationFailed
    case missingFormat
    case missingAsset(assetId: UUID)
    case invalidTimeline(reason: String)
    case cancelled

    /// An asset referenced by a clip was not found in the export asset list.
    /// This case maps from `PipelineNeo.FCPXMLExportError.missingAsset(assetId: String)`,
    /// where the asset ID is a string (r-prefixed resource ID) rather than a UUID.
    case missingAssetRef(assetRef: String)

    public var errorDescription: String? {
        switch self {
        case .xmlGenerationFailed:
            return "Failed to generate XML string"
        case .missingFormat:
            return "Missing format resource"
        case .missingAsset(let assetId):
            return "Missing asset resource: \(assetId)"
        case .invalidTimeline(let reason):
            return "Invalid timeline: \(reason)"
        case .cancelled:
            return "Export operation was cancelled"
        case .missingAssetRef(let assetRef):
            return "Missing asset resource for reference: \(assetRef)"
        }
    }
}

#endif
