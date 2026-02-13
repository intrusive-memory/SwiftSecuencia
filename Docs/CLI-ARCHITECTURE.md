# CLI Architecture

**Component**: SecuenciaCLI + SecuenciaCLICore
**Version**: 2.0.2
**Last Updated**: 2026-02-13

---

## Overview

The `secuencia` CLI tool converts JSON timeline definitions to Final Cut Pro FCPXML format. It consists of two targets:

- **SecuenciaCLI** (executable) - Entry point only, `@main` struct
- **SecuenciaCLICore** (library) - All business logic, testable

This architecture enables proper unit testing while maintaining a clean executable interface.

---

## Architecture (v2.0.2 Refactor)

### Problem Solved

Swift Package Manager **prohibits importing executable targets** in tests. The original design had all CLI code in the `SecuenciaCLI` executable target, making it impossible to write unit tests.

### Solution

Extract business logic into a **library target** (`SecuenciaCLICore`) that tests can import:

```
SecuenciaCLI (executable)
└─ Secuencia.swift (12 lines)
   └─ imports SecuenciaCLICore

SecuenciaCLICore (library)
├─ Commands/ (public API)
│   ├── BuildCommand.swift
│   ├── ValidateCommand.swift
│   └── SchemaCommand.swift
├─ Parsing/
│   ├── JSONTimelineParser.swift
│   ├── FileResolver.swift
│   ├── MediaProbe.swift
│   ├── TimeStringParser.swift
│   └── FrameRateParser.swift
├─ Builder/
│   └── TimelineBuilder.swift
├─ Models/
│   └── TimelineDefinition.swift
├─ SwiftData/
│   └── SwiftDataBootstrap.swift
├─ Resources/
│   └── schema.json
└─ SchemaResource.swift (Bundle.module accessor)
```

### Package.swift Configuration

```swift
.target(
    name: "SecuenciaCLICore",
    dependencies: [
        "SwiftSecuencia",
        .target(name: "Pipeline", condition: .when(platforms: [.macOS])),
        .product(name: "SwiftFijos", package: "SwiftFijos"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Universal", package: "universal"),
    ],
    resources: [.process("Resources/")]
),
.executableTarget(
    name: "SecuenciaCLI",
    dependencies: [
        "SecuenciaCLICore",  // Import library
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
    ]
),
.testTarget(
    name: "SecuenciaCLITests",
    dependencies: [
        "SecuenciaCLICore",  // Tests import library, NOT executable
        "SwiftSecuencia",
        .product(name: "SwiftFijos", package: "SwiftFijos"),
    ]
)
```

### Public API

Commands must be `public` to be accessible from the executable:

```swift
// BuildCommand.swift
public struct Build: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(...)

    @Argument public var inputFile: String
    @Option public var output: String?
    @Flag public var bundle: Bool = false

    public init() {}

    public mutating func run() async throws { ... }
}
```

### Resource Access

Resources (schema.json) are in `SecuenciaCLICore`, but tests run in `SecuenciaCLITests` bundle. Use helper:

```swift
// SchemaResource.swift
public enum SchemaResource {
    public static var schemaURL: URL? {
        Bundle.module.url(forResource: "schema", withExtension: "json")
    }
}

// In tests
let schemaURL = SchemaResource.schemaURL  // ✅ Works
let schemaURL = Bundle.module.url(...)    // ❌ Wrong bundle
```

---

## Three Subcommands

### 1. secuencia build

**Purpose**: Convert JSON timeline to FCPXML

**Pipeline**:
```
JSON File
  ↓ JSONTimelineParser
TimelineDefinition
  ↓ FileResolver (resolve relative paths)
Resolved Paths
  ↓ MediaProbe (ffprobe for durations)
Complete Definition
  ↓ TimelineBuilder (create SwiftData timeline)
Timeline Model
  ↓ FCPXMLExporter/FCPXMLBundleExporter
FCPXML Output (.fcpxml or .fcpxmld)
```

**Flags**:
- `--output` - Output path (default: `<input>.fcpxml`)
- `--bundle` - Create `.fcpxmld` bundle with embedded media
- `--format-version` - FCPXML version (1.8-1.13, default: 1.11)
- `--strict` - Fail on DTD validation errors (default: warn only)

**Example**:
```bash
secuencia build timeline.json
secuencia build --bundle --format-version 1.13 --strict timeline.json
```

**Key Files**:
- `BuildCommand.swift` - Main logic
- `TimelineBuilder.swift` - SwiftData timeline creation
- `FCPXMLExporter.swift` - Standalone export
- `FCPXMLBundleExporter.swift` - Bundle export

