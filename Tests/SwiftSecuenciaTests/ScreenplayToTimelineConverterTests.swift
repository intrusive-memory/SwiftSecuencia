//
//  ScreenplayToTimelineConverterTests.swift
//  SwiftSecuencia
//
//  Tests for ScreenplayToTimelineConverter.
//

import Testing
import Foundation
import SwiftData
import SwiftCompartido
@testable import SwiftSecuencia

@Suite("ScreenplayToTimelineConverter Tests")
struct ScreenplayToTimelineConverterTests {

    // MARK: - Test Helpers

    /// Creates a test model container with TypedDataStorage
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
        duration: Double
    ) -> TypedDataStorage {
        let storage = TypedDataStorage(
            providerId: "test-provider",
            requestorID: "test-requestor",
            mimeType: "audio/mp4",
            binaryValue: Data([0x00, 0x01, 0x02]),  // Dummy audio data
            prompt: prompt,
            durationSeconds: duration
        )
        context.insert(storage)
        return storage
    }

    // MARK: - Basic Conversion Tests

    @Test("Convert screenplay with audio elements to timeline")
    @MainActor
    func testConvertWithAudioElements() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        // Create test audio elements
        let audio1 = createTestAudio(in: context, prompt: "First line", duration: 2.5)
        let audio2 = createTestAudio(in: context, prompt: "Second line", duration: 3.0)
        let audio3 = createTestAudio(in: context, prompt: "Third line", duration: 1.5)

        let audioElements = [audio1, audio2, audio3]

        // Convert to timeline
        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Test Script",
            audioElements: audioElements
        )

        // Verify timeline properties
        #expect(timeline.name == "Test Script")
        #expect(timeline.clips.count == 3)

        // Verify clips are sequenced correctly
        let sortedClips = timeline.clips.sorted { $0.offset < $1.offset }

        #expect(sortedClips[0].offset == Timecode.zero)
        #expect(sortedClips[0].duration == Timecode(seconds: 2.5))
        #expect(sortedClips[0].name == "First line")

        #expect(sortedClips[1].offset == Timecode(seconds: 2.5))
        #expect(sortedClips[1].duration == Timecode(seconds: 3.0))
        #expect(sortedClips[1].name == "Second line")

        #expect(sortedClips[2].offset == Timecode(seconds: 5.5))
        #expect(sortedClips[2].duration == Timecode(seconds: 1.5))
        #expect(sortedClips[2].name == "Third line")

        // Verify total timeline duration
        #expect(timeline.duration == Timecode(seconds: 7.0))
    }


    @Test("Convert handles missing duration with default")
    @MainActor
    func testConvertWithMissingDuration() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        // Create audio without duration
        let storage = TypedDataStorage(
            providerId: "test-provider",
            requestorID: "test-requestor",
            mimeType: "audio/mp4",
            binaryValue: Data([0x00]),
            prompt: "No duration",
            durationSeconds: nil  // Missing duration
        )
        context.insert(storage)

        // Convert to timeline
        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Test",
            audioElements: [storage]
        )

        // Verify default duration was used (3 seconds)
        #expect(timeline.clips.count == 1)
        #expect(timeline.clips[0].duration == Timecode(seconds: 3.0))
    }

    @Test("Convert truncates long clip names")
    @MainActor
    func testConvertTruncatesLongNames() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        // Create audio with very long prompt
        let longPrompt = String(repeating: "A", count: 100)
        let audio = createTestAudio(in: context, prompt: longPrompt, duration: 1.0)

        // Convert to timeline
        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Test",
            audioElements: [audio]
        )

        // Verify name was truncated to 50 characters
        #expect(timeline.clips[0].name?.count == 50)
    }

    // MARK: - Error Handling Tests

    @Test("Convert throws error for empty audio elements")
    @MainActor
    func testConvertEmptyElements() async throws {
        let converter = ScreenplayToTimelineConverter()

        do {
            _ = try await converter.convertToTimeline(
                screenplayName: "Empty",
                audioElements: []
            )
            Issue.record("Expected error to be thrown")
        } catch let error as ConverterError {
            #expect(error == .noAudioElements)
        }
    }

    @Test("Convert throws error for non-audio elements")
    @MainActor
    func testConvertNonAudioElements() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        // Create video storage (not audio)
        let videoStorage = TypedDataStorage(
            providerId: "test-provider",
            requestorID: "test-requestor",
            mimeType: "video/mp4",  // Not audio
            binaryValue: Data([0x00]),
            prompt: "Video",
            durationSeconds: 5.0
        )
        context.insert(videoStorage)

        // Convert should fail (no audio)
        let converter = ScreenplayToTimelineConverter()

        do {
            _ = try await converter.convertToTimeline(
                screenplayName: "Test",
                audioElements: [videoStorage]
            )
            Issue.record("Expected error to be thrown")
        } catch let error as ConverterError {
            #expect(error == .noAudioElements)
        }
    }

    // MARK: - Progress Tracking Tests

    @Test("Convert reports progress correctly")
    @MainActor
    func testConvertProgressTracking() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        // Create test audio elements
        let audio1 = createTestAudio(in: context, prompt: "First", duration: 1.0)
        let audio2 = createTestAudio(in: context, prompt: "Second", duration: 1.0)
        let audio3 = createTestAudio(in: context, prompt: "Third", duration: 1.0)

        // Create progress tracker
        let progress = Progress(totalUnitCount: 100)

        // Convert to timeline
        let converter = ScreenplayToTimelineConverter()
        _ = try await converter.convertToTimeline(
            screenplayName: "Test",
            audioElements: [audio1, audio2, audio3],
            progress: progress
        )

        // Verify progress completed
        #expect(progress.completedUnitCount == 100)
    }

    @Test("Convert respects cancellation")
    @MainActor
    func testConvertCancellation() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        // Create test audio
        let audio = createTestAudio(in: context, prompt: "Test", duration: 1.0)

        // Create progress and cancel immediately
        let progress = Progress(totalUnitCount: 100)
        progress.cancel()

        // Convert should throw cancelled error
        let converter = ScreenplayToTimelineConverter()

        do {
            _ = try await converter.convertToTimeline(
                screenplayName: "Test",
                audioElements: [audio],
                progress: progress
            )
            Issue.record("Expected cancellation error to be thrown")
        } catch let error as ConverterError {
            #expect(error == .cancelled)
        }
    }

    // MARK: - Custom Format Tests

    @Test("Convert with custom video format")
    @MainActor
    func testConvertCustomVideoFormat() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio = createTestAudio(in: context, prompt: "Test", duration: 1.0)

        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Test",
            audioElements: [audio],
            videoFormat: .hd720p(frameRate: .fps30)
        )

        #expect(timeline.videoFormat == .hd720p(frameRate: .fps30))
    }

    @Test("Convert with custom audio settings")
    @MainActor
    func testConvertCustomAudioSettings() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio = createTestAudio(in: context, prompt: "Test", duration: 1.0)

        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Test",
            audioElements: [audio],
            audioLayout: .mono,
            audioRate: .rate44_1kHz
        )

        #expect(timeline.audioLayout == .mono)
        #expect(timeline.audioRate == .rate44_1kHz)
    }

    @Test("Convert to specific lane")
    @MainActor
    func testConvertToSpecificLane() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)

        let audio = createTestAudio(in: context, prompt: "Test", duration: 1.0)

        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: "Test",
            audioElements: [audio],
            lane: -1  // Audio lane
        )

        #expect(timeline.clips[0].lane == -1)
    }
}
