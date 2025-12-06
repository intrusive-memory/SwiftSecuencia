//
//  FCPXMLBundleExporter.swift
//  SwiftSecuencia
//
//  Exports Timeline to FCPXML bundle (.fcpxmld) with embedded media.
//

import Foundation
import SwiftData
import SwiftCompartido

/// Exports Timeline objects to FCPXML bundle format (.fcpxmld).
///
/// FCPXMLBundleExporter creates a self-contained bundle that includes:
/// - The FCPXML document
/// - Info.plist with bundle metadata
/// - Media folder with all referenced assets
///
/// ## Bundle Structure
///
/// ```
/// Timeline.fcpxmld/
/// ├── Info.plist
/// ├── Info.fcpxml
/// └/// Media/
///     ├── asset1.mov
///     ├── asset2.wav
///     └── ...
/// ```
///
/// ## Basic Usage
///
/// ```swift
/// let exporter = FCPXMLBundleExporter()
/// try await exporter.exportBundle(
///     timeline: myTimeline,
///     modelContext: context,
///     to: outputURL,
///     bundleName: "MyProject"
/// )
/// ```
public struct FCPXMLBundleExporter {

    /// FCPXML version to generate.
    public let version: String

    /// Whether to copy media files into the bundle.
    public let includeMedia: Bool

    /// Creates an FCPXML bundle exporter.
    ///
    /// - Parameters:
    ///   - version: FCPXML version string (default: "1.11").
    ///   - includeMedia: Whether to copy media files into the bundle (default: true).
    public init(version: String = "1.11", includeMedia: Bool = true) {
        self.version = version
        self.includeMedia = includeMedia
    }

    /// Exports a timeline to an FCPXML bundle (.fcpxmld).
    ///
    /// - Parameters:
    ///   - timeline: The timeline to export.
    ///   - modelContext: The model context to fetch assets from.
    ///   - to: The directory where the bundle will be created.
    ///   - bundleName: Name for the bundle (without extension). If nil, uses timeline name.
    ///   - libraryName: Name for the library element (default: "Exported Library").
    ///   - eventName: Name for the event element (default: "Exported Event").
    ///   - projectName: Name for the project (default: timeline name).
    /// - Returns: URL of the created bundle.
    /// - Throws: Export errors if bundle creation fails.
    public mutating func exportBundle(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        to directory: URL,
        bundleName: String? = nil,
        libraryName: String = "Exported Library",
        eventName: String = "Exported Event",
        projectName: String? = nil
    ) async throws -> URL {
        let name = bundleName ?? timeline.name
        let bundleURL = directory.appendingPathComponent("\(name).fcpxmld")

        // Create bundle directory structure
        try createBundleStructure(at: bundleURL)

        // Export media files if enabled
        var assetURLMap: [UUID: String] = [:]
        if includeMedia {
            assetURLMap = try await exportMedia(
                timeline: timeline,
                modelContext: modelContext,
                to: bundleURL
            )
        }

        // Generate FCPXML with relative media paths
        let fcpxml = try generateFCPXML(
            timeline: timeline,
            modelContext: modelContext,
            assetURLMap: assetURLMap,
            libraryName: libraryName,
            eventName: eventName,
            projectName: projectName
        )

        // Write FCPXML to bundle
        let fcpxmlURL = bundleURL.appendingPathComponent("Info.fcpxml")
        try fcpxml.write(to: fcpxmlURL, atomically: true, encoding: .utf8)

        // Generate and write Info.plist
        try generateInfoPlist(bundleName: name, to: bundleURL)

        return bundleURL
    }

    // MARK: - Bundle Structure

    /// Creates the bundle directory structure.
    private func createBundleStructure(at bundleURL: URL) throws {
        let fileManager = FileManager.default

        // Remove existing bundle if present
        if fileManager.fileExists(atPath: bundleURL.path) {
            try fileManager.removeItem(at: bundleURL)
        }

        // Create bundle directory
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        // Create Media subdirectory
        let mediaURL = bundleURL.appendingPathComponent("Media")
        try fileManager.createDirectory(at: mediaURL, withIntermediateDirectories: true)
    }

    // MARK: - Media Export

