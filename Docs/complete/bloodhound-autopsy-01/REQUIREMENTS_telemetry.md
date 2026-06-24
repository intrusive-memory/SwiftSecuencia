# SwiftSecuencia Telemetry Requirements

**Priority**: 🟡 HIGH  
**Status**: Not Started  
**Effort Estimate**: 2-3 hours  
**Dependencies**: None

## Context

Produciesta telemetry showed memory doesn't fully return to baseline after episodes complete. After VoxAlta model unload, memory should drop to ~250 MB but instead stays elevated.

SwiftSecuencia handles:
1. Audio timeline creation
2. SwiftData ModelContext lifecycle
3. Audio export via AVFoundation
4. Timeline clip management

Any of these could be leaking memory across episodes.

## Objectives

1. **Track SwiftData ModelContext lifecycle** - Are contexts being deallocated?
2. **Monitor audio buffer retention** - Are WAV/M4A buffers staying in memory?
3. **Watch timeline clip growth** - Are clips accumulating?
4. **Check AVFoundation cleanup** - Is the export session releasing resources?

## Telemetry Points

### 1. ModelContext Lifecycle

**File**: `Sources/SwiftSecuencia/ForegroundAudioExporter.swift` (or equivalent)

Track ModelContext creation and cleanup:

```swift
@MainActor
public func exportAudio(timeline: Timeline, modelContext: ModelContext, to outputURL: URL) async throws {
    // TELEMETRY: Before export
    await telemetry?.capture(.exportStart(
        timelineClipCount: timeline.clips.count,
        modelContextObjects: modelContext.registeredObjects.count
    ))
    
    // ... existing export logic ...
    
    // TELEMETRY: After export
    await telemetry?.capture(.exportComplete(
        outputSizeMB: getFileSize(outputURL),
        modelContextObjects: modelContext.registeredObjects.count,
        pendingChanges: modelContext.hasChanges
    ))
}
```

### 2. Audio Buffer Tracking

**File**: `Sources/SwiftSecuencia/ScreenplayToTimelineConverter.swift`

Track audio data accumulation during timeline creation:

```swift
public func convertToTimeline(
    screenplayName: String,
    audioElements: [TypedDataStorage],
    audioMetadata: [ScreenplayMetadata]?,
    videoFormat: VideoFormat,
    progress: ProgressReporter?
) async throws -> Timeline {
    // TELEMETRY: Before conversion
    let totalAudioMB = audioElements.map { Double($0.binaryValue?.count ?? 0) }.reduce(0, +) / 1024 / 1024
    await telemetry?.capture(.timelineConversionStart(
        elementCount: audioElements.count,
        totalAudioMB: totalAudioMB
    ))
    
    // ... existing conversion logic ...
    
    // TELEMETRY: After conversion
    await telemetry?.capture(.timelineConversionComplete(
        clipCount: timeline.clips.count,
        durationSeconds: timeline.duration
    ))
    
    return timeline
}
```

### 3. Timeline Clip Memory

**File**: `Sources/SwiftSecuencia/Timeline.swift`

Report timeline state:

```swift
@Model
public final class Timeline {
    // ... existing properties ...
    
    public func reportMemoryState() -> TimelineTelemetry {
        let clipCount = clips.count
        let totalDuration = clips.map(\.duration).reduce(0, +)
        
        return TimelineTelemetry(
            clipCount: clipCount,
            totalDurationSeconds: totalDuration,
            estimatedMemoryMB: Double(clipCount) * 0.5  // Rough estimate
        )
    }
}
```

### 4. AVFoundation Export Session

**File**: `Sources/SwiftSecuencia/ForegroundAudioExporter.swift`

Track export session lifecycle:

```swift
private func exportWithAVFoundation(_ composition: AVComposition, to outputURL: URL) async throws {
    // TELEMETRY: Before export session
    await telemetry?.capture(.avExportStart(
        compositionDuration: composition.duration.seconds
    ))
    
    let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
    exportSession?.outputURL = outputURL
    exportSession?.outputFileType = .m4a
    
    await exportSession?.export()
    
    // TELEMETRY: After export (ensure session is released)
    await telemetry?.capture(.avExportComplete(
        sessionRetained: exportSession != nil  // Should be false if properly released
    ))
}
```

## Data Structures

### Telemetry Events

