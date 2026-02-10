import Testing
import Foundation
import SwiftData
import SwiftCompartido
@testable import SwiftSecuencia

@Suite("FileAssetProvider Tests")
struct FileAssetProviderTests {

    @Test("Returns correct metadata for registered asset")
    func returnsCorrectMetadata() throws {
        // Create a temporary test file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-asset.m4a")
        try Data("test audio".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Create entry
        let assetID = UUID()
        let entry = FileAssetEntry(
            fileURL: tempURL,
            name: "Test Audio",
            mimeType: "audio/mp4",
            durationSeconds: 30.0,
            hasVideo: false,
            hasAudio: true,
            width: nil,
            height: nil
        )

        // Create provider with registered entry
        let provider = FileAssetProvider(registry: [assetID: entry])

        // Retrieve metadata
        let metadata = try provider.assetMetadata(for: assetID)

        #expect(metadata.id == assetID)
        #expect(metadata.name == "Test Audio")
        #expect(metadata.mimeType == "audio/mp4")
        #expect(metadata.durationSeconds == 30.0)
        #expect(metadata.hasVideo == false)
        #expect(metadata.hasAudio == true)
        #expect(metadata.width == nil)
        #expect(metadata.height == nil)
    }

    @Test("Returns correct file URL")
    func returnsCorrectFileURL() throws {
        // Create a temporary test file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-video.mov")
        try Data("test video".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let assetID = UUID()
        let entry = FileAssetEntry(
            fileURL: tempURL,
            name: "Test Video",
            mimeType: "video/quicktime",
            durationSeconds: 60.0,
            hasVideo: true,
            hasAudio: true
        )

        let provider = FileAssetProvider(registry: [assetID: entry])

        // Retrieve file URL
        let fileURL = try provider.assetFileURL(for: assetID)

        #expect(fileURL == tempURL)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("Unregistered ID throws assetNotFound")
    func unregisteredIDThrowsAssetNotFound() throws {
        let provider = FileAssetProvider()
        let unknownID = UUID()

        #expect(throws: AssetProviderError.self) {
            try provider.assetMetadata(for: unknownID)
        }
    }

    @Test("Nonexistent file throws fileNotFound")
    func nonexistentFileThrowsFileNotFound() throws {
        let assetID = UUID()
        let nonexistentURL = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).mov")

        let entry = FileAssetEntry(
            fileURL: nonexistentURL,
            name: "Missing File",
            mimeType: "video/quicktime",
            durationSeconds: 10.0,
            hasVideo: true,
            hasAudio: true
        )

        let provider = FileAssetProvider(registry: [assetID: entry])

        #expect(throws: AssetProviderError.self) {
            try provider.assetFileURL(for: assetID)
        }
    }

    @Test("hasVideo and hasAudio flags match registration")
    func mediaFlagsMatchRegistration() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-image.png")
        try Data("test image".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let assetID = UUID()

        // Test 1: Video with audio
        let videoEntry = FileAssetEntry(
            fileURL: tempURL,
            name: "Video Asset",
            mimeType: "video/quicktime",
            hasVideo: true,
            hasAudio: true
        )
        let videoProvider = FileAssetProvider(registry: [assetID: videoEntry])
        let videoMetadata = try videoProvider.assetMetadata(for: assetID)
        #expect(videoMetadata.hasVideo == true)
        #expect(videoMetadata.hasAudio == true)

        // Test 2: Audio only
        let audioEntry = FileAssetEntry(
            fileURL: tempURL,
            name: "Audio Asset",
            mimeType: "audio/mp4",
            hasVideo: false,
            hasAudio: true
        )
        let audioProvider = FileAssetProvider(registry: [assetID: audioEntry])
        let audioMetadata = try audioProvider.assetMetadata(for: assetID)
        #expect(audioMetadata.hasVideo == false)
        #expect(audioMetadata.hasAudio == true)

        // Test 3: Image (video only, no audio)
        let imageEntry = FileAssetEntry(
            fileURL: tempURL,
            name: "Image Asset",
            mimeType: "image/png",
            hasVideo: true,
            hasAudio: false
        )
        let imageProvider = FileAssetProvider(registry: [assetID: imageEntry])
        let imageMetadata = try imageProvider.assetMetadata(for: assetID)
        #expect(imageMetadata.hasVideo == true)
        #expect(imageMetadata.hasAudio == false)
    }

