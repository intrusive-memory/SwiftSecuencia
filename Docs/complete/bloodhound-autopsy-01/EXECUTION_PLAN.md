---
feature_name: OPERATION BLOODHOUND AUTOPSY
starting_point_commit: 8dbb75d5b632c8767180e65c8578b2eb24a0e33f
mission_branch: mission/bloodhound-autopsy/1
iteration: 1
---

# EXECUTION_PLAN.md — SwiftSecuencia Telemetry

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Mission Objective

Add telemetry instrumentation to SwiftSecuencia to diagnose memory retention issues in Produciesta. The telemetry will track:
1. SwiftData ModelContext lifecycle (object retention)
2. Audio buffer retention (WAV/M4A data in memory)
3. Timeline clip growth (clip accumulation)
4. AVFoundation cleanup (export session resource release)

**Root Cause**: Produciesta telemetry shows memory doesn't return to baseline after episodes complete. After VoxAlta model unload, memory should drop to ~250 MB but stays elevated. SwiftSecuencia handles audio timeline creation, SwiftData lifecycle, audio export, and timeline clip management — any of these could be leaking memory.

**Success Criteria**: Telemetry events fire at critical lifecycle points, enabling Produciesta to identify which subsystem retains memory across episodes.

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|--------------|
| Telemetry Instrumentation | Sources/SwiftSecuencia | 4 | 1 | none |

---

## Sortie Definitions

### Sortie 1: Telemetry Infrastructure

**Entry criteria**:
- [x] First sortie — no prerequisites
- [x] Requirements document specifies `SecuenciaTelemetryEvent` enum and `SecuenciaTelemetryReporter` protocol

**Tasks**:
1. Create `Sources/SwiftSecuencia/Telemetry/SecuenciaTelemetryEvent.swift` with enum cases:
   - `exportStart(timelineClipCount: Int, modelContextObjects: Int)`
   - `exportComplete(outputSizeMB: Double, modelContextObjects: Int, pendingChanges: Bool)`
   - `timelineConversionStart(elementCount: Int, totalAudioMB: Double)`
   - `timelineConversionComplete(clipCount: Int, durationSeconds: Double)`
   - `avExportStart(compositionDuration: Double)`
   - `avExportComplete(sessionRetained: Bool)`
   - `modelContextLeak(registeredObjects: Int, insertedObjects: Int)`
2. Create `Sources/SwiftSecuencia/Telemetry/SecuenciaTelemetryReporter.swift` with protocol:
   - `func capture(_ event: SecuenciaTelemetryEvent) async`
   - Mark protocol as `Sendable`
3. Ensure both files are `public` (library code)
4. Add documentation comments explaining each event's purpose

**Exit criteria**:
- [x] `SecuenciaTelemetryEvent.swift` exists with all 7 event cases
- [x] `SecuenciaTelemetryReporter.swift` exists with async `capture` method
- [x] Both types conform to `Sendable` requirement
- [x] `swift build` succeeds from package root

---

### Sortie 2: Export Instrumentation

**Entry criteria**:
- [x] Sortie 1 complete (telemetry types available)
- [x] `ForegroundAudioExporter.swift` exists at `Sources/SwiftSecuencia/ForegroundAudioExporter.swift`

**Tasks**:
1. Add optional `telemetry: SecuenciaTelemetryReporter?` parameter to `ForegroundAudioExporter` initializer
2. Instrument `exportAudio(timeline:modelContext:to:)` method:
   - Before export: capture `.exportStart` with `timeline.clips.count` and `modelContext.registeredObjects.count`
   - After export: capture `.exportComplete` with output file size (MB), `modelContext.registeredObjects.count`, and `modelContext.hasChanges`
3. Instrument `exportWithAVFoundation(_:to:)` private method (if it exists):
   - Before export session: capture `.avExportStart` with `composition.duration.seconds`
   - After export session: capture `.avExportComplete` with `sessionRetained` flag
4. Add helper method `getFileSize(_ url: URL) -> Double` to calculate MB from bytes
5. Ensure all telemetry calls are `await telemetry?.capture(...)`

