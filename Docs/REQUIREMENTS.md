# SwiftSecuencia Requirements

## Overview

SwiftSecuencia is a Swift library for generating Final Cut Pro X timelines from TypedDataStorage media records and exporting them as `.fcpbundle` packages.

## Scope

### In Scope (MVP)

- Generate FCPXML documents programmatically
- Create timelines from SwiftCompartido `TypedDataStorage` records
- Export self-contained `.fcpbundle` packages with embedded media
- Support audio, video, and image assets
- Configurable video format (resolution, frame rate)

### Out of Scope (Future)

- Parsing/importing existing FCPXML files
- Round-trip editing of FCP projects
- Effects, transitions, color grading
- Multicam, compound clips
- Titles and text overlays

---

## Functional Requirements

### FR-1: Timeline Management

#### FR-1.1: Create Timeline
- **Description**: Create a new empty timeline with configurable format settings
- **Input**: Format configuration (resolution, frame rate, audio layout)
- **Output**: Timeline object with start time of 0

#### FR-1.2: Append Clip to Timeline
- **Description**: Add a TypedDataStorage record as an asset-clip at the end of timeline
- **Input**: TypedDataStorage record
- **Output**: Updated timeline with new clip appended; returns clip placement info
- **Behavior**:
  - Clip is placed sequentially after all existing clips on primary storyline (lane 0)
  - Clip duration is derived from TypedDataStorage.durationSeconds
  - Timeline end time extends to accommodate new clip
  - Returns the clip's position on timeline (offset, duration, lane)

#### FR-1.3: Insert Clip at Specific Timecode
- **Description**: Add a TypedDataStorage record at a specific position on the timeline
- **Input**: TypedDataStorage record, target offset (Timecode), optional lane
- **Output**: Updated timeline with clip at specified position; returns clip placement info
- **Behavior**:
  - Clip is placed at the exact timecode specified
  - If lane is not specified, uses next available lane (for overlapping clips)
  - Clips can overlap temporally (FCP handles audio mixing)
  - Does NOT shift existing clips - overlapping is allowed and expected
  - Returns the clip's position on timeline (offset, duration, lane)

#### FR-1.4: Query Timeline State
- **Description**: Get current timeline boundaries and statistics
- **Output**: Start time, end time, total duration, clip count, lane count

#### FR-1.5: Query Clip Information
- **Description**: Retrieve timing information for an existing clip on the timeline
- **Input**: Clip identifier (clipID or TypedDataStorage.id)
- **Output**: ClipPlacement with offset, duration, lane, start/end times
- **Behavior**:
  - Returns nil if clip not found
  - Supports lookup by clip ID or source TypedDataStorage UUID

#### FR-1.6: List All Clips
- **Description**: Retrieve all clips on the timeline with their placement info
- **Output**: Array of ClipPlacement sorted by offset, then by lane
- **Filtering Options**:
  - By lane (e.g., only primary storyline, only connected clips)
  - By time range (clips overlapping a given range)

### FR-1.7: Overlapping Audio Support
- **Description**: Support multiple audio clips playing simultaneously
- **Behavior**:
  - Multiple clips can exist at the same timecode on different lanes
  - Lane 0 = primary storyline
  - Lane 1, 2, 3... = connected clips (above primary)
  - Lane -1, -2, -3... = connected clips (below primary)
  - Audio mixing is delegated to Final Cut Pro at import time
  - No pre-mixing or volume adjustment in SwiftSecuencia

### FR-2: Asset Management

#### FR-2.1: Register Asset from TypedDataStorage
- **Description**: Create an FCPXML asset from a TypedDataStorage record
- **Input**: TypedDataStorage with audio/video/image content
- **Output**: Asset reference with unique ID
- **Metadata Extraction**:
  - Duration from `durationSeconds`
  - Sample rate from `sampleRate`
  - Channels from `channels`
  - MIME type from `mimeType`
  - File extension derived from MIME type

