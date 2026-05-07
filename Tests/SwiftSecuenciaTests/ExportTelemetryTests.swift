//
//  ExportTelemetryTests.swift
//  SwiftSecuencia
//
//  Tests for telemetry instrumentation in ForegroundAudioExporter.
//

import Foundation
import SwiftCompartido
import SwiftData
import Testing

@testable import SwiftSecuencia

@Suite("Export Telemetry Tests")
struct ExportTelemetryTests {

  // MARK: - Test Helpers

  /// Creates a test model container
  private func createTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
      configurations: config
    )
  }

  /// Creates test audio storage with real audio data
  @MainActor
  private func createTestAudio(
    in context: ModelContext,
    prompt: String,
    duration: Double
  ) throws -> TypedDataStorage {
    // Generate real audio data (required for AVFoundation export)
    let audioData = try TestUtilities.generateAudioData(duration: duration)

    let storage = TypedDataStorage(
      providerId: "test-provider",
      requestorID: "test-requestor",
      mimeType: "audio/mp4",
      binaryValue: audioData,
      prompt: prompt,
      durationSeconds: duration
    )
    context.insert(storage)
    return storage
  }

  // MARK: - Export Telemetry Tests

  @Test("Export fires exportStart and exportComplete events")
  @MainActor
  func testExportFiresStartAndCompleteEvents() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create a timeline with clips
    let audio1 = try createTestAudio(in: context, prompt: "First clip", duration: 1.0)
    let audio2 = try createTestAudio(in: context, prompt: "Second clip", duration: 1.5)

    let timeline = Timeline(name: "Test Timeline")
    let clip1 = TimelineClip(
      name: "First clip",
      assetStorageId: audio1.id,
      offset: Timecode.zero,
      duration: Timecode(seconds: 1.0),
      lane: 0
    )
    let clip2 = TimelineClip(
      name: "Second clip",
      assetStorageId: audio2.id,
      offset: Timecode(seconds: 1.0),
      duration: Timecode(seconds: 1.5),
      lane: 0
    )
    timeline.clips = [clip1, clip2]

    context.insert(timeline)
    context.insert(clip1)
    context.insert(clip2)

    // Create mock telemetry reporter
    let telemetry = MockTelemetryReporter()
    let exporter = ForegroundAudioExporter(telemetry: telemetry)

    // Export audio
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".m4a")

    do {
      _ = try await exporter.exportAudio(
        timeline: timeline,
        modelContext: context,
        to: outputURL
      )

      // Verify telemetry events
      let events = await telemetry.events
      #expect(events.count >= 2, "Should have at least exportStart and exportComplete events")

      // Verify exportStart event
      let exportStartEvent = await telemetry.firstEvent { event in
        if case .exportStart = event { return true }
        return false
      }
      #expect(exportStartEvent != nil, "Should capture exportStart event")

      if case let .exportStart(clipCount, modelObjects) = exportStartEvent! {
        #expect(clipCount == 2, "Should report correct clip count")
        #expect(modelObjects >= 0, "Should report ModelContext object count")
      }

      // Verify exportComplete event
      let exportCompleteEvent = await telemetry.firstEvent { event in
        if case .exportComplete = event { return true }
        return false
      }
      #expect(exportCompleteEvent != nil, "Should capture exportComplete event")

      if case let .exportComplete(outputSizeMB, modelObjects, pendingChanges) = exportCompleteEvent! {
        #expect(outputSizeMB > 0, "Should report output file size")
        #expect(modelObjects >= 0, "Should report ModelContext object count")
        // pendingChanges can be true or false depending on SwiftData state
      }

      // Clean up
      try? FileManager.default.removeItem(at: outputURL)

    } catch {
      // Clean up on error
      try? FileManager.default.removeItem(at: outputURL)
      throw error
    }
  }

  @Test("Export reports correct clip count in exportStart event")
  @MainActor
  func testExportReportsCorrectClipCount() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create a timeline with 3 clips
    let audio1 = try createTestAudio(in: context, prompt: "Clip 1", duration: 1.0)
    let audio2 = try createTestAudio(in: context, prompt: "Clip 2", duration: 1.0)
    let audio3 = try createTestAudio(in: context, prompt: "Clip 3", duration: 1.0)

    let timeline = Timeline(name: "Test Timeline")
    let clip1 = TimelineClip(name: "Clip 1", assetStorageId: audio1.id, offset: Timecode.zero, duration: Timecode(seconds: 1.0), lane: 0)
    let clip2 = TimelineClip(name: "Clip 2", assetStorageId: audio2.id, offset: Timecode(seconds: 1.0), duration: Timecode(seconds: 1.0), lane: 0)
    let clip3 = TimelineClip(name: "Clip 3", assetStorageId: audio3.id, offset: Timecode(seconds: 2.0), duration: Timecode(seconds: 1.0), lane: 0)
    timeline.clips = [clip1, clip2, clip3]

    context.insert(timeline)
    context.insert(clip1)
    context.insert(clip2)
    context.insert(clip3)

    // Create mock telemetry reporter
    let telemetry = MockTelemetryReporter()
    let exporter = ForegroundAudioExporter(telemetry: telemetry)

    // Export audio
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".m4a")

    do {
      _ = try await exporter.exportAudio(
        timeline: timeline,
        modelContext: context,
        to: outputURL
      )

      // Verify exportStart has correct clip count
      let exportStartEvent = await telemetry.firstEvent { event in
        if case .exportStart = event { return true }
        return false
      }

      if case let .exportStart(clipCount, _) = exportStartEvent! {
        #expect(clipCount == 3, "Should report 3 clips in exportStart event")
      }

      // Clean up
      try? FileManager.default.removeItem(at: outputURL)

    } catch {
      try? FileManager.default.removeItem(at: outputURL)
      throw error
    }
  }

  @Test("Export reports output file size in MB")
  @MainActor
  func testExportReportsOutputSizeInMB() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create a timeline with one clip
    let audio = try createTestAudio(in: context, prompt: "Test audio", duration: 2.0)

    let timeline = Timeline(name: "Test Timeline")
    let clip = TimelineClip(
      name: "Test clip",
      assetStorageId: audio.id,
      offset: Timecode.zero,
      duration: Timecode(seconds: 2.0),
      lane: 0
    )
    timeline.clips = [clip]

    context.insert(timeline)
    context.insert(clip)

    // Create mock telemetry reporter
    let telemetry = MockTelemetryReporter()
    let exporter = ForegroundAudioExporter(telemetry: telemetry)

    // Export audio
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".m4a")

    do {
      _ = try await exporter.exportAudio(
        timeline: timeline,
        modelContext: context,
        to: outputURL
      )

      // Verify exportComplete reports file size
      let exportCompleteEvent = await telemetry.firstEvent { event in
        if case .exportComplete = event { return true }
        return false
      }

      if case let .exportComplete(outputSizeMB, _, _) = exportCompleteEvent! {
        #expect(outputSizeMB > 0, "Output size should be greater than 0 MB")
        #expect(outputSizeMB < 10, "Output size should be reasonable (< 10 MB for test audio)")

        // Verify file actually exists and size calculation is accurate
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        if let fileSize = fileAttributes?[.size] as? Int64 {
          let expectedSizeMB = Double(fileSize) / (1024 * 1024)
          let tolerance = 0.01  // Allow 0.01 MB tolerance
          #expect(abs(outputSizeMB - expectedSizeMB) < tolerance, "Reported size should match actual file size")
        }
      }

      // Clean up
      try? FileManager.default.removeItem(at: outputURL)

    } catch {
      try? FileManager.default.removeItem(at: outputURL)
      throw error
    }
  }

  @Test("Export without telemetry does not crash")
  @MainActor
  func testExportWithoutTelemetryDoesNotCrash() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create a simple timeline
    let audio = try createTestAudio(in: context, prompt: "Test", duration: 1.0)
    let timeline = Timeline(name: "Test")
    let clip = TimelineClip(name: "Test", assetStorageId: audio.id, offset: Timecode.zero, duration: Timecode(seconds: 1.0), lane: 0)
    timeline.clips = [clip]

    context.insert(timeline)
    context.insert(clip)

    // Create exporter WITHOUT telemetry
    let exporter = ForegroundAudioExporter(telemetry: nil)

    // Export should succeed without telemetry
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".m4a")

    do {
      _ = try await exporter.exportAudio(
        timeline: timeline,
        modelContext: context,
        to: outputURL
      )

      // Verify export succeeded
      #expect(FileManager.default.fileExists(atPath: outputURL.path), "Export should succeed without telemetry")

      // Clean up
      try? FileManager.default.removeItem(at: outputURL)

    } catch {
      try? FileManager.default.removeItem(at: outputURL)
      throw error
    }
  }
}
