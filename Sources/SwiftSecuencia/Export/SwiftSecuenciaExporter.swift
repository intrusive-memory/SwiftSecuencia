//
//  SwiftSecuenciaExporter.swift
//  SwiftSecuencia
//
//  Core bridge that converts SwiftSecuencia's SwiftData-persisted Timeline models
//  into FCPXML document strings using PipelineNeo's FCPXMLExporter.
//
//  ## Architecture
//
//  ```
//  SwiftSecuencia.Timeline (SwiftData)
//      |
//      v  toPipelineNeoTimeline(resourceMap:)     (TimelineAdapters.swift)
//  PipelineNeo.Timeline (value type)
//      |
//      +-- assets via PipelineNeoAssetProvider    (PipelineNeoAssetProvider.swift)
//      |
//      v  PipelineNeo.FCPXMLExporter.export()
//  FCPXML String
//      |
//      v  XMLDocument post-processing (remove library name attribute)
//  Cleaned FCPXML String
//  ```
//
//  ## Empty Timeline Guard
//
//  PipelineNeo throws `FCPXMLExportError.invalidTimeline` for empty timelines.
//  This exporter detects empty timelines before calling PipelineNeo and returns
//  a hand-crafted minimal FCPXML string that is valid per the DTD.
//
//  ## Library Name Bug Fix
//
//  PipelineNeo adds a `name` attribute to `<library>` elements, but the FCPXML DTD
//  does not permit this attribute. After export, the FCPXML is parsed as XMLDocument
//  and the invalid attribute is removed. This uses Foundation's XMLDocument API, NOT
//  regex, for correctness.
//
//  ## Error Mapping
//
//  All PipelineNeo errors are caught and remapped to SwiftSecuencia error types via
//  `remappingExportErrors(_:)` (see ExportErrorMapping.swift). Callers never see
//  PipelineNeo error types.
//

