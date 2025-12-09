# Background Audio Export Code Path

This document maps the complete execution flow for background audio export in SwiftSecuencia.

## High-Level Overview

```
User Click → Main Thread Setup → Background Thread Export → Main Thread Completion
   (UI)         (Metadata)           (I/O Heavy)              (UI Update)
```

## Detailed Code Path Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. USER ACTION (Main Thread)                                               │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                                              │
│ ExportMenuView.swift:105                                                    │
│ ┌──────────────────────────────────────────────────────────────┐           │
│ │ Button {                                                      │           │
│ │     Task {                                                    │           │
│ │         await exportToM4A()  ────────────────────────────────┼──────┐    │
│ │     }                                                         │      │    │
│ │ } label: {                                                    │      │    │
│ │     Label("Export to Audio File", systemImage: "waveform")   │      │    │
│ │ }                                                             │      │    │
│ └──────────────────────────────────────────────────────────────┘      │    │
└───────────────────────────────────────────────────────────────────────┼────┘
                                                                         │
┌────────────────────────────────────────────────────────────────────────┼────┐
│ 2. SHOW SAVE DIALOG (Main Thread)                                     │    │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━━━ │
│                                                                         ▼    │
│ ExportMenuView.swift:148-154                                                │
│ ┌──────────────────────────────────────────────────────────────┐           │
│ │ @MainActor                                                    │           │
│ │ private func exportToM4A() async {                            │           │
│ │     // Show save dialog immediately - no processing yet       │           │
│ │     showM4AExporter = true  ◄─── USER SEES DIALOG NOW         │           │
│ │ }                                                             │           │
│ └──────────────────────────────────────────────────────────────┘           │
│                                                                              │
│ ▼ User chooses save location                                                │
│                                                                              │
│ ExportMenuView.swift:158                                                    │
│ ┌──────────────────────────────────────────────────────────────┐           │
│ │ private func handleM4AExportResult(                           │           │
│ │     _ result: Result<URL, Error>                              │           │
│ │ ) {                                                           │           │
│ │     switch result {                                           │           │
│ │     case .success(let destinationURL):                        │           │
│ │         Task {                                                │           │
│ │             await performM4AExport(to: destinationURL) ───────┼──────┐    │
│ │         }                                                     │      │    │
│ │     }                                                         │      │    │
│ │ }                                                             │      │    │
│ └──────────────────────────────────────────────────────────────┘      │    │
└───────────────────────────────────────────────────────────────────────┼────┘
                                                                         │
┌────────────────────────────────────────────────────────────────────────┼────┐
│ 3. BUILD TIMELINE METADATA (Main Thread - 30% of progress)            │    │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━━━ │
│                                                                         ▼    │
│ ExportMenuView.swift:177-204                                                │
│ ┌──────────────────────────────────────────────────────────────┐           │
│ │ @MainActor                                                    │           │
│ │ private func performM4AExport(to destinationURL: URL) async { │           │
│ │                                                               │           │
│ │     // Set up progress (caller provides Progress object)     │           │
│ │     if let progress = progress {                             │           │
│ │         progress.totalUnitCount = 100                        │           │
│ │     }                                                         │           │
│ │                                                               │           │
│ │     // Phase 1: Build Timeline (metadata only)               │           │
│ │     let converter = ScreenplayToTimelineConverter()          │           │
│ │     let timeline = try await converter.convertToTimeline(    │           │
│ │         screenplayName: document.exportName,                 │           │
│ │         audioElements: audioFiles,  ◄─── Just IDs, no data   │           │
│ │         progress: conversionProgress                         │           │
│ │     )                                                         │           │
│ │                                                               │           │
│ │     // Save to SwiftData                                     │           │
│ │     modelContext.insert(timeline)                            │           │
│ │     try modelContext.save()                                  │           │
│ │                                                               │           │
│ │     // Get persistent ID for cross-actor communication       │           │
│ │     let timelineID = timeline.persistentModelID ◄─── Safe!   │           │
│ │     let container = modelContext.container                   │           │
│ │                                                               │           │
│ │     // Launch background export ──────────────────────────────┼──────┐    │
│ │     let outputURL = try await Task.detached(                 │      │    │
│ │         priority: .high  ◄─── MAX PERFORMANCE                 │      │    │
│ │     ) {                                                       │      │    │
│ │         // ... background work ...                           │      │    │
│ │     }.value                                                   │      │    │
│ │ }                                                             │      │    │
│ └──────────────────────────────────────────────────────────────┘      │    │
└───────────────────────────────────────────────────────────────────────┼────┘
                                                                         │
