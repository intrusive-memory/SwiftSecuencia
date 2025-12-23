# Timecode Synchronization Requirements

## Overview

Add inline timecode generation during audio export to enable karaoke-style transcript synchronization in web players. This feature will output timing data (start/end timestamps) for each spoken line/segment, allowing synchronized "follow along" text display.

## Functional Requirements

### FR-1: Timing Data Generation

**Description**: Generate precise timing data for each dialogue segment during audio export.

**Requirements**:
- **FR-1.1**: Record start and end timestamps for each audio clip in the timeline
- **FR-1.2**: Associate timing data with the source transcript segment (dialogue line)
- **FR-1.3**: Timing precision must be within ±100ms of actual audio
- **FR-1.4**: Support all audio formats exported by SwiftSecuencia (M4A)
- **FR-1.5**: Timing data must account for silence/gaps between clips

**Acceptance Criteria**:
- Exported timing data accurately reflects audio playback positions
- Timing data can be used to highlight text in sync with audio
- Works with both continuous and non-continuous timelines (clips with gaps)

---

### FR-2: Output Format

**Description**: Export timing data in web-standard formats optimized for karaoke-style synchronization.

**Requirements**:
- **FR-2.1**: Primary output format must be WebVTT (W3C standard)
- **FR-2.2**: Optional JSON format for advanced use cases
- **FR-2.3**: Include segment identifier (cue ID or clip UUID)
- **FR-2.4**: Include start/end timestamps in standard format
- **FR-2.5**: Include segment text content
- **FR-2.6**: Support character voice tags in WebVTT format
- **FR-2.7**: Support both formats simultaneously (dual export)

**WebVTT Format** (Primary - Recommended):
```
WEBVTT

NOTE Screenplay: My Script

1
00:00:00.000 --> 00:00:03.200
<v ALICE>Hello, world!</v>

2
00:00:03.500 --> 00:00:07.800
<v BOB>How are you?</v>

3
00:00:08.000 --> 00:00:12.500
<v ALICE>I'm doing great!</v>
```

**JSON Format** (Optional):
```json
{
  "version": "1.0",
  "audioFile": "screenplay.m4a",
  "duration": 150.5,
  "segments": [
    {
      "id": "line-1",
      "startTime": 0.0,
      "endTime": 3.2,
      "text": "Hello, world!",
      "metadata": {
        "character": "ALICE",
        "lane": 1,
        "clipId": "clip-uuid-1234"
      }
    }
  ]
}
```

**Acceptance Criteria**:
- WebVTT validates against W3C specification
- JSON validates against schema (when enabled)
- Web players can use WebVTT with native `<track>` element
- File size remains reasonable (< 1% of audio file size for typical scripts)

---

### FR-3: API Integration

**Description**: Integrate timing data generation into existing audio export APIs with format selection.

**Requirements**:
- **FR-3.1**: Add optional `timingDataFormat` parameter to `ForegroundAudioExporter.exportAudioDirect()`
- **FR-3.2**: Add optional `timingDataFormat` parameter to `ForegroundAudioExporter.exportAudio()`
- **FR-3.3**: Add optional `timingDataFormat` parameter to `BackgroundAudioExporter.exportAudio()`
- **FR-3.4**: Return timing data file URL(s) alongside audio file URL
- **FR-3.5**: WebVTT files use `.vtt` extension (e.g., `screenplay.vtt`)
- **FR-3.6**: JSON files use `.timing.json` extension (e.g., `screenplay.timing.json`)
- **FR-3.7**: Default behavior: `timingDataFormat = .none` (backward compatible)
- **FR-3.8**: Support `.both` format for dual export

**API Example**:
```swift
// Format selection enum
public enum TimingDataFormat {
    case none             // No timing data (default)
    case webvtt           // WebVTT only (recommended)
    case json             // JSON only
    case both             // Both WebVTT and JSON
}

// Foreground export with WebVTT timing data
let result = try await exporter.exportAudioDirect(
    audioElements: audioFiles,
    modelContext: modelContext,
    to: destinationURL,
    timingDataFormat: .webvtt,  // NEW parameter
    progress: progress
)

// result.audioURL = file:///path/screenplay.m4a
// result.webvttURL = file:///path/screenplay.vtt
// result.jsonURL = nil

// Export both formats
let result2 = try await exporter.exportAudioDirect(
    audioElements: audioFiles,
    modelContext: modelContext,
    to: destinationURL,
    timingDataFormat: .both,
    progress: progress
)

// result2.webvttURL = file:///path/screenplay.vtt
// result2.jsonURL = file:///path/screenplay.timing.json
```

**Acceptance Criteria**:
- Existing API calls continue to work without changes
- Timing data generation does not impact performance when disabled
- Both foreground and background exporters support all formats
- Web players can use native `<track>` element with WebVTT files

---

### FR-4: Performance

**Description**: Timing data generation must not significantly impact export performance.

