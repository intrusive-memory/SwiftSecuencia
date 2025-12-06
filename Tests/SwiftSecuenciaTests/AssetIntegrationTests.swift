import Testing
import Foundation
import SwiftData
import SwiftCompartido
@testable import SwiftSecuencia

// MARK: - Asset Validation Tests

@Test func validateAssetAudioOnNegativeLane() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create audio asset
    let audioAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "audio-test",
        mimeType: "audio/mpeg",
        binaryValue: Data([0x00, 0x01, 0x02]),
        durationSeconds: 30.0
    )
    context.insert(audioAsset)

    // Create clip on negative lane (audio track)
    let clip = TimelineClip(
        assetStorageId: audioAsset.id,
        duration: Timecode(seconds: 30)
    )
    clip.lane = -1

    // Validate should succeed
    let validated = try clip.validateAsset(in: context)
    #expect(validated.id == audioAsset.id)
}

@Test func validateAssetVideoOnPositiveLane() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create video asset
    let videoAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "video-test",
        mimeType: "video/mp4",
        binaryValue: Data([0x00, 0x01, 0x02]),
        durationSeconds: 60.0
    )
    context.insert(videoAsset)

    // Create clip on positive lane
    let clip = TimelineClip(
        assetStorageId: videoAsset.id,
        duration: Timecode(seconds: 60)
    )
    clip.lane = 1

    // Validate should succeed
    let validated = try clip.validateAsset(in: context)
    #expect(validated.id == videoAsset.id)
}

@Test func validateAssetFailsWrongMimeTypeOnNegativeLane() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create video asset
    let videoAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "video-test",
        mimeType: "video/mp4",
        binaryValue: Data([0x00, 0x01, 0x02]),
        durationSeconds: 60.0
    )
    context.insert(videoAsset)

    // Create clip on negative lane (expects audio)
    let clip = TimelineClip(
        assetStorageId: videoAsset.id,
        duration: Timecode(seconds: 60)
    )
    clip.lane = -1

    // Validate should fail
    do {
        _ = try clip.validateAsset(in: context)
        Issue.record("Expected validation to fail for video on audio lane")
    } catch let error as TimelineError {
        if case .invalidFormat = error {
            // Expected
        } else {
            Issue.record("Wrong error type: \(error)")
        }
    }
}

@Test func validateAssetFailsMissingAsset() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create clip with non-existent asset
    let clip = TimelineClip(
        assetStorageId: UUID(),
        duration: Timecode(seconds: 10)
    )

    // Validate should fail
    do {
        _ = try clip.validateAsset(in: context)
        Issue.record("Expected validation to fail for missing asset")
    } catch let error as TimelineError {
        if case .invalidAssetReference = error {
            // Expected
        } else {
            Issue.record("Wrong error type: \(error)")
        }
    }
}

// MARK: - Asset Query Tests

@Test func fetchAssetReturnsAsset() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create asset
    let asset = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "audio/mpeg",
        binaryValue: Data(),
        durationSeconds: 10.0
    )
    context.insert(asset)

    // Create clip
    let clip = TimelineClip(
        assetStorageId: asset.id,
        duration: Timecode(seconds: 10)
    )

    // Fetch asset
    let fetched = clip.fetchAsset(in: context)
    #expect(fetched?.id == asset.id)
}

@Test func fetchAssetReturnsNilForMissing() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create clip with non-existent asset
    let clip = TimelineClip(
        assetStorageId: UUID(),
        duration: Timecode(seconds: 10)
    )

    // Fetch should return nil
    let fetched = clip.fetchAsset(in: context)
    #expect(fetched == nil)
}

@Test func isAudioClipDetectsAudio() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create audio asset
    let audioAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "audio/mpeg",
        binaryValue: Data(),
        durationSeconds: 10.0
    )
    context.insert(audioAsset)

    // Create clip
    let clip = TimelineClip(
        assetStorageId: audioAsset.id,
        duration: Timecode(seconds: 10)
    )

    #expect(clip.isAudioClip(in: context) == true)
    #expect(clip.isVideoClip(in: context) == false)
    #expect(clip.isImageClip(in: context) == false)
}

@Test func isVideoClipDetectsVideo() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create video asset
    let videoAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "video/mp4",
        binaryValue: Data(),
        durationSeconds: 60.0
    )
    context.insert(videoAsset)

    // Create clip
    let clip = TimelineClip(
        assetStorageId: videoAsset.id,
        duration: Timecode(seconds: 60)
    )

    #expect(clip.isVideoClip(in: context) == true)
    #expect(clip.isAudioClip(in: context) == false)
    #expect(clip.isImageClip(in: context) == false)
}

@Test func isImageClipDetectsImage() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    // Create image asset
    let imageAsset = TypedDataStorage(
        providerId: "test",
        requestorID: "test",
        mimeType: "image/png",
        binaryValue: Data(),
        durationSeconds: nil
    )
    context.insert(imageAsset)

    // Create clip
    let clip = TimelineClip(
        assetStorageId: imageAsset.id,
        duration: Timecode(seconds: 5)
    )

    #expect(clip.isImageClip(in: context) == true)
    #expect(clip.isVideoClip(in: context) == false)
    #expect(clip.isAudioClip(in: context) == false)
}

// MARK: - Timeline Asset Query Tests