┌────────────────────────────────────────────────────────────────────────┼────┐
│ 4. BACKGROUND EXPORT (Background Thread - 70% of progress)            │    │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━━━ │
│                                                                         ▼    │
│ ExportMenuView.swift:220-227 → BackgroundAudioExporter.swift:56             │
│ ┌──────────────────────────────────────────────────────────────┐           │
│ │ Task.detached(priority: .high) {                             │           │
│ │     let exporter = BackgroundAudioExporter(                  │           │
│ │         modelContainer: container                            │           │
│ │     )                                                         │           │
│ │     return try await exporter.exportAudio(                   │           │
│ │         timelineID: timelineID,  ◄─── ID, not object         │           │
│ │         to: destinationURL,                                  │           │
│ │         progress: exportProgressChild                        │           │
│ │     )                                                         │           │
│ │ }                                                             │           │
│ └──────────────────────────────────────────────────────────────┘           │
│                                                                              │
│ BackgroundAudioExporter.swift:56-133 (@ModelActor)                         │
│ ┌──────────────────────────────────────────────────────────────┐           │
│ │ public func exportAudio(                                     │           │
│ │     timelineID: PersistentIdentifier,                        │           │
│ │     to outputURL: URL,                                       │           │
│ │     progress: Progress?                                      │           │
│ │ ) async throws -> URL {                                      │           │
│ │                                                               │           │
│ │     // Step 1: Fetch Timeline by ID (5%)                     │           │
│ │     updateProgress(progress, 5, "Loading timeline")          │           │
│ │     guard let timeline = self[timelineID, as: Timeline.self] │           │
│ │                                                               │           │
│ │     // Step 2: Filter audio clips (5%)                       │           │
│ │     updateProgress(progress, 10, "Filtering clips")          │           │
│ │     let audioClips = try filterAudioClips(timeline.clips)    │           │
│ │                                                               │           │
│ │     // Step 3: Build composition (30%) ───────────────────────┼──────┐    │
│ │     updateProgress(progress, nil, "Building composition")    │      │    │
│ │     let (composition, tempFiles) = try await buildComposition│      │    │
│ │                                                               │      │    │
│ │     // Step 4: Export to M4A (60%) ───────────────────────────┼─────────┐ │
│ │     updateProgress(progress, nil, "Exporting audio")         │      │  │ │
│ │     try await exportComposition(composition, to: outputURL)  │      │  │ │
│ │                                                               │      │  │ │
│ │     cleanupTempFiles(tempFiles)                              │      │  │ │
│ │     updateProgress(progress, 100, "Export complete")         │      │  │ │
│ │     return outputURL                                         │      │  │ │
│ │ }                                                             │      │  │ │
│ └──────────────────────────────────────────────────────────────┘      │  │ │
└───────────────────────────────────────────────────────────────────────┼──┼─┘
                                                                         │  │
