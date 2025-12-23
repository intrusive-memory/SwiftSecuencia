# SwiftSecuencia

A Swift library for professional media timeline generation and export.

## Core Functions

SwiftSecuencia provides **three distinct, well-defined functions**:

### 1. 🎬 Generate a Timeline
Create type-safe `Timeline` and `TimelineClip` SwiftData models with precise timing, multi-lane support, and asset management.

```swift
let timeline = Timeline(name: "Episode 1")
timeline.appendClip(audioClip1)
timeline.rippleInsertClip(audioClip2, at: 30.0)
// Query clips by lane, time range, or asset
```

### 2. 🎥 Export to Final Cut Pro (macOS only)
Generate FCPXML bundles (`.fcpxmld`) with embedded media that import directly into Final Cut Pro.

```swift
let exporter = FCPXMLBundleExporter(includeMedia: true)
try await exporter.exportBundle(timeline: timeline, ...)
// Creates: Timeline.fcpxmld with Info.fcpxml + Media/
```

### 3. 🎵 Export to M4A Audio (macOS + iOS)
Convert timelines to high-quality M4A audio with **two performance modes** and **optional timing data** for karaoke-style text sync:

- **Background Export** - UI stays responsive, ideal for large timelines
- **Foreground Export** - Maximum speed (15-20% faster), blocks UI
- **Timing Data** - WebVTT/JSON for synchronized text display (optional)

```swift
// Background: UI responsive
let exporter = BackgroundAudioExporter(modelContainer: container)
try await exporter.exportAudio(timelineID: id, to: url)

// Foreground: Maximum speed + timing data
let exporter = ForegroundAudioExporter()
try await exporter.exportAudio(
    timeline: timeline,
    timingDataFormat: .webvtt  // Optional: .json, .both, .none
)
```

---

## Quick Reference

| Function | Platform | Performance | Use Case |
|----------|----------|-------------|----------|
| **Timeline Generation** | macOS + iOS | Instant | Create and manage media sequences |
| **FCPXML Export** | macOS only | ~100ms + media copy | Import into Final Cut Pro |
| **M4A Export (Background)** | macOS + iOS | ~12s for 50 clips | Large timelines, UI responsiveness |
| **M4A Export (Foreground)** | macOS + iOS | ~10s for 50 clips | Maximum speed, UI blocking OK |

## Overview

SwiftSecuencia provides a type-safe, Swift-native API for creating and exporting media timelines. Build timelines programmatically and export to professional formats for Final Cut Pro, audio production, and more.

For a detailed evaluation of effectiveness and efficiency, see [Docs/EFFECTIVENESS-EVALUATION.md](Docs/EFFECTIVENESS-EVALUATION.md).

## Requirements

- Swift 6.2+
- **macOS 26.0+** (full support: FCPXML + audio export)
- **iOS 26.0+** (partial support: audio export only)
- [SwiftCompartido](https://github.com/intrusive-memory/SwiftCompartido) (dependency)

### Platform Support

| Feature | macOS 26+ | iOS 26+ |
|---------|-----------|---------|
| FCPXML Export (`FCPXMLExporter`, `FCPXMLBundleExporter`) | ✅ | ❌ |
| Audio Export (`TimelineAudioExporter`) | ✅ | ✅ |
| Timeline/TimelineClip Models | ✅ | ✅ |
| App Intents (Shortcuts) | ✅ | ✅ |

**Notes:**
- FCPXML export requires macOS because it uses the `XMLDocument` API (not available on iOS) and Final Cut Pro for iPad does not support FCPXML import/export.
- iOS 26+ is fully tested in CI for audio export and Timeline/TimelineClip models.

## Installation

### Swift Package Manager

Add SwiftSecuencia to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftSecuencia.git", from: "1.0.5")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwiftSecuencia"]
)
```

## Quick Start

```swift
import SwiftSecuencia

// Create a new FCPXML document
var document = FCPXMLDocument()

// Define a video format (1080p @ 23.98fps)
let format = Format(
    id: "r1",
    name: "FFVideoFormat1080p2398",
    frameDuration: Timecode(value: 1001, timescale: 24000),
    width: 1920,
    height: 1080
)
document.resources.formats.append(format)

// Add a media asset
let asset = Asset(
    id: "r2",
    name: "Interview_A",
    src: URL(fileURLWithPath: "/Volumes/Media/Interview_A.mov"),
    duration: Timecode(seconds: 120),
    hasVideo: true,
    hasAudio: true,
    formatRef: "r1",
    audioChannels: 2,
    audioRate: 48000
)
document.resources.assets.append(asset)

// Create a sequence with clips
let sequence = Sequence(formatRef: "r1", audioLayout: .stereo)

