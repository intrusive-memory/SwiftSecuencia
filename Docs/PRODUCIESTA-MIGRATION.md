# Produciesta Migration Guide

## Using ScreenplayToTimelineConverter

The `exportToFinalCutPro()` function in Produciesta should use `ScreenplayToTimelineConverter` for better testability and separation of concerns.

### Before (Produciesta UI code)

```swift
private func exportToFinalCutPro() async {
    // ... UI code (save panel) ...

    do {
        // Create timeline from document
        let timeline = Timeline(name: document.filename ?? "Screenplay")
        timeline.videoFormat = VideoFormat.hd1080p(frameRate: .fps24)

        // Add clips for each audio element
        var currentOffset = Timecode.zero
        let audioFiles = document.sortedElementGeneratedContent(mimeTypePrefix: "audio/")

        for audioStorage in audioFiles {
            let duration = if let durationSeconds = audioStorage.durationSeconds {
                Timecode(seconds: durationSeconds)
            } else {
                Timecode(seconds: 3.0)
            }

            let clip = TimelineClip(
                name: audioStorage.prompt.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines),
                assetStorageId: audioStorage.id,
                duration: duration,
                sourceStart: .zero
            )

            timeline.insertClip(clip, at: currentOffset, lane: 0)
            currentOffset = currentOffset + duration
        }

        // Save timeline to SwiftData
        modelContext.insert(timeline)
        try modelContext.save()

        // Export using SwiftSecuencia
        let bundleURL = try await exporter.exportBundle(...)

        // ... UI code (notifications, Finder) ...
    }
}
```

### After (Using ScreenplayToTimelineConverter)

```swift
import SwiftSecuencia

private func exportToFinalCutPro() async {
    // Show save panel for directory selection
    let savePanel = NSSavePanel()
    savePanel.title = "Export to Final Cut Pro"
    savePanel.message = "Choose where to save the Final Cut Pro project with audio assets"
    savePanel.nameFieldStringValue = "\(document.filename ?? "Screenplay").fcpxmld"
    savePanel.canCreateDirectories = true
    savePanel.showsTagField = false

    let response = await savePanel.begin()
    guard response == .OK, let url = savePanel.url else {
        return
    }

    do {
        // Get audio elements from document
        let audioFiles = document.sortedElementGeneratedContent(mimeTypePrefix: "audio/")

        // Create progress for both conversion and export
        let progress = Progress(totalUnitCount: 100)
        progress.localizedDescription = "Exporting to Final Cut Pro"
        documentProgressState.trackProgress(progress, description: "Exporting to Final Cut Pro")

        // Phase 1: Convert to Timeline (30% of total progress)
        let conversionProgress = Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 30)

        let converter = ScreenplayToTimelineConverter()
        let timeline = try await converter.convertToTimeline(
            screenplayName: document.filename ?? "Screenplay",
            audioElements: audioFiles,
            videoFormat: .hd1080p(frameRate: .fps24),
            progress: conversionProgress
        )

        // Save timeline to SwiftData
        modelContext.insert(timeline)
        try modelContext.save()

        // Phase 2: Export to FCPXML Bundle (70% of total progress)
        let exportProgress = Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 70)

        let exporter = FCPXMLBundleExporter(includeMedia: true)
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
            libraryName: "Produciesta Export",
            eventName: document.filename ?? "Screenplay",
            progress: exportProgress
        )

        // Show success notification
        notificationManager.info("Exported to Final Cut Pro: \(bundleURL.lastPathComponent)")

        // Reveal in Finder
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])

    } catch {
        exportError = "Failed to export to Final Cut Pro: \(error.localizedDescription)"
        showExportError = true
    }
}
```

## Benefits

1. **Testable** - Timeline conversion logic can be unit tested in SwiftSecuencia
2. **Reusable** - Other apps can use the same conversion logic
3. **Progress Tracking** - Proper progress reporting for both conversion and export phases
4. **Separation of Concerns** - UI code only handles UI, business logic in library
5. **Error Handling** - Clear error types (ConverterError) separate from export errors

## Progress Breakdown

The updated code splits progress into two phases:
- **30%**: Converting screenplay to timeline (ScreenplayToTimelineConverter)
- **70%**: Exporting FCPXML bundle (FCPXMLBundleExporter)

This gives users more accurate progress feedback during the entire export process.

## Testing

You can now test the timeline conversion logic in isolation:

```swift
@Test
func testScreenplayConversion() async throws {
    let converter = ScreenplayToTimelineConverter()
    let timeline = try await converter.convertToTimeline(
        screenplayName: "Test Script",
        audioElements: mockAudioElements
    )

    #expect(timeline.clips.count == mockAudioElements.count)
    #expect(timeline.duration == expectedDuration)
}
```

This wasn't possible when the conversion logic was embedded in the UI code.