    /// Exports media files from TypedDataStorage to the Media folder.
    ///
    /// - Parameters:
    ///   - timeline: The timeline containing clips.
    ///   - modelContext: The model context to fetch assets from.
    ///   - bundleURL: The bundle URL.
    /// - Returns: Dictionary mapping asset IDs to relative file paths.
    private func exportMedia(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        to bundleURL: URL
    ) async throws -> [UUID: String] {
        let assets = timeline.allAssets(in: modelContext)
        var assetURLMap: [UUID: String] = [:]

        let mediaURL = bundleURL.appendingPathComponent("Media")

        for asset in assets {
            // Determine file extension from MIME type
            let ext = fileExtension(for: asset.mimeType)

            // Generate unique filename
            let filename = "\(asset.id.uuidString).\(ext)"
            let fileURL = mediaURL.appendingPathComponent(filename)

            // Write binary data to file
            guard let binaryValue = asset.binaryValue else {
                throw FCPXMLExportError.invalidTimeline(reason: "Asset \(asset.id) has no binary data")
            }
            try binaryValue.write(to: fileURL, options: .atomic)

            // Store relative path (Media/filename)
            assetURLMap[asset.id] = "Media/\(filename)"
        }

        return assetURLMap
    }

    /// Returns file extension for MIME type.
    private func fileExtension(for mimeType: String) -> String {
        let components = mimeType.split(separator: "/")
        guard components.count == 2 else { return "dat" }

        let subtype = String(components[1])

        // Map common MIME types to extensions
        switch subtype {
        case "mp4": return "mp4"
        case "quicktime": return "mov"
        case "mpeg": return "mp3"
        case "wav", "x-wav": return "wav"
        case "aac": return "aac"
        case "png": return "png"
        case "jpeg": return "jpg"
        case "gif": return "gif"
        case "webp": return "webp"
        default: return subtype
        }
    }

    // MARK: - FCPXML Generation

    /// Generates FCPXML string with asset references.
    private mutating func generateFCPXML(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        assetURLMap: [UUID: String],
        libraryName: String,
        eventName: String,
        projectName: String?
    ) throws -> String {
        var exporter = FCPXMLExporter(version: version)

        // If we have asset URLs, we need to use a modified exporter
        if !assetURLMap.isEmpty {
            return try generateBundleFCPXML(
                timeline: timeline,
                modelContext: modelContext,
                assetURLMap: assetURLMap,
                libraryName: libraryName,
                eventName: eventName,
                projectName: projectName,
                exporter: &exporter
            )
        } else {
            // Use standard exporter with absolute paths
            return try exporter.export(
                timeline: timeline,
                modelContext: modelContext,
                libraryName: libraryName,
                eventName: eventName,
                projectName: projectName
            )
        }
    }

    /// Generates FCPXML with relative media paths for bundle.
    private mutating func generateBundleFCPXML(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        assetURLMap: [UUID: String],
        libraryName: String,
        eventName: String,
        projectName: String?,
        exporter: inout FCPXMLExporter
    ) throws -> String {
        // Create root XML document
        let doc = XMLDocument(rootElement: nil)
        doc.version = "1.0"
        doc.characterEncoding = "UTF-8"

        // Create root fcpxml element
        let fcpxml = XMLElement(name: "fcpxml")
        fcpxml.addAttribute(XMLNode.attribute(withName: "version", stringValue: version) as! XMLNode)
        doc.setRootElement(fcpxml)

        // Collect all assets and formats
        var resourceMap = ResourceMap()
        let assets = timeline.allAssets(in: modelContext)

        // Generate resources section
        let resources = XMLElement(name: "resources")

        // Add format resource
        let format = timeline.videoFormat ?? VideoFormat.hd1080p(frameRate: .fps23_98)
        let formatElement = try generateFormatElement(format: format, resourceMap: &resourceMap)
        resources.addChild(formatElement)

        // Add asset resources with relative paths
        for asset in assets {
            let assetElement = try generateAssetElement(
                asset: asset,
                relativePath: assetURLMap[asset.id],
                resourceMap: &resourceMap
            )
            resources.addChild(assetElement)
        }

        fcpxml.addChild(resources)

        // Generate library > event > project > sequence > spine structure
        let library = XMLElement(name: "library")

        let event = XMLElement(name: "event")
        event.addAttribute(XMLNode.attribute(withName: "name", stringValue: eventName) as! XMLNode)

        let project = XMLElement(name: "project")
        let pName = projectName ?? timeline.name
        project.addAttribute(XMLNode.attribute(withName: "name", stringValue: pName) as! XMLNode)

        // Create sequence
        let sequence = try generateSequenceElement(
            timeline: timeline,
            modelContext: modelContext,
            resourceMap: resourceMap
        )

        project.addChild(sequence)
        event.addChild(project)
        library.addChild(event)
        fcpxml.addChild(library)

        // Generate XML string
        let xmlData = doc.xmlData(options: [.nodePrettyPrint])
        guard let xmlString = String(data: xmlData, encoding: .utf8) else {
            throw FCPXMLExportError.xmlGenerationFailed
        }

        return xmlString
    }