    @Test("Register method creates new provider with additional asset")
    func registerMethodAddsAsset() throws {
        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("asset1.m4a")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("asset2.m4a")
        try Data("asset1".utf8).write(to: tempURL1)
        try Data("asset2".utf8).write(to: tempURL2)
        defer {
            try? FileManager.default.removeItem(at: tempURL1)
            try? FileManager.default.removeItem(at: tempURL2)
        }

        let id1 = UUID()
        let id2 = UUID()

        let entry1 = FileAssetEntry(
            fileURL: tempURL1,
            name: "Asset 1",
            mimeType: "audio/mp4",
            hasVideo: false,
            hasAudio: true
        )

        let entry2 = FileAssetEntry(
            fileURL: tempURL2,
            name: "Asset 2",
            mimeType: "audio/mp4",
            hasVideo: false,
            hasAudio: true
        )

        // Start with one asset
        let provider1 = FileAssetProvider(registry: [id1: entry1])
        #expect(provider1.assetIDs.count == 1)

        // Register second asset
        let provider2 = provider1.register(entry2, for: id2)
        #expect(provider2.assetIDs.count == 2)
        #expect(provider2.assetIDs.contains(id1))
        #expect(provider2.assetIDs.contains(id2))
    }

    @Test("assetData reads file from disk")
    func assetDataReadsFileFromDisk() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-data.txt")
        let expectedData = Data("Hello, World!".utf8)
        try expectedData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let assetID = UUID()
        let entry = FileAssetEntry(
            fileURL: tempURL,
            name: "Test File",
            mimeType: "text/plain",
            hasVideo: false,
            hasAudio: false
        )

        let provider = FileAssetProvider(registry: [assetID: entry])
        let data = try provider.assetData(for: assetID)

        #expect(data == expectedData)
    }
}

// MARK: - SwiftDataAssetProvider Tests

@Suite("SwiftDataAssetProvider Tests")
@MainActor
struct SwiftDataAssetProviderTests {

    @Test("Default assetData implementation throws dataNotSupported")
    func defaultAssetDataThrowsDataNotSupported() async throws {
        // Create in-memory container
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        // Create a test asset with fileReference but no binaryValue
        let assetID = UUID()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-file.m4a")
        try Data("test".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let storage = TypedDataStorage(
            id: assetID,
            name: "Test Asset",
            mimeType: "audio/mp4",
            binaryValue: nil,  // No binary data
            fileReference: tempURL
        )
        context.insert(storage)
        try context.save()

        // Create provider
        let provider = SwiftDataAssetProvider(modelContext: context)

        // Attempting to get data should throw dataNotSupported
        #expect(throws: AssetProviderError.self) {
            try provider.assetData(for: assetID)
        }
    }

    @Test("Derives hasVideo=true, hasAudio=true for video/quicktime")
    func derivesVideoAndAudioFlagsForVideo() async throws {
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let assetID = UUID()
        let storage = TypedDataStorage(
            id: assetID,
            name: "Test Video",
            mimeType: "video/quicktime",
            binaryValue: Data("video".utf8)
        )
        context.insert(storage)
        try context.save()

        let provider = SwiftDataAssetProvider(modelContext: context)
        let metadata = try provider.assetMetadata(for: assetID)

        #expect(metadata.hasVideo == true)
        #expect(metadata.hasAudio == true)
        #expect(metadata.mimeType == "video/quicktime")
    }

