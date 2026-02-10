import Foundation
import SwiftData
import SwiftCompartido

/// Asset provider that fetches assets from a SwiftData `ModelContext`.
///
/// This provider retrieves media assets stored in SwiftData's `TypedDataStorage` model.
/// It derives `hasVideo` and `hasAudio` flags from the asset's MIME type.
///
/// - Important: This struct must be used on the `@MainActor` because `ModelContext`
///   is not `Sendable` and requires main actor isolation.
@MainActor
public struct SwiftDataAssetProvider: @preconcurrency AssetProvider {
    private let modelContext: ModelContext

    /// Creates a SwiftData asset provider.
    ///
    /// - Parameter modelContext: The SwiftData model context to fetch assets from.
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - AssetProvider Implementation

    public func assetMetadata(for id: UUID) throws -> AssetMetadata {
        // Fetch the TypedDataStorage asset from SwiftData
        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.id == id
            }
        )

        guard let storage = try modelContext.fetch(descriptor).first else {
            throw AssetProviderError.assetNotFound(id)
        }

        // Derive hasVideo and hasAudio from MIME type
        let mimeType = storage.mimeType
        let hasVideo = mimeType.hasPrefix("video/") || mimeType.hasPrefix("image/")
        let hasAudio = mimeType.hasPrefix("video/") || mimeType.hasPrefix("audio/")

        // Extract duration if available from TypedDataStorage properties
        let durationSeconds = storage.durationSeconds

        // Extract dimensions if available
        let width = storage.width
        let height = storage.height

        // Generate a name from prompt or use a default
        let name = storage.prompt.isEmpty ? "Asset-\(id.uuidString.prefix(8))" : String(storage.prompt.prefix(50))

        return AssetMetadata(
            id: id,
            name: name,
            mimeType: mimeType,
            durationSeconds: durationSeconds,
            hasVideo: hasVideo,
            hasAudio: hasAudio,
            width: width,
            height: height
        )
    }

    public func assetFileURL(for id: UUID) throws -> URL {
        // SwiftData storage doesn't provide direct file URLs
        // TypedDataStorage stores data in SwiftData, not as accessible file URLs
        // CLI and other file-based workflows should use FileAssetProvider instead
        // FCPXMLBundleExporter uses assetData() which is supported
        throw AssetProviderError.dataNotSupported
    }

    public func assetData(for id: UUID) throws -> Data {
        // Fetch the TypedDataStorage asset from SwiftData
        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.id == id
            }
        )

        guard let storage = try modelContext.fetch(descriptor).first else {
            throw AssetProviderError.assetNotFound(id)
        }

        // Return the binary value if available
        guard let binaryValue = storage.binaryValue else {
            throw AssetProviderError.dataNotSupported
        }

        return binaryValue
    }
}