    // MARK: - XML Element Generation

    private var resourceIDCounter = 0

    private mutating func nextResourceID() -> String {
        resourceIDCounter += 1
        return "r\(resourceIDCounter)"
    }

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

        let colorSpaceValue = format.colorSpace.fcpxmlValue
        if colorSpaceValue != "1-1-1 (Rec. 709)" {
            element.addAttribute(XMLNode.attribute(withName: "colorSpace", stringValue: colorSpaceValue) as! XMLNode)
        }

        return element
    }

    private mutating func generateAssetElement(
        asset: TypedDataStorage,
        relativePath: String?,
        resourceMap: inout ResourceMap
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

        // Use relative path if provided, otherwise placeholder
        let srcURL = relativePath ?? "file:///placeholder/\(asset.id.uuidString)"
        element.addAttribute(XMLNode.attribute(withName: "src", stringValue: srcURL) as! XMLNode)

        // Add duration if available
        if let duration = asset.durationSeconds {
            let timecode = Timecode(seconds: duration)
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

        return element
    }

    private func generateSequenceElement(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        resourceMap: ResourceMap
    ) throws -> XMLElement {
        let element = XMLElement(name: "sequence")

        guard let formatID = resourceMap.formatID else {
            throw FCPXMLExportError.missingFormat
        }
        element.addAttribute(XMLNode.attribute(withName: "format", stringValue: formatID) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: timeline.duration.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "tcStart", stringValue: "0s") as! XMLNode)

        let spine = try generateSpineElement(timeline: timeline, modelContext: modelContext, resourceMap: resourceMap)
        element.addChild(spine)

        return element
    }

    private func generateSpineElement(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        resourceMap: ResourceMap
    ) throws -> XMLElement {
        let element = XMLElement(name: "spine")

        let allClips = timeline.sortedClips

        for clip in allClips {
            let clipElement = try generateAssetClipElement(clip: clip, resourceMap: resourceMap)
            element.addChild(clipElement)
        }

        return element
    }

    private func generateAssetClipElement(
        clip: TimelineClip,
        resourceMap: ResourceMap
    ) throws -> XMLElement {
        guard let assetID = resourceMap.assetIDs[clip.assetStorageId] else {
            throw FCPXMLExportError.missingAsset(assetId: clip.assetStorageId)
        }

        let element = XMLElement(name: "asset-clip")
        element.addAttribute(XMLNode.attribute(withName: "ref", stringValue: assetID) as! XMLNode)

        if let name = clip.name {
            element.addAttribute(XMLNode.attribute(withName: "name", stringValue: name) as! XMLNode)
        }

        element.addAttribute(XMLNode.attribute(withName: "offset", stringValue: clip.offset.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: clip.duration.fcpxmlString) as! XMLNode)

        if clip.sourceStart != .zero {
            element.addAttribute(XMLNode.attribute(withName: "start", stringValue: clip.sourceStart.fcpxmlString) as! XMLNode)
        }

        if clip.lane != 0 {
            element.addAttribute(XMLNode.attribute(withName: "lane", stringValue: "\(clip.lane)") as! XMLNode)
        }

        if clip.isVideoDisabled {
            element.addAttribute(XMLNode.attribute(withName: "enabled", stringValue: "0") as! XMLNode)
        }

        return element
    }

    // MARK: - Info.plist Generation

    /// Generates and writes Info.plist for the bundle.
    private func generateInfoPlist(bundleName: String, to bundleURL: URL) throws {
        let plist: [String: Any] = [
            "CFBundleName": bundleName,
            "CFBundleIdentifier": "com.swiftsecuencia.\(bundleName.lowercased().replacingOccurrences(of: " ", with: "-"))",
            "CFBundleVersion": "1.0",
            "CFBundlePackageType": "FCPB",
            "CFBundleShortVersionString": "1.0",
            "CFBundleInfoDictionaryVersion": "6.0",
            "NSHumanReadableCopyright": "Generated with SwiftSecuencia"
        ]

        let plistURL = bundleURL.appendingPathComponent("Info.plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        try plistData.write(to: plistURL, options: .atomic)
    }
}