// Add clips to the timeline
sequence.spine.append(
    AssetClip(
        ref: "r2",
        offset: Timecode.zero,
        start: Timecode(seconds: 10),  // Start 10 seconds into source
        duration: Timecode(seconds: 30)
    )
)

// Add a gap
sequence.spine.append(
    Gap(duration: Timecode(seconds: 2))
)

// Add another clip
sequence.spine.append(
    AssetClip(
        ref: "r2",
        start: Timecode(seconds: 60),
        duration: Timecode(seconds: 30)
    )
)

// Wrap in project and event
let project = Project(name: "Assembly Edit", sequence: sequence)
let event = Event(name: "Scene 1", items: [.project(project)])
document.library = Library(
    location: URL(fileURLWithPath: "/Users/editor/Movies/MyLibrary.fcpbundle"),
    events: [event]
)

// Export to FCPXML string
let xmlString = try document.fcpxmlString()

// Or write directly to file
try document.write(to: URL(fileURLWithPath: "/path/to/output.fcpxml"))
```

## Features

### Supported FCPXML Elements

- **Resources**: Formats, Assets, Effects, Media (compound clips, multicam)
- **Organization**: Libraries, Events, Projects, Collections
- **Timeline**: Sequences, Spines, Clips, Gaps, Transitions
- **Clip Types**: Asset clips, Reference clips, Sync clips, Multicam clips, Auditions
- **Media**: Video, Audio, Titles
- **Adjustments**: Transform, Crop, Volume, Blend, Effects
- **Timing**: Rate conforming, Time remapping, Keyframe animation
- **Markers**: Standard markers, Chapter markers, Keywords, Ratings
- **Metadata**: Custom metadata fields

### FCPXML Versions

SwiftSecuencia supports FCPXML versions 1.8 through 1.11 (default). You can specify the version when exporting:

```swift
let xml = try document.fcpxmlString(version: "1.10")
```

### Time Representation

The library uses rational time values for frame-accurate timing:

```swift
// Common frame durations
let ntsc2398 = Timecode(value: 1001, timescale: 24000)  // 23.98 fps
let film24 = Timecode(value: 100, timescale: 2400)       // 24 fps
let pal25 = Timecode(value: 100, timescale: 2500)        // 25 fps
let ntsc2997 = Timecode(value: 1001, timescale: 30000)   // 29.97 fps

// Duration in seconds
let fiveSeconds = Timecode(seconds: 5)

// From timecode string (requires format context)
let tc = Timecode(timecodeString: "01:00:00:00", frameRate: .fps2398)
```

## Architecture

SwiftSecuencia models the FCPXML document hierarchy:

```
FCPXMLDocument
├── Resources
│   ├── Format[]
│   ├── Asset[]
│   ├── Effect[]
│   └── Media[]
└── Library
    └── Event[]
        ├── Project
        │   └── Sequence
        │       └── Spine
        │           ├── AssetClip
        │           ├── Gap
        │           ├── Transition
        │           └── ...
        ├── Clip[]
        └── Collection[]
```

### Audio Export: Background vs Foreground

SwiftSecuencia provides **two audio exporters** with different performance trade-offs. Both use parallel file I/O for optimal performance.

#### When to Use Each Exporter

| Scenario | Background | Foreground |
|----------|-----------|-----------|
| **Large timelines (100+ clips)** | ✅ Recommended | ❌ May freeze UI too long |
| **Small/medium timelines (< 100)** | ✅ Works fine | ✅ Fastest |
| **User needs UI during export** | ✅ Required | ❌ UI blocked |
| **Export speed critical** | ⚠️ ~10-15% slower | ✅ Maximum speed |
| **Background processing** | ✅ Ideal | ❌ Not background |
| **User actively waiting** | ✅ Works | ✅ Best |

#### BackgroundAudioExporter (UI Responsiveness)

**Best for:** Large timelines, UI responsiveness required

```swift
let exporter = BackgroundAudioExporter(modelContainer: container)
let outputURL = try await exporter.exportAudio(
    timelineID: timelineID,
    to: destinationURL,
    progress: progress
)
```

**Key Features:**
- ✅ UI remains fully responsive
- ✅ Runs on background thread with `.high` priority
- ✅ Safe SwiftData concurrency with `@ModelActor`
- ✅ Parallel file I/O (3-10x faster than serial)
- ✅ Memory-efficient (one asset at a time)
- ⚠️ ~10-15% slower than foreground due to actor overhead

**Performance:** ~12 seconds for 50 clips, 2.5 minutes duration

#### ForegroundAudioExporter (Maximum Speed)

**Best for:** Small/medium timelines, maximum speed, UI blocking acceptable

```swift
@MainActor
let exporter = ForegroundAudioExporter()
let outputURL = try await exporter.exportAudio(
    timeline: timeline,
    modelContext: modelContext,
    to: destinationURL,
    progress: progress
)
```

**Key Features:**
- ✅ Fastest possible export (~15-20% faster than background)
- ✅ No actor context switching overhead
- ✅ Direct ModelContext access
- ✅ Parallel file I/O with `.high` priority
- ⚠️ Blocks UI during export
- ⚠️ Higher memory usage (all audio loaded at once)

**Performance:** ~10 seconds for 50 clips, 2.5 minutes duration

#### Timing Data Export (WebVTT & JSON)

Both audio exporters support **optional timing data generation** for karaoke-style text synchronization in web players:

```swift
@MainActor
let exporter = ForegroundAudioExporter()
let outputURL = try await exporter.exportAudioDirect(
    audioElements: audioFiles,
    modelContext: modelContext,
    to: destinationURL,
    timingDataFormat: .webvtt  // Or .json, .both, .none (default)
)
// Creates: screenplay.m4a + screenplay.vtt
```

**Supported Formats:**
- **`.webvtt`** - W3C-compliant WebVTT for browser TextTrack API (±10ms precision)
- **`.json`** - Structured JSON timing data for custom parsers
- **`.both`** - Generate both WebVTT and JSON files
- **`.none`** - No timing data (default)

**File Naming:**
- WebVTT: `screenplay.vtt` (replaces .m4a extension)
- JSON: `screenplay.m4a.timing.json` (appends .timing.json)

**Use Case:** Enable synchronized "follow along" text display in web players, perfect for screenplay/podcast narration where text highlights in sync with audio playback.

**WebVTT Example Output:**
```vtt
WEBVTT