┌────────────────────────────────────────────────────────────────────────┼──┼─┐
│ 4a. BUILD COMPOSITION (Background Thread - 30% of total)              │  │ │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━━┼━ │
│                                                                         ▼  │ │
│ BackgroundAudioExporter.swift:162-208                                  │  │ │
│ ┌──────────────────────────────────────────────────────────────┐      │  │ │
│ │ private func buildComposition(                               │      │  │ │
│ │     from timeline: Timeline,                                 │      │  │ │
│ │     audioClips: [TimelineClip],                              │      │  │ │
│ │     progress: Progress                                       │      │  │ │
│ │ ) async throws -> (AVMutableComposition, [URL]) {            │      │  │ │
│ │                                                               │      │  │ │
│ │     let composition = AVMutableComposition()                 │      │  │ │
│ │     var tempFiles: [URL] = []                                │      │  │ │
│ │     let sortedClips = audioClips.sorted { $0.offset < $1 }   │      │  │ │
│ │                                                               │      │  │ │
│ │     // FOR EACH CLIP (process one at a time)                 │      │  │ │
│ │     for (index, clip) in sortedClips.enumerated() {          │      │  │ │
│ │                                                               │      │  │ │
│ │         updateProgress(progress, nil,                        │      │  │ │
│ │             "Loading audio clip \(index+1) of \(total)")     │      │  │ │
│ │                                                               │      │  │ │
│ │         // Create track for this clip                        │      │  │ │
│ │         let track = composition.addMutableTrack(...)         │      │  │ │
│ │                                                               │      │  │ │
│ │         // Process clip ──────────────────────────────────────┼──────┼──┼─┐ │
│ │         let tempURL = try await insertClipIntoTrack(         │      │  │ │ │
│ │             clip: clip,                                      │      │  │ │ │
│ │             track: track,                                    │      │  │ │ │
│ │             progress: progress,                              │      │  │ │ │
│ │             index: index + 1,                                │      │  │ │ │
│ │             total: sortedClips.count                         │      │  │ │ │
│ │         )                                                     │      │  │ │ │
│ │         tempFiles.append(tempURL)                            │      │  │ │ │
│ │                                                               │      │  │ │ │
│ │         updateProgress(progress, calculatedUnits, nil)       │      │  │ │ │
│ │     }                                                         │      │  │ │ │
│ │     return (composition, tempFiles)                          │      │  │ │ │
│ │ }                                                             │      │  │ │ │
│ └──────────────────────────────────────────────────────────────┘      │  │ │ │
└───────────────────────────────────────────────────────────────────────┼──┼─┼─┘
                                                                         │  │ │
