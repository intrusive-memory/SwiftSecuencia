//
//  SwiftSecuenciaBundleExporter.swift
//  SwiftSecuencia
//
//  Exports a SwiftSecuencia Timeline to a Final Cut Pro bundle (.fcpbundle)
//  with embedded media files.
//
//  ## Architecture
//
//  ```
//  SwiftSecuencia.Timeline (SwiftData)
//      |
//      v  SwiftSecuenciaExporter.export()  (SwiftSecuenciaExporter.swift)
//  Cleaned FCPXML String (absolute src paths, library name attribute removed)
//      |
//      v  XMLDocument post-processing: replace absolute src URLs → relative "Media/r2.m4a"
//  FCPXML String with relative Media/ paths
//      |
//      v  Write Info.fcpxml to bundle directory
//      |
//      v  Copy media files to {bundle}/Media/ using r-prefixed filenames
//  {name}.fcpbundle/
//  ├── Info.fcpxml
//  └── Media/
//      ├── r2.m4a
//      └── r3.wav
//  ```
//
//  ## Bundle Extension
//
//  This exporter creates `.fcpbundle` bundles, which is the correct extension
//  for Final Cut Pro libraries. Note that PipelineNeo's FCPXMLBundleExporter
//  creates `.fcpxmld` bundles — this exporter deliberately diverges to use the
//  correct Final Cut Pro extension.
//
//  ## Media File Coordination
//
//  Media files are written with r-prefixed filenames matching the resource IDs
//  in the FCPXML document:
//  - Asset with resource ID "r2" → Media/r2.{ext}
//  - Asset with resource ID "r3" → Media/r3.{ext}
//
//  Asset src paths in the FCPXML are updated to use these relative paths via
//  XMLDocument post-processing after SwiftSecuenciaExporter generates the document.
//
//  ## FCPXML Generation Delegation
//
//  FCPXML generation (including library name attribute removal) is fully delegated
//  to SwiftSecuenciaExporter. This exporter adds bundle directory creation, src path
//  rewriting, and media file copying on top of that foundation.
//

#if os(macOS)

import Foundation
import SwiftData
import PipelineNeo

// MARK: - SwiftSecuenciaBundleExporter

/// Exports a `SwiftSecuencia.Timeline` to a Final Cut Pro bundle (`.fcpbundle`)
/// with embedded media files.
///
/// `SwiftSecuenciaBundleExporter` creates a self-contained bundle directory that
/// includes the FCPXML document (`Info.fcpxml`) and all referenced media files
/// in a `Media/` subdirectory.
///
/// ## Bundle Structure
///
/// ```
/// MyProject.fcpbundle/
/// ├── Info.fcpxml
/// └── Media/
///     ├── r2.m4a
///     └── r3.wav
/// ```
///
/// ## Usage with AssetProvider
///
/// ```swift
/// let provider = FileAssetProvider(registry: myRegistry)
/// let exporter = SwiftSecuenciaBundleExporter()
/// try await exporter.exportBundle(
///     timeline: myTimeline,
///     projectName: "My Project",
///     eventName: "My Event",
///     bundleURL: URL(fileURLWithPath: "/path/to/MyProject.fcpbundle"),
///     assetProvider: provider
/// )
/// ```
///
/// ## Usage with ModelContext
///
/// ```swift
/// let exporter = SwiftSecuenciaBundleExporter()
/// try await exporter.exportBundle(
///     timeline: myTimeline,
///     projectName: "My Project",
///     eventName: "My Event",
///     bundleURL: outputURL,
///     modelContext: context
/// )
/// ```
@MainActor
public struct SwiftSecuenciaBundleExporter {

    // MARK: - Properties

    /// The FCPXML version to generate.
    public let version: FCPXMLVersion

    // MARK: - Initializers

