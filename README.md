# SwiftSecuencia

A Swift library for generating and exporting Final Cut Pro X timelines via FCPXML.

## Overview

SwiftSecuencia provides a type-safe, Swift-native API for creating FCPXML documents that can be imported into Final Cut Pro X. Build timelines programmatically with clips, transitions, effects, and more.

## Requirements

- Swift 6.2+
- macOS 26.0+ / iOS 26.0+
- [SwiftCompartido](https://github.com/intrusive-memory/SwiftCompartido) (dependency)

## Installation

### Swift Package Manager

Add SwiftSecuencia to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftSecuencia.git", from: "0.1.0")
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
// Add a marker
clip.markers.append(
    Marker(
        start: Timecode(seconds: 5),
        value: "Review this section",
        note: "Color correction needed"
    )
)

// Add keywords
clip.keywords.append(
    Keyword(
        start: .zero,
        duration: Timecode(seconds: 30),
        value: "Interview"
    )
)
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