#### FR-2.2: Handle Missing Metadata
- **Description**: When TypedDataStorage lacks required metadata, read from binary data
- **Behavior**:
  - Use AVFoundation to probe media file for duration, sample rate, channels
  - Cache extracted metadata for subsequent access
  - Fail with descriptive error if media cannot be probed

### FR-3: Bundle Export

#### FR-3.1: Export as .fcpbundle
- **Description**: Write complete project as self-contained bundle
- **Input**: Timeline, destination URL
- **Output**: `.fcpbundle` directory package containing:
  ```
  MyProject.fcpbundle/
  ├── Info.plist
  ├── MyProject.fcpxml
  └── Media/
      ├── {asset-id}.mp3
      ├── {asset-id}.mov
      └── ...
  ```
- **Behavior**:
  - Copy binary data from TypedDataStorage into Media/ directory
  - Generate FCPXML with relative paths to Media/ files
  - Create Info.plist with bundle metadata

#### FR-3.2: Export FCPXML Only
- **Description**: Export just the XML file (for cases where media is external)
- **Input**: Timeline, destination URL, media base path
- **Output**: `.fcpxml` file with absolute or relative media paths

### FR-4: Format Configuration

#### FR-4.1: Video Format Presets
- **Description**: Common video format presets
- **Presets**:
  - 1080p @ 23.98fps (NTSC Film)
  - 1080p @ 24fps (Film)
  - 1080p @ 25fps (PAL)
  - 1080p @ 29.97fps (NTSC Video)
  - 1080p @ 30fps
  - 4K @ 23.98fps
  - 4K @ 24fps
  - Custom (user-specified)

#### FR-4.2: Audio Configuration
- **Description**: Configure timeline audio settings
- **Options**:
  - Audio layout: mono, stereo, surround
  - Sample rate: 44.1kHz, 48kHz, 96kHz

---

## Non-Functional Requirements

### NFR-1: Performance

#### NFR-1.1: Large Timeline Support
- Support timelines with 1000+ clips
- Export should complete in reasonable time (< 30 seconds for 1000 clips)
- Memory usage should not exceed 2x the size of media being processed

#### NFR-1.2: Async Operations
- Bundle export should be async to avoid blocking main thread
- Progress reporting for long-running exports

### NFR-2: Compatibility

#### NFR-2.1: FCPXML Version
- Generate FCPXML version 1.11 by default
- Support export to versions 1.8, 1.9, 1.10 for compatibility

#### NFR-2.2: Final Cut Pro Compatibility
- Generated bundles must import successfully into Final Cut Pro 10.6+
- No import warnings or errors for valid documents

#### NFR-2.3: Platform Support
- macOS 13.0+ (primary)
- iOS 16.0+ (limited - no FCP but useful for generation)

### NFR-3: Reliability

#### NFR-3.1: Validation
- Validate document structure before export
- Detect and report:
  - Missing asset references
  - Invalid time values
  - Unsupported media types

#### NFR-3.2: Error Handling
- Typed errors with descriptive messages
- Recoverable vs fatal error distinction
- Partial export cleanup on failure

### NFR-4: Integration

#### NFR-4.1: SwiftCompartido Dependency
- Hard dependency on SwiftCompartido package
- Direct use of TypedDataStorage, TypedDataFileReference types
- Compatible with SwiftCompartido's storage patterns

---

## Data Model