    /// Creates a bundle exporter with the given FCPXML version.
    ///
    /// - Parameter version: The FCPXML version for the exported document.
    ///   Defaults to `.default`, which is the latest supported version (1.14).
    public init(version: FCPXMLVersion = .default) {
        self.version = version
    }

    // MARK: - Bundle Export with AssetProvider

    /// Exports a timeline to a `.fcpbundle` directory with embedded media files.
    ///
    /// This is the primary export method. It performs these steps in order:
    ///
    /// 1. Builds a `ResourceMap` to assign r-prefixed IDs to all assets.
    /// 2. Creates the `{bundleURL}/` and `{bundleURL}/Media/` directories.
    /// 3. Generates FCPXML via `SwiftSecuenciaExporter` (handles library name fix).
    /// 4. Post-processes the FCPXML to rewrite absolute `src` URLs to relative
    ///    `Media/r2.m4a` paths via `XMLDocument`.
    /// 5. Writes `Info.fcpxml` to the bundle root.
    /// 6. Copies each asset's source file into `Media/` using the r-prefixed filename.
    ///
    /// The `bundleURL` should end with `.fcpbundle` (e.g.,
    /// `URL(fileURLWithPath: "/path/to/MyProject.fcpbundle")`).
    ///
    /// - Parameters:
    ///   - timeline: The SwiftSecuencia timeline to export.
    ///   - projectName: Name for the `<project>` element in the FCPXML.
    ///   - eventName: Name for the `<event>` element in the FCPXML.
    ///   - bundleURL: The full path where the `.fcpbundle` directory will be created.
    ///   - assetProvider: Provider for accessing asset files.
    /// - Throws: `FCPXMLBundleExportError` if the bundle or media files cannot be created,
    ///           `FCPXMLExportError` if FCPXML generation fails.
    public func exportBundle(
        timeline: Timeline,
        projectName: String,
        eventName: String,
        bundleURL: URL,
        assetProvider: any AssetProvider
    ) async throws {
        // Step 1: Build ResourceMap.
        // This must be done before FCPXML generation so we can compute r-prefixed
        // filenames for the Media/ directory. ResourceMap assigns the same IDs that
        // SwiftSecuenciaExporter will use internally (both sort UUIDs identically).
        let resourceMap = buildResourceMap(for: timeline)

        // Step 2: Build the relative path map: asset UUID → "Media/r2.m4a"
        let relativePathMap = try buildRelativePathMap(
            for: timeline,
            assetProvider: assetProvider,
            resourceMap: resourceMap
        )

        // Step 3: Create the bundle directory structure.
        let mediaDirectoryURL = bundleURL.appendingPathComponent("Media", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: mediaDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw FCPXMLBundleExportError.bundleCreationFailed(
                reason: "Could not create bundle directory at \(bundleURL.path): \(error.localizedDescription)"
            )
        }

        // Step 4: Generate FCPXML using SwiftSecuenciaExporter.
        // This produces a cleaned FCPXML string (library name attribute removed)
        // with absolute src paths. We will rewrite those paths in the next step.
        let exporter = SwiftSecuenciaExporter(version: version)
        let rawFCPXML = try exporter.export(
            timeline: timeline,
            assetProvider: assetProvider,
            eventName: eventName,
            projectName: projectName
        )

        // Step 5: Rewrite absolute src paths to relative Media/ paths.
        // Parse the FCPXML as XMLDocument and update each <asset> element's src attribute
        // to use the r-prefixed relative path (e.g., "Media/r2.m4a").
        let bundledFCPXML = try rewriteSrcPaths(
            in: rawFCPXML,
            relativePathMap: relativePathMap,
            assetProvider: assetProvider,
            resourceMap: resourceMap
        )

        // Step 6: Write Info.fcpxml to the bundle root.
        let infoFCPXMLURL = bundleURL.appendingPathComponent("Info.fcpxml")
        do {
            try bundledFCPXML.write(to: infoFCPXMLURL, atomically: true, encoding: .utf8)
        } catch {
            throw FCPXMLBundleExportError.writeFailed(
                reason: "Could not write Info.fcpxml: \(error.localizedDescription)"
            )
        }

        // Step 7: Verify that the library name attribute is absent from Info.fcpxml.
        // SwiftSecuenciaExporter already removes it, but this is an explicit double-check
        // per the sortie requirements.
        try verifyLibraryNameRemoved(from: infoFCPXMLURL)

        // Step 8: Copy media files into Media/ using r-prefixed filenames.
        try copyMediaFiles(
            for: timeline,
            assetProvider: assetProvider,
            resourceMap: resourceMap,
            relativePathMap: relativePathMap,
            mediaDirectoryURL: mediaDirectoryURL
        )
    }

