# Export UI Migration Guide

This guide shows how to replace Produciesta's custom export UI with SwiftSecuencia's reusable `ExportMenuView` component.

## What Changed

**Before**: Produciesta had custom `AudioConverter`, `AudioExportFormat`, and `AudioExportFormatPicker` with buggy audio concatenation.

**After**: SwiftSecuencia provides:
- `ExportMenuView` - Reusable toolbar component
- `ExportableDocument` - Protocol for exportable documents
- Only FCP and M4A exports (removed AIFF, WAV, CAF, MP3)
- Uses `TimelineAudioExporter` for reliable audio export
- Uses `ScreenplayToTimelineConverter` for timeline creation

## Step 1: Make Your Document Conform to ExportableDocument

```swift
import SwiftSecuencia

extension GuionDocumentModel: ExportableDocument {
    public var exportName: String {
        return filename ?? "Screenplay"
    }

    public func audioElements() -> [TypedDataStorage] {
        return sortedElementGeneratedContent(mimeTypePrefix: "audio/")
    }
}
```

## Step 2: Replace Toolbar Export Menu

### Before (Produciesta's old code)

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button {
                showExportFormatPicker = true
            } label: {
                Label("Export to Audio File", systemImage: "waveform")
            }
            .disabled(document.sortedElementGeneratedContent(mimeTypePrefix: "audio/").isEmpty)

            #if os(macOS)
            Button {
                Task { await exportToFinalCutPro() }
            } label: {
                Label("Export to Final Cut Pro", systemImage: "film")
            }
            .disabled(document.sortedElementGeneratedContent(mimeTypePrefix: "audio/").isEmpty)
            #endif
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .disabled(document.sortedElementGeneratedContent(mimeTypePrefix: "audio/").isEmpty)
    }
}
```

### After (Using ExportMenuView)

```swift
import SwiftSecuencia

.toolbar {
    ToolbarItem(placement: .primaryAction) {
        ExportMenuView(document: document)
    }
}
```

That's it! The component handles everything:
- Menu with FCP and M4A options
- Progress tracking
- Error alerts
- File export dialogs
- Finder reveal (macOS)

## Step 3: Remove Old Code

Delete these files/types from Produciesta:
- `AudioConverter.swift`
- `AudioExportFormat.swift`
- `AudioExportFormatPicker.swift`
- `ExportableAudioDocument` struct

Remove these from `GuionDocumentView`:
- `@State private var showExportFormatPicker`
- `@State private var selectedExportFormat`
- `@State private var showExportSheet`
- `@State private var exportedAudioData`
- `private func getExportAudioData()`
- `private func exportToFinalCutPro()`
- `.sheet(isPresented: $showExportFormatPicker)`
- `.fileExporter` for audio export

## Step 4: Ensure ModelContext is in Environment

`ExportMenuView` reads `ModelContext` from the environment:

```swift
struct MyApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: GuionDocumentModel()) { file in
            GuionDocumentView(document: file.document)
                .modelContainer(sharedModelContainer)  // ✅ Provides ModelContext
        }
    }
}
```

## Features You Get

### M4A Export
- Converts audio elements to Timeline using `ScreenplayToTimelineConverter`
- Exports to M4A using `TimelineAudioExporter`
- Progress tracking with 30% conversion + 70% export phases
- File exporter dialog with automatic naming

### FCP Export (macOS only)
- Converts audio elements to Timeline using `ScreenplayToTimelineConverter`
- Exports .fcpxmld bundle using `FCPXMLBundleExporter`
- Progress tracking with 30% conversion + 70% export phases
- Save panel with automatic naming
- Reveals bundle in Finder

### Error Handling
- User-friendly error alerts
- Progress cancellation support
- Automatic cleanup of temporary files

### Progress Tracking
- Both exports show progress through SwiftSecuencia's Progress API
- If you have a progress tracking UI, you can access `exportProgress`

## Customization

### Custom Menu Label

```swift
ExportMenuView(
    document: document,
    label: "Export",
    systemImage: "arrow.up.doc"
)
```

### Access Progress (Optional)

If you want to display progress in your UI, you'll need to add a binding. For now, the component manages progress internally.

## Benefits

1. **No More Buggy AudioConverter**: Uses SwiftSecuencia's tested `TimelineAudioExporter`
2. **Reusable**: Same component works in any app with `ExportableDocument`
3. **Testable**: Export logic is unit tested in SwiftSecuencia
4. **Consistent**: FCP and M4A exports use same Timeline conversion path
5. **Progress Tracking**: Built-in progress reporting
6. **Error Handling**: Clear error messages
7. **Less Code**: ~500 lines of Produciesta code → ~5 lines

## Platform Support

| Feature | macOS | iOS |
|---------|-------|-----|
| M4A Export | ✅ | ✅ |
| FCP Export | ✅ | ❌ |

iOS gets M4A export only (Final Cut Pro for iPad doesn't support FCPXML).
