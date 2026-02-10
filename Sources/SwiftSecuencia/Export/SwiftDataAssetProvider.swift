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
public struct SwiftDataAssetProvider: AssetProvider {
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

        // Extract duration if available
        let durationSeconds: Double? = {
            if let metadata = storage.metadata,
               let durationValue = metadata["duration"] as? Double {
                return durationValue
            }
            return nil
        }()

        // Extract dimensions if available
        let width: Int? = {
            if let metadata = storage.metadata,
               let widthValue = metadata["width"] as? Int {
                return widthValue
            }
            return nil
        }()

        let height: Int? = {
            if let metadata = storage.metadata,
               let heightValue = metadata["height"] as? Int {
                return heightValue
            }
            return nil
        }()

        return AssetMetadata(
            id: id,
            name: storage.name,
            mimeType: mimeType,
            durationSeconds: durationSeconds,
            hasVideo: hasVideo,
            hasAudio: hasAudio,
            width: width,
            height: height
        )
    }

    public func assetFileURL(for id: UUID) throws -> URL {
        // Fetch the TypedDataStorage asset from SwiftData
        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.id == id
            }
        )

        guard let storage = try modelContext.fetch(descriptor).first else {
            throw AssetProviderError.assetNotFound(id)
        }

        // Return the file reference if available
        guard let fileReference = storage.fileReference else {
            throw AssetProviderError.fileNotFound(id, URL(fileURLWithPath: "/dev/null"))
        }

        return fileReference
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
