//
//  GenerateFCPXMLBundleIntent.swift
//  SwiftSecuencia
//
//  App Intent for generating FCPXML bundles from screenplay elements.
//

#if os(macOS)

import AppIntents
import Foundation
import SwiftData
import SwiftCompartido

/// Generate a Final Cut Pro XML bundle (.fcpxmld) from screenplay elements with audio.
///
/// This intent takes a `ScreenplayElementsReference` (from SwiftCompartido's parse intent)
/// and creates a complete FCPXML bundle with:
/// - Timeline structure based on screenplay scenes
/// - Audio clips for dialogue elements with generated voiceovers
/// - Proper sequencing and timing
///
/// **Example Shortcuts Workflow**:
/// ```
/// Parse Screenplay File (filter: dialogue)
/// → ScreenplayElementsReference
/// → Generate FCPXML Bundle
/// → Save to Files app
/// → Import into Final Cut Pro
/// ```
///
/// **Requirements**:
/// - Screenplay elements must have audio files generated (via voice generation workflow)
/// - Audio files stored in TypedDataStorage with matching element IDs
public struct GenerateFCPXMLBundleIntent: AppIntent {

    public static let title: LocalizedStringResource = "Generate FCPXML Bundle"

    public static let description = IntentDescription(
        stringLiteral: "Create a Final Cut Pro XML bundle from screenplay elements with audio. Includes timeline structure and embedded media files."
    )

    public static let openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "Screenplay Elements",
        description: "The screenplay elements to convert to FCPXML (from Parse Screenplay File)"
    )
    public var elementsReference: ScreenplayElementsReference

    @Parameter(
        title: "Output Directory",
        description: "Directory where the .fcpxmld bundle will be created"
    )
    public var outputDirectory: URL

    @Parameter(
        title: "Project Name",
        description: "Name for the Final Cut Pro project (default: screenplay title)"
    )
    public var projectName: String?

    @Parameter(
        title: "Clip Duration",
        description: "Default duration in seconds for clips without audio (default: 3.0)",
        default: 3.0
    )
    public var defaultClipDuration: Double

    @Parameter(
        title: "Frame Rate",
        description: "Timeline frame rate (default: 23.98)",
        default: 23.98
    )
    public var frameRate: Double

    // MARK: - Initializer

    public init() {
        // Required empty initializer for AppIntent
    }

    public init(
        elementsReference: ScreenplayElementsReference,
        outputDirectory: URL,
        projectName: String? = nil,
        defaultClipDuration: Double = 3.0,
        frameRate: Double = 23.98
    ) {
        self.elementsReference = elementsReference
        self.outputDirectory = outputDirectory
        self.projectName = projectName
        self.defaultClipDuration = defaultClipDuration
        self.frameRate = frameRate
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        // Create model container for TypedDataStorage access
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Create timeline
        let timeline = try await createTimeline(
            from: elementsReference,
            modelContext: context
        )

        context.insert(timeline)
        try context.save()

        // Export to FCPXML bundle
        var exporter = FCPXMLBundleExporter(includeMedia: true)
        let bundleURL = try await exporter.exportBundle(
            timeline: timeline,
            modelContext: context,
            to: outputDirectory,
            bundleName: projectName ?? elementsReference.documentTitle ?? "Screenplay",
            libraryName: "AI Generated Content",
            eventName: elementsReference.documentTitle ?? "Screenplay"
        )

        // Return as IntentFile for Shortcuts
        let intentFile = IntentFile(fileURL: bundleURL)

        return .result(value: intentFile)
    }

    // MARK: - Timeline Creation

    /// Creates a timeline from screenplay elements.
    @MainActor
    private func createTimeline(
        from reference: ScreenplayElementsReference,
        modelContext: SwiftData.ModelContext
    ) async throws -> Timeline {
        // Create timeline with appropriate settings
        let timeline = Timeline(name: reference.documentTitle ?? "Screenplay")
        timeline.videoFormat = frameRateToVideoFormat(frameRate)

        // Process dialogue elements and add audio clips
        var currentOffset = Timecode.zero

        for element in reference.elements where element.isDialogue {
            // Try to find audio for this element
            if let audio = try? findAudio(for: element, in: modelContext) {
                let duration = audio.durationSeconds.map { Timecode(seconds: $0) } ?? Timecode(seconds: defaultClipDuration)

                let clip = TimelineClip(
                    name: "\(element.characterName ?? "Character"): \(String(element.elementText.prefix(30)))...",
                    assetStorageId: audio.id,
                    offset: currentOffset,
                    duration: duration,
                    lane: 0
                )

                timeline.insertClip(clip, at: currentOffset, lane: 0)
                currentOffset = currentOffset + duration
            } else {
                // No audio found - skip this dialogue or add placeholder
                // For now, we skip elements without audio
                continue
            }
        }

        return timeline
    }

    /// Finds audio TypedDataStorage for a screenplay element.
    @MainActor
    private func findAudio(
        for element: ElementReference,
        in modelContext: SwiftData.ModelContext
    ) throws -> TypedDataStorage? {
        // Query TypedDataStorage for audio matching this element
        // Strategy: Use element text hash or ID to match generated audio
        let descriptor = FetchDescriptor<TypedDataStorage>(
            predicate: #Predicate { storage in
                storage.mimeType.starts(with: "audio/")
            }
        )

        let allAudio = try modelContext.fetch(descriptor)

        // Try to match by element text in prompt
        let elementText = element.elementText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find audio where prompt contains the element text
        return allAudio.first { audio in
            let prompt = audio.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            return prompt.contains(elementText) || elementText.contains(prompt)
        }
    }

    /// Converts frame rate to VideoFormat.
    private func frameRateToVideoFormat(_ fps: Double) -> VideoFormat {
        let rate: FrameRate
        switch fps {
        case 23.98: rate = .fps23_98
        case 24.0: rate = .fps24
        case 25.0: rate = .fps25
        case 29.97: rate = .fps29_97
        case 30.0: rate = .fps30
        case 50.0: rate = .fps50
        case 59.94: rate = .fps59_94
        case 60.0: rate = .fps60
        default: rate = .fps23_98 // Default fallback
        }

        return VideoFormat.hd1080p(frameRate: rate)
    }
}

#endif
