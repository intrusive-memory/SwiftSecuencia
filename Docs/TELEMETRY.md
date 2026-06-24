# SwiftSecuencia Telemetry Integration Testing

This document describes how to test SwiftSecuencia's telemetry instrumentation in a real-world integration environment.

## Overview

SwiftSecuencia emits telemetry events at critical lifecycle points to help diagnose memory retention issues. These events track:

- **Export Events**: Audio export lifecycle and ModelContext state
- **Timeline Conversion Events**: Audio buffer accumulation and clip creation
- **AVFoundation Events**: Export session resource cleanup
- **Memory Leak Detection**: ModelContext object retention

## Unit Testing

Run the telemetry test suite with:

```bash
make test
```

The test suite includes:

- `MockTelemetryReporter.swift` — Thread-safe mock reporter for testing
- `ExportTelemetryTests.swift` — Tests for `ForegroundAudioExporter` telemetry
- `TimelineTelemetryTests.swift` — Tests for `ScreenplayToTimelineConverter` telemetry

## Integration Testing with Produciesta

SwiftSecuencia is used in production by Produciesta, a podcast audio generation CLI. You can test telemetry instrumentation end-to-end using Produciesta's `--telemetry` flag.

### Prerequisites

1. **Produciesta CLI**: Installed at `bin/produciesta` (from the Produciesta project)
2. **Test Project**: A Produciesta project directory with screenplay files
3. **SwiftSecuencia Library**: Produciesta must link against your local SwiftSecuencia checkout

### Running Integration Tests

From the Produciesta project directory:

```bash
bin/produciesta ~/test-project --telemetry | grep "Secuencia"
```

This will:
1. Generate audio from screenplay files
2. Convert screenplay elements to timelines (SwiftSecuencia)
3. Export audio to M4A format (SwiftSecuencia)
4. Print telemetry events from SwiftSecuencia components

### Expected Output Format

Telemetry events are logged with structured data. Look for these event names:

#### Timeline Conversion Events

```
[Secuencia.timelineConversionStart] elementCount=16 totalAudioMB=12.5
[Secuencia.timelineConversionComplete] clipCount=16 durationSeconds=240.3
```

**What to verify:**
- `elementCount` matches the number of screenplay elements
- `totalAudioMB` reflects the size of generated audio buffers
- `clipCount` matches `elementCount` (1:1 mapping)
- `durationSeconds` is the sum of all clip durations

**Leak detection:**
- If `totalAudioMB` remains elevated after conversion completes, audio buffers are not being released
- If `clipCount` accumulates across episodes (16 → 32 → 48), timeline objects are persisting

#### Export Events

```
[Secuencia.exportStart] timelineClipCount=16 modelContextObjects=0
[Secuencia.exportComplete] outputSizeMB=8.3 modelContextObjects=0 pendingChanges=false
```

**What to verify:**
- `timelineClipCount` matches the number of clips in the timeline
- `modelContextObjects` should be 0 (or minimal) at export start
- `modelContextObjects` should return to baseline after export completes
- `pendingChanges` should be `false` after export

**Leak detection:**
- If `modelContextObjects` is non-zero at export start, ModelContext objects are not being released between exports
- If `modelContextObjects` increases across episodes (0 → 5 → 10), ModelContext is leaking objects
- If `pendingChanges` is `true` after export, incomplete cleanup may have occurred

#### AVFoundation Events

```
[Secuencia.avExportStart] compositionDuration=240.3
[Secuencia.avExportComplete] sessionRetained=false
```

**What to verify:**
- `compositionDuration` matches the timeline duration
- `sessionRetained` should be `false` after export

**Leak detection:**
- If `sessionRetained` is `true`, the AVAssetExportSession is not being properly released (memory leak)

### Multi-Episode Testing

To test for memory leaks across multiple episodes, run Produciesta on multiple projects sequentially:

```bash
for episode in episode-001 episode-002 episode-003; do
  echo "=== Processing $episode ==="
  bin/produciesta ~/projects/$episode --telemetry | grep "Secuencia"
done
```

**What to look for:**
- **Baseline memory**: `modelContextObjects` should return to 0 between episodes
- **Clip accumulation**: `clipCount` should not accumulate (should be the same for each episode)
- **Audio buffer accumulation**: `totalAudioMB` should not increase across episodes
- **Session cleanup**: `sessionRetained` should always be `false`

### Example: Healthy Run