```swift
public enum SecuenciaTelemetryEvent: Sendable {
    case exportStart(timelineClipCount: Int, modelContextObjects: Int)
    case exportComplete(outputSizeMB: Double, modelContextObjects: Int, pendingChanges: Bool)
    case timelineConversionStart(elementCount: Int, totalAudioMB: Double)
    case timelineConversionComplete(clipCount: Int, durationSeconds: Double)
    case avExportStart(compositionDuration: Double)
    case avExportComplete(sessionRetained: Bool)
    case modelContextLeak(registeredObjects: Int, insertedObjects: Int)
}
```

### Telemetry Reporter Protocol

```swift
public protocol SecuenciaTelemetryReporter: Sendable {
    func capture(_ event: SecuenciaTelemetryEvent) async
}
```

### Integration with Produciesta

```swift
// In Produciesta's exportAudioOnMainActor():
let secuenciaTelemetry = SecuenciaTelemetryAdapter(memoryTelemetry: memoryTelemetry)
let exporter = ForegroundAudioExporter(telemetry: secuenciaTelemetry)
```

## Implementation Checklist

### Phase 1: Infrastructure (1 hour)
- [ ] Create `SecuenciaTelemetryEvent` enum
- [ ] Create `SecuenciaTelemetryReporter` protocol
- [ ] Add `telemetry` parameter to `ForegroundAudioExporter`
- [ ] Add `telemetry` parameter to `ScreenplayToTimelineConverter`

### Phase 2: Core Instrumentation (1-2 hours)
- [ ] Instrument `exportAudio()` - before/after
- [ ] Instrument `convertToTimeline()` - before/after
- [ ] Add ModelContext object tracking
- [ ] Add audio buffer size calculation

### Phase 3: Testing (30 min)
- [ ] Unit test: telemetry events fire
- [ ] Integration test: reports to Produciesta

## Testing Strategy

### Unit Tests

```swift
func testExportTelemetry() async throws {
    let mockTelemetry = MockTelemetryReporter()
    let exporter = ForegroundAudioExporter(telemetry: mockTelemetry)
    
    // ... create test timeline and context ...
    
    try await exporter.exportAudio(timeline: timeline, modelContext: context, to: outputURL)
    
    XCTAssertEqual(mockTelemetry.events.count, 2)
    XCTAssert(mockTelemetry.events.contains { event in
        if case .exportStart = event { return true }
        return false
    })
}
```

### Integration Test

```bash
bin/produciesta ~/test-project --telemetry | grep "Secuencia"
```

Expected:
```
📊 [Secuencia] Export start: 16 clips, 0 model objects
📊 [Secuencia] Timeline conversion: 16 elements, 2.4 MB audio
📊 [Secuencia] Export complete: 2.1 MB output, 16 model objects
```

## Success Criteria

### Must Have
- [x] Export start/complete tracked with memory state
- [x] ModelContext object count tracked
- [x] Timeline clip count tracked
- [x] Audio buffer sizes calculated

### Nice to Have
- [ ] AVFoundation session retention check
- [ ] Per-clip memory estimation
- [ ] SwiftData context leak detection

## Expected Findings

**Scenario 1: ModelContext Leak**
```
Export start: 0 registered objects
Export complete: 16 registered objects ⚠️
Next episode start: 16 registered objects (should be 0)
```
→ ModelContext not being deallocated between episodes

**Scenario 2: Timeline Clip Accumulation**
```
Episode 1: 16 clips
Episode 2: 32 clips ⚠️ (should still be 16)
```
→ Timeline objects persisting across episodes

**Scenario 3: Audio Buffer Retention**
```
Export start: 2.4 MB audio data
Export complete: still 2.4 MB in memory ⚠️
```
→ Audio buffers not released after export

## Next Steps After Instrumentation

1. **Run telemetry test** with Produciesta
2. **Check ModelContext lifecycle** - objects cleaned up?
3. **Verify timeline cleanup** - clips released?
4. **Test audio buffer release** - memory freed after export?
5. **Implement fix** if leak found

## References

- **Produciesta telemetry**: [TELEMETRY_FINDINGS.md](../Produciesta/TELEMETRY_FINDINGS.md)
- **Coordination doc**: [MULTI_REPO_TELEMETRY.md](../Produciesta/MULTI_REPO_TELEMETRY.md)
- **ForegroundAudioExporter**: `Sources/SwiftSecuencia/ForegroundAudioExporter.swift`

---

**Ready to start?** Open a new Claude Code window in `/Users/stovak/Projects/SwiftSecuencia` and follow this REQUIREMENTS document.