@Test func timelineAllAssetsReturnsUniqueAssets() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    // Create assets
    let audio1 = TypedDataStorage(providerId: "test", requestorID: "a1", mimeType: "audio/mpeg", binaryValue: Data())
    let audio2 = TypedDataStorage(providerId: "test", requestorID: "a2", mimeType: "audio/wav", binaryValue: Data())
    let video1 = TypedDataStorage(providerId: "test", requestorID: "v1", mimeType: "video/mp4", binaryValue: Data())

    context.insert(audio1)
    context.insert(audio2)
    context.insert(video1)

    // Add clips (some using same asset)
    timeline.insertClip(TimelineClip(assetStorageId: audio1.id, duration: Timecode(seconds: 10)), at: .zero)
    timeline.insertClip(TimelineClip(assetStorageId: audio1.id, duration: Timecode(seconds: 10)), at: Timecode(seconds: 10))
    timeline.insertClip(TimelineClip(assetStorageId: audio2.id, duration: Timecode(seconds: 5)), at: Timecode(seconds: 20))
    timeline.insertClip(TimelineClip(assetStorageId: video1.id, duration: Timecode(seconds: 30)), at: .zero)

    // Should return 3 unique assets
    let assets = timeline.allAssets(in: context)
    #expect(assets.count == 3)

    let assetIds = Set(assets.map { $0.id })
    #expect(assetIds.contains(audio1.id))
    #expect(assetIds.contains(audio2.id))
    #expect(assetIds.contains(video1.id))
}

@Test func timelineAudioAssetsFiltersAudio() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    // Create assets
    let audio = TypedDataStorage(providerId: "test", requestorID: "a", mimeType: "audio/mpeg", binaryValue: Data())
    let video = TypedDataStorage(providerId: "test", requestorID: "v", mimeType: "video/mp4", binaryValue: Data())

    context.insert(audio)
    context.insert(video)

    // Add clips
    timeline.insertClip(TimelineClip(assetStorageId: audio.id, duration: Timecode(seconds: 10)), at: .zero)
    timeline.insertClip(TimelineClip(assetStorageId: video.id, duration: Timecode(seconds: 30)), at: .zero)

    // Should return only audio
    let audioAssets = timeline.audioAssets(in: context)
    #expect(audioAssets.count == 1)
    #expect(audioAssets[0].id == audio.id)
}

@Test func timelineVideoAssetsFiltersVideo() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    // Create assets
    let audio = TypedDataStorage(providerId: "test", requestorID: "a", mimeType: "audio/mpeg", binaryValue: Data())
    let video = TypedDataStorage(providerId: "test", requestorID: "v", mimeType: "video/mp4", binaryValue: Data())

    context.insert(audio)
    context.insert(video)

    // Add clips
    timeline.insertClip(TimelineClip(assetStorageId: audio.id, duration: Timecode(seconds: 10)), at: .zero)
    timeline.insertClip(TimelineClip(assetStorageId: video.id, duration: Timecode(seconds: 30)), at: .zero)

    // Should return only video
    let videoAssets = timeline.videoAssets(in: context)
    #expect(videoAssets.count == 1)
    #expect(videoAssets[0].id == video.id)
}

@Test func timelineImageAssetsFiltersImages() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    // Create assets
    let image = TypedDataStorage(providerId: "test", requestorID: "i", mimeType: "image/png", binaryValue: Data())
    let video = TypedDataStorage(providerId: "test", requestorID: "v", mimeType: "video/mp4", binaryValue: Data())

    context.insert(image)
    context.insert(video)

    // Add clips
    timeline.insertClip(TimelineClip(assetStorageId: image.id, duration: Timecode(seconds: 5)), at: .zero)
    timeline.insertClip(TimelineClip(assetStorageId: video.id, duration: Timecode(seconds: 30)), at: .zero)

    // Should return only image
    let imageAssets = timeline.imageAssets(in: context)
    #expect(imageAssets.count == 1)
    #expect(imageAssets[0].id == image.id)
}

@Test func timelineValidateAllAssetsDetectsInvalid() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
    let context = ModelContext(container)

    let timeline = Timeline(name: "Test")
    context.insert(timeline)

    // Create one valid asset
    let validAsset = TypedDataStorage(providerId: "test", requestorID: "valid", mimeType: "audio/mpeg", binaryValue: Data())
    context.insert(validAsset)

    // Add clips - one valid, one invalid
    let validClip = TimelineClip(assetStorageId: validAsset.id, duration: Timecode(seconds: 10))
    let invalidClip = TimelineClip(assetStorageId: UUID(), duration: Timecode(seconds: 10))

    timeline.insertClip(validClip, at: .zero)
    timeline.insertClip(invalidClip, at: Timecode(seconds: 10))

    // Validate should return invalid clip ID
    let invalidIds = timeline.validateAllAssets(in: context)
    #expect(invalidIds.count == 1)
    #expect(invalidIds.contains(invalidClip.id))
}

@Test func timelineClipsWithAssetIdFindsClips() async throws {
    let timeline = Timeline(name: "Test")

    let assetId1 = UUID()
    let assetId2 = UUID()

    // Add clips with different assets
    timeline.insertClip(TimelineClip(assetStorageId: assetId1, duration: Timecode(seconds: 10)), at: .zero)
    timeline.insertClip(TimelineClip(assetStorageId: assetId1, duration: Timecode(seconds: 10)), at: Timecode(seconds: 10))
    timeline.insertClip(TimelineClip(assetStorageId: assetId2, duration: Timecode(seconds: 5)), at: Timecode(seconds: 20))

    // Should find 2 clips with assetId1
    let clips1 = timeline.clips(withAssetId: assetId1)
    #expect(clips1.count == 2)

    // Should find 1 clip with assetId2
    let clips2 = timeline.clips(withAssetId: assetId2)
    #expect(clips2.count == 1)
}
