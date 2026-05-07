//
//  TimelineTelemetryTests.swift
//  SwiftSecuencia
//
//  Tests for telemetry instrumentation in ScreenplayToTimelineConverter.
//

import Foundation
import SwiftCompartido
import SwiftData
import Testing

@testable import SwiftSecuencia

@Suite("Timeline Telemetry Tests")
struct TimelineTelemetryTests {

  // MARK: - Test Helpers

  /// Creates a test model container
  private func createTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
      configurations: config
    )
  }

  /// Creates test audio storage
  @MainActor
  private func createTestAudio(
    in context: ModelContext,
    prompt: String,
    duration: Double,
    sizeKB: Int = 10
  ) -> TypedDataStorage {
    // Create audio data of specified size (in KB)
    let audioData = Data(repeating: 0x00, count: sizeKB * 1024)

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

  // MARK: - Timeline Conversion Telemetry Tests

  @Test("Timeline conversion fires start and complete events")
  @MainActor
  func testTimelineConversionFiresStartAndCompleteEvents() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create audio elements
    let audio1 = createTestAudio(in: context, prompt: "First", duration: 2.0)
    let audio2 = createTestAudio(in: context, prompt: "Second", duration: 3.0)
    let audioElements = [audio1, audio2]

    // Create mock telemetry reporter
    let telemetry = MockTelemetryReporter()
    let converter = ScreenplayToTimelineConverter(telemetry: telemetry)

    // Convert to timeline
    _ = try await converter.convertToTimeline(
      screenplayName: "Test Script",
      audioElements: audioElements
    )

    // Verify telemetry events
    let events = await telemetry.events
    #expect(events.count == 2, "Should have timelineConversionStart and timelineConversionComplete events")

    // Verify timelineConversionStart event
    let startEvent = await telemetry.firstEvent { event in
      if case .timelineConversionStart = event { return true }
      return false
    }
    #expect(startEvent != nil, "Should capture timelineConversionStart event")

    // Verify timelineConversionComplete event
    let completeEvent = await telemetry.firstEvent { event in
      if case .timelineConversionComplete = event { return true }
      return false
    }
    #expect(completeEvent != nil, "Should capture timelineConversionComplete event")
  }

  @Test("Timeline conversion reports correct element count")
  @MainActor
  func testTimelineConversionReportsCorrectElementCount() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create 4 audio elements
    let audio1 = createTestAudio(in: context, prompt: "One", duration: 1.0)
    let audio2 = createTestAudio(in: context, prompt: "Two", duration: 1.0)
    let audio3 = createTestAudio(in: context, prompt: "Three", duration: 1.0)
    let audio4 = createTestAudio(in: context, prompt: "Four", duration: 1.0)
    let audioElements = [audio1, audio2, audio3, audio4]

    // Create mock telemetry reporter
    let telemetry = MockTelemetryReporter()
    let converter = ScreenplayToTimelineConverter(telemetry: telemetry)

    // Convert to timeline
    _ = try await converter.convertToTimeline(
      screenplayName: "Test Script",
      audioElements: audioElements
    )

    // Verify timelineConversionStart has correct element count
    let startEvent = await telemetry.firstEvent { event in
      if case .timelineConversionStart = event { return true }
      return false
    }

    if case let .timelineConversionStart(elementCount, _) = startEvent! {
      #expect(elementCount == 4, "Should report 4 audio elements in timelineConversionStart event")
    }
  }

  @Test("Timeline conversion calculates audio size accurately")
  @MainActor
  func testTimelineConversionCalculatesAudioSizeAccurately() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create audio elements with known sizes (in KB)
    // 100 KB + 200 KB + 300 KB = 600 KB = 0.5859375 MB
    let audio1 = createTestAudio(in: context, prompt: "Small", duration: 1.0, sizeKB: 100)
    let audio2 = createTestAudio(in: context, prompt: "Medium", duration: 1.5, sizeKB: 200)
    let audio3 = createTestAudio(in: context, prompt: "Large", duration: 2.0, sizeKB: 300)
    let audioElements = [audio1, audio2, audio3]

    // Calculate expected total size
    let expectedTotalBytes = (100 + 200 + 300) * 1024
    let expectedTotalMB = Double(expectedTotalBytes) / (1024 * 1024)

    // Create mock telemetry reporter
    let telemetry = MockTelemetryReporter()
    let converter = ScreenplayToTimelineConverter(telemetry: telemetry)

    // Convert to timeline
    _ = try await converter.convertToTimeline(
      screenplayName: "Test Script",
      audioElements: audioElements
    )

    // Verify timelineConversionStart reports accurate audio size
    let startEvent = await telemetry.firstEvent { event in
      if case .timelineConversionStart = event { return true }
      return false
    }

    if case let .timelineConversionStart(_, totalAudioMB) = startEvent! {
      let tolerance = 0.001  // Allow 0.001 MB tolerance
      #expect(abs(totalAudioMB - expectedTotalMB) < tolerance,
        "Audio size should be \(expectedTotalMB) MB, got \(totalAudioMB) MB")
    }
  }

  @Test("Timeline conversion reports correct clip count")
  @MainActor
  func testTimelineConversionReportsCorrectClipCount() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create 3 audio elements
    let audio1 = createTestAudio(in: context, prompt: "First", duration: 1.5)
    let audio2 = createTestAudio(in: context, prompt: "Second", duration: 2.0)
    let audio3 = createTestAudio(in: context, prompt: "Third", duration: 1.0)
    let audioElements = [audio1, audio2, audio3]

    // Create mock telemetry reporter
    let telemetry = MockTelemetryReporter()
    let converter = ScreenplayToTimelineConverter(telemetry: telemetry)

    // Convert to timeline
    let timeline = try await converter.convertToTimeline(
      screenplayName: "Test Script",
      audioElements: audioElements
    )

    // Verify timelineConversionComplete has correct clip count
    let completeEvent = await telemetry.firstEvent { event in
      if case .timelineConversionComplete = event { return true }
      return false
    }

    if case let .timelineConversionComplete(clipCount, durationSeconds) = completeEvent! {
      #expect(clipCount == 3, "Should report 3 clips in timelineConversionComplete event")
      #expect(clipCount == timeline.clips.count, "Reported clip count should match actual timeline")

      // Verify duration is accurate
      let expectedDuration = 1.5 + 2.0 + 1.0  // Sum of clip durations
      let tolerance = 0.1  // Allow 0.1 second tolerance
      #expect(abs(durationSeconds - expectedDuration) < tolerance,
        "Duration should be \(expectedDuration) seconds, got \(durationSeconds) seconds")
    }
  }

  @Test("Timeline conversion reports accurate duration")
  @MainActor
  func testTimelineConversionReportsAccurateDuration() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create audio elements with specific durations
    let audio1 = createTestAudio(in: context, prompt: "First", duration: 2.5)
    let audio2 = createTestAudio(in: context, prompt: "Second", duration: 3.7)
    let audio3 = createTestAudio(in: context, prompt: "Third", duration: 1.2)
    let audioElements = [audio1, audio2, audio3]

    let expectedDuration = 2.5 + 3.7 + 1.2  // 7.4 seconds

    // Create mock telemetry reporter
    let telemetry = MockTelemetryReporter()
    let converter = ScreenplayToTimelineConverter(telemetry: telemetry)

    // Convert to timeline
    let timeline = try await converter.convertToTimeline(
      screenplayName: "Test Script",
      audioElements: audioElements
    )

    // Verify timelineConversionComplete reports accurate duration
    let completeEvent = await telemetry.firstEvent { event in
      if case .timelineConversionComplete = event { return true }
      return false
    }

    if case let .timelineConversionComplete(_, durationSeconds) = completeEvent! {
      #expect(durationSeconds == timeline.duration.seconds, "Reported duration should match timeline duration")

      let tolerance = 0.1
      #expect(abs(durationSeconds - expectedDuration) < tolerance,
        "Duration should be \(expectedDuration) seconds, got \(durationSeconds) seconds")
    }
  }

  @Test("Timeline conversion handles empty audio data")
  @MainActor
  func testTimelineConversionHandlesEmptyAudioData() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create audio elements with nil binary values (no audio data)
    let audio1 = TypedDataStorage(
      providerId: "test-provider",
      requestorID: "test-requestor",
      mimeType: "audio/mp4",
      binaryValue: nil,  // No audio data
      prompt: "Empty",
      durationSeconds: 1.0
    )
    context.insert(audio1)

    let audioElements = [audio1]

    // Create mock telemetry reporter
    let telemetry = MockTelemetryReporter()
    let converter = ScreenplayToTimelineConverter(telemetry: telemetry)

    // Convert to timeline
    _ = try await converter.convertToTimeline(
      screenplayName: "Test Script",
      audioElements: audioElements
    )

    // Verify timelineConversionStart reports 0 MB for empty audio
    let startEvent = await telemetry.firstEvent { event in
      if case .timelineConversionStart = event { return true }
      return false
    }

    if case let .timelineConversionStart(_, totalAudioMB) = startEvent! {
      #expect(totalAudioMB == 0.0, "Empty audio data should report 0 MB")
    }
  }

  @Test("Timeline conversion without telemetry does not crash")
  @MainActor
  func testTimelineConversionWithoutTelemetryDoesNotCrash() async throws {
    let container = try createTestContainer()
    let context = ModelContext(container)

    // Create audio elements
    let audio = createTestAudio(in: context, prompt: "Test", duration: 1.0)
    let audioElements = [audio]

    // Create converter WITHOUT telemetry
    let converter = ScreenplayToTimelineConverter(telemetry: nil)

    // Conversion should succeed without telemetry
    let timeline = try await converter.convertToTimeline(
      screenplayName: "Test Script",
      audioElements: audioElements
    )

    #expect(timeline.clips.count == 1, "Timeline conversion should succeed without telemetry")
  }
}
