# Timeline Audio Export Requirements

## Overview

Export a `Timeline` to a stereo M4A audio file using AVMutableComposition and AVAssetExportSession.

## Scope

- **In Scope**: Audio clips from timeline, stereo mixdown, AAC compression
- **Out of Scope**:
  - Video clips (ignored during export)
  - Multi-track/uncompressed export (use FCPXML export for that)

## Requirements

### M4A Stereo Mixdown

1. **Track Mixing**
   - All timeline lanes are mixed down to a single stereo track
   - Overlapping clips are automatically summed (mixed together)
   - AVMutableComposition handles mixing automatically

2. **Compression**
   - AAC encoding at 256 kbps (high quality)
   - Uses AVAssetExportPresetAppleM4A
   - Optimized file size for sharing/playback

3. **Gap Handling**
   - Preserve timeline timing exactly
   - Gaps between clips result in silence in the output

4. **Clip Handling**
   - Respects `offset`, `duration`, and `sourceStart` properties
   - Multiple clips at same time = automatic mixing
   - No volume adjustments or effects applied
   - Total export duration = `timeline.duration`
   - Example:
     ```
     Timeline: [Clip 1: 0s-3s] [GAP] [Clip 2: 5s-10s]
     Export:   [3s audio] [2s silence] [5s audio] = 10s total
     ```

### Audio Quality

- **Format**: M4A (MPEG-4 Audio)
- **Codec**: AAC (Advanced Audio Coding)
- **Bitrate**: 256 kbps (high quality)
- **Sample Rate**: Inherits from source audio (typically 44.1kHz or 48kHz)
- **Channels**: Stereo (2-channel)
- **Processing**: Raw audio without adjustments
  - Ignore `TimelineClip.volumeDb`
  - Ignore `TimelineClip.isMuted`
  - No normalization or effects

### Format Support

```swift
public enum AudioExportFormat: String, Sendable {
    case m4a  // M4A (stereo mixdown, AAC compressed, 256 kbps)
}
```

- **M4A Only**: Compressed AAC, stereo mixdown, optimized for sharing/playback
- **For Multi-Track**: Use `FCPXMLBundleExporter` to export to Final Cut Pro

### Progress Reporting

- Use Foundation's `Progress` API (consistent with `FCPXMLBundleExporter`)
- Report progress phases:
  1. Analyzing timeline (5%)
  2. Preparing audio tracks (10%)
  3. Rendering audio per clip (70%)
  4. Writing output file (15%)

### API Design

```swift
/// Exports Timeline objects to multi-track audio files.
public struct TimelineAudioExporter {

    /// Creates an audio exporter.
    public init()

    /// Exports a timeline to a multi-track audio file.
    ///
    /// - Parameters:
    ///   - timeline: The timeline to export.
    ///   - modelContext: The model context to fetch assets from.
    ///   - outputURL: The destination file URL.
    ///   - format: Audio format (default: .caf).
    ///   - progress: Optional Progress object for tracking.
    /// - Returns: URL of the created audio file.
    /// - Throws: AudioExportError if export fails.
    @MainActor
    public func exportAudio(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        to outputURL: URL,
        format: AudioExportFormat = .caf,
        progress: Progress? = nil
    ) async throws -> URL
}
```

### Error Handling

```swift
public enum AudioExportError: Error, LocalizedError {
    case emptyTimeline
    case missingAsset(assetId: UUID)
    case invalidAudioData(assetId: UUID)
    case audioWriterFailed(reason: String)
    case cancelled

    public var errorDescription: String? { ... }
}
```

## Implementation Notes

### Lane Normalization Algorithm

```swift
// Example: Timeline has clips on lanes [-2, 0, 0, 3]
// Unique lanes: [-2, 0, 3]
// Sorted: [-2, 0, 3]
// Mapping: [-2 → Track 0, 0 → Track 1, 3 → Track 2]
```

### Overlap Detection Algorithm

```swift
// For each lane:
//   Sort clips by offset
//   For each clip:
//     If clip.offset < previousClip.endTime:
//       Assign to next available track
//     Else:
//       Keep on current track
```

### AVFoundation Implementation

- Use `AVAssetWriter` with `AVAssetWriterInput` for each track
- Use `AVAudioPCMBuffer` for audio samples
- Format settings:
  ```swift
  let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 44100.0,
      AVNumberOfChannelsKey: 1,  // Mono per track
      AVLinearPCMBitDepthKey: 24,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false
  ]
  ```

### Silence Generation

```swift
// Create silent PCM buffer of specified duration
func generateSilence(duration: TimeInterval, sampleRate: Double) -> AVAudioPCMBuffer {
    let frameCount = AVAudioFrameCount(duration * sampleRate)
    let format = AVAudioFormat(
        commonFormat: .pcmFormatInt32,
        sampleRate: sampleRate,
        channels: 1,
        interleaved: false
    )!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount
    // Buffer is already zeroed (silent)
    return buffer
}
```

## Testing Requirements

### Unit Tests

1. Lane normalization mapping
2. Overlap detection and track assignment
3. Gap/silence insertion
4. Progress reporting

### Integration Tests

1. Export single-lane timeline
2. Export multi-lane timeline
3. Export timeline with overlaps (auto-track assignment)
4. Export timeline with gaps (silence insertion)
5. Export to CAF format
6. Export to WAV format
7. Verify output audio properties (24-bit, 44.1kHz)
8. Verify track count matches lane count
9. Cancellation via Progress API

## File Structure

```
Sources/SwiftSecuencia/Export/
├── FCPXMLBundleExporter.swift
├── FCPXMLExporter.swift
└── TimelineAudioExporter.swift  ← New file

Tests/SwiftSecuenciaTests/
└── TimelineAudioExporterTests.swift  ← New file
```

## Dependencies

- **AVFoundation**: Audio file writing (`AVAssetWriter`, `AVAudioPCMBuffer`)
- **Foundation**: Progress reporting
- **SwiftData**: Asset fetching
- **SwiftCompartido**: `TypedDataStorage` for audio binary data

## Future Enhancements (Out of Scope)

- Volume adjustment support (`volumeDb` property)
- Mute support (`isMuted` property)
- Audio effects/filters
- Sample rate conversion
- Compressed formats (MP3, AAC)
- Stereo/5.1 mixing (currently mono tracks only)