#if os(macOS)

  import Foundation
  import SwiftData
  import PipelineNeo

  // MARK: - FCPXMLVersion Public Re-export

  /// Re-exports `PipelineNeo.FCPXMLVersion` under the unqualified name so that
  /// SwiftSecuencia consumers do not need to import PipelineNeo directly.
  ///
  /// This typealias replaces the FCPXMLVersion that was previously provided by the
  /// embedded Pipeline module. All existing code that references `FCPXMLVersion`
  /// continues to work without changes.
  public typealias FCPXMLVersion = PipelineNeo.FCPXMLVersion

  // MARK: - SwiftSecuenciaExporter

  /// Exports a `SwiftSecuencia.Timeline` to an FCPXML document string using
  /// PipelineNeo's `FCPXMLExporter`.
  ///
  /// This struct is the primary bridge between SwiftSecuencia's SwiftData models
  /// and PipelineNeo's value-type export pipeline. It handles:
  ///
  /// 1. **ResourceMap construction** -- Assigns DTD-compliant r-prefixed IDs to assets.
  /// 2. **Timeline conversion** -- Uses adapters from `TimelineAdapters.swift`.
  /// 3. **Asset conversion** -- Uses `PipelineNeoAssetProvider` for asset metadata.
  /// 4. **FCPXML generation** -- Delegates to `PipelineNeo.FCPXMLExporter`.
  /// 5. **Post-processing** -- Removes invalid `<library name="...">` attribute via XMLDocument.
  ///
  /// ## Usage with AssetProvider
  ///
  /// ```swift
  /// let provider = FileAssetProvider(...)
  /// let exporter = SwiftSecuenciaExporter(version: .v1_11)
  /// let fcpxml = try exporter.export(
  ///     timeline: myTimeline,
  ///     assetProvider: provider,
  ///     eventName: "My Event"
  /// )
  /// ```
  ///
  /// ## Usage with ModelContext
  ///
  /// ```swift
  /// let exporter = SwiftSecuenciaExporter()
  /// let fcpxml = try exporter.export(
  ///     timeline: myTimeline,
  ///     modelContext: context
  /// )
  /// ```
  public struct SwiftSecuenciaExporter {

    // MARK: - Properties

    /// The FCPXML version to generate.
    public let version: FCPXMLVersion

    // MARK: - Initializers

    /// Creates a `SwiftSecuenciaExporter` with the given FCPXML version.
    ///
    /// - Parameter version: The FCPXML version for the exported document.
    ///   Defaults to `.default`, which is the latest supported version (1.14).
    public init(version: FCPXMLVersion = .default) {
      self.version = version
    }

    /// Creates a `SwiftSecuenciaExporter` from a version string.
    ///
    /// Recognised version strings: `"1.5"` through `"1.14"`. Unrecognised strings
    /// fall back to `FCPXMLVersion.default`.
    ///
    /// - Parameter versionString: A version string such as `"1.11"` or `"1_11"`.
    public init(versionString: String) {
      self.version = FCPXMLVersion(string: versionString) ?? .default
    }

    // MARK: - Export with AssetProvider

    /// Exports a timeline to an FCPXML document string using an `AssetProvider`.
    ///
    /// This is the primary export method. It builds a ResourceMap, converts the
    /// timeline and assets to PipelineNeo types, generates FCPXML, and post-processes
    /// the output to remove the invalid library name attribute.
    ///
    /// - Parameters:
    ///   - timeline: The SwiftSecuencia timeline to export.
    ///   - assetProvider: Provider for accessing asset metadata and file URLs.
    ///   - libraryName: Name for the library element (default: "Exported Library").
    ///   - eventName: Name for the event element (default: "Exported Event").
    ///   - projectName: Name for the project (default: timeline name).
    /// - Returns: A valid FCPXML document string.
    /// - Throws: `FCPXMLExportError`, `VideoFormatConversionError`, `AssetConversionError`,
    ///           or `AssetProviderError`.
    public func export(
      timeline: Timeline,
      assetProvider: any AssetProvider,
      libraryName: String = "Exported Library",
      eventName: String = "Exported Event",
      projectName: String? = nil
    ) throws -> String {
      // Empty timeline guard: PipelineNeo throws on empty timelines, so we
      // bypass it entirely and return a hand-crafted minimal FCPXML.
      if timeline.clips.isEmpty {
        return generateMinimalFCPXML(
          timeline: timeline,
          eventName: eventName,
          projectName: projectName
        )
      }

      // Step 1: Build ResourceMap from timeline asset UUIDs.
      // Format is always "r1"; assets get "r2", "r3", ... in sorted UUID order.
      let resourceMap = buildResourceMap(for: timeline)

      // Step 2: Convert SwiftSecuencia.Timeline to PipelineNeo.Timeline.
      // ResourceMap is passed to all adapter calls so asset UUIDs become
      // r-prefixed resource IDs.
      let pipelineNeoTimeline = try timeline.toPipelineNeoTimeline(resourceMap: resourceMap)

      // Step 3: Convert assets using PipelineNeoAssetProvider.
      let assetAdapter = PipelineNeoAssetProvider(
        assetProvider: assetProvider,
        resourceMap: resourceMap
      )
      let pipelineNeoAssets = try assetAdapter.exportAssets(for: timeline)

      // Step 4: Export via PipelineNeo's FCPXMLExporter, remapping errors.
      let pipelineNeoExporter = PipelineNeo.FCPXMLExporter(version: version)
      let rawXML = try remappingExportErrors {
        try pipelineNeoExporter.export(
          timeline: pipelineNeoTimeline,
          assets: pipelineNeoAssets,
          libraryName: libraryName,
          eventName: eventName,
          projectName: projectName
        )
      }

      // Step 5: Post-process to remove invalid library name attribute and standalone declaration.
      var cleanedXML = try removeLibraryNameAttribute(from: rawXML)

      // Remove standalone="yes" from XML declaration for DTD validation compliance
      if cleanedXML.hasPrefix("<?xml") {
        cleanedXML = cleanedXML.replacingOccurrences(
          of: #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#,
          with: #"<?xml version="1.0" encoding="UTF-8"?>"#
        )
      }

      return cleanedXML
    }

    // MARK: - Export with ModelContext

    /// Exports a timeline to an FCPXML document string using a SwiftData `ModelContext`.
    ///
    /// This convenience method creates a `SwiftDataAssetProvider` internally and
    /// delegates to the `AssetProvider`-based export method.
    ///
    /// - Parameters:
    ///   - timeline: The SwiftSecuencia timeline to export.
    ///   - modelContext: The SwiftData model context to fetch assets from.
    ///   - libraryName: Name for the library element (default: "Exported Library").
    ///   - eventName: Name for the event element (default: "Exported Event").
    ///   - projectName: Name for the project (default: timeline name).
    /// - Returns: A valid FCPXML document string.
    /// - Throws: `FCPXMLExportError`, `VideoFormatConversionError`, `AssetConversionError`,
    ///           or `AssetProviderError`.
    @MainActor
    public func export(
      timeline: Timeline,
      modelContext: SwiftData.ModelContext,
      libraryName: String = "Exported Library",
      eventName: String = "Exported Event",
      projectName: String? = nil
    ) throws -> String {
      let provider = SwiftDataAssetProvider(modelContext: modelContext)
      return try export(
        timeline: timeline,
        assetProvider: provider,
        libraryName: libraryName,
        eventName: eventName,
        projectName: projectName
      )
    }

    // MARK: - ResourceMap Construction

    /// Builds a `ResourceMap` that assigns DTD-compliant r-prefixed IDs to the
    /// format resource and each unique asset referenced by the timeline's clips.
    ///
    /// - Format always gets `"r1"` (reserved by PipelineNeo convention).
    /// - Assets get `"r2"`, `"r3"`, etc. in sorted UUID order for determinism.
    ///
    /// - Parameter timeline: The timeline whose clips reference assets.
    /// - Returns: A fully-populated `ResourceMap`.
    private func buildResourceMap(for timeline: Timeline) -> ResourceMap {
      var resourceMap = ResourceMap()

      // Collect unique asset UUIDs from timeline clips
      let uniqueAssetUUIDs = Array(Set(timeline.clips.map { $0.assetStorageId }))

      // Register all assets in sorted order for deterministic ID assignment.
      // ResourceMap.registerAssets() handles sorting internally.
      resourceMap.registerAssets(uniqueAssetUUIDs)

      return resourceMap
    }

    // MARK: - Library Name Fix (XMLDocument)

    /// Removes the invalid `name` attribute from `<library>` elements in FCPXML.
    ///
    /// PipelineNeo adds `name="..."` to `<library>` elements, but the FCPXML DTD
    /// only allows `location` and `colorProcessing` attributes on `<library>`.
    /// This method parses the FCPXML as an XMLDocument, finds the `<library>` element,
    /// removes the `name` attribute, and re-serializes.
    ///
    /// Uses Foundation's `XMLDocument` API for correctness. Regex is NOT used because
    /// it cannot reliably handle XML attribute quoting, entities, or edge cases.
    ///
    /// - Parameter xmlString: The raw FCPXML string from PipelineNeo.
    /// - Returns: The FCPXML string with the library name attribute removed.
    /// - Throws: `FCPXMLExportError.xmlGenerationFailed` if the XML cannot be parsed.
    private func removeLibraryNameAttribute(from xmlString: String) throws -> String {
      let doc: XMLDocument
      do {
        doc = try XMLDocument(xmlString: xmlString, options: [.nodePreserveAll])
      } catch {
        throw FCPXMLExportError.xmlGenerationFailed
      }

      // Navigate: <fcpxml> -> <library>
      // The library element is a direct child of the root <fcpxml> element.
      if let root = doc.rootElement() {
        for library in root.elements(forName: "library") {
          library.removeAttribute(forName: "name")
        }
      }

      // Re-serialize. Use .nodePrettyPrint for readable output.
      return doc.xmlString(options: [.nodePrettyPrint])
    }

    // MARK: - Minimal FCPXML Generation

    /// Generates a minimal valid FCPXML document for an empty timeline.
    ///
    /// When a timeline has no clips, PipelineNeo cannot generate FCPXML (it throws
    /// `invalidTimeline`). This method provides a valid fallback that includes:
    /// - A format resource (using the timeline's video format or 1080p@23.98 default)
    /// - A library with an event and project containing an empty spine
    ///
    /// The output is valid per the FCPXML DTD.
    ///
    /// - Parameters:
    ///   - timeline: The empty timeline.
    ///   - eventName: Name for the `<event>` element.
    ///   - projectName: Name for the `<project>` element (defaults to timeline name).
    /// - Returns: A valid minimal FCPXML document string.
    private func generateMinimalFCPXML(
      timeline: Timeline,
      eventName: String,
      projectName: String?
    ) -> String {
      let pName = projectName ?? timeline.name
      let format = timeline.videoFormat ?? VideoFormat.hd1080p(frameRate: .fps23_98)

      return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="\(version.rawValue)">
          <resources>
            <format id="r1" name="\(format.fcpxmlFormatName)" frameDuration="\(format.frameDuration.fcpxmlString)" width="\(format.width)" height="\(format.height)"/>
          </resources>
          <library>
            <event name="\(eventName)">
              <project name="\(pName)">
                <sequence format="r1" duration="0s" tcStart="0s">
                  <spine/>
                </sequence>
              </project>
            </event>
          </library>
        </fcpxml>
        """
    }
  }

  // MARK: - FCPXMLVersion + SwiftSecuencia Extensions

  extension FCPXMLVersion {

    /// The DTD filename including the `.dtd` extension.
    ///
    /// Used by `FCPXMLDTDValidator` and `BuildCommand` to locate the bundled
    /// DTD resource in the `Resources/FCPXML-DTDs/` directory.
    ///
    /// Example: version `1.13` -> `"FCPXMLv1_13.dtd"`.
    public var dtdFilenameWithExtension: String {
      let versionSlug = rawValue.replacingOccurrences(of: ".", with: "_")
      return "FCPXMLv\(versionSlug).dtd"
    }
  }

#endif  // os(macOS)