**Exit criteria**:
- [x] `ForegroundAudioExporter` has `telemetry` property
- [x] Export start/complete events fire with correct ModelContext object counts
- [x] AVFoundation events fire if `exportWithAVFoundation` method exists
- [x] File size calculation returns MB (not bytes)
- [x] `swift build` succeeds

---

### Sortie 3: Timeline Conversion Instrumentation

**Entry criteria**:
- [x] Sortie 1 complete (telemetry types available)
- [x] `ScreenplayToTimelineConverter.swift` exists at `Sources/SwiftSecuencia/ScreenplayToTimelineConverter.swift`

**Tasks**:
1. Add optional `telemetry: SecuenciaTelemetryReporter?` parameter to `ScreenplayToTimelineConverter` initializer
2. Instrument `convertToTimeline(screenplayName:audioElements:audioMetadata:videoFormat:progress:)` method:
   - Before conversion: calculate total audio MB from `audioElements.map { $0.binaryValue?.count ?? 0 }`, capture `.timelineConversionStart`
   - After conversion: capture `.timelineConversionComplete` with `timeline.clips.count` and `timeline.duration`
3. Add helper method `calculateAudioDataMB(_ elements: [TypedDataStorage]) -> Double`
4. Ensure all telemetry calls are `await telemetry?.capture(...)`

**Exit criteria**:
- [x] `ScreenplayToTimelineConverter` has `telemetry` property
- [x] Timeline conversion start event fires with element count and total audio MB
- [x] Timeline conversion complete event fires with clip count and duration
- [x] Audio size calculation sums all `binaryValue` byte counts and converts to MB
- [x] `swift build` succeeds

---

### Sortie 4: Test Infrastructure

**Entry criteria**:
- [x] Sorties 1, 2, 3 complete (all instrumentation in place)
- [x] Test target exists in `Package.swift`

**Tasks**:
1. Create `Tests/SwiftSecuenciaTests/MockTelemetryReporter.swift`:
   - Implement `SecuenciaTelemetryReporter` protocol
   - Store captured events in `var events: [SecuenciaTelemetryEvent] = []`
   - Mark as `actor` for thread-safety
2. Create `Tests/SwiftSecuenciaTests/ExportTelemetryTests.swift`:
   - Test that `exportAudio()` fires `exportStart` and `exportComplete` events
   - Verify event payload contains correct clip count and ModelContext object count
3. Create `Tests/SwiftSecuenciaTests/TimelineTelemetryTests.swift`:
   - Test that `convertToTimeline()` fires `timelineConversionStart` and `timelineConversionComplete` events
   - Verify audio size calculation is accurate
4. Update `README.md` or create `TELEMETRY.md` documenting integration test approach:
   - How to run: `bin/produciesta ~/test-project --telemetry | grep "Secuencia"`
   - Expected output format with example

**Exit criteria**:
- [x] `MockTelemetryReporter` exists and conforms to protocol
- [x] Export telemetry tests pass (`swift test`)
- [x] Timeline telemetry tests pass (`swift test`)
- [x] Integration testing documented with concrete example
- [x] All tests in test suite pass

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 1 |
| Total sorties | 4 |
| Dependency structure | Sequential (1 → 2, 3 → 4) |
| Estimated effort | 2-3 hours |
| Deliverables | 7 new files, 2 modified files, test suite |

---

## Dependency Graph

```
Sortie 1 (Infrastructure)
    ↓
Sortie 2 (Export)    Sortie 3 (Timeline)
    ↓                     ↓
    └─────────┬───────────┘
              ↓
         Sortie 4 (Tests)
```

**Parallelization opportunities**: Sorties 2 and 3 can execute in parallel after Sortie 1 completes.

---

## Notes

- **No version changes required**: This is internal instrumentation only; no public API surface changes
- **Backward compatibility**: Telemetry is optional (`telemetry: SecuenciaTelemetryReporter?`), so existing callers continue to work
- **Integration testing**: Requires Produciesta CLI (`bin/produciesta`) for end-to-end verification
- **Expected findings**: See REQUIREMENTS_telemetry.md § Expected Findings for leak scenarios

---

**Generated by**: Mission Supervisor (breakdown command)  
**Source**: REQUIREMENTS_telemetry.md  
**Ready for**: /mission-supervisor refine