    @Test("Derives hasVideo=false, hasAudio=true for audio/mp4")
    func derivesAudioOnlyFlagsForAudio() async throws {
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let assetID = UUID()
        let storage = TypedDataStorage(
            id: assetID,
            name: "Test Audio",
            mimeType: "audio/mp4",
            binaryValue: Data("audio".utf8)
        )
        context.insert(storage)
        try context.save()

        let provider = SwiftDataAssetProvider(modelContext: context)
        let metadata = try provider.assetMetadata(for: assetID)

        #expect(metadata.hasVideo == false)
        #expect(metadata.hasAudio == true)
        #expect(metadata.mimeType == "audio/mp4")
    }

    @Test("Derives hasVideo=true, hasAudio=false for image/png")
    func derivesVideoOnlyFlagsForImage() async throws {
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let assetID = UUID()
        let storage = TypedDataStorage(
            id: assetID,
            name: "Test Image",
            mimeType: "image/png",
            binaryValue: Data("image".utf8)
        )
        context.insert(storage)
        try context.save()

        let provider = SwiftDataAssetProvider(modelContext: context)
        let metadata = try provider.assetMetadata(for: assetID)

        #expect(metadata.hasVideo == true)
        #expect(metadata.hasAudio == false)
        #expect(metadata.mimeType == "image/png")
    }

    @Test("assetFileURL returns fileReference when available")
    func assetFileURLReturnsFileReference() async throws {
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let assetID = UUID()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-ref.m4a")
        try Data("test".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let storage = TypedDataStorage(
            id: assetID,
            name: "Test Asset",
            mimeType: "audio/mp4",
            binaryValue: nil,
            fileReference: tempURL
        )
        context.insert(storage)
        try context.save()

        let provider = SwiftDataAssetProvider(modelContext: context)
        let fileURL = try provider.assetFileURL(for: assetID)

        #expect(fileURL == tempURL)
    }

    @Test("assetFileURL throws fileNotFound when fileReference is nil")
    func assetFileURLThrowsWhenNoFileReference() async throws {
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let assetID = UUID()
        let storage = TypedDataStorage(
            id: assetID,
            name: "Test Asset",
            mimeType: "audio/mp4",
            binaryValue: Data("audio".utf8),
            fileReference: nil  // No file reference
        )
        context.insert(storage)
        try context.save()

        let provider = SwiftDataAssetProvider(modelContext: context)

        #expect(throws: AssetProviderError.self) {
            try provider.assetFileURL(for: assetID)
        }
    }

    @Test("assetData returns binaryValue when available")
    func assetDataReturnsBinaryValue() async throws {
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let assetID = UUID()
        let expectedData = Data("Hello from SwiftData!".utf8)
        let storage = TypedDataStorage(
            id: assetID,
            name: "Test Asset",
            mimeType: "audio/mp4",
            binaryValue: expectedData
        )
        context.insert(storage)
        try context.save()

        let provider = SwiftDataAssetProvider(modelContext: context)
        let data = try provider.assetData(for: assetID)

        #expect(data == expectedData)
    }

    @Test("Extracts metadata dimensions and duration")
    func extractsMetadataDimensionsAndDuration() async throws {
        let schema = Schema([TypedDataStorage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let assetID = UUID()
        let storage = TypedDataStorage(
            id: assetID,
            name: "Test Video",
            mimeType: "video/mp4",
            binaryValue: Data("video".utf8)
        )
        storage.metadata = [
            "duration": 120.5,
            "width": 1920,
            "height": 1080
        ]
        context.insert(storage)
        try context.save()

        let provider = SwiftDataAssetProvider(modelContext: context)
        let metadata = try provider.assetMetadata(for: assetID)

        #expect(metadata.durationSeconds == 120.5)
        #expect(metadata.width == 1920)
        #expect(metadata.height == 1080)
    }
}