┌────────────────────────────────────────────────────────────────────────┼──┼─┼─┐
│ 4b. INSERT CLIP INTO TRACK (Background Thread - per clip)             │  │ │ │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━━┼━┼━ │
│                                                                         ▼  │ │ │
│ BackgroundAudioExporter.swift:210-268                                  │  │ │ │
│ ┌──────────────────────────────────────────────────────────────┐      │  │ │ │
│ │ private func insertClipIntoTrack(                            │      │  │ │ │
│ │     clip: TimelineClip,                                      │      │  │ │ │
│ │     track: AVMutableCompositionTrack,                        │      │  │ │ │
│ │     progress: Progress,                                      │      │  │ │ │
│ │     index: Int, total: Int                                   │      │  │ │ │
│ │ ) async throws -> URL {                                      │      │  │ │ │
│ │                                                               │      │  │ │ │
│ │     // Fetch asset from SwiftData (READ-ONLY)                │      │  │ │ │
│ │     updateProgress(progress, nil,                            │      │  │ │ │
│ │         "Fetching clip \(index) of \(total)")                │      │  │ │ │
│ │     guard let asset = clip.fetchAsset(in: modelContext)      │      │  │ │ │
│ │     guard let audioData = asset.binaryValue                  │      │  │ │ │
│ │                                                               │      │  │ │ │
│ │     // Write to temp file                                    │      │  │ │ │
│ │     updateProgress(progress, nil,                            │      │  │ │ │
│ │         "Writing clip \(index) of \(total)")                 │      │  │ │ │
│ │     let tempURL = FileManager.default.temporaryDirectory     │      │  │ │ │
│ │         .appendingPathComponent(UUID().uuidString)           │      │  │ │ │
│ │     try audioData.write(to: tempURL)  ◄─── DISK I/O          │      │  │ │ │
│ │     // audioData released from memory here                   │      │  │ │ │
│ │                                                               │      │  │ │ │
│ │     // Create AVAsset from file                              │      │  │ │ │
│ │     updateProgress(progress, nil,                            │      │  │ │ │
│ │         "Processing clip \(index) of \(total)")              │      │  │ │ │
│ │     let avAsset = AVURLAsset(url: tempURL)                   │      │  │ │ │
│ │     let sourceTrack = try await avAsset.loadTracks(...)      │      │  │ │ │
│ │                                                               │      │  │ │ │
│ │     // Calculate time ranges                                 │      │  │ │ │
│ │     let startTime = CMTime(seconds: clip.sourceStart...)     │      │  │ │ │
│ │     let duration = CMTime(seconds: clip.duration...)         │      │  │ │ │
│ │     let insertTime = CMTime(seconds: clip.offset...)         │      │  │ │ │
│ │                                                               │      │  │ │ │
│ │     // Insert into composition                               │      │  │ │ │
│ │     updateProgress(progress, nil,                            │      │  │ │ │
│ │         "Adding clip \(index) of \(total)")                  │      │  │ │ │
│ │     try track.insertTimeRange(timeRange, of: sourceTrack,    │      │  │ │ │
│ │                               at: insertTime)                │      │  │ │ │
│ │                                                               │      │  │ │ │
│ │     return tempURL  ◄─── Keep alive until export done        │      │  │ │ │
│ │ }                                                             │      │  │ │ │
│ └──────────────────────────────────────────────────────────────┘      │  │ │ │
│                                                                         │  │ │ │
│ ▲ LOOP BACK for next clip ──────────────────────────────────────────────┘  │ │ │
└────────────────────────────────────────────────────────────────────────────┼─┼─┘
                                                                              │ │
┌─────────────────────────────────────────────────────────────────────────────┼─┼─┐
│ 4c. EXPORT COMPOSITION TO M4A (Background Thread - 60% of total)           │ │ │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━┼━ │
│                                                                              ▼ │ │
│ BackgroundAudioExporter.swift:272-311                                       │ │ │
│ ┌──────────────────────────────────────────────────────────────┐            │ │ │
│ │ private func exportComposition(                              │            │ │ │
│ │     _ composition: AVMutableComposition,                     │            │ │ │
│ │     to outputURL: URL,                                       │            │ │ │
│ │     progress: Progress                                       │            │ │ │
│ │ ) async throws {                                             │            │ │ │
│ │                                                               │            │ │ │
│ │     // Validate composition has audio tracks                 │            │ │ │
│ │     guard !composition.tracks(withMediaType: .audio).isEmpty │            │ │ │
│ │                                                               │            │ │ │
│ │     // Remove existing file if present                       │            │ │ │
│ │     if FileManager.default.fileExists(at: outputURL) {       │            │ │ │
│ │         try FileManager.default.removeItem(at: outputURL)    │            │ │ │
│ │     }                                                         │            │ │ │
│ │                                                               │            │ │ │
│ │     // Create export session                                 │            │ │ │
│ │     guard let exportSession = AVAssetExportSession(          │            │ │ │
│ │         asset: composition,                                  │            │ │ │
│ │         presetName: AVAssetExportPresetAppleM4A              │            │ │ │
│ │     )                                                         │            │ │ │
│ │     exportSession.outputURL = outputURL                      │            │ │ │
│ │     exportSession.outputFileType = .m4a                      │            │ │ │
│ │                                                               │            │ │ │
│ │     updateProgress(progress, nil, "Encoding M4A audio")      │            │ │ │
│ │                                                               │            │ │ │
│ │     // Export (Apple's encoder - optimized internally)       │            │ │ │
│ │     try await exportSession.export(to: outputURL, as: .m4a)  │            │ │ │
│ │     // ▲ This is the slowest part (encoding)                 │            │ │ │
│ │                                                               │            │ │ │
│ │     updateProgress(progress, 100, "Export complete")         │            │ │ │
│ │ }                                                             │            │ │ │
│ └──────────────────────────────────────────────────────────────┘            │ │ │
└─────────────────────────────────────────────────────────────────────────────┼─┼─┘
                                                                                │ │
