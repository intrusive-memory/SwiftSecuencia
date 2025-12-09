//
//  ExportMenuView.swift
//  SwiftSecuencia
//
//  Reusable export menu for FCP and M4A exports.
//

#if canImport(SwiftUI)
import SwiftUI
import SwiftData
import SwiftCompartido
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

/// Reusable export menu component for Final Cut Pro and M4A audio exports.
///
/// This component provides a toolbar menu with export options for:
/// - Export Audio (Background) - macOS + iOS: UI stays responsive
/// - Export Audio (Foreground) - macOS + iOS: Maximum speed, blocks UI
/// - Export to Final Cut Pro - macOS only
///
/// ## Usage in Toolbar
///
/// ```swift
/// .toolbar {
///     ToolbarItem(placement: .primaryAction) {
///         ExportMenuView(document: document, progress: exportProgress)
///     }
/// }
/// ```
///
/// ## Requirements
///
/// Your document must conform to `ExportableDocument` and provide:
/// - `exportName`: Name for exported files
/// - `audioElements()`: Returns sorted audio elements
///
/// The view reads `ModelContext` from the SwiftUI environment.
///
/// ## Progress Reporting
///
/// The caller is responsible for providing a Progress object for tracking export progress.
/// The library does not dictate which progress UI to use - use any progress indicator you prefer.
///
/// ## Features
///
/// - Error handling with user-friendly alerts
/// - Automatic file naming
/// - macOS: Reveals exported files in Finder
/// - Disables menu when no audio content available
public struct ExportMenuView<Document: ExportableDocument>: View {

    // MARK: - Properties

    /// The document to export
    public let document: Document

    /// Optional custom label for the menu button
    public let label: String

    /// Optional custom system image for the menu button
    public let systemImage: String

    /// Optional closure to create Progress objects for tracking export operations
    /// This closure is called for each export operation, allowing concurrent exports
    /// to have separate progress tracking
    public let progressFactory: (() -> Progress)?

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var exportError: Error?
    @State private var showError = false
    @State private var showM4AExporter = false
    @State private var useBackgroundExport = true

    // MARK: - Initialization

    /// Creates an export menu view.
    ///
    /// - Parameters:
    ///   - document: The document to export (must conform to ExportableDocument)
    ///   - label: Custom label for the menu button (default: "Share")
    ///   - systemImage: Custom system image for the menu button (default: "square.and.arrow.up")
    ///   - progressFactory: Optional closure that creates Progress objects for tracking export operations (default: nil)
    ///                      Called once per export operation to allow concurrent exports with separate progress tracking
    public init(
        document: Document,
        label: String = "Share",
        systemImage: String = "square.and.arrow.up",
        progressFactory: (() -> Progress)? = nil
    ) {
        self.document = document
        self.label = label
        self.systemImage = systemImage
        self.progressFactory = progressFactory
    }

    // MARK: - Body

    public var body: some View {
        Menu {
            // M4A Audio Export - Background (iOS + macOS)
            Button {
                Task {
                    useBackgroundExport = true
                    await exportToM4A()
                }
            } label: {
                Label("Export Audio (Background)", systemImage: "waveform")
            }
            .disabled(document.audioElements().isEmpty)

            // M4A Audio Export - Foreground (iOS + macOS)
            Button {
                Task {
                    useBackgroundExport = false
                    await exportToM4A()
                }
            } label: {
                Label("Export Audio (Foreground)", systemImage: "bolt.fill")
            }
            .disabled(document.audioElements().isEmpty)

            #if os(macOS)
            Divider()

            // Final Cut Pro Export (macOS only)
            Button {
                Task {
                    await exportToFinalCutPro()
                }
            } label: {
                Label("Export to Final Cut Pro", systemImage: "film")
            }
            .disabled(document.audioElements().isEmpty)
            #endif
        } label: {
            Label(label, systemImage: systemImage)
        }
        .disabled(document.audioElements().isEmpty)
        .fileExporter(
            isPresented: $showM4AExporter,
            document: M4AExportDocument(),
            contentType: .mpeg4Audio,
            defaultFilename: "\(document.exportName).m4a"
        ) { result in
            handleM4AExportResult(result)
        }
        .alert("Export Error", isPresented: $showError, presenting: exportError) { _ in
            Button("OK") {
                exportError = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - M4A Export

    @MainActor
    private func exportToM4A() async {
        // Show save dialog immediately - no processing yet
        showM4AExporter = true
    }

    @MainActor
    private func handleM4AExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let destinationURL):
            // User chose a location - now do the export
            // Note: fileExporter automatically manages security-scoped access
            // The destinationURL is already security-scoped and valid for writing
            Task {
                await performM4AExport(to: destinationURL)
            }
        case .failure(let error):
            // User cancelled or error occurred
            if (error as NSError).code != NSUserCancelledError {
                exportError = error
                showError = true
            }
        }
    }