    // MARK: - Bundle Export with ModelContext

    /// Exports a timeline to a `.fcpbundle` directory using a SwiftData `ModelContext`.
    ///
    /// This convenience method wraps the `AssetProvider`-based export, creating a
    /// `SwiftDataAssetProvider` from the model context.
    ///
    /// - Parameters:
    ///   - timeline: The SwiftSecuencia timeline to export.
    ///   - projectName: Name for the `<project>` element in the FCPXML.
    ///   - eventName: Name for the `<event>` element in the FCPXML.
    ///   - bundleURL: The full path where the `.fcpbundle` directory will be created.
    ///   - modelContext: The SwiftData model context for fetching assets.
    /// - Throws: `FCPXMLBundleExportError` or `FCPXMLExportError`.
    public func exportBundle(
        timeline: Timeline,
        projectName: String,
        eventName: String,
        bundleURL: URL,
        modelContext: SwiftData.ModelContext
    ) async throws {
        let provider = SwiftDataAssetProvider(modelContext: modelContext)
        try await exportBundle(
            timeline: timeline,
            projectName: projectName,
            eventName: eventName,
            bundleURL: bundleURL,
            assetProvider: provider
        )
    }

    // MARK: - Private: ResourceMap Construction

    /// Builds a `ResourceMap` from the unique asset UUIDs referenced by a timeline's clips.
    ///
    /// Uses the same sorting strategy as `SwiftSecuenciaExporter.buildResourceMap(for:)`:
    /// sorts UUIDs alphabetically before assigning IDs, guaranteeing that the same set of
    /// UUIDs produces identical ID mappings across both exporters.
    private func buildResourceMap(for timeline: Timeline) -> ResourceMap {
        var resourceMap = ResourceMap()
        let uniqueAssetUUIDs = Array(Set(timeline.clips.map { $0.assetStorageId }))
        resourceMap.registerAssets(uniqueAssetUUIDs)
        return resourceMap
    }

    // MARK: - Private: Relative Path Map Construction

    /// Builds a map from asset UUID to relative Media/ path (e.g., UUID → "Media/r2.m4a").
    ///
    /// The filename uses the r-prefixed resource ID so the path matches both the `<asset src>`
    /// attribute in the FCPXML and the actual filename written to the `Media/` directory.
    private func buildRelativePathMap(
        for timeline: Timeline,
        assetProvider: any AssetProvider,
        resourceMap: ResourceMap
    ) throws -> [UUID: String] {
        let uniqueAssetUUIDs = Array(Set(timeline.clips.map { $0.assetStorageId }))

        var map: [UUID: String] = [:]
        for uuid in uniqueAssetUUIDs {
            guard let resourceID = resourceMap.assetResourceID(for: uuid) else {
                continue
            }
            let metadata = try assetProvider.assetMetadata(for: uuid)
            let ext = mimeTypeFileExtension(for: metadata.mimeType)
            map[uuid] = "Media/\(resourceID).\(ext)"
        }
        return map
    }

    // MARK: - Private: src Path Rewriting