┌───────────────────────────────────────────────────────────────────────────────┼─┼─┐
│ 5. PROGRESS UPDATE MECHANISM (Throughout - Non-Blocking)                     │ │ │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━┼━ │
│                                                                                ▼ │ │
│ BackgroundAudioExporter.swift:328-343                                         │ │ │
│ ┌──────────────────────────────────────────────────────────────┐              │ │ │
│ │ private func updateProgress(                                 │              │ │ │
│ │     _ progress: Progress,                                    │              │ │ │
│ │     completedUnits: Int64?,                                  │              │ │ │
│ │     description: String?                                     │              │ │ │
│ │ ) {                                                           │              │ │ │
│ │     // Fire-and-forget dispatch to MainActor                 │              │ │ │
│ │     // Does NOT block export thread!                         │              │ │ │
│ │     Task { @MainActor in                                     │              │ │ │
│ │         if let completedUnits = completedUnits {             │              │ │ │
│ │             progress.completedUnitCount = completedUnits     │              │ │ │
│ │         }                                                     │              │ │ │
│ │         if let description = description {                   │              │ │ │
│ │             progress.localizedAdditionalDescription = desc   │              │ │ │
│ │         }                                                     │              │ │ │
│ │     }                                                         │              │ │ │
│ │     // ▲ Returns immediately, doesn't wait for MainActor     │              │ │ │
│ │ }                                                             │              │ │ │
│ └──────────────────────────────────────────────────────────────┘              │ │ │
│                                                                                 │ │ │
│ ┌─────────────────────────────────────────────────────────┐                   │ │ │
│ │ SwiftUI Progress Observer (Main Thread)                 │                   │ │ │
│ │ ───────────────────────────────────────────────────────  │                   │ │ │
│ │                                                          │                   │ │ │
│ │ ProgressView(progress)                                  │                   │ │ │
│ │     .progressViewStyle(.linear)                         │                   │ │ │
│ │                                                          │                   │ │ │
│ │ ▲ Automatically observes Progress changes via KVO       │                   │ │ │
│ │ ▲ Updates UI when progress.completedUnitCount changes   │                   │ │ │
│ └─────────────────────────────────────────────────────────┘                   │ │ │
└───────────────────────────────────────────────────────────────────────────────┼─┼─┘
                                                                                  │ │
┌─────────────────────────────────────────────────────────────────────────────────┼─┼─┐
│ 6. COMPLETION (Returns to Main Thread)                                         │ │ │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━┼━ │
│                                                                                  ▼ │ │
│ ExportMenuView.swift:227-232                                                   │ │ │
│ ┌──────────────────────────────────────────────────────────────┐                │ │ │
│ │ let outputURL = try await Task.detached(...).value          │                │ │ │
│ │ // ▲ Waits for background task to complete                   │                │ │ │
│ │                                                               │                │ │ │
│ │ #if os(macOS)                                                │                │ │ │
│ │ // Reveal in Finder (main thread)                           │                │ │ │
│ │ NSWorkspace.shared.activateFileViewerSelecting([outputURL]) │                │ │ │
│ │ #endif                                                        │                │ │ │
│ └──────────────────────────────────────────────────────────────┘                │ │ │
└─────────────────────────────────────────────────────────────────────────────────┼─┼─┘
                                                                                    │ │
                                                                                    │ │
