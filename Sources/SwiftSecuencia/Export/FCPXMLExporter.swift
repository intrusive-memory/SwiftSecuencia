//
//  FCPXMLExporter.swift
//  SwiftSecuencia
//
//  Exports Timeline to FCPXML format.
//

import Foundation
import SwiftData
import SwiftCompartido
import Pipeline

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

    /// Exports a timeline to FCPXML format.
    ///
    /// - Parameters:
    ///   - timeline: The timeline to export.
    ///   - modelContext: The model context to fetch assets from.
    ///   - libraryName: Name for the library element (default: "Exported Library").
    ///   - eventName: Name for the event element (default: "Exported Event").
    ///   - projectName: Name for the project (default: timeline name).
    /// - Returns: FCPXML string representation.
    /// - Throws: Export errors if timeline is invalid or assets are missing.
    public mutating func export(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        libraryName: String = "Exported Library",
        eventName: String = "Exported Event",
        projectName: String? = nil
    ) throws -> String {
        // Collect all assets and formats
        var resourceMap = ResourceMap()
        let assets = timeline.allAssets(in: modelContext)

        // Generate resources
        var resourceElements: [XMLElement] = []

        // Add format resource (use timeline's videoFormat if available, otherwise default to 1080p23.98)
        let format = timeline.videoFormat ?? VideoFormat.hd1080p(frameRate: .fps23_98)
        let formatElement = try generateFormatElement(format: format, resourceMap: &resourceMap)
        resourceElements.append(formatElement)

        // Add asset resources (using frame rate from format)
        for asset in assets {
            let assetElement = try generateAssetElement(asset: asset, resourceMap: &resourceMap, frameRate: format.frameRate)
            resourceElements.append(assetElement)
        }

        // Generate library > event > project > sequence > spine structure
        let event = XMLElement(name: "event")
        event.addAttribute(XMLNode.attribute(withName: "name", stringValue: eventName) as! XMLNode)

        let project = XMLElement(name: "project")
        let pName = projectName ?? timeline.name
        project.addAttribute(XMLNode.attribute(withName: "name", stringValue: pName) as! XMLNode)

        // Create sequence (using frame rate from format)
        let sequence = try generateSequenceElement(
            timeline: timeline,
            modelContext: modelContext,
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

    // MARK: - Resource Generation

    /// Generates a format XML element.
    private mutating func generateFormatElement(
        format: VideoFormat,
        resourceMap: inout ResourceMap
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

    /// Generates an asset XML element.
    private mutating func generateAssetElement(
        asset: TypedDataStorage,
        resourceMap: inout ResourceMap,
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

    /// Generates a sequence XML element with spine and clips.
    private func generateSequenceElement(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        resourceMap: ResourceMap,
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
        resourceMap: ResourceMap,
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
        resourceMap: ResourceMap,
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

/// Maps Timeline objects to FCPXML resource IDs.
struct ResourceMap {
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
        }
    }
}
