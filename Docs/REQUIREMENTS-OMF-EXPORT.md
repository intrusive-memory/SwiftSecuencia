# Requirements: OMF Export for Logic Pro (Feature #2)

**Status**: Draft
**Created**: 2025-12-06
**Target Version**: v1.2.0
**Related**: REQUIREMENTS-MULTI-TIMELINE-EXPORT.md

## Overview

Enable SwiftSecuencia to export Timeline objects to OMF (Open Media Framework) format for direct import into Logic Pro and other DAWs. OMF export will support audio-only timelines with external media references, making it easy to transfer audio projects from SwiftSecuencia to Logic Pro for mixing and post-production.

## Background

### Why OMF Instead of AAF?

Based on research and industry feedback:
- **Logic Pro + AAF**: Significant compatibility issues ([source](https://www.jespersoderstrom.com/logic-pro-audio-post/omf-aaf-xml/))
- **Logic Pro + OMF**: Works reliably with Type 1 (embedded) or Type 2 (external) files
- **OMF Limitations**: Older format, loses some metadata (volume automation, track names) but is the most reliable option for Logic Pro import

**Decision**: Prioritize OMF export for Logic Pro compatibility.

## Use Cases

1. **Audio Post-Production**: Export audio timeline from SwiftSecuencia to Logic Pro for mixing
2. **Music Production**: Transfer narration/voiceover timeline to Logic for music composition
3. **Chapter-Based Mixing**: Export individual chapters as separate OMF files for focused mixing
4. **Cross-Platform Workflow**: Exchange audio projects with Pro Tools, Nuendo, or other DAWs that support OMF
5. **Archive & Compatibility**: OMF is a widely-supported interchange format for long-term project preservation

## Functional Requirements

### FR-1: OMF File Generation

**Description**: The system shall generate valid OMF (Open Media Framework) files compatible with Logic Pro.

**Specifications**:
- OMF version: **OMF 2.0** (most widely supported)
- File extension: `.omf`
- Structure: Type 2 OMF (external media references)
- Audio format: AIFF or WAV references (Logic Pro compatible)

**Example**:
```swift
let exporter = OMFExporter()
let omfURL = try await exporter.export(
    timeline: timeline,
    modelContext: context,
    outputURL: URL(fileURLWithPath: "/path/to/output.omf")
)
// Creates:
// - output.omf (OMF file with timeline structure)
// - Audio Files/ (folder with referenced audio files)
```

**Validation**: Generated OMF must:
- Open successfully in Logic Pro (File > Import > OMF)
- Preserve clip positions and timing
- Reference external audio files correctly

### FR-2: Audio-Only Export

**Description**: OMF export shall include only audio clips, omitting video and image clips.

**Behavior**:
- **Include**: Clips with `mimeType.hasPrefix("audio/")`
- **Exclude**: Clips with `mimeType.hasPrefix("video/")` or `mimeType.hasPrefix("image/")`
- **Result**: Timeline contains only audio clips with correct timing and placement

**Rationale**: Logic Pro is an audio-focused DAW and doesn't need video references in the OMF.

**Example**:
```swift
// Original timeline
timeline.clips = [
    clip1: audio/mpeg (include)
    clip2: video/mp4 (exclude)
    clip3: audio/wav (include)
    clip4: image/jpeg (exclude)
    clip5: audio/aiff (include)
]

// OMF export result
omf.tracks = [
    track1: clip1, clip3, clip5 (audio only)
]
```

### FR-3: Type 2 OMF (External Media)

**Description**: Export shall use Type 2 OMF format with external audio file references.

**Structure**:
```
ProjectName.omf                  # OMF file (timeline structure)
Audio Files/                     # Folder with audio media
├── audio_001.aiff              # Clip 1 audio
├── audio_002.aiff              # Clip 2 audio
└── audio_003.aiff              # Clip 3 audio
```

**OMF Content**:
- Timeline structure (tracks, clips, edits)
- Clip metadata (name, duration, in/out points)
- Audio file references (relative paths to Audio Files/)
- Timecode and timing information

**Rationale**:
- Matches our existing `.fcpxmld` bundle approach (external media)
- Smaller OMF file size
- More flexible (audio files can be replaced/updated)
- Standard workflow for professional audio post

### FR-4: Audio Format Conversion

**Description**: Export shall convert source audio to 48kHz / 24-bit AIFF or WAV format.

**Conversion Rules**:
1. **Sample Rate**: Convert all audio to 48kHz (professional video standard)
2. **Bit Depth**: Convert to 24-bit (professional audio standard)
3. **Format**: Export as **AIFF** (Audio Interchange File Format) - preferred for Mac/Logic
4. **Alternative**: Support WAV if AIFF fails

**Conversion Process**:
- Use AVFoundation's `AVAssetExportSession` or `AVAudioConverter`
- Preserve original audio quality (use highest quality settings)
- Handle stereo and mono sources
- Report conversion errors clearly

**Example**:
```swift
// Source audio: 44.1kHz, 16-bit, MP3
// Exported: 48kHz, 24-bit, AIFF

Input:  audio.mp3 (44.1kHz, 16-bit)
Output: audio_001.aiff (48kHz, 24-bit, PCM)
```

### FR-5: Multi-Timeline Export (Chapter-Based)

**Description**: Support exporting timelines with chapter markers as multiple OMF files.

**Behavior**:
- If timeline has chapter markers, export one OMF file per chapter
- Each OMF file is named after the chapter
- Audio files are shared across OMFs (de-duplicated)
- If no chapter markers, export single OMF

**Structure**:
```
Output/
├── Introduction.omf
├── MainContent.omf
├── Conclusion.omf
└── Audio Files/               # Shared audio folder
    ├── audio_001.aiff        # Used by multiple OMFs
    ├── audio_002.aiff
    └── audio_003.aiff
```

**Naming**:
- OMF files named after `ChapterMarker.value`
- Sanitize filenames (remove invalid characters)
- Default to "Untitled Chapter {N}" if name is empty

**Validation**: Each OMF should:
- Open independently in Logic Pro
- Reference the shared Audio Files/ folder
- Contain only clips within its chapter time range

### FR-6: Clip Timing and Placement

**Description**: Clips shall maintain correct timing and placement in the OMF timeline.

**Timing Rules**:
1. **Single Timeline Export**:
   - Clip offsets preserved as-is
   - Timeline starts at 0:00:00:00 (timecode zero)
   - Clip in/out points calculated from `sourceStart` and `duration`

2. **Multi-Timeline Export (Chapters)**:
   - Each chapter OMF starts at 0:00:00:00
   - Clips re-timed relative to chapter start (same as FCPXML multi-timeline)
   - `sourceStart` preserved (in point within source audio)
   - `duration` preserved

**Example**:
```swift
// Original timeline with chapters
Chapter "Intro": 0s-60s
  - Clip A: offset=10s, duration=20s, sourceStart=0s

Chapter "Main": 60s-120s
  - Clip B: offset=70s, duration=30s, sourceStart=5s

// Exported OMFs
Intro.omf:
  - Clip A: offset=10s, duration=20s, sourceStart=0s (unchanged)

Main.omf:
  - Clip B: offset=10s, duration=30s, sourceStart=5s (re-timed: 70s - 60s = 10s)
```

### FR-7: Track Organization

**Description**: Audio clips shall be organized into tracks in the OMF.

**Track Assignment**:
- **Primary Storyline (lane 0)**: Maps to Track 1 in OMF
- **Secondary Storylines (lane != 0)**: Map to additional tracks

**Behavior**:
- Sort clips by lane, then by offset
- Each lane becomes a separate audio track in OMF
- Track names: "Track 1", "Track 2", etc. (OMF has limited metadata)

**Example**:
```swift
Timeline:
  Lane 0: Clip A, Clip B, Clip C
  Lane 1: Clip D, Clip E
  Lane -1: Clip F

OMF Tracks:
  Track 1 (Lane 0): Clip A, Clip B, Clip C
  Track 2 (Lane 1): Clip D, Clip E
  Track 3 (Lane -1): Clip F
```

**Note**: OMF doesn't preserve track names or automation, but Logic Pro can import multi-track OMFs.

### FR-8: Audio File Management

**Description**: Audio files shall be exported to the Audio Files/ folder with proper naming and de-duplication.

**File Naming**:
- Format: `audio_{NNN}.aiff` (e.g., `audio_001.aiff`, `audio_002.aiff`)
- Numbering: Sequential, zero-padded (001, 002, ..., 999)
- Extension: `.aiff` (preferred) or `.wav`

**De-duplication**:
- If multiple clips reference the same asset, export audio file once
- OMF clips reference the same audio file
- Reduces file size and storage

**Conversion**:
- Convert source audio to 48kHz / 24-bit AIFF
- Use `AVAssetExportSession` for format conversion
- Handle errors (unsupported formats, corrupted files)

**Example**:
```swift
Timeline:
  Clip A: assetId=UUID-1 → exports to audio_001.aiff
  Clip B: assetId=UUID-2 → exports to audio_002.aiff
  Clip C: assetId=UUID-1 → references audio_001.aiff (same asset)

Result:
  Audio Files/
    audio_001.aiff (used by Clip A and Clip C)
    audio_002.aiff (used by Clip B)
```

## Non-Functional Requirements

### NFR-1: AAF SDK Integration

**Description**: Use the AAF SDK (C++ library) via Swift C interop to generate OMF files.

**Approach**:
1. **AAF SDK**: Use official AAF SDK from [aaf.sourceforge.net](https://aaf.sourceforge.net/)
2. **OMF Support**: AAF SDK includes OMF 2.0 read/write support
3. **C Bridging**: Create C wrapper around AAF SDK C++ API
4. **Swift Layer**: Call C wrapper from Swift OMFExporter

**Justification**:
- AAF SDK is industry-standard, battle-tested
- OMF is a complex binary format (difficult to implement from scratch)
- SDK provides cross-platform support (macOS, Linux if needed)
- Maintained by [AMWA (Advanced Media Workflow Association)](https://www.amwa.tv/)

**Build Integration**:
- Add AAF SDK as a package dependency or git submodule
- Build AAF SDK static library (`.a`) for macOS
- Link against static library in Package.swift
- Bundle C headers for Swift bridging

**References**:
- [AAF SDK on GitHub](https://github.com/dneg/aaf)
- [AAF Developers' Guide](https://aafassociation.org/specs/aafguide/aafguide.html)
- [Building AAF SDK on macOS](https://github.com/nexgenta/aaf)

### NFR-2: Performance

**Description**: OMF export shall complete within reasonable time for typical timelines.

**Performance Targets**:
- **Small timeline** (10 clips, 5 minutes): < 10 seconds
- **Medium timeline** (50 clips, 30 minutes): < 30 seconds
- **Large timeline** (200 clips, 2 hours): < 2 minutes

**Performance Factors**:
- Audio conversion time (dominant factor)
- OMF file writing (fast, binary format)
- File I/O (copying audio to Audio Files/)

**Optimizations**:
- Parallel audio conversion (multiple clips at once)
- Async file operations
- Progress reporting for long exports

### NFR-3: Error Handling

**Description**: Export shall handle errors gracefully with clear user feedback.

**Error Scenarios**:
1. **Missing Audio Asset**: Clip references asset that doesn't exist
2. **Audio Conversion Failure**: Source audio is corrupted or unsupported format
3. **Disk Space**: Insufficient space for audio files
4. **File Permissions**: Cannot write to output directory
5. **OMF Generation Failure**: AAF SDK reports error

**Error Handling**:
- Throw descriptive Swift errors
- Include clip name/ID in error messages
- Suggest remediation steps (e.g., "Check that asset exists in TypedDataStorage")
- Partial cleanup on failure (delete incomplete files)

**Example**:
```swift
public enum OMFExportError: Error, LocalizedError {
    case missingAudioAsset(clipId: UUID, assetId: UUID)
    case audioConversionFailed(assetId: UUID, reason: String)
    case omfGenerationFailed(reason: String)
    case insufficientDiskSpace(requiredBytes: Int64)

    public var errorDescription: String? {
        switch self {
        case .missingAudioAsset(let clipId, let assetId):
            return "Clip \(clipId) references missing audio asset \(assetId)"
        case .audioConversionFailed(let assetId, let reason):
            return "Failed to convert audio \(assetId): \(reason)"
        case .omfGenerationFailed(let reason):
            return "OMF generation failed: \(reason)"
        case .insufficientDiskSpace(let required):
            return "Insufficient disk space: need \(required) bytes"
        }
    }
}
```

### NFR-4: API Design

**Description**: OMF export API shall follow SwiftSecuencia's existing patterns.

**API Style**:
- Struct-based exporter (like `FCPXMLExporter`)
- Async/throws methods
- Configuration via initializer
- Progress reporting via async stream or callback

**Proposed API**:
```swift
public struct OMFExporter {
    /// OMF export options
    public struct Options {
        public var sampleRate: AudioSampleRate = .rate48kHz
        public var bitDepth: AudioBitDepth = .depth24bit
        public var audioFormat: AudioFileFormat = .aiff
        public var includeMultiLane: Bool = true

        public init() {}
    }

    /// Creates an OMF exporter with options.
    public init(options: Options = Options())

    /// Exports a timeline to OMF format.
    ///
    /// - Parameters:
    ///   - timeline: The timeline to export (audio clips only).
    ///   - modelContext: SwiftData context for fetching assets.
    ///   - outputURL: Directory URL for OMF and audio files.
    ///   - exportChapters: If true and timeline has chapters, export multiple OMFs.
    /// - Returns: Array of exported OMF file URLs.
    /// - Throws: OMFExportError if export fails.
    public mutating func export(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        outputURL: URL,
        exportChapters: Bool = true
    ) async throws -> [URL]
}

/// Audio sample rates supported by OMF export
public enum AudioSampleRate: Int {
    case rate44_1kHz = 44100
    case rate48kHz = 48000
    case rate96kHz = 96000
}

/// Audio bit depths supported by OMF export
public enum AudioBitDepth: Int {
    case depth16bit = 16
    case depth24bit = 24
}

/// Audio file formats for OMF media
public enum AudioFileFormat {
    case aiff
    case wav
}
```

### NFR-5: Testing

**Description**: OMF export shall have comprehensive test coverage (80%+).

**Test Requirements**:
- Unit tests for audio conversion
- Unit tests for OMF structure generation
- Integration tests for complete export
- Manual Logic Pro import tests
- Multi-timeline export tests

**Test Scope**:
- Audio-only filtering
- Multi-lane organization
- Chapter-based splitting
- Clip timing accuracy
- Error handling

### NFR-6: Documentation

**Description**: OMF export API shall be fully documented with DocC.

**Documentation Requirements**:
- API documentation for all public types/methods
- Usage examples (single timeline, multi-timeline)
- Limitations and known issues
- Logic Pro import workflow guide

## Edge Cases

### EC-1: Timeline with No Audio Clips

**Scenario**: Timeline contains only video/image clips (no audio)
**Expected**: Throw error `OMFExportError.noAudioClips`
**Rationale**: Empty OMF is not useful

### EC-2: Audio Asset Not Found

**Scenario**: Clip references audio asset that doesn't exist in TypedDataStorage
**Expected**: Throw error `OMFExportError.missingAudioAsset(clipId, assetId)`
**Rationale**: Cannot export incomplete timeline

### EC-3: Unsupported Audio Format

**Scenario**: Audio asset is in format that cannot be converted (e.g., DRM-protected)
**Expected**: Throw error `OMFExportError.audioConversionFailed(assetId, reason)`
**Rationale**: Conversion failure should be reported clearly

### EC-4: Chapter with No Audio Clips

**Scenario**: Multi-timeline export, one chapter has no audio clips (only video)
**Expected**: Skip that chapter OMF, log warning
**Rationale**: Don't create empty OMFs

### EC-5: Overlapping Clips on Same Lane

**Scenario**: Two audio clips overlap on lane 0
**Expected**: Export both clips, let Logic handle overlap (crossfade or cut)
**Rationale**: OMF supports overlapping clips (Logic handles mixing)

### EC-6: Very Long Timeline

**Scenario**: Timeline is 10 hours with 1000+ audio clips
**Expected**: Export successfully, report progress, may take several minutes
**Rationale**: Performance should scale reasonably

## Implementation Phases

### Phase 1: AAF SDK Integration
- Build AAF SDK for macOS
- Create C wrapper for OMF write API
- Create Swift bridging module
- Test basic OMF generation

### Phase 2: Single Timeline Export
- Implement `OMFExporter` struct
- Audio clip filtering
- Track organization (lane → track mapping)
- Audio file conversion (48kHz / 24-bit AIFF)
- Basic OMF generation

### Phase 3: Multi-Timeline Export
- Integrate with chapter marker system
- Export multiple OMFs
- Shared Audio Files/ folder
- Clip re-timing for chapters

### Phase 4: Testing & Validation
- Unit tests (audio conversion, filtering, etc.)
- Integration tests (complete export)
- Manual Logic Pro import tests
- Performance testing

### Phase 5: Documentation
- DocC API documentation
- Usage examples
- Logic Pro import guide
- Update README.md

## Testing Strategy

### Unit Tests

1. **Audio Clip Filtering**
   - Test that only audio/* MIME types are included
   - Test that video/image clips are excluded

2. **Track Organization**
   - Test lane-to-track mapping
   - Test multi-lane sorting

3. **Audio Conversion**
   - Test conversion to 48kHz / 24-bit
   - Test AIFF file generation
   - Test error handling (corrupt audio)

4. **File Management**
   - Test audio file naming (audio_001.aiff, etc.)
   - Test de-duplication (same asset → one file)

### Integration Tests

1. **Single Timeline Export**
   - Timeline with 5 audio clips, various lanes
   - Validate OMF structure
   - Validate Audio Files/ contents
   - Import into Logic Pro (manual test)

2. **Multi-Timeline Export**
   - Timeline with 3 chapters
   - Validate 3 OMF files created
   - Validate shared Audio Files/ folder
   - Import each OMF into Logic (manual test)

3. **Edge Cases**
   - Empty timeline (no audio)
   - Missing assets
   - Unsupported formats
   - Very long timeline

### Logic Pro Import Tests (Manual)

1. Export sample timeline to OMF
2. Open Logic Pro
3. **File > Import > OMF**
4. Select exported .omf file
5. Verify:
   - All audio tracks imported
   - Clip positions correct
   - Audio plays correctly
   - No missing media warnings

## Success Criteria

- [ ] OMF export generates valid OMF 2.0 files
- [ ] Logic Pro can import OMF without errors
- [ ] Audio clips play at correct positions in Logic
- [ ] Multi-lane timelines import as multi-track
- [ ] Chapter-based export creates multiple OMFs
- [ ] 80%+ code coverage on OMF export code
- [ ] All unit and integration tests pass
- [ ] Documentation complete

## Known Limitations

1. **No Automation**: OMF doesn't preserve volume automation or pan (Logic Pro limitation)
2. **No Track Names**: OMF has limited metadata (tracks named "Track 1", "Track 2", etc.)
3. **No Effects**: Audio effects/plugins are not preserved
4. **macOS Only**: AAF SDK integration targets macOS 26+ (matches SwiftSecuencia platform)
5. **Audio Only**: Video clips are excluded from export

## Future Enhancements

1. **OMF Type 1 Support**: Embedded audio in OMF file (single file export)
2. **AAF Export**: Add AAF support for Pro Tools compatibility
3. **Volume Automation**: Explore AAF for automation support
4. **Video Reference**: Include video references for picture lock workflows
5. **Marker Export**: Export timeline markers to OMF (if supported)

## References

### OMF/AAF Resources
- [Advanced Authoring Format (AAF) - Wikipedia](https://en.wikipedia.org/wiki/Advanced_Authoring_Format)
- [AAF SDK Developer Support](https://aaf.sourceforge.net/)
- [AAF SDK on GitHub](https://github.com/dneg/aaf)
- [AAF Developers' Guide](https://aafassociation.org/specs/aafguide/aafguide.html)
- [AAF Object Specification](https://aafassociation.org/specs/object_spec.html)

### Logic Pro Compatibility
- [OMF, AAF or XML with Logic Pro X?](https://www.jespersoderstrom.com/logic-pro-audio-post/omf-aaf-xml/)
- [AAF files in Logic Pro - Apple Support](https://support.apple.com/guide/logicpro/aaf-files-lgcp6f2262ba/10.7/mac/11.0)
- [Logic Pro AAF Import Issues - Gearspace](https://gearspace.com/board/post-production-forum/876509-problems-importing-aaf-into-logic-x-avid-mc.html)

### Technical Resources
- [OMF vs AAF Comparison](https://www.production-expert.com/production-expert-1/aaf-and-omfs-post-audio-expert-panel-on-the-good-the-bad-and-the-ugly)
- [What is AAF in Audio Production?](https://www.travsonic.com/what-is-aaf-in-audio-production/)
- [LibAAF - C Library for AAF/OMF](https://github.com/agfline/LibAAF)

## Related Documentation

- REQUIREMENTS-MULTI-TIMELINE-EXPORT.md (Feature #1)
- FEATURE-1-SUMMARY.md
- Timeline.swift
- TimelineClip.swift
- TypedDataStorage (from SwiftCompartido)