### Timeline
```swift
public struct Timeline: Sendable {
    public let format: VideoFormat
    public private(set) var clips: [TimelineClip]

    public var startTime: Timecode { get }
    public var endTime: Timecode { get }
    public var duration: Timecode { get }
    public var clipCount: Int { get }
    public var laneRange: ClosedRange<Int> { get }  // e.g., -2...3

    // Append to end of primary storyline (lane 0)
    public mutating func append(_ storage: TypedDataStorage) throws -> ClipPlacement

    // Insert at specific timecode, optionally on specific lane
    public mutating func insert(
        _ storage: TypedDataStorage,
        at offset: Timecode,
        lane: Int? = nil  // nil = auto-assign to avoid conflicts
    ) throws -> ClipPlacement

    // Query clip by ID
    public func placement(for clipID: String) -> ClipPlacement?
    public func placement(for storageID: UUID) -> ClipPlacement?

    // List clips with optional filtering
    public func allPlacements() -> [ClipPlacement]
    public func placements(inLane lane: Int) -> [ClipPlacement]
    public func placements(overlapping range: Range<Timecode>) -> [ClipPlacement]
}
```

### TimelineClip
```swift
public struct TimelineClip: Sendable, Identifiable {
    public let id: String                    // Unique clip ID
    public let storageID: UUID               // Source TypedDataStorage.id
    public let assetRef: String              // Reference to asset in resources
    public let offset: Timecode              // Position on timeline
    public let duration: Timecode            // Clip duration
    public let lane: Int                     // 0 = primary, +N = above, -N = below
    public let sourceStart: Timecode?        // Start point in source media (optional trim)
}
```

### ClipPlacement
```swift
public struct ClipPlacement: Sendable {
    public let clipID: String
    public let storageID: UUID               // Source TypedDataStorage.id
    public let offset: Timecode              // Position on timeline
    public let duration: Timecode            // Clip duration
    public let lane: Int                     // Lane assignment
    public let endTime: Timecode             // offset + duration

    // Timeline state at time of placement
    public let timelineStart: Timecode
    public let timelineEnd: Timecode
    public let timelineDuration: Timecode
}
```

### VideoFormat
```swift
public struct VideoFormat: Sendable {
    public let width: Int
    public let height: Int
    public let frameRate: FrameRate
    public let colorSpace: ColorSpace

    public static let hd1080p2398: VideoFormat
    public static let hd1080p24: VideoFormat
    public static let hd1080p25: VideoFormat
    public static let hd1080p2997: VideoFormat
    public static let uhd4k2398: VideoFormat
}
```

### Timecode
```swift
public struct Timecode: Sendable, Equatable, Hashable, Codable {
    public let value: Int64
    public let timescale: Int32

    public var seconds: Double { get }
    public var fcpxmlString: String { get }

    public static let zero: Timecode

    public init(seconds: Double, preferredTimescale: Int32)
    public init(value: Int64, timescale: Int32)
}
```

---

## API Design

### Basic Usage: Sequential Timeline

```swift
import SwiftSecuencia
import SwiftCompartido

// Create timeline with format
var timeline = Timeline(format: .hd1080p2398)

// Add clips sequentially (one after another)
for storage in audioRecords {
    let placement = try timeline.append(storage)
    print("Added clip at \(placement.offset) for \(placement.duration)")
}

print("Timeline duration: \(timeline.duration)")

// Export as bundle
let exporter = FCPBundleExporter(timeline: timeline)
try await exporter.export(
    to: URL(fileURLWithPath: "/path/to/MyProject.fcpbundle"),
    projectName: "My Project"
)
```

### Placing Clips at Specific Timecodes

```swift
var timeline = Timeline(format: .hd1080p24)

// Place narration on primary storyline
let narration = try timeline.insert(
    narrationAudio,
    at: Timecode.zero,
    lane: 0
)

// Add background music starting at same time (different lane)
let music = try timeline.insert(
    backgroundMusic,
    at: Timecode.zero,
    lane: -1  // Below primary storyline
)

// Add sound effect at specific moment
let sfx = try timeline.insert(
    doorSlamSound,
    at: Timecode(seconds: 15.5),
    lane: 1  // Above primary storyline
)

// Overlapping clips are fine - FCP handles mixing
print("Clips at t=0: narration + music")
print("Clips at t=15.5: narration + music + sfx")
```