    /// Rewrites absolute `src` URLs in FCPXML `<asset>` elements to relative `Media/` paths.
    ///
    /// PipelineNeo generates `<asset src="file:///absolute/path/to/file.m4a"/>`. For bundle
    /// exports, the src should be a relative path like `Media/r2.m4a`. This method parses
    /// the FCPXML as `XMLDocument`, iterates over `<asset>` elements in `<resources>`, and
    /// replaces each `src` attribute with the corresponding relative path.
    ///
    /// The mapping from absolute URL to relative path is resolved by finding the asset UUID
    /// whose file URL matches the current `src` value, then looking up the relative path in
    /// `relativePathMap`.
    ///
    /// - Parameters:
    ///   - xmlString: The FCPXML string with absolute src paths.
    ///   - relativePathMap: Maps asset UUID → relative path (e.g., "Media/r2.m4a").
    ///   - assetProvider: Used to resolve asset file URLs for matching.
    ///   - resourceMap: Used to resolve resource IDs back to UUIDs.
    /// - Returns: The FCPXML string with relative src paths.
    /// - Throws: `FCPXMLBundleExportError.writeFailed` if the XML cannot be parsed.
    private func rewriteSrcPaths(
        in xmlString: String,
        relativePathMap: [UUID: String],
        assetProvider: any AssetProvider,
        resourceMap: ResourceMap
    ) throws -> String {
        let doc: XMLDocument
        do {
            doc = try XMLDocument(xmlString: xmlString, options: [.nodePreserveAll])
        } catch {
            throw FCPXMLBundleExportError.writeFailed(
                reason: "Could not parse FCPXML for src path rewriting: \(error.localizedDescription)"
            )
        }

        // Build a reverse map: file URL string → relative path, for efficient lookup.
        // We resolve each UUID's file URL and map it to the relative path.
        var fileURLToRelativePath: [String: String] = [:]
        for (uuid, relativePath) in relativePathMap {
            if let fileURL = try? assetProvider.assetFileURL(for: uuid) {
                fileURLToRelativePath[fileURL.absoluteString] = relativePath
                // Also index the path string (without "file://") for robustness
                fileURLToRelativePath[fileURL.path] = relativePath
            }
        }

        // Navigate to <fcpxml><resources> and find all <asset> elements.
        guard let root = doc.rootElement() else {
            return xmlString
        }

        for resourcesElement in root.elements(forName: "resources") {
            for assetElement in resourcesElement.elements(forName: "asset") {
                // Each <asset> may contain a <media-rep> child with the src.
                // Some FCPXML versions also put src directly on <asset>.
                updateSrcAttribute(
                    on: assetElement,
                    fileURLToRelativePath: fileURLToRelativePath
                )
                for mediaRep in assetElement.elements(forName: "media-rep") {
                    updateSrcAttribute(
                        on: mediaRep,
                        fileURLToRelativePath: fileURLToRelativePath
                    )
                }
            }
        }

        return doc.xmlString(options: [.nodePrettyPrint])
    }

    /// Updates the `src` attribute on an XML element if it matches a known file URL.
    private func updateSrcAttribute(
        on element: XMLElement,
        fileURLToRelativePath: [String: String]
    ) {
        guard let srcAttr = element.attribute(forName: "src"),
              let currentSrc = srcAttr.stringValue else {
            return
        }

        if let relativePath = fileURLToRelativePath[currentSrc] {
            srcAttr.stringValue = relativePath
        }
    }

    // MARK: - Private: Library Name Verification

