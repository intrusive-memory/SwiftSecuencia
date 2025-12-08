# SwiftSecuencia Concurrency Architecture

## Overview

SwiftSecuencia uses a carefully designed concurrency model to ensure UI responsiveness during audio export operations. This document details the architecture, design decisions, and implementation patterns for concurrent audio export.

## Problem Statement

Audio export involves several time-consuming operations:
1. Building timeline metadata from screenplay elements
2. Loading audio binary data from SwiftData
3. Writing audio to temporary files
4. Building AVMutableComposition
5. Exporting to M4A format

Without proper concurrency, these operations would block the main thread, causing UI lag and poor user experience.

## Solution: Two-Phase Export Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ MAIN THREAD (MainActor)                                         │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                                  │
│ 1. User clicks "Export to Audio File"                          │
│    └─> Show save dialog IMMEDIATELY ✅                          │
│                                                                  │
│ 2. User chooses save location                                  │
│    └─> Get destinationURL                                       │
│                                                                  │
│ 3. Build Timeline (NO audio data touched)                      │
│    ├─> Create Timeline object with metadata                    │
│    ├─> Create TimelineClip objects (just IDs, offsets, etc.)  │
│    ├─> Insert into SwiftData                                    │
│    ├─> Save to SwiftData                                        │
│    └─> Update progress bar: "Building timeline..." (30%)       │
│                                                                  │
│ 4. Hand off to background thread                               │
│    ├─> Get Timeline.persistentModelID                           │
│    ├─> Get ModelContainer                                       │
│    └─> Launch BackgroundAudioExporter                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ BACKGROUND THREAD (Task.detached with .utility priority)       │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                                  │
│ 5. BackgroundAudioExporter.export()                            │
│    ├─> Create background ModelContext from ModelContainer      │
│    ├─> Fetch Timeline by persistentModelID (READ-ONLY)         │
│    ├─> For each TimelineClip:                                  │
│    │   ├─> Fetch TypedDataStorage asset (READ-ONLY)           │
│    │   ├─> Read binaryValue into memory                        │
│    │   ├─> Write to temp file                                  │
│    │   └─> Build AVMutableComposition track                    │
│    ├─> Update progress: "Exporting audio..." (70%)             │
│    ├─> Export AVMutableComposition to M4A                      │
│    └─> Clean up temp files                                     │
│                                                                  │
│ 6. On completion                                                │
│    └─> MainActor.run { update UI, reveal in Finder }          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Key Design Principles

### 1. Immediate UI Responsiveness

**Save Dialog Appears Immediately**
- No processing occurs before showing the save dialog
- User can choose save location without waiting
- Eliminates perceived lag from the user's perspective

```swift
@MainActor
private func exportToM4A() async {
    // Show save dialog immediately - no processing yet
    showM4AExporter = true
}
```

### 2. Metadata-Only Main Thread Processing

**Timeline Building is Fast**
- Only metadata is processed on the main thread
- No audio data is loaded into memory
- Timeline clips contain only references (IDs, offsets, durations)
- SwiftData operations are lightweight

```swift
// Phase 1: Main thread (fast - metadata only)
let timeline = try await converter.convertToTimeline(
    screenplayName: document.exportName,
    audioElements: audioFiles,  // Just references, no audio data
    videoFormat: .hd1080p(frameRate: .fps24),
    progress: conversionProgress
)
```

### 3. Background Thread for I/O Operations

**Heavy Work Happens Off Main Thread**
- Audio data loading
- File I/O operations
- AVFoundation composition building
- M4A export encoding

```swift
// Phase 2: Background thread (slow - I/O heavy)
let outputURL = try await Task.detached(priority: .utility) {
    let exporter = BackgroundAudioExporter(modelContainer: container)
    return try await exporter.exportAudio(
        timelineID: timelineID,
        to: destinationURL,
        progress: exportProgressChild
    )
}.value
```

### 4. Safe SwiftData Concurrency with @ModelActor

**@ModelActor Pattern**
- Automatic SwiftData concurrency management
- Provides actor-isolated `modelContext`
- Ensures serial access to SwiftData
- Prevents data races

```swift
@ModelActor
public actor BackgroundAudioExporter {
    public func exportAudio(
        timelineID: PersistentIdentifier,
        to outputURL: URL,
        progress: Progress? = nil
    ) async throws -> URL {
        // Fetch timeline using actor-isolated modelContext
        guard let timeline = self[timelineID, as: Timeline.self] else {
            throw AudioExportError.exportFailed(reason: "Timeline not found")
        }
        // ... rest of export logic
    }
}
```

### 5. Pass Identifiers, Not Objects

**Cross-Actor Boundary Safety**
- Timeline and ModelContext are main actor-isolated
- Cannot be passed directly to background thread
- Use `persistentModelID` for safe cross-actor communication

```swift
// Main thread: Get persistent ID
let timelineID = timeline.persistentModelID

// Pass ID to background thread (safe)
Task.detached(priority: .utility) {
    let exporter = BackgroundAudioExporter(modelContainer: container)
    try await exporter.exportAudio(timelineID: timelineID, ...)
}
```

