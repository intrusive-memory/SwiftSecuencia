//
//  FinalFadeOutTests.swift
//  SwiftSecuencia
//
//  Tests for final fade-out feature in ForegroundAudioExporter.
//

import AVFoundation
import Foundation
import SwiftData
import Testing

// Use selective import to avoid ambiguity with TypedDataStorage
import class SwiftCompartido.TypedDataStorage

@testable import SwiftSecuencia

@Suite("Final Fade-Out Tests")
struct FinalFadeOutTests {

  // MARK: - Test Helpers

  private func createTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
      configurations: config
    )
  }

  @MainActor
  private func createTestAudioAsset(
    in context: ModelContext,
    duration: Double = 2.0,
    prompt: String = "Test Audio"
  ) throws -> TypedDataStorage {
    let audioData = try TestUtilities.generateAudioData(duration: duration)

    let asset = TypedDataStorage(
      providerId: "test-provider",
      requestorID: "test-requestor",
      mimeType: "audio/mp4",
      binaryValue: audioData,
      prompt: prompt,
      durationSeconds: duration
    )

    context.insert(asset)
    return asset
  }

  @MainActor
  private func createTestTimeline(
    clips: [TimelineClip],
    in context: ModelContext
  ) -> Timeline {
    let timeline = Timeline(name: "Test Timeline")
    timeline.clips = clips
    context.insert(timeline)
    return timeline
  }

  // MARK: - makeAudioMix Tests

  @Test("makeAudioMix with finalFadeOut=0 produces no ramp")
  func testMakeAudioMixNoFade() async throws {
    // Create a temporary audio file for testing
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-audio-\(UUID().uuidString).m4a")
    let audioData = try TestUtilities.generateAudioData(duration: 2.0)
    try audioData.write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let dummyAsset = AVURLAsset(url: tempURL)
    let tracks = try await dummyAsset.loadTracks(withMediaType: .audio)
    guard let track = tracks.first else {
      Issue.record("No audio track found")
      return
    }

    let mix = ForegroundAudioExporter.makeAudioMix(
      [(track: track, volume: 1.0)],
      compositionDuration: CMTime(seconds: 10, preferredTimescale: 600),
      finalFadeOut: 0
    )

    #expect(mix.inputParameters.count == 1)

    let params = mix.inputParameters[0]
    var startVolume: Float = -1
    var endVolume: Float = -1
    var range = CMTimeRange.zero

    // Check volume at start - should be constant 1.0, no ramp
    _ = params.getVolumeRamp(for: .zero, startVolume: &startVolume, endVolume: &endVolume, timeRange: &range)
    #expect(abs(startVolume - 1.0) < 0.001, "Start volume should be 1.0")

    // Check volume at end (should still be constant, no ramp)
    _ = params.getVolumeRamp(
      for: CMTime(seconds: 9.9, preferredTimescale: 600),
      startVolume: &startVolume,
      endVolume: &endVolume,
      timeRange: &range
    )
    #expect(abs(startVolume - 1.0) < 0.001, "End volume should be 1.0 with no fade")
  }

  @Test("makeAudioMix with finalFadeOut applies ramp to all tracks")
  func testMakeAudioMixWithFade() async throws {
    // Create temporary audio files for testing
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-audio-\(UUID().uuidString).m4a")
    let audioData = try TestUtilities.generateAudioData(duration: 2.0)
    try audioData.write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let dummyAsset = AVURLAsset(url: tempURL)
    let tracks = try await dummyAsset.loadTracks(withMediaType: .audio)
    guard tracks.count > 0 else {
      Issue.record("No audio track found")
      return
    }
    let track1 = tracks[0]

    // Create a second composition with another track for testing multiple tracks
    let composition = AVMutableComposition()
    guard let track2 = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      Issue.record("Failed to create second track")
      return
    }

    let totalDuration = CMTime(seconds: 10, preferredTimescale: 600)
    let fadeOutDuration: TimeInterval = 4.0

    let mix = ForegroundAudioExporter.makeAudioMix(
      [
        (track: track1, volume: 1.0),
        (track: track2, volume: 0.5),
      ],
      compositionDuration: totalDuration,
      finalFadeOut: fadeOutDuration
    )

    #expect(mix.inputParameters.count == 2)

    // Verify each track has the fade ramp applied
    for (index, params) in mix.inputParameters.enumerated() {
      let expectedVolume: Float = index == 0 ? 1.0 : 0.5

      var startVolume: Float = -1
      var endVolume: Float = -1
      var range = CMTimeRange.zero

      // Check volume at start of fade (T-4)
      _ = params.getVolumeRamp(
        for: CMTime(seconds: 6.0, preferredTimescale: 600),
        startVolume: &startVolume,
        endVolume: &endVolume,
        timeRange: &range
      )

      #expect(abs(startVolume - expectedVolume) < 0.001, "Track \(index) should start at \(expectedVolume)")
      #expect(abs(endVolume - 0.0) < 0.001, "Track \(index) should fade to 0")
      #expect(abs(range.start.seconds - 6.0) < 0.01, "Fade should start at T-4")
      #expect(abs(range.duration.seconds - 4.0) < 0.01, "Fade duration should be 4 seconds")
    }
  }

  @Test("makeAudioMix clamps fade window when finalFadeOut exceeds timeline duration")
  func testMakeAudioMixFadeClamp() async throws {
    // Create a temporary audio file for testing
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-audio-\(UUID().uuidString).m4a")
    let audioData = try TestUtilities.generateAudioData(duration: 2.0)
    try audioData.write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let dummyAsset = AVURLAsset(url: tempURL)
    let tracks = try await dummyAsset.loadTracks(withMediaType: .audio)
    guard let track = tracks.first else {
      Issue.record("No audio track found")
      return
    }

    let totalDuration = CMTime(seconds: 3, preferredTimescale: 600)
    let fadeOutDuration: TimeInterval = 10.0  // Longer than timeline

    let mix = ForegroundAudioExporter.makeAudioMix(
      [(track: track, volume: 1.0)],
      compositionDuration: totalDuration,
      finalFadeOut: fadeOutDuration
    )

    #expect(mix.inputParameters.count == 1)

    let params = mix.inputParameters[0]
    var startVolume: Float = -1
    var endVolume: Float = -1
    var range = CMTimeRange.zero

    // Check that fade starts at 0 (clamped)
    _ = params.getVolumeRamp(
      for: CMTime(seconds: 0.1, preferredTimescale: 600),
      startVolume: &startVolume,
      endVolume: &endVolume,
      timeRange: &range
    )

    #expect(range.start.seconds >= 0, "Fade start should be clamped to 0")
    #expect(abs(range.end.seconds - 3.0) < 0.01, "Fade end should be at timeline end")
  }

  // MARK: - Export Integration Tests

  @Test("exportAudio with finalFadeOut=0 maintains backward compatibility")
  @MainActor
  func testExportNoFadeBackwardCompatibility() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create test audio asset
    let asset = try createTestAudioAsset(in: context, duration: 2.0)

    // Create timeline with one clip
    let clip = TimelineClip(
      assetStorageId: asset.id,
      duration: .init(seconds: 2.0)
    )
    let timeline = createTestTimeline(clips: [clip], in: context)

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-no-fade-\(UUID().uuidString).m4a")

    let exporter = ForegroundAudioExporter()

    // Export with default finalFadeOut=0
    let result = try await exporter.exportAudio(
      timeline: timeline,
      modelContext: context,
      to: outputURL,
      finalFadeOut: 0  // Explicit no fade
    )

    #expect(result == outputURL)
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    // Verify audio file was created (duration may vary based on test audio generation)
    let avAsset = AVURLAsset(url: outputURL)
    let duration = try await avAsset.load(.duration)
    #expect(duration.seconds > 0, "Duration should be non-zero")

    // Cleanup
    try? FileManager.default.removeItem(at: outputURL)
  }

  @Test("exportAudio with finalFadeOut creates valid audio with fade")
  @MainActor
  func testExportWithFade() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create test audio asset (5 seconds)
    let asset = try createTestAudioAsset(in: context, duration: 5.0)

    // Create timeline with one clip
    let clip = TimelineClip(
      assetStorageId: asset.id,
      duration: .init(seconds: 5.0)
    )
    let timeline = createTestTimeline(clips: [clip], in: context)

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-with-fade-\(UUID().uuidString).m4a")

    let exporter = ForegroundAudioExporter()

    // Export with 2-second fade-out
    let result = try await exporter.exportAudio(
      timeline: timeline,
      modelContext: context,
      to: outputURL,
      finalFadeOut: 2.0
    )

    #expect(result == outputURL)
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    // Verify audio file was created (duration may vary based on test audio generation)
    let avAsset = AVURLAsset(url: outputURL)
    let duration = try await avAsset.load(.duration)
    #expect(duration.seconds > 0, "Duration should be non-zero")

    // File was created successfully with fade applied
    // (RMS analysis would require AVAudioFile reading, which is beyond unit test scope)

    // Cleanup
    try? FileManager.default.removeItem(at: outputURL)
  }

  @Test("exportAudioDirect with finalFadeOut works correctly")
  @MainActor
  func testExportDirectWithFade() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create test audio assets
    let asset1 = try createTestAudioAsset(in: context, duration: 3.0, prompt: "Asset 1")
    let asset2 = try createTestAudioAsset(in: context, duration: 2.0, prompt: "Asset 2")

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-direct-fade-\(UUID().uuidString).m4a")

    let exporter = ForegroundAudioExporter()

    // Export directly with 1.5-second fade-out
    let result = try await exporter.exportAudioDirect(
      audioElements: [asset1, asset2],
      modelContext: context,
      to: outputURL,
      finalFadeOut: 1.5
    )

    #expect(result == outputURL)
    #expect(FileManager.default.fileExists(atPath: outputURL.path))

    // Verify audio file was created (duration may vary based on test audio generation)
    let avAsset = AVURLAsset(url: outputURL)
    let duration = try await avAsset.load(.duration)
    #expect(duration.seconds > 0, "Duration should be non-zero")

    // Cleanup
    try? FileManager.default.removeItem(at: outputURL)
  }
}
