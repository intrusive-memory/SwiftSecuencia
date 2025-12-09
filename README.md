# SwiftSecuencia

A Swift library for working with sequenced media - timelines, audio, and exports for professional video and audio applications.

## Overview

SwiftSecuencia provides a type-safe, Swift-native API for creating and exporting media timelines. Build timelines programmatically with clips, transitions, effects, and export to multiple formats:

- **FCPXML** - Import into Final Cut Pro X (macOS only)
- **M4A Audio** - High-quality stereo mixdowns (macOS + iOS)
- **Logic Pro** _(coming soon)_ - Import into Logic Pro

Create timelines once and export to multiple professional tools.

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
    .package(url: "https://github.com/intrusive-memory/SwiftSecuencia.git", from: "1.0.3")
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

SwiftSecuencia provides **two audio exporters** with different performance trade-offs:

#### BackgroundAudioExporter (UI Responsiveness)

Exports audio on a background thread, keeping the UI responsive:

```swift
let exporter = BackgroundAudioExporter(modelContainer: container)
let outputURL = try await exporter.exportAudio(
    timelineID: timelineID,
    to: destinationURL,
    progress: progress
)
```

**When to use:**
- Large timelines (100+ clips)
- User needs to interact with UI during export
- Background processing is preferred

**Characteristics:**
- Runs on background thread with `.high` priority
- UI remains fully responsive
- Uses `@ModelActor` for safe SwiftData concurrency
- Parallel file I/O for optimal performance
- ~10-15% slower than foreground due to actor overhead

#### ForegroundAudioExporter (Maximum Speed)

Exports audio on the main thread for maximum performance:

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

**When to use:**
- Small to medium timelines (< 100 clips)
- Export speed is critical
- UI blocking is acceptable
- User is actively waiting for export

**Characteristics:**
- Runs on main thread (blocks UI)
- No actor context switching overhead
- Direct ModelContext access
- Parallel file I/O with high priority tasks
- Fastest possible export speed

**Two-Phase Export Architecture:**
1. **Main Thread (30%)** - Build timeline metadata (no audio data loaded)
2. **Export Phase (70%)** - Load audio, write to disk, export to M4A
   - Background: Uses background thread with `@ModelActor`
   - Foreground: Uses main thread with direct access

For complete concurrency details, see [Docs/CONCURRENCY-ARCHITECTURE.md](Docs/CONCURRENCY-ARCHITECTURE.md).

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