    /// Verifies that `Info.fcpxml` has no `<library name="...">` attribute.
    ///
    /// `SwiftSecuenciaExporter` removes this attribute, but the task specification
    /// requires an explicit double-check after `Info.fcpxml` is written. If the attribute
    /// is unexpectedly present, it is removed and the file is rewritten.
    private func verifyLibraryNameRemoved(from infoFCPXMLURL: URL) throws {
        let xmlString: String
        do {
            xmlString = try String(contentsOf: infoFCPXMLURL, encoding: .utf8)
        } catch {
            throw FCPXMLBundleExportError.writeFailed(
                reason: "Could not read Info.fcpxml for library name verification: \(error.localizedDescription)"
            )
        }

        let doc: XMLDocument
        do {
            doc = try XMLDocument(xmlString: xmlString, options: [.nodePreserveAll])
        } catch {
            throw FCPXMLBundleExportError.writeFailed(
                reason: "Could not parse Info.fcpxml as XMLDocument during library name verification: \(error.localizedDescription)"
            )
        }

        var modified = false
        if let root = doc.rootElement() {
            for library in root.elements(forName: "library") {
                if library.attribute(forName: "name") != nil {
                    library.removeAttribute(forName: "name")
                    modified = true
                }
            }
        }

        // Rewrite only if the attribute was unexpectedly present
        if modified {
            let cleanedXML = doc.xmlString(options: [.nodePrettyPrint])
            do {
                try cleanedXML.write(to: infoFCPXMLURL, atomically: true, encoding: .utf8)
            } catch {
                throw FCPXMLBundleExportError.writeFailed(
                    reason: "Could not rewrite Info.fcpxml after library name removal: \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Private: Media File Copying

    /// Copies each asset's source file into the bundle's `Media/` directory.
    ///
    /// Files are named using the r-prefixed resource ID with the appropriate extension
    /// (e.g., "r2.m4a"), matching the relative paths embedded in `Info.fcpxml`.
    ///
    /// The method tries file URL copy first (most efficient). If the asset provider does
    /// not support file URLs, it falls back to writing binary data.
    private func copyMediaFiles(
        for timeline: Timeline,
        assetProvider: any AssetProvider,
        resourceMap: ResourceMap,
        relativePathMap: [UUID: String],
        mediaDirectoryURL: URL
    ) throws {
        let uniqueAssetUUIDs = Array(Set(timeline.clips.map { $0.assetStorageId }))

        for uuid in uniqueAssetUUIDs {
            guard let resourceID = resourceMap.assetResourceID(for: uuid),
                  let relativePath = relativePathMap[uuid] else {
                continue
            }

            // Extract just the filename component from the relative path (e.g., "r2.m4a")
            let filename = (relativePath as NSString).lastPathComponent
            let destinationURL = mediaDirectoryURL.appendingPathComponent(filename)

            // Remove existing file if present (idempotent re-export support)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }

            // Try file URL copy first (no data loading into memory)
            let didCopy = try copyViaFileURL(
                uuid: uuid,
                assetProvider: assetProvider,
                destinationURL: destinationURL,
                resourceID: resourceID
            )

            if didCopy {
                continue
            }

            // Fallback: write binary data directly to the destination
            do {
                let data = try assetProvider.assetData(for: uuid)
                try data.write(to: destinationURL)
            } catch {
                throw FCPXMLBundleExportError.mediaCopyFailed(
                    assetRef: resourceID,
                    underlying: error
                )
            }
        }
    }

    /// Attempts to copy an asset via file URL.
    ///
    /// - Returns: `true` if the copy succeeded, `false` if the asset provider does not
    ///   provide a file URL (caller should fall back to binary data copy).
    /// - Throws: `FCPXMLBundleExportError.mediaCopyFailed` if the file URL is available
    ///   but the copy operation fails.
    private func copyViaFileURL(
        uuid: UUID,
        assetProvider: any AssetProvider,
        destinationURL: URL,
        resourceID: String
    ) throws -> Bool {
        let sourceURL: URL
        do {
            sourceURL = try assetProvider.assetFileURL(for: uuid)
        } catch {
            // Asset provider does not support file URLs; caller will use binary data
            return false
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return true
        } catch {
            throw FCPXMLBundleExportError.mediaCopyFailed(
                assetRef: resourceID,
                underlying: error
            )
        }
    }
}

#endif // os(macOS)
