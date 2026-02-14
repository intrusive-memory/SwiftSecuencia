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
        // Fetch the TypedDataStorage asset from SwiftData
        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.id == id
            }
        )

        guard let storage = try modelContext.fetch(descriptor).first else {
            throw AssetProviderError.assetNotFound(id)
        }

        // Create a temporary file from binaryValue to support DTD validation tests
        // Note: fileReference support requires StorageAreaReference which isn't available in this context
        // For production use with file references, use FileAssetProvider instead
        if let binaryValue = storage.binaryValue {
            // Create a temporary file path
            let tempDir = FileManager.default.temporaryDirectory
            let ext = fileExtension(for: storage.mimeType)
            let tempURL = tempDir.appendingPathComponent("\(id.uuidString).\(ext)")

            // Write data if file doesn't exist
            if !FileManager.default.fileExists(atPath: tempURL.path) {
                try binaryValue.write(to: tempURL)
            }

            return tempURL
        }

        // SwiftData storage without binary data doesn't provide direct file URLs
        // CLI and other file-based workflows should use FileAssetProvider instead
        throw AssetProviderError.dataNotSupported
    }

    /// Returns file extension for MIME type.
    private func fileExtension(for mimeType: String) -> String {
        let components = mimeType.split(separator: "/")
        guard components.count == 2 else { return "dat" }

        let type = String(components[0])
        let subtype = String(components[1])

        // Map common MIME types to extensions
        switch subtype {
        case "mp4":
            // audio/mp4 uses .m4a extension, video/mp4 uses .mp4
            return type == "audio" ? "m4a" : "mp4"
        case "quicktime": return "mov"
        case "mpeg": return "mp3"
        case "wav", "x-wav", "vnd.wave": return "wav"
        case "aiff", "x-aiff": return "aiff"
        case "png": return "png"
        case "jpeg": return "jpg"
        default: return subtype
        }
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
