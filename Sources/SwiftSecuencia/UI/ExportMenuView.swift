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
/// - Export to M4A Audio File (macOS + iOS)
/// - Export to Final Cut Pro (macOS only)
///
/// ## Usage in Toolbar
///
/// ```swift
/// .toolbar {
///     ToolbarItem(placement: .primaryAction) {
///         ExportMenuView(document: document)
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
/// ## Features
///
/// - Progress tracking during export
/// - Error handling with user-friendly alerts
/// - Automatic file naming
/// - macOS: Reveals exported files in Finder
/// - Disables menu when no audio content available
@available(iOS 17.0, macOS 26.0, *)
public struct ExportMenuView<Document: ExportableDocument>: View {

    // MARK: - Properties

    /// The document to export
    public let document: Document

    /// Optional custom label for the menu button
    public let label: String

    /// Optional custom system image for the menu button
    public let systemImage: String

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var isExporting = false
    @State private var exportProgress: Progress?
    @State private var exportError: Error?
    @State private var showError = false
    @State private var showM4AExporter = false
    @State private var m4aExportURL: URL?

    // MARK: - Initialization

    /// Creates an export menu view.
    ///
    /// - Parameters:
    ///   - document: The document to export (must conform to ExportableDocument)
    ///   - label: Custom label for the menu button (default: "Share")
    ///   - systemImage: Custom system image for the menu button (default: "square.and.arrow.up")
    public init(
        document: Document,
        label: String = "Share",
        systemImage: String = "square.and.arrow.up"
    ) {
        self.document = document
        self.label = label
        self.systemImage = systemImage
    }

    // MARK: - Body

    public var body: some View {
        Menu {
            // M4A Audio Export (iOS + macOS)
            Button {
                Task {
                    await exportToM4A()
                }
            } label: {
                Label("Export to Audio File", systemImage: "waveform")
            }
            .disabled(document.audioElements().isEmpty)

            #if os(macOS)
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
            document: M4AExportDocument(url: m4aExportURL),
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
        let audioFiles = document.audioElements()
        guard !audioFiles.isEmpty else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            // Create progress
            let progress = Progress(totalUnitCount: 100)
            progress.localizedDescription = "Exporting to M4A"
            exportProgress = progress

            // Phase 1: Convert to Timeline (30%)
            let conversionProgress = Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 30)

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

            // Phase 2: Export to M4A (70%)
            let exportProgressChild = Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 70)

            let exporter = TimelineAudioExporter()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")

            _ = try await exporter.exportAudio(
                timeline: timeline,
                modelContext: modelContext,
                to: tempURL,
                progress: exportProgressChild
            )

            // Show file exporter
            m4aExportURL = tempURL
            showM4AExporter = true

        } catch {
            exportError = error
            showError = true
        }
    }

    @MainActor
    private func handleM4AExportResult(_ result: Result<URL, Error>) {
        // Clean up temp file
        if let tempURL = m4aExportURL {
            try? FileManager.default.removeItem(at: tempURL)
            m4aExportURL = nil
        }

        switch result {
        case .success(let url):
            #if os(macOS)
            // Reveal in Finder on macOS
            NSWorkspace.shared.activateFileViewerSelecting([url])
            #endif
        case .failure(let error):
            // User cancelled or error occurred
            if (error as NSError).code != NSUserCancelledError {
                exportError = error
                showError = true
            }
        }
    }

    #if os(macOS)
    // MARK: - Final Cut Pro Export (macOS only)

    @MainActor
    private func exportToFinalCutPro() async {
        let audioFiles = document.audioElements()
        guard !audioFiles.isEmpty else { return }

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

        isExporting = true
        defer { isExporting = false }

        do {
            // Create progress for both conversion and export
            let progress = Progress(totalUnitCount: 100)
            progress.localizedDescription = "Exporting to Final Cut Pro"
            exportProgress = progress

            // Phase 1: Convert to Timeline (30%)
            let conversionProgress = Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 30)

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
            let exportProgressChild = Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 70)

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

/// FileDocument wrapper for M4A export via fileExporter.
@available(iOS 17.0, macOS 26.0, *)
private struct M4AExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.mpeg4Audio]

    let url: URL?

    init(url: URL?) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        self.url = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = url else {
            throw NSError(
                domain: "com.swiftsecuencia",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No audio data available"]
            )
        }

        guard let data = try? Data(contentsOf: url) else {
            throw NSError(
                domain: "com.swiftsecuencia",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read audio file"]
            )
        }

        return FileWrapper(regularFileWithContents: data)
    }
}

#endif
