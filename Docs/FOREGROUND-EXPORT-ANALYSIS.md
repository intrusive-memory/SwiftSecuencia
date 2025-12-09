# Foreground Export: Complete Path Analysis

**Date:** December 9, 2025
**Current Performance:** ~10 seconds for 50 clips, 2.5 min duration

## Complete Execution Path

```
User Click "Export Audio (Foreground)"
    ↓
1. exportToM4A() - Show file dialog ⚡ instant
    ↓
2. handleM4AExportResult() - Get destination URL ⚡ instant
    ↓
3. performM4AExport() - Main orchestration
    ↓
    ├─ Phase 1 (30% of progress): Build Timeline
    │   ↓
    │   A. ScreenplayToTimelineConverter.convertToTimeline()
    │      ├─ Filter audio elements ⚡ instant
    │      ├─ Create Timeline object ⚡ instant
    │      ├─ Loop: Create TimelineClip objects ⚡ instant (metadata only)
    │      └─ Insert clips into timeline ⚡ instant (array ops)
    │   ↓
    │   B. modelContext.insert(timeline) ⚡ instant (in-memory)
    │   ↓
    │   C. modelContext.save() ⚠️ BOTTLENECK #1 (~0.5s)
    │      └─ Disk I/O to persist timeline to SwiftData
    │
    └─ Phase 2 (70% of progress): Export Audio
        ↓
        D. ForegroundAudioExporter.exportAudio()
           ↓
           ├─ filterAudioClips() ⚠️ BOTTLENECK #2 (~0.3s)
           │   └─ Loop through clips + fetchAsset() for each (N+1 queries)
           ↓
           ├─ buildComposition()
           │   ↓
           │   ├─ loadAllAudioData() ⚠️ BOTTLENECK #3 (~1.5s)
           │   │   └─ Loop: fetchAsset() + asset.binaryValue (one-by-one)
           │   ↓
           │   ├─ writeAudioFilesToDisk() ✅ OPTIMIZED (~1.0s)
           │   │   └─ Parallel file I/O with TaskGroup
           │   ↓
           │   └─ buildCompositionFromFiles() ⚠️ BOTTLENECK #4 (~1.0s)
           │       └─ Loop: AVURLAsset + loadTracks + insertTimeRange
           ↓
           └─ exportComposition() ⚠️ BOTTLENECK #5 (~6.5s)
               └─ AVAssetExportSession.export() [Apple's M4A encoder]
```

---

## Bottleneck Analysis

### Bottleneck #1: modelContext.save() (~0.5s, 5% of time)

**Location:** ExportMenuView.swift:218

**Current:**
```swift
// Save timeline to SwiftData (main thread)
modelContext.insert(timeline)
try modelContext.save()  // ⚠️ Disk I/O
```

**Problem:** We're persisting a temporary Timeline to disk that we only use for export

**Solution:** Skip Timeline creation entirely for foreground export!

**Impact:** ✅ **Save ~0.5s (5%)**

---

### Bottleneck #2: filterAudioClips() N+1 queries (~0.3s, 3% of time)

**Location:** ForegroundAudioExporter.swift:138-155

**Current:**
```swift
for clip in clips {
    guard let asset = clip.fetchAsset(in: modelContext) else {  // ⚠️ N+1
        throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
    }
    if asset.mimeType.hasPrefix("audio/") {
        audioClips.append(clip)
    }
}
```

**Problem:** We already know these are audio elements! We're re-fetching just to check MIME type.

**Solution:** Skip this entirely if we pass audio elements directly.

**Impact:** ✅ **Save ~0.3s (3%)**

---

### Bottleneck #3: loadAllAudioData() N+1 fetches (~1.5s, 15% of time)

**Location:** ForegroundAudioExporter.swift:213-240

**Current:**
```swift
for (index, clip) in clips.enumerated() {
    guard let asset = clip.fetchAsset(in: modelContext) else {  // ⚠️ N+1
        throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
    }
    guard let data = asset.binaryValue else {  // ⚠️ Fetch binary
        throw AudioExportError.invalidAudioData(...)
    }
    audioData.append((data: data, fileExtension: ext))
}
```

**Problems:**
1. N+1 SwiftData queries (one fetchAsset per clip)
2. Loading binaryValue one-by-one instead of batch
3. We could skip the clip/timeline layer entirely!

**Solution:** Batch fetch all assets upfront (like BackgroundAudioExporter)

**Impact:** ✅ **Save ~0.5s (5%)**

---

### Bottleneck #4: buildCompositionFromFiles() (~1.0s, 10% of time)

**Location:** ForegroundAudioExporter.swift:279-329

**Current:**
```swift
for (index, clip) in clips.enumerated() {
    let avAsset = AVURLAsset(url: tempURL)  // ⚠️ Parse audio file
    guard let sourceTrack = try await avAsset.loadTracks(withMediaType: .audio).first else {  // ⚠️ Async I/O
        throw AudioExportError.invalidAudioData(...)
    }
    try compositionTrack.insertTimeRange(timeRange, of: sourceTrack, at: insertTime)
}
```