    @MainActor
    private func performM4AExport(to destinationURL: URL) async {
        let audioFiles = document.audioElements()

        do {
            // Create a new Progress object for this export operation
            let progress = progressFactory?()

            // Set up progress reporting if provided by caller
            if let progress = progress {
                progress.totalUnitCount = 100
                progress.localizedDescription = useBackgroundExport
                    ? "Exporting to M4A (Background)"
                    : "Exporting to M4A (Foreground)"
            }

            let outputURL: URL

            if useBackgroundExport {
                // Background export: Create Timeline, persist, export on background thread
                // This path creates a Timeline for potential reuse

                // Phase 1: Build Timeline on Main Thread (30%)
                let conversionProgress = progress.map {
                    Progress(totalUnitCount: 100, parent: $0, pendingUnitCount: 30)
                }

                let converter = ScreenplayToTimelineConverter()
                let timeline = try await converter.convertToTimeline(
                    screenplayName: document.exportName,
                    audioElements: audioFiles,
                    videoFormat: .hd1080p(frameRate: .fps24),
                    progress: conversionProgress
                )

                // Save timeline to SwiftData (main thread)
                modelContext.insert(timeline)
                try modelContext.save()

                // Phase 2: Export to M4A on background thread (70%)
                let exportProgressChild = progress.map {
                    Progress(totalUnitCount: 100, parent: $0, pendingUnitCount: 70)
                }

                let timelineID = timeline.persistentModelID
                let container = modelContext.container

                outputURL = try await Task.detached(priority: .high) {
                    let exporter = BackgroundAudioExporter(modelContainer: container)
                    return try await exporter.exportAudio(
                        timelineID: timelineID,
                        to: destinationURL,
                        progress: exportProgressChild
                    )
                }.value
            } else {
                // Foreground export: Skip Timeline creation, export directly (FAST PATH)
                // This path skips Timeline creation for maximum speed

                let exporter = ForegroundAudioExporter()
                outputURL = try await exporter.exportAudioDirect(
                    audioElements: audioFiles,
                    modelContext: modelContext,
                    to: destinationURL,
                    progress: progress
                )
            }

            #if os(macOS)
            // Reveal in Finder on macOS (back on main thread)
            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
            #endif

        } catch {
            exportError = error
            showError = true
        }
    }

    #if os(macOS)
    // MARK: - Final Cut Pro Export (macOS only)

    @MainActor
    private func exportToFinalCutPro() async {
        let audioFiles = document.audioElements()

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export to Final Cut Pro"
        savePanel.message = "Choose where to save the Final Cut Pro project with audio assets"
        savePanel.nameFieldStringValue = "\(document.exportName).fcpxmld"
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false

        let response = await savePanel.begin()
        guard response == .OK, let url = savePanel.url else {
            return
        }

        do {
            // Create a new Progress object for this export operation
            let progress = progressFactory?()

            // Set up progress reporting if provided by caller
            if let progress = progress {
                progress.totalUnitCount = 100
                progress.localizedDescription = "Exporting to Final Cut Pro"
            }

            // Phase 1: Convert to Timeline (30%)
            let conversionProgress = progress.map {
                Progress(totalUnitCount: 100, parent: $0, pendingUnitCount: 30)
            }

            let converter = ScreenplayToTimelineConverter()
            let timeline = try await converter.convertToTimeline(
                screenplayName: document.exportName,
                audioElements: audioFiles,
                videoFormat: .hd1080p(frameRate: .fps24),
                progress: conversionProgress
            )

            // Save timeline to SwiftData
            modelContext.insert(timeline)
            try modelContext.save()

            // Phase 2: Export to FCPXML Bundle (70%)
            let exportProgressChild = progress.map {
                Progress(totalUnitCount: 100, parent: $0, pendingUnitCount: 70)
            }

            var exporter = FCPXMLBundleExporter(includeMedia: true)
            let parentDirectory = url.deletingLastPathComponent()
            let bundleName = url.deletingPathExtension().lastPathComponent

            try FileManager.default.createDirectory(
                at: parentDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let bundleURL = try await exporter.exportBundle(
                timeline: timeline,
                modelContext: modelContext,
                to: parentDirectory,
                bundleName: bundleName,
                libraryName: "SwiftSecuencia Export",
                eventName: document.exportName,
                progress: exportProgressChild
            )

            // Reveal in Finder
            NSWorkspace.shared.activateFileViewerSelecting([bundleURL])

        } catch {
            exportError = error
            showError = true
        }
    }
    #endif
}

// MARK: - M4A Export Document

/// Placeholder FileDocument for M4A export via fileExporter.
/// The actual export happens after the user chooses the save location.
private struct M4AExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.mpeg4Audio]

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Return empty file wrapper - the actual content will be written
        // directly to the destination URL after the user chooses it
        return FileWrapper(regularFileWithContents: Data())
    }
}

#endif