```
=== Episode 1 ===
[Secuencia.timelineConversionStart] elementCount=16 totalAudioMB=12.5
[Secuencia.timelineConversionComplete] clipCount=16 durationSeconds=240.3
[Secuencia.exportStart] timelineClipCount=16 modelContextObjects=0
[Secuencia.avExportStart] compositionDuration=240.3
[Secuencia.avExportComplete] sessionRetained=false
[Secuencia.exportComplete] outputSizeMB=8.3 modelContextObjects=0 pendingChanges=false

=== Episode 2 ===
[Secuencia.timelineConversionStart] elementCount=18 totalAudioMB=14.2
[Secuencia.timelineConversionComplete] clipCount=18 durationSeconds=268.7
[Secuencia.exportStart] timelineClipCount=18 modelContextObjects=0
[Secuencia.avExportStart] compositionDuration=268.7
[Secuencia.avExportComplete] sessionRetained=false
[Secuencia.exportComplete] outputSizeMB=9.1 modelContextObjects=0 pendingChanges=false
```

**Analysis:** Clean run. ModelContext returns to 0 objects between episodes. No clip accumulation. Session properly released.

### Example: Memory Leak Detected

```
=== Episode 1 ===
[Secuencia.timelineConversionStart] elementCount=16 totalAudioMB=12.5
[Secuencia.timelineConversionComplete] clipCount=16 durationSeconds=240.3
[Secuencia.exportStart] timelineClipCount=16 modelContextObjects=0
[Secuencia.avExportStart] compositionDuration=240.3
[Secuencia.avExportComplete] sessionRetained=false
[Secuencia.exportComplete] outputSizeMB=8.3 modelContextObjects=5 pendingChanges=false

=== Episode 2 ===
[Secuencia.timelineConversionStart] elementCount=18 totalAudioMB=14.2
[Secuencia.timelineConversionComplete] clipCount=18 durationSeconds=268.7
[Secuencia.exportStart] timelineClipCount=18 modelContextObjects=5
[Secuencia.avExportStart] compositionDuration=268.7
[Secuencia.avExportComplete] sessionRetained=false
[Secuencia.exportComplete] outputSizeMB=9.1 modelContextObjects=10 pendingChanges=false
```

**Analysis:** LEAK DETECTED. ModelContext objects accumulate (0 → 5 → 10). Objects are not being released between episodes.

## Interpreting Results

### Normal Behavior

- `modelContextObjects` returns to 0 between exports
- `clipCount` matches `elementCount` for each episode
- `totalAudioMB` varies based on episode content (not cumulative)
- `sessionRetained` is always `false`
- `outputSizeMB` is reasonable for the audio duration

### Leak Indicators

- **ModelContext Leak**: `modelContextObjects` accumulates across episodes
- **Timeline Leak**: `clipCount` accumulates (16 → 32 → 48)
- **Audio Buffer Leak**: `totalAudioMB` increases across episodes
- **AVFoundation Leak**: `sessionRetained` is `true`
- **Incomplete Cleanup**: `pendingChanges` is `true` after export

## Troubleshooting

### No Telemetry Events Appear

**Cause**: Produciesta is not passing a telemetry reporter to SwiftSecuencia.

**Fix**: Verify Produciesta's telemetry flag implementation:
- Check that `--telemetry` creates a telemetry reporter
- Verify the reporter is passed to `ForegroundAudioExporter` and `ScreenplayToTimelineConverter`

### Events Missing Expected Fields

**Cause**: SwiftSecuencia telemetry instrumentation may be incomplete.

**Fix**: Run unit tests to verify telemetry instrumentation:
```bash
make test
```

### Events Show Unexpected Values

**Cause**: Data calculation or ModelContext introspection may be incorrect.

**Fix**: Check the following in SwiftSecuencia:
- `calculateAudioDataMB()` — Verify byte-to-MB conversion
- `getModelContextObjectCount()` — Verify registered object count
- `getFileSize()` — Verify file size calculation

## Related Documentation

- **Telemetry Events**: `Sources/SwiftSecuencia/Telemetry/SecuenciaTelemetryEvent.swift`
- **Telemetry Reporter Protocol**: `Sources/SwiftSecuencia/Telemetry/SecuenciaTelemetryReporter.swift`
- **Unit Tests**: `Tests/SwiftSecuenciaTests/*TelemetryTests.swift`
- **Requirements**: `REQUIREMENTS_telemetry.md` (if available)

---

**Last Updated**: 2026-05-06  
**SwiftSecuencia Version**: 3.2.1+
