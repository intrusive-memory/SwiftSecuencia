//
//  ExportTimelineAudioIntent.swift
//  SwiftSecuencia
//
//  App Intent for exporting timeline audio to M4A.
//

import AppIntents
import Foundation
import SwiftData
import SwiftCompartido

/// Export a timeline's audio as a high-quality M4A file.
///
/// This intent takes a timeline (or creates one from screenplay elements) and exports
/// all audio clips as a stereo M4A file with AAC compression at 256 kbps.
///
/// **Example Shortcuts Workflow**:
/// ```
/// Get Timeline
/// → Export Timeline Audio
/// → Save to Files app
/// → Share/Play audio
/// ```
///
/// **Alternative: From Screenplay**:
/// ```
/// Parse Screenplay File (filter: dialogue)
/// → Generate FCPXML Bundle (creates timeline)
/// → Export Timeline Audio
/// → Save to Files app
/// ```
///
/// **Audio Format**:
/// - Format: M4A (AAC)
/// - Quality: 256 kbps
/// - Channels: Stereo mixdown
/// - All timeline lanes are mixed together
public struct ExportTimelineAudioIntent: AppIntent {

    public static let title: LocalizedStringResource = "Export Timeline Audio"

    public static let description = IntentDescription(
        stringLiteral: "Export timeline audio as a high-quality M4A file. All lanes are mixed down to stereo with AAC compression at 256 kbps."
    )

    public static let openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "Timeline Name",
        description: "Name of the timeline to export (must exist in SwiftData)"
    )
    public var timelineName: String

    @Parameter(
        title: "Output Directory",
        description: "Directory where the M4A file will be saved"
    )
    public var outputDirectory: URL

    @Parameter(
        title: "Output Filename",
        description: "Name for the M4A file (without extension, default: timeline name)",
        default: nil
    )
    public var outputFilename: String?

    // MARK: - Initializer

    public init() {
        // Required empty initializer for AppIntent
    }

    public init(
        timelineName: String,
        outputDirectory: URL,
        outputFilename: String? = nil
    ) {
        self.timelineName = timelineName
        self.outputDirectory = outputDirectory
        self.outputFilename = outputFilename
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        // Create model container
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try ModelContainer(
            for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Find the timeline by name
        let descriptor = FetchDescriptor<Timeline>(
            predicate: #Predicate { timeline in
                timeline.name == timelineName
            }
        )

        let timelines = try context.fetch(descriptor)
        guard let timeline = timelines.first else {
            throw ExportTimelineAudioError.timelineNotFound(name: timelineName)
        }

        // Determine output filename
        let filename = (outputFilename ?? timeline.name)
            .appending(".m4a")

        let outputURL = outputDirectory
            .appendingPathComponent(filename)

        // Export audio
        let exporter = TimelineAudioExporter()
        let resultURL = try await exporter.exportAudio(
            timeline: timeline,
            modelContext: context,
            to: outputURL
        )

        // Return as IntentFile for Shortcuts
        let intentFile = IntentFile(fileURL: resultURL)

        return .result(value: intentFile)
    }
}

/// Errors that can occur during timeline audio export.
public enum ExportTimelineAudioError: Error, LocalizedError {
    case timelineNotFound(name: String)

    public var errorDescription: String? {
        switch self {
        case .timelineNotFound(let name):
            return "Timeline '\(name)' not found in database"
        }
    }
}
