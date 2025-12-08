//
//  ScreenplayToTimelineConverter.swift
//  SwiftSecuencia
//
//  Converts screenplay elements to Timeline with proper timing and progress tracking.
//

import Foundation
import SwiftData
import SwiftCompartido

/// Converts screenplay elements with generated audio into a Timeline.
///
/// ScreenplayToTimelineConverter takes a `ScreenplayElementsReference` (or direct access to elements)
/// and creates a properly-timed Timeline with clips sequenced based on audio durations.
///
/// ## Basic Usage
///
/// ```swift
/// let converter = ScreenplayToTimelineConverter()
/// let progress = Progress(totalUnitCount: 100)
///
/// let timeline = try await converter.convertToTimeline(
///     screenplayName: "My Script",
///     elements: screenplayElements,
///     modelContext: context,
///     progress: progress
/// )
/// ```
///
/// ## Progress Tracking
///
/// The converter reports progress in phases:
/// - 10%: Validating screenplay elements
/// - 80%: Creating timeline clips (proportional per clip)
/// - 10%: Finalizing timeline
///
/// ## Features
///
/// - Automatically sequences clips based on audio duration
/// - Handles missing durations with sensible defaults
/// - Filters for audio-only elements
/// - Supports progress cancellation
/// - Works on both macOS and iOS
public struct ScreenplayToTimelineConverter {

    /// Default duration for clips without duration metadata (3 seconds)
    private static let defaultClipDuration: Double = 3.0

    /// Creates a new screenplay to timeline converter.
    public init() {}


    /// Converts screenplay elements to a Timeline with sequenced audio clips (direct element access).
    ///
    /// Use this variant when you already have direct access to TypedDataStorage elements.
    ///
    /// - Parameters:
    ///   - screenplayName: Name for the timeline
    ///   - audioElements: Array of TypedDataStorage with audio content
    ///   - videoFormat: Video format for the timeline (default: HD 1080p @ 24fps)
    ///   - audioLayout: Audio layout (default: stereo)
    ///   - audioRate: Audio sample rate (default: 48kHz)
    ///   - lane: Timeline lane for clips (default: 0 for primary)
    ///   - progress: Optional Progress object for tracking
    /// - Returns: A Timeline with sequenced audio clips
    /// - Throws: ConverterError if conversion fails
    @MainActor
    public func convertToTimeline(
        screenplayName: String,
        audioElements: [TypedDataStorage],
        videoFormat: VideoFormat = .hd1080p(frameRate: .fps24),
        audioLayout: AudioLayout = .stereo,
        audioRate: AudioRate = .rate48kHz,
        lane: Int = 0,
        progress: Progress? = nil
    ) async throws -> Timeline {
        // Set up progress tracking
        let conversionProgress = progress ?? Progress(totalUnitCount: 100)
        conversionProgress.localizedDescription = "Converting audio to timeline"

        // Phase 1: Validate elements (10%)
        conversionProgress.localizedAdditionalDescription = "Validating audio elements"

        guard !audioElements.isEmpty else {
            throw ConverterError.noAudioElements
        }

        // Filter for audio only
        let audioFiles = audioElements.filter { $0.mimeType.hasPrefix("audio/") }

        guard !audioFiles.isEmpty else {
            throw ConverterError.noAudioElements
        }

        conversionProgress.completedUnitCount = 10

        // Check for cancellation
        if conversionProgress.isCancelled {
            throw ConverterError.cancelled
        }

        // Phase 2: Create timeline and clips (80%)
        conversionProgress.localizedAdditionalDescription = "Creating timeline clips"

        let timeline = Timeline(
            name: screenplayName,
            videoFormat: videoFormat,
            audioLayout: audioLayout,
            audioRate: audioRate
        )

        var currentOffset = Timecode.zero
        let clipProgressIncrement = 80.0 / Double(audioFiles.count)

        for (index, audioStorage) in audioFiles.enumerated() {
            // Check for cancellation
            if conversionProgress.isCancelled {
                throw ConverterError.cancelled
            }

            // Get duration from metadata or use default
            let durationSeconds = audioStorage.durationSeconds ?? Self.defaultClipDuration
            let duration = Timecode(seconds: durationSeconds)

            // Create clip with truncated name
            let clipName = audioStorage.prompt
                .prefix(50)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let clip = TimelineClip(
                name: clipName,
                assetStorageId: audioStorage.id,
                duration: duration,
                sourceStart: .zero
            )

            // Insert clip at current offset
            timeline.insertClip(clip, at: currentOffset, lane: lane)

            // Advance offset
            currentOffset = currentOffset + duration

            // Update progress
            conversionProgress.completedUnitCount = Int64(10 + Int((Double(index + 1) * clipProgressIncrement)))
        }

        // Phase 3: Finalize (10%)
        conversionProgress.localizedAdditionalDescription = "Finalizing timeline"
        conversionProgress.completedUnitCount = 100

        return timeline
    }

}

// MARK: - Errors

/// Errors that can occur during screenplay to timeline conversion.
public enum ConverterError: Error, LocalizedError {
    case noAudioElements
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .noAudioElements:
            return "No audio elements found in screenplay"
        case .cancelled:
            return "Conversion was cancelled"
        }
    }
}