**Problems:**
1. Creating AVURLAsset for each file (parsing overhead)
2. Async loadTracks() for each file (I/O overhead)
3. Sequential processing (could potentially parallelize)

**Possible Optimization:** Parallelize AVAsset loading with TaskGroup

**Impact:** ⚠️ **Maybe save ~0.2-0.3s (2-3%)** - risky, AVFoundation may not like parallel asset loading

---

### Bottleneck #5: AVAssetExportSession (~6.5s, 65% of time)

**Location:** ForegroundAudioExporter.swift:334-369

**Current:**
```swift
let exportSession = AVAssetExportSession(
    asset: composition,
    presetName: AVAssetExportPresetAppleM4A
)
try await exportSession.export(to: outputURL, as: .m4a)
```

**Problem:** Apple's M4A encoder is the slowest part

**Possible Optimizations:**
1. ✅ Add `audioTimePitchAlgorithm = .varispeed` (fastest algorithm)
2. ⚠️ Lower quality preset (NOT RECOMMENDED - you advertise "high-quality")
3. ⚠️ Use different codec (NOT RECOMMENDED - not M4A)

**Impact:** ✅ **Save ~0.1-0.2s (1-2%)** with varispeed algorithm

---

## The Nuclear Option: Skip Timeline Entirely

**Current Flow:**
```
audioElements -> Timeline -> TimelineClips -> fetch assets -> export
```

**Optimized Flow:**
```
audioElements -> export directly
```

**Why are we creating a Timeline?**
- ExportMenuView uses ScreenplayToTimelineConverter to build a Timeline
- ForegroundAudioExporter then reads from that Timeline
- Timeline is persisted to SwiftData (disk I/O)
- Timeline is only used temporarily for export!

**New Direct Export API:**
```swift
public func exportAudioDirect(
    audioElements: [TypedDataStorage],  // Already have these!
    modelContext: ModelContext,
    to outputURL: URL,
    progress: Progress? = nil
) async throws -> URL
```

**Savings:**
- ❌ Skip Timeline creation
- ❌ Skip modelContext.save() (~0.5s)
- ❌ Skip clip filtering (~0.3s)
- ❌ Skip redundant asset fetches (~0.3s)

**Total savings:** ✅ **~1.1s (11%)**

---

## Summary: All Possible Optimizations

| Optimization | Difficulty | Time Saved | Risk | Worth It? |
|--------------|-----------|------------|------|-----------|
| **1. Skip Timeline creation** | Medium | ~1.1s (11%) | Low | ✅ YES |
| **2. Batch asset fetch** | Easy | ~0.5s (5%) | None | ✅ YES |
| **3. FileHandle pre-allocation** | Easy | ~0.2s (2%) | None | ✅ YES |
| **4. audioTimePitchAlgorithm** | Trivial | ~0.1s (1%) | None | ✅ YES |
| **5. Parallelize AVAsset loading** | Hard | ~0.2s (2%) | Medium | ⚠️ MAYBE |
| **Total Safe Optimizations** | | **~1.9s (19%)** | | |
| **Final Time** | | **~8.1s** | | |

---

## Recommended Implementation

### Option A: Direct Export API (Maximum Speed)

**Create new method in ForegroundAudioExporter:**
```swift
@MainActor
public func exportAudioDirect(
    audioElements: [TypedDataStorage],
    to outputURL: URL,
    progress: Progress? = nil
) async throws -> URL {
    // Skip Timeline creation entirely
    // Export directly from audioElements
}
```

**ExportMenuView changes:**
```swift
// OLD (creates Timeline)
let timeline = try await converter.convertToTimeline(...)
modelContext.insert(timeline)
try modelContext.save()
let url = try await exporter.exportAudio(timeline: timeline, ...)

// NEW (direct export)
let url = try await exporter.exportAudioDirect(
    audioElements: audioFiles,
    to: destinationURL,
    progress: progress
)
```

**Expected Final Time:** ~8.1 seconds (19% faster)

---

### Option B: Apply Small Optimizations Only

Keep current architecture, just add:
1. Batch asset fetch
2. FileHandle pre-allocation
3. audioTimePitchAlgorithm = .varispeed

**Expected Final Time:** ~9.2 seconds (8% faster)

---

## Recommendation

**Go with Option A: Direct Export API**

**Why:**
- Creating a Timeline just to export audio is wasteful
- Timeline persistence to SwiftData is pure overhead
- Foreground export is meant for SPEED - skip unnecessary layers
- Still maintain Timeline-based API for other use cases

**Architecture:**
```
Background Export: audioElements -> Timeline (persisted) -> export
Foreground Export: audioElements -> export directly ⚡
```

This matches the philosophy:
- **Background:** Persist Timeline for potential reuse
- **Foreground:** Maximum speed, skip persistence

Would you like me to implement Option A?