### 2. secuencia validate

**Purpose**: Validate JSON without generating FCPXML

**Steps**:
1. Parse JSON structure
2. Resolve file paths (relative to JSON file)
3. Probe media durations (ffprobe)
4. Report summary:
   - Timeline name, format, audio config
   - Clip counts by type (video, audio, image, marker)
   - Asset counts (unique files)
   - Duration and lane usage
5. Warnings:
   - Short clips (<0.5s)
   - Overlapping clips
   - Gaps in timeline

**Example**:
```bash
secuencia validate timeline.json
```

Output:
```
✅ Validation successful!

Timeline Summary:
  Name: My Project
  Format: 1920×1080 @ 24 fps
  Audio: stereo, 48kHz

Clips:
  Total: 15
  video: 5
  audio: 8
  marker: 2

Assets:
  Unique files: 12
```

**Key Files**:
- `ValidateCommand.swift`
- `FileResolver.swift`
- `MediaProbe.swift`

### 3. secuencia schema

**Purpose**: Output JSON Schema for programmatic validation

**Output**: JSON Schema (draft 2020-12) with:
- Timeline configuration schema
- Clip definition schema
- All format types and enums
- Time string format examples

**Example**:
```bash
secuencia schema > schema.json
```

**Key Files**:
- `SchemaCommand.swift`
- `Resources/schema.json` (4.8KB)

---

## JSON Timeline Format

### Structure

```json
{
  "timeline": {
    "name": "Project Name",
    "format": {
      "width": 1920,
      "height": 1080,
      "frameRate": "24",
      "colorSpace": "Rec. 709"
    },
    "audio": {
      "layout": "stereo",
      "rate": "48kHz"
    }
  },
  "clips": [
    {
      "type": "video",
      "file": "media/intro.mov",
      "offset": "0s",
      "duration": "5s"
    },
    {
      "type": "audio",
      "file": "media/voice.m4a",
      "offset": "5s",
      "duration": "auto",
      "lane": 1
    },
    {
      "type": "marker",
      "name": "Chapter 1",
      "offset": "10s",
      "markerType": "chapter"
    }
  ]
}
```

### Time Strings

**Formats**:
- Integer: `"3s"`, `"120s"`
- Decimal: `"3.5s"`, `"10.25s"`
- Rational: `"1001/24000s"` (FCPXML native format)

**Special Values**:
- `"auto"` - Probe duration from media file (requires `ffprobe`)

### File Paths

**Resolution Rules**:
- Relative paths → Relative to JSON file directory
- Absolute paths → Used as-is
- Deduplication → Same file = same FCPXML asset

**Example**:
```json
{
  "file": "media/clip.mov"           // → /path/to/json/media/clip.mov
  "file": "/absolute/path/clip.mov"  // → /absolute/path/clip.mov
}
```

### MIME Type Derivation

Automatic MIME type inference from clip type + file extension:

| Clip Type | Extension | MIME Type | hasVideo | hasAudio |
|-----------|-----------|-----------|----------|----------|
| `video` | `.mov` | `video/quicktime` | ✅ | ✅ |
| `video` | `.mp4` | `video/mp4` | ✅ | ✅ |
| `audio` | `.m4a` | `audio/mp4` | ❌ | ✅ |
| `audio` | `.wav` | `audio/wav` | ❌ | ✅ |
| `audio` | `.mp3` | `audio/mpeg` | ❌ | ✅ |
| `image` | `.png` | `image/png` | ✅ | ❌ |
| `image` | `.jpg` | `image/jpeg` | ✅ | ❌ |
| `marker` | - | - | ❌ | ❌ |

### Clip Types

| Type | Purpose | Requires File | FCPXML Element |
|------|---------|---------------|----------------|
| `video` | Video with audio | ✅ | `<asset-clip>` |
| `audio` | Audio only | ✅ | `<asset-clip>` |
| `image` | Still image | ✅ | `<asset-clip>` |
| `marker` | Chapter/TODO marker | ❌ | `<marker>` |

### Lane Assignment

- **Default**: Lane 0 (primary lane)
- **Multi-lane**: Specify `"lane": 1`, `"lane": 2`, etc.
- **Dual Dialogue**: Use `dualDialogueGroupId` (auto lane assignment)

---

## Media Probing

### FFprobe Integration

`MediaProbe` uses `ffprobe` to determine media duration when `"duration": "auto"`:

```swift
let probe = MediaProbe()
let probed = try await probe.probeMissingDurations(in: definition)
```

**Command**:
```bash
ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 /path/to/media.mov
```