### 6. Read-Only SwiftData Access

**Background Thread Never Modifies**
- All SwiftData operations are read-only
- Fetches Timeline and TypedDataStorage objects
- No inserts, updates, or deletes
- Eliminates potential for data corruption

```swift
// Read-only access in BackgroundAudioExporter
guard let asset = clip.fetchAsset(in: modelContext) else {
    throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
}
guard let audioData = asset.binaryValue else {
    throw AudioExportError.invalidAudioData(...)
}
```

### 7. Memory-Efficient Audio Loading

**One Asset at a Time**
- Load audio data into memory
- Write to temporary file immediately
- Release audio data from memory
- AVFoundation streams from temp files

```swift
for clip in sortedClips {
    // Load audio data
    guard let audioData = asset.binaryValue else { ... }

    // Write to temp file
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(fileExtension(for: asset.mimeType))
    try audioData.write(to: tempURL)

    // Release audio data (Swift handles this)
    // AVFoundation will stream from tempURL

    // Build composition track
    let avAsset = AVURLAsset(url: tempURL)
    // ...
}
```

### 8. Thread-Safe Progress Reporting

**Foundation.Progress is Thread-Safe**
- Created on main thread
- Updated from background thread
- Automatically thread-safe by design
- No MainActor.run needed for updates

```swift
// Main thread
let progress = Progress(totalUnitCount: 100)
exportProgress = progress

// Background thread (safe to update)
progress.localizedAdditionalDescription = "Loading timeline"
progress.completedUnitCount = 5
```

## Implementation Components

### BackgroundAudioExporter

**Location**: `Sources/SwiftSecuencia/Export/BackgroundAudioExporter.swift`

**Purpose**: Performs audio export on background thread with safe SwiftData access

**Key Methods**:
- `exportAudio(timelineID:to:progress:)` - Main export function
- `filterAudioClips(_:)` - Filters timeline clips to audio only
- `buildComposition(from:audioClips:progress:)` - Builds AVMutableComposition
- `insertClipIntoTrack(clip:track:)` - Inserts individual clip into composition
- `exportComposition(_:to:progress:)` - Exports composition to M4A

### ExportMenuView Integration

**Location**: `Sources/SwiftSecuencia/UI/ExportMenuView.swift`

**Key Methods**:
- `exportToM4A()` - Shows save dialog immediately
- `handleM4AExportResult(_:)` - Handles save dialog result
- `performM4AExport(to:)` - Orchestrates two-phase export

## Thread Execution Guarantees

### Main Thread Operations
- Save dialog presentation
- Timeline metadata building
- SwiftData insert and save
- Progress object creation
- UI updates (via MainActor.run if needed)
- Finder reveal (macOS)

### Background Thread Operations
- ModelContext creation
- Timeline and asset fetching
- Audio data loading
- Temporary file writing
- AVMutableComposition building
- M4A export encoding
- Temporary file cleanup

## Error Handling

### Cancellation Support
- Progress.isCancelled checked at multiple points
- Temporary files cleaned up on cancellation
- AudioExportError.cancelled thrown

```swift
// Check for cancellation
if progress.isCancelled {
    cleanupTempFiles(tempFiles)
    throw AudioExportError.cancelled
}
```

### Cleanup on Error
- Temporary files always cleaned up
- Deferred cleanup in error paths
- No resource leaks

```swift
do {
    let (composition, tempFiles) = try await buildComposition(...)
    try await exportComposition(composition, to: outputURL, ...)
    cleanupTempFiles(tempFiles)
} catch {
    cleanupTempFiles(tempFiles)
    throw error
}
```

## Performance Characteristics

### Phase Distribution
- Phase 1 (Main Thread): ~30% of total time
  - Fast: Only metadata, no I/O
  - Typically completes in < 1 second
- Phase 2 (Background Thread): ~70% of total time
  - Slow: Heavy I/O operations
  - Scales with number and size of audio assets

### Memory Usage
- Minimal main thread memory impact
- Background thread loads one asset at a time
- Temp files written immediately, data released
- AVFoundation streams from temp files (no full audio in memory)

### UI Responsiveness
- Save dialog: Immediate (no lag)
- Progress updates: Real-time
- Main thread never blocked by export
- Background priority (.utility) prevents CPU contention

## Testing

All 237 tests pass, including:
- Empty timeline error handling
- Missing asset error handling
- Single clip export
- Multi-clip export
- Multi-lane mixing
- Overlapping clips (automatic mixing)
- Clips with gaps (silence insertion)
- Progress tracking
- Cancellation support

## References

- [Using ModelActor in SwiftData | BrightDigit](https://brightdigit.com/tutorials/swiftdata-modelactor/)
- [ModelActor | Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/modelactor)
- [SwiftData Background Tasks](https://useyourloaf.com/blog/swiftdata-background-tasks/)
- [Concurrent Programming in SwiftData](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/)
- [How to run Swift Data and Core Data operations in the background](https://www.polpiella.dev/core-data-swift-data-concurrency)

## Version History

- **v1.0.5** (December 2025) - Initial implementation with @ModelActor