00:00:00.000 --> 00:00:02.500
<v ALICE>Hello, world!</v>

00:00:02.500 --> 00:00:05.000
<v BOB>How are you today?</v>
```

**JSON Example Output:**
```json
{
  "audioFile": "screenplay.m4a",
  "duration": 5.0,
  "segments": [
    {
      "id": "uuid-1",
      "startTime": 0.0,
      "endTime": 2.5,
      "text": "Hello, world!",
      "metadata": {
        "character": "ALICE",
        "lane": 0
      }
    }
  ],
  "version": "1.0"
}
```

#### Technical Details

**Both exporters use a two-phase architecture:**

1. **Phase 1: Main Thread (30%)** - Build timeline metadata (fast, no audio data)
2. **Phase 2: Export (70%)** - Load audio, write files in parallel, export to M4A
   - **Background:** Uses background thread with `@ModelActor`
   - **Foreground:** Uses main thread with direct access

**Performance Improvements (v1.0.6):**
- Parallel file I/O: **3-4x faster** than serial writes
- Batch SwiftData fetches: Eliminates N+1 queries
- Non-blocking progress updates: Zero wait time
- `.high` priority tasks: Maximum CPU utilization

For complete concurrency details and architecture diagrams, see [Docs/CONCURRENCY-ARCHITECTURE.md](Docs/CONCURRENCY-ARCHITECTURE.md).

## Examples

### Adding Transitions

```swift
// Add a cross dissolve between clips
let dissolve = Transition(
    name: "Cross Dissolve",
    duration: Timecode(frames: 24, frameRate: .fps24),
    effectRef: "r3"  // Reference to a dissolve effect
)
sequence.spine.insert(dissolve, at: 1)
```

### Connected Clips (B-Roll)

```swift
// Attach B-roll above the primary storyline
let bRoll = AssetClip(
    ref: "r4",
    lane: 1,  // Lane 1 = above primary storyline
    offset: Timecode(seconds: 5),
    duration: Timecode(seconds: 10)
)
sequence.spine.connectedClips.append(bRoll)
```

### Audio Adjustments

```swift
var clip = AssetClip(ref: "r2", duration: Timecode(seconds: 30))
clip.adjustVolume = AdjustVolume(amount: "-6dB")
clip.adjustVolume?.keyframes = [
    Keyframe(time: .zero, value: "-12dB"),
    Keyframe(time: Timecode(seconds: 2), value: "-6dB", interpolation: .ease)
]
```

### Markers and Keywords

```swift
// Add standard markers to clips
clip.markers.append(
    Marker(
        start: Timecode(seconds: 5),
        value: "Review this section",
        note: "Color correction needed"
    )
)

// Add chapter markers to timeline
timeline.chapterMarkers.append(
    ChapterMarker(
        start: Timecode.zero,
        value: "Introduction",
        posterOffset: Timecode(seconds: 2)
    )
)

// Add keywords for organization
clip.keywords.append(
    Keyword(
        start: .zero,
        duration: Timecode(seconds: 30),
        value: "Interview"
    )
)

// Mark favorite clips
clip.ratings.append(
    Rating(
        start: .zero,
        duration: Timecode(seconds: 30),
        value: .favorite,
        note: "Best take"
    )
)