**Output**: `"5.002"`

### Duration Tolerance

Auto-probed durations are validated against manual durations:
- **Tolerance**: ±0.1 seconds
- **Purpose**: Catch stale manual durations that need updating

---

## Asset Deduplication

`FileResolver` ensures unique files map to single FCPXML assets:

```json
{
  "clips": [
    { "file": "media/voice.m4a", "offset": "0s" },
    { "file": "media/voice.m4a", "offset": "10s" }
  ]
}
```

**Result**: Single `<asset>` element, two `<asset-clip>` references

---

## DTD Validation

### Process

1. Generate FCPXML XML
2. Load DTD file for requested version
3. Validate XML against DTD
4. Report errors/warnings

### DTD Versions

Bundled DTDs (from Apple):
- FCPXMLv1_8.dtd
- FCPXMLv1_9.dtd
- FCPXMLv1_10.dtd
- FCPXMLv1_11.dtd (default)
- FCPXMLv1_12.dtd
- FCPXMLv1_13.dtd

### Validation Modes

**Default (warn)**:
```bash
secuencia build timeline.json  # Warns if invalid, still writes output
```

**Strict (fail)**:
```bash
secuencia build --strict timeline.json  # Exits with error if invalid
```

---

## Testing

### Test Structure

```swift
@Suite("BuildCommand Tests")
struct BuildCommandTests {
    @Test("Export standalone FCPXML from valid JSON")
    @MainActor
    func exportStandaloneFCPXML() async throws {
        let inputURL = try Fijos.getFixture("simple-timeline.json")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".fcpxml")

        // Run build command
        var command = Build()
        command.inputFile = inputURL.path
        command.output = outputURL.path
        try await command.run()

        // Verify output
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        // Validate FCPXML structure
        let xml = try String(contentsOf: outputURL)
        #expect(xml.contains("<fcpxml version=\"1.11\">"))
    }
}
```

### Test Fixtures

**Location**: `Tests/SecuenciaCLITests/Fixtures/`

**JSON Files**:
- `simple-timeline.json` - Basic timeline (3 clips)
- `multi-lane-timeline.json` - Multi-lane audio
- `markers-timeline.json` - Chapter markers
- `auto-duration.json` - Duration probing
- `invalid-clip-type.json` - Schema validation test
- `missing-file.json` - File resolution error test

**Media Files**:
- `media/test-video.mov` - H.264 video (5s)
- `media/test-audio.m4a` - AAC audio (3s)
- `media/test-audio.wav` - PCM audio (2s)
- `media/test-image.png` - PNG image (1920×1080)

---

## Performance

### Validation Speed

- **JSON parsing**: <1ms
- **File resolution**: ~5ms (10 files)
- **Media probing**: ~50ms per file (ffprobe overhead)
- **Total**: ~500ms for 10-file timeline

### Build Speed

- **JSON → Timeline**: ~10ms
- **Timeline → FCPXML**: ~20ms
- **DTD validation**: ~50ms
- **Total**: ~80ms (excluding media probing)

### Bundle Export

- **FCPXML generation**: ~80ms
- **File copying**: ~100ms per GB
- **ZIP compression**: ~500ms per GB

---

## Error Handling

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `JSON parsing failed` | Invalid JSON syntax | Validate with `jsonlint` |
| `File not found: media/clip.mov` | Missing media file | Check file path relative to JSON |
| `Invalid time string: "5"` | Missing `s` suffix | Use `"5s"` not `"5"` |
| `Invalid clip type: "vidoe"` | Typo in type | Use `"video"` not `"vidoe"` |
| `DTD validation failed` | Malformed FCPXML | Check generated XML structure |
| `ffprobe not found` | FFmpeg not installed | Install: `brew install ffmpeg` |

---

## Future Enhancements

### Planned Features

1. **Preview Command** - Generate thumbnail strip
2. **Diff Command** - Compare two FCPXML files
3. **Merge Command** - Combine multiple timelines
4. **Info Command** - Analyze existing FCPXML files
5. **Convert Command** - FCPXML → JSON (reverse operation)

### Schema Improvements

- JSON Schema $ref resolution
- Custom validation rules (warnings for best practices)
- Auto-completion support for editors (VS Code, etc.)

---

## Related Documentation

- **AGENTS.md** - Quick reference for AI agents
- **CONCURRENCY-ARCHITECTURE.md** - SwiftData concurrency patterns
- **FCPXML-Reference.md** - FCPXML element documentation
- **FCPXML-Elements.md** - Detailed element specs

---

**End of CLI-ARCHITECTURE.md**