**Requirements**:
- **FR-4.1**: Overhead when enabled must be < 5% of total export time
- **FR-4.2**: Timing data generation must run in parallel with audio export where possible
- **FR-4.3**: Memory usage must remain constant (O(n) where n = number of clips)
- **FR-4.4**: Timing data file write must not block audio export completion

**Acceptance Criteria**:
- Export time increase < 5% when timing data enabled
- No memory leaks or excessive allocations
- Progress reporting remains accurate

---

## Non-Functional Requirements

### NFR-1: Platform Support

- **NFR-1.1**: macOS 26.0+ (matches audio export requirements)
- **NFR-1.2**: iOS 26.0+ (audio export only)

### NFR-2: Accuracy

- **NFR-2.1**: Timing precision: ±100ms
- **NFR-2.2**: Start time must reflect actual audio playback position (accounting for composition gaps)
- **NFR-2.3**: End time must match audio clip duration

### NFR-3: Reliability

- **NFR-3.1**: Timing data generation must not cause export failures
- **NFR-3.2**: If timing data generation fails, audio export should still succeed (log warning)
- **NFR-3.3**: WebVTT output must be W3C specification compliant
- **NFR-3.4**: JSON output must be valid UTF-8

### NFR-4: Maintainability

- **NFR-4.1**: Timing data models must be Codable for easy serialization
- **NFR-4.2**: Code must follow SwiftSecuencia concurrency patterns (@ModelActor, async/await)
- **NFR-4.3**: Unit test coverage: 90%+

---

## User Stories

### US-1: Web Player Synchronization

**As a** web player developer
**I want** timing data for each dialogue line
**So that** I can highlight text in sync with audio playback

**Acceptance Criteria**:
- Export generates `.vtt` file alongside `.m4a` audio
- WebVTT contains properly formatted timestamps for each line
- Timing is accurate within 100ms
- Web player can use native `<track>` element

---

### US-2: Karaoke-Style Display

**As a** Daily Dao user
**I want** text to highlight as the narrator speaks
**So that** I can follow along with the audio

**Acceptance Criteria**:
- Web player uses timing data to highlight current line
- Transition between lines is smooth (no jumps)
- Works with overlapping audio (multiple characters speaking)

---

### US-3: Performance Monitoring

**As a** developer
**I want** timing data generation to be fast
**So that** users don't experience slower exports

**Acceptance Criteria**:
- Export time increase < 5%
- Progress reporting reflects timing data generation phase

---

## Open Questions

1. **Multi-lane handling**: How should overlapping clips be represented in timing data?
   - **Option A**: Separate segments for each lane (multiple entries with overlapping times)
   - **Option B**: Merge overlapping clips into single segment with array of texts
   - **Recommendation**: Option A (simpler, more flexible for web player)

2. **Silence handling**: Should gaps between clips be included in timing data?
   - **Option A**: Yes, include silence segments with `text: null`
   - **Option B**: No, only include spoken segments
   - **Recommendation**: Option B (web player doesn't need silence info)

3. **Character metadata**: Should timing data include character names from Fountain?
   - **Option A**: Yes, extract from clip metadata if available
   - **Option B**: No, web player should handle character association
   - **Recommendation**: Option A (more useful for debugging, optional field)

4. **ID generation**: How should segment IDs be generated?
   - **Option A**: Sequential (line-1, line-2, ...)
   - **Option B**: Clip UUID (matches TimelineClip.id)
   - **Recommendation**: Option B (more robust, easier to correlate with source)

---

## Out of Scope

The following are explicitly **not** included in this feature:

1. **Word-level timing**: Only line/segment-level timing (word-level requires speech recognition)
2. **SRT format**: WebVTT and JSON only (SRT is less feature-rich)
3. **Video synchronization**: Only audio timing (FCPXML already handles video)
4. **Real-time generation**: Timing data only available after export completes
5. **Timing data editing**: No API to modify timing data post-export
6. **Advanced WebVTT styling**: Basic voice tags only (no CSS regions or positioning)

---

## Dependencies

1. **SwiftData**: Timeline and TimelineClip models (existing)
2. **AVFoundation**: Audio composition timing (existing)
3. **Foundation**: JSONEncoder, FileManager (existing)
4. **TypedDataStorage**: Asset metadata extraction (SwiftCompartido)
5. **swift-webvtt-parser**: WebVTT generation (new dependency)
   - Repository: https://github.com/mihai8804858/swift-webvtt-parser
   - Version: 1.0.0+
   - License: MIT

---

## Success Metrics

1. **Accuracy**: 95%+ of segments within ±100ms of actual playback
2. **Performance**: < 5% export time increase
3. **Adoption**: Used in Daily Dao web player within 1 month
4. **Reliability**: 0 crashes or export failures caused by timing data generation

---

## References

- [WebVTT Specification (W3C)](https://www.w3.org/TR/webvtt1/)
- [WebVTT API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API)
- [swift-webvtt-parser GitHub](https://github.com/mihai8804858/swift-webvtt-parser)
- [Web Audio API Timing](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [AVFoundation Composition Timing](https://developer.apple.com/documentation/avfoundation/avmutablecomposition)
- [HTML Track Element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/track)