// Add custom metadata
var metadata = Metadata()
metadata.setReel("A001")
metadata.setScene("1")
metadata.setTake("3")
metadata.setDescription("Interview with subject")
clip.metadata = metadata
```

## App Intents & Shortcuts Integration

SwiftSecuencia provides App Intents for integration with Apple Shortcuts, enabling automated workflows from screenplay to Final Cut Pro.

### Generate FCPXML Bundle Intent

Create a complete Final Cut Pro bundle (.fcpxmld) from screenplay elements with audio:

**Example Shortcuts Workflow:**

1. Parse Screenplay File (from SwiftCompartido) → ScreenplayElementsReference
2. Generate FCPXML Bundle → .fcpxmld bundle
3. Save to Files app
4. Import into Final Cut Pro

**Parameters:**
- `elementsReference`: Screenplay elements from Parse Screenplay File intent
- `outputDirectory`: Where to save the .fcpxmld bundle
- `projectName`: Optional FCP project name (defaults to screenplay title)
- `defaultClipDuration`: Duration for clips without audio (default: 3.0 seconds)
- `frameRate`: Timeline frame rate (default: 23.98 fps)

**Requirements:**
- Screenplay elements must have audio files generated via voice generation workflow
- Audio files stored in TypedDataStorage with matching element text in prompts

**Swift Usage:**

```swift
import SwiftSecuencia
import AppIntents

let intent = GenerateFCPXMLBundleIntent(
    elementsReference: screenplayElements,
    outputDirectory: URL(fileURLWithPath: "/path/to/output"),
    projectName: "My Screenplay",
    defaultClipDuration: 3.0,
    frameRate: 23.98
)

let result = try await intent.perform()
let bundleFile = result.value  // IntentFile pointing to .fcpxmld bundle
```

**Output Structure:**

```
MyScreenplay.fcpxmld/
├── Info.plist           # Bundle metadata
├── Info.fcpxml          # Timeline with audio clips
└── Media/
    ├── [uuid1].wav      # Audio for dialogue 1
    ├── [uuid2].wav      # Audio for dialogue 2
    └── ...
```

## Documentation

- [FCPXML Reference](Docs/FCPXML-Reference.md) - Comprehensive FCPXML format documentation
- [Element Reference](Docs/FCPXML-Elements.md) - Quick reference for all FCPXML elements

## Related Projects

- [DAWFileKit](https://github.com/orchetect/DAWFileKit) - Swift library for DAW file formats including FCPXML
- [Pipeline](https://github.com/reuelk/pipeline) - Original FCPXML Swift framework
- [FCP Cafe](https://fcp.cafe/developers/fcpxml/) - Community FCPXML resources

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## Credits

### Pipeline

SwiftSecuencia includes code from the [Pipeline](https://github.com/reuelk/pipeline) project by Reuel Kim, licensed under the MIT License. Pipeline provides FCPXML document manipulation capabilities that have been integrated and adapted for Swift 6.2 and macOS 26.0+.

See [PIPELINE-LICENSE.md](PIPELINE-LICENSE.md) for the full Pipeline license.

### iOS Audio Export Example

```swift
import SwiftSecuencia
import SwiftData

// Create a timeline with audio clips
let timeline = Timeline(name: "Podcast Episode 1")

// Add audio clips (from SwiftCompartido TypedDataStorage)
let clip1 = TimelineClip(
    assetStorageId: audioAsset1.id,
    offset: Timecode(seconds: 0),
    duration: Timecode(seconds: 30)
)
let clip2 = TimelineClip(
    assetStorageId: audioAsset2.id,
    offset: Timecode(seconds: 30),
    duration: Timecode(seconds: 45)
)

timeline.appendClip(clip1)
timeline.appendClip(clip2)

// Save timeline to SwiftData
modelContext.insert(timeline)
try modelContext.save()

// Option 1: Background export (UI stays responsive)
let backgroundExporter = BackgroundAudioExporter(modelContainer: modelContext.container)
let outputURL = try await backgroundExporter.exportAudio(
    timelineID: timeline.persistentModelID,
    to: FileManager.default.temporaryDirectory.appendingPathComponent("podcast.m4a"),
    progress: nil
)

// Option 2: Foreground export (maximum speed, blocks UI)
@MainActor
func exportFast() async throws -> URL {
    let foregroundExporter = ForegroundAudioExporter()
    return try await foregroundExporter.exportAudio(
        timeline: timeline,
        modelContext: modelContext,
        to: FileManager.default.temporaryDirectory.appendingPathComponent("podcast.m4a"),
        progress: nil
    )
}

// Result: High-quality M4A file with AAC compression at 256 kbps
// All timeline lanes are automatically mixed to stereo
```

