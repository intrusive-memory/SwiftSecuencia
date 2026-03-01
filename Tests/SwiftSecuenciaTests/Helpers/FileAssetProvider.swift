//
//  FileAssetProvider.swift
//  SwiftSecuenciaTests
//
//  In-memory asset provider for testing PipelineNeo export workflows.
//
//  This provider has NO SwiftData dependency — it uses only Foundation and
//  PipelineNeo types. Assets are registered manually via `register(assetID:...)`,
//  making tests fast, lightweight, and isolated from the persistence layer.
//
//  ## Usage
//
//  ```swift
//  let provider = TestFileAssetProvider()
//  provider.register(
//      assetID: "r2",
//      url: URL(fileURLWithPath: "/tmp/test.m4a"),
//      duration: CMTime(value: 600, timescale: 600),
//      hasVideo: false,
//      hasAudio: true
//  )
//
//  let asset = provider.asset(for: "r2")
//  // => FCPXMLExportAsset(id: "r2", src: .../test.m4a, ...)
//  ```
//
//  ## Why Not Use SwiftSecuencia.FileAssetProvider?
//
//  The production `FileAssetProvider` in `Sources/SwiftSecuencia/Export/` conforms
//  to the `AssetProvider` protocol, which uses UUIDs and `AssetMetadata`. For testing
//  PipelineNeo export paths, we need a provider that works directly with resource IDs
//  (e.g., "r2", "r3") and returns `PipelineNeo.FCPXMLExportAsset` values. This test
//  helper avoids the UUID-to-resourceID conversion layer entirely, making tests more
//  direct and readable.

import Foundation
import CoreMedia

#if os(macOS)
import PipelineNeo
#endif

// MARK: - Test File Asset Entry

/// A single registered test asset entry.
///
/// This lightweight struct holds all the information needed to create a
/// `PipelineNeo.FCPXMLExportAsset` for testing. No SwiftData types involved.
public struct TestFileAssetEntry: Sendable {
    /// The file URL where the asset is located (can be a dummy path for tests).
    public let url: URL

    /// Display name for the asset (optional).
    public let name: String?

    /// Duration of the asset. Use `CMTime.zero` for still images.
    public let duration: CMTime?

    /// Whether the asset contains video content.
    public let hasVideo: Bool

    /// Whether the asset contains audio content.
    public let hasAudio: Bool

    /// Optional relative path for bundle exports (e.g., "Media/clip.mov").
    public let relativePath: String?

    public init(
        url: URL,
        name: String? = nil,
        duration: CMTime? = nil,
        hasVideo: Bool = true,
        hasAudio: Bool = true,
        relativePath: String? = nil
    ) {
        self.url = url
        self.name = name
        self.duration = duration
        self.hasVideo = hasVideo
        self.hasAudio = hasAudio
        self.relativePath = relativePath
    }
}

// MARK: - Test File Asset Provider

/// In-memory asset provider for testing PipelineNeo export workflows.
///
/// Assets are registered by their resource ID (e.g., `"r2"`, `"r3"`), which matches
/// the IDs used in `PipelineNeo.FCPXMLExportAsset` and `PipelineNeo.TimelineClip.assetRef`.
///
/// This provider has NO SwiftData dependency and NO `AssetProvider` protocol conformance.
/// It works directly with PipelineNeo types for maximum test simplicity.
public final class TestFileAssetProvider: @unchecked Sendable {
    private var registry: [String: TestFileAssetEntry] = [:]

    public init() {}

    /// Registers a test asset by resource ID.
    ///
    /// - Parameters:
    ///   - assetID: The resource ID for this asset (e.g., `"r2"`).
    ///   - url: The file URL (can be a dummy path for unit tests).
    ///   - duration: Duration of the asset.
    ///   - hasVideo: Whether the asset has video.
    ///   - hasAudio: Whether the asset has audio.
    ///   - name: Optional display name.
    ///   - relativePath: Optional relative path for bundle exports.
    public func register(
        assetID: String,
        url: URL,
        duration: CMTime? = nil,
        hasVideo: Bool = true,
        hasAudio: Bool = true,
        name: String? = nil,
        relativePath: String? = nil
    ) {
        registry[assetID] = TestFileAssetEntry(
            url: url,
            name: name,
            duration: duration,
            hasVideo: hasVideo,
            hasAudio: hasAudio,
            relativePath: relativePath
        )
    }

    /// Returns the number of registered assets.
    public var count: Int {
        registry.count
    }

    /// Returns all registered asset IDs.
    public var registeredIDs: [String] {
        Array(registry.keys).sorted()
    }

    #if os(macOS)

    /// Retrieves a `PipelineNeo.FCPXMLExportAsset` for the given resource ID.
    ///
    /// Returns `nil` if the resource ID has not been registered. This matches the
    /// graceful error handling pattern used in production (missing assets return nil,
    /// not throw).
    ///
    /// - Parameter assetID: The resource ID to look up (e.g., `"r2"`).
    /// - Returns: A `PipelineNeo.FCPXMLExportAsset`, or `nil` if not found.
    public func asset(for assetID: String) -> PipelineNeo.FCPXMLExportAsset? {
        guard let entry = registry[assetID] else {
            return nil
        }

        return PipelineNeo.FCPXMLExportAsset(
            id: assetID,
            name: entry.name,
            src: entry.url,
            duration: entry.duration,
            hasVideo: entry.hasVideo,
            hasAudio: entry.hasAudio,
            relativePath: entry.relativePath
        )
    }

    /// Retrieves all registered assets as `PipelineNeo.FCPXMLExportAsset` instances.
    ///
    /// Assets are returned sorted by resource ID for deterministic test output.
    ///
    /// - Returns: An array of `PipelineNeo.FCPXMLExportAsset` structs.
    public func allAssets() -> [PipelineNeo.FCPXMLExportAsset] {
        registry.keys.sorted().compactMap { asset(for: $0) }
    }

    #endif // os(macOS)
}