┌───────────────────────────────────────────────────────────────────────────────────┼─┼─┐
│ THREAD EXECUTION SUMMARY                                                          │ │ │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━┼━ │
│                                                                                    ▼ ▼ │
│ Main Thread:                                                                      │ │ │
│ ├─ User interaction                                                               │ │ │
│ ├─ Show save dialog (immediate, no lag)                                           │ │ │
│ ├─ Build timeline metadata (30% progress, ~1 second)                              │ │ │
│ ├─ Launch background task                                                         │ │ │
│ ├─ Receive progress updates asynchronously                                        │ │ │
│ ├─ Update ProgressView UI                                                         │ │ │
│ └─ Reveal in Finder when complete                                                 │ │ │
│                                                                                    │ │ │
│ Background Thread (.high priority):                                               │ │ │
│ ├─ Create BackgroundAudioExporter (@ModelActor)                                   │ │ │
│ ├─ Fetch Timeline by ID (READ-ONLY SwiftData)                                     │ │ │
│ ├─ Filter audio clips                                                             │ │ │
│ ├─ FOR EACH CLIP (70% progress):                                                  │ │ │
│ │   ├─ Fetch asset from SwiftData (READ-ONLY)                                     │ │ │
│ │   ├─ Load audio binary data                                                     │ │ │
│ │   ├─ Write to temp file (DISK I/O)                                              │ │ │
│ │   ├─ Release audio data from memory                                             │ │ │
│ │   ├─ Create AVURLAsset from temp file                                           │ │ │
│ │   ├─ Load audio track                                                           │ │ │
│ │   └─ Insert into AVMutableComposition                                           │ │ │
│ ├─ Export AVMutableComposition to M4A (Apple encoder)                             │ │ │
│ ├─ Clean up temp files                                                            │ │ │
│ └─ Return output URL                                                              │ │ │
│                                                                                    │ │ │
│ Progress Updates (fire-and-forget to MainActor):                                  │ │ │
│ ├─ Background thread calls updateProgress()                                       │ │ │
│ ├─ Schedules Task { @MainActor in } (doesn't wait)                                │ │ │
│ ├─ Background thread continues immediately                                        │ │ │
│ ├─ Main thread eventually executes progress update                                │ │ │
│ └─ SwiftUI observes Progress changes and updates UI                               │ │ │
└───────────────────────────────────────────────────────────────────────────────────┘ │ │
                                                                                       │ │
                                                                                       │ │
┌─────────────────────────────────────────────────────────────────────────────────────┼─┼─┐
│ KEY PERFORMANCE OPTIMIZATIONS                                                       │ │ │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━┼━ │
│                                                                                      ▼ ▼ │
│ 1. Task.detached(priority: .high)                                                   │ │ │
│    └─> Uses all available CPU cycles without starving UI                            │ │ │
│    └─> Maximum I/O throughput for file operations                                   │ │ │
│    └─> Priority encoding time for AVAssetExportSession                              │ │ │
│                                                                                      │ │ │
│ 2. Fire-and-forget progress updates                                                 │ │ │
│    └─> Background thread never blocks waiting for MainActor                         │ │ │
│    └─> Continuous I/O operations without interruption                               │ │ │
│    └─> Lower context switching overhead                                             │ │ │
│                                                                                      │ │ │
│ 3. Memory-efficient clip processing                                                 │ │ │
│    └─> Load one asset at a time                                                     │ │ │
│    └─> Write to temp file immediately                                               │ │ │
│    └─> Release audio data from memory                                               │ │ │
│    └─> AVFoundation streams from temp files                                         │ │ │
│                                                                                      │ │ │
│ 4. Read-only SwiftData access                                                       │ │ │
│    └─> No data races or corruption risk                                             │ │ │
│    └─> Safe concurrent access via @ModelActor                                       │ │ │
│    └─> Background ModelContext from ModelContainer                                  │ │ │
│                                                                                      │ │ │
│ 5. Pass identifiers, not objects                                                    │ │ │
│    └─> timeline.persistentModelID crosses actor boundary safely                     │ │ │
│    └─> No Sendable violations                                                       │ │ │
│    └─> Clean actor isolation                                                        │ │ │
└─────────────────────────────────────────────────────────────────────────────────────┘ │ │
                                                                                         │ │
                                                                                         │ │
┌───────────────────────────────────────────────────────────────────────────────────────┼─┼─┐
│ TIMING BREAKDOWN (Typical Export)                                                    │ │ │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━┼━ │
│                                                                                        ▼ ▼ │
│ Save Dialog:           0ms   (shows immediately)                                     │ │ │
│ Build Timeline:      ~1s     (main thread, 30% progress)                             │ │ │
│ Composition Build:   ~30%    (background, per-clip I/O)                              │ │ │
│ M4A Export:          ~60%    (background, Apple encoder)                             │ │ │
│ Cleanup & Reveal:    <100ms  (main thread)                                           │ │ │
│                                                                                        │ │ │
│ Total time scales with:                                                               │ │ │
│ - Number of clips                                                                     │ │ │
│ - Size of audio files                                                                 │ │ │
│ - Disk I/O speed                                                                      │ │ │
│ - CPU speed (for encoding)                                                            │ │ │
└───────────────────────────────────────────────────────────────────────────────────────┘ │ │
                                                                                           │ │
                                                                                           ▼ ▼
                                                                                        DONE!
```

## File Locations

| Component | File Path | Line Numbers |
|-----------|-----------|--------------|
| User Action | `Sources/SwiftSecuencia/UI/ExportMenuView.swift` | 105-112 |
| Show Save Dialog | `Sources/SwiftSecuencia/UI/ExportMenuView.swift` | 148-154 |
| Handle Save Result | `Sources/SwiftSecuencia/UI/ExportMenuView.swift` | 158-174 |
| Perform M4A Export | `Sources/SwiftSecuencia/UI/ExportMenuView.swift` | 177-238 |
| Launch Background Task | `Sources/SwiftSecuencia/UI/ExportMenuView.swift` | 220-227 |
| Background Export | `Sources/SwiftSecuencia/Export/BackgroundAudioExporter.swift` | 56-133 |
| Build Composition | `Sources/SwiftSecuencia/Export/BackgroundAudioExporter.swift` | 162-208 |
| Insert Clip | `Sources/SwiftSecuencia/Export/BackgroundAudioExporter.swift` | 210-268 |
| Export Composition | `Sources/SwiftSecuencia/Export/BackgroundAudioExporter.swift` | 272-311 |
| Update Progress | `Sources/SwiftSecuencia/Export/BackgroundAudioExporter.swift` | 328-343 |

## Critical Concurrency Points

### Actor Boundaries

1. **Main Thread → Background Thread**
   - Location: `ExportMenuView.swift:220`
   - Mechanism: `Task.detached(priority: .high)`
   - Safe data: `PersistentIdentifier`, `ModelContainer`, `Progress`

2. **Background Thread → Main Thread (Progress)**
   - Location: `BackgroundAudioExporter.swift:332`
   - Mechanism: `Task { @MainActor in }`
   - Fire-and-forget: Doesn't block background thread

### Data Flow

```
ModelContext (Main)
    ↓ insert/save
SwiftData Storage
    ↓ persistentModelID
Background Thread
    ↓ new ModelContext(container)
SwiftData Storage (READ-ONLY)
    ↓ fetch assets
Audio Binary Data
    ↓ write to disk
Temp Files
    ↓ AVFoundation
AVMutableComposition
    ↓ AVAssetExportSession
M4A File
```

## See Also

- [CONCURRENCY-ARCHITECTURE.md](./CONCURRENCY-ARCHITECTURE.md) - Detailed concurrency design
- [BackgroundAudioExporter.swift](../Sources/SwiftSecuencia/Export/BackgroundAudioExporter.swift) - Implementation
- [ExportMenuView.swift](../Sources/SwiftSecuencia/UI/ExportMenuView.swift) - UI integration