### Querying Clip Information

```swift
// Get placement for a specific clip
if let placement = timeline.placement(for: someStorageID) {
    print("Clip starts at \(placement.offset)")
    print("Clip duration: \(placement.duration)")
    print("Clip ends at \(placement.endTime)")
    print("On lane: \(placement.lane)")
}

// Get all clips on primary storyline
let primaryClips = timeline.placements(inLane: 0)
for clip in primaryClips {
    print("\(clip.clipID): \(clip.offset) - \(clip.endTime)")
}

// Find clips in a time range
let range = Timecode(seconds: 10)..<Timecode(seconds: 20)
let overlappingClips = timeline.placements(overlapping: range)
print("Clips between 10s and 20s: \(overlappingClips.count)")
```

### Overlapping Audio Tracks

```swift
var timeline = Timeline(format: .hd1080p24)

// Scene 1: Dialogue with ambient background
let dialogue1 = try timeline.insert(scene1Dialogue, at: Timecode.zero, lane: 0)
let ambient1 = try timeline.insert(forestAmbient, at: Timecode.zero, lane: -1)

// Scene 2: Starts at 30s, dialogue + different ambient
let dialogue2 = try timeline.insert(scene2Dialogue, at: Timecode(seconds: 30), lane: 0)
let ambient2 = try timeline.insert(cityAmbient, at: Timecode(seconds: 30), lane: -1)

// Music bed runs throughout
let musicBed = try timeline.insert(
    backgroundScore,
    at: Timecode.zero,
    lane: -2  // Lowest layer
)

// Result: FCP will mix all overlapping audio at playback
// Timeline structure:
//   Lane  0: [dialogue1]-------[dialogue2]-------
//   Lane -1: [forestAmbient]---[cityAmbient]-----
//   Lane -2: [=========backgroundScore=========]
```

### Configuration Options

```swift
// Custom format
let format = VideoFormat(
    width: 3840,
    height: 2160,
    frameRate: .fps24,
    colorSpace: .rec709
)

var timeline = Timeline(format: format, audioLayout: .stereo, audioRate: .rate48k)

// Export options
let options = ExportOptions(
    fcpxmlVersion: "1.10",
    includeChecksum: true,
    progressHandler: { progress in
        print("Export: \(Int(progress * 100))%")
    }
)

try await exporter.export(to: url, options: options)
```

---

## Constraints

### Technical Constraints

1. **SwiftData Isolation**: TypedDataStorage is a SwiftData model; must handle actor isolation when accessing properties
2. **Binary Data Access**: Large media files stored in TypedDataStorage.binaryValue or via TypedDataFileReference
3. **File I/O**: Bundle writing must handle large files efficiently (streaming vs loading into memory)

### Business Constraints

1. **No FCP Required**: Library must work without Final Cut Pro installed (generation only)
2. **Cross-Platform Consideration**: Core types should work on iOS even though FCP is macOS-only

---

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| SwiftCompartido | main | TypedDataStorage, TypedDataFileReference |
| Foundation | - | XML generation, file I/O |
| AVFoundation | - | Media metadata extraction (optional) |

---

## Milestones

### M1: Core Types (v0.1.0)
- Timecode type with FCPXML formatting
- VideoFormat presets
- Timeline data structure
- Basic clip management

### M2: TypedDataStorage Integration (v0.2.0)
- Asset creation from TypedDataStorage
- Media metadata extraction
- SwiftCompartido dependency wired up

### M3: FCPXML Generation (v0.3.0)
- Complete FCPXML document generation
- All required elements (resources, library, event, project, sequence, spine)
- Asset-clip elements with proper timing

### M4: Bundle Export (v0.4.0)
- .fcpbundle package creation
- Media file copying
- Info.plist generation
- Async export with progress

### M5: Validation & Polish (v1.0.0)
- Document validation
- Error handling refinement
- Documentation
- Final Cut Pro import testing
