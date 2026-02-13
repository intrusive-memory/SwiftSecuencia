# AI Agent Development Guidelines

**Last Updated**: 2026-02-13
**Version**: 2.0.2-dev
**Target Audience**: Claude, Gemini, and other AI development assistants

---

## What This Project Does

SwiftSecuencia is a **Swift library and CLI tool** for professional media timeline generation and export to Final Cut Pro FCPXML format.

**Core Features**:
- **Timeline Generation** - Type-safe SwiftData models, multi-lane audio, dual dialogue
- **FCPXML Export** (macOS only) - Standalone `.fcpxml` and `.fcpxmld` bundles with DTD validation
- **M4A Audio Export** (iOS + macOS) - High-performance rendering with timing data (WebVTT/JSON)
- **CLI Tool** (`secuencia`) - JSON→FCPXML conversion with schema validation

**Platforms**: macOS 26.0+, iOS 26.0+ (audio only)
**Language**: Swift 6.2 with strict concurrency

---

## Critical Rules

### 1. Platform Versions - NEVER LOWER

```swift
platforms: [
    .macOS(.v26),  // NEVER change
    .iOS(.v26)     // NEVER change
]
```

**Why**: XMLDocument (FCPXML) is macOS-only. FCP for iPad doesn't support FCPXML import.

### 2. Build System - xcodebuild ONLY

**NEVER** use `swift build` or `swift test`. **ALWAYS** use `xcodebuild`.

```bash
# Build
xcodebuild build -scheme SwiftSecuencia-Package -destination 'platform=macOS'

# Test
xcodebuild test -scheme SwiftSecuencia-Package -destination 'platform=macOS'
```

### 3. Platform-Specific Code

Use `#if os(macOS)` for FCPXML features (NOT `@available`):
- FCPXMLExporter, FCPXMLBundleExporter
- FCPXMLValidator, FCPXMLDTDValidator
- SecuenciaCLI, SecuenciaCLICore (entire CLI)
- Pipeline library (all FCPXML manipulation)

---

## Architecture Overview

### Package Structure

```
SwiftSecuencia/
├── Sources/
│   ├── SwiftSecuencia/           # Core library (iOS + macOS)
│   │   ├── Models/               # Timeline, Timecode, VideoFormat
│   │   ├── Export/               # FCPXML + audio exporters
│   │   │   ├── FCPXMLExporter.swift
│   │   │   ├── FCPXMLBundleExporter.swift
│   │   │   ├── BackgroundAudioExporter.swift
│   │   │   ├── ForegroundAudioExporter.swift
│   │   │   ├── AssetProvider.swift (protocol)
│   │   │   ├── FileAssetProvider.swift
│   │   │   └── SwiftDataAssetProvider.swift
│   │   └── AppIntents/           # Shortcuts integration
│   ├── SecuenciaCLICore/         # CLI business logic (library)
│   │   ├── Commands/             # Build, Validate, Schema (public)
│   │   ├── Parsing/              # JSONTimelineParser, MediaProbe
│   │   ├── Builder/              # TimelineBuilder
│   │   ├── Models/               # TimelineDefinition, ClipDefinition
│   │   ├── SwiftData/            # SwiftDataBootstrap
│   │   ├── Resources/            # schema.json
│   │   └── SchemaResource.swift  # Bundle.module accessor
│   ├── SecuenciaCLI/             # CLI entry point (executable)
│   │   └── Secuencia.swift       # @main, imports SecuenciaCLICore
│   └── Pipeline/                 # FCPXML manipulation (MIT License)
├── Tests/
│   ├── SwiftSecuenciaTests/      # 315 tests
│   └── SecuenciaCLITests/        # 116 tests (imports SecuenciaCLICore)
└── Fixtures/                     # DTD files, test media
```

### Key Architecture Points

**CLI Architecture** (v2.0.2 refactor):
- `SecuenciaCLI` (executable) - Entry point only, cannot be imported by tests
- `SecuenciaCLICore` (library) - All business logic, tests import this
- Commands are `public` structs conforming to `AsyncParsableCommand`

**Asset Providers**:
- `FileAssetProvider` - For CLI (file-based workflows)
- `SwiftDataAssetProvider` - For app (SwiftData storage)
  - Maps `audio/mp4` → `.m4a` extension (NOT `.mp4`)
  - Creates temp files from `binaryValue` for DTD validation tests

**Audio Exporters**:
- `BackgroundAudioExporter` - UI responsive, uses `@ModelActor` background thread
- `ForegroundAudioExporter` - Maximum speed, main thread, 19% faster

---

## CLI Tool (secuencia)

### Three Subcommands

| Command | Purpose | Key Features |
|---------|---------|--------------|
| `build` | JSON → FCPXML | Standalone/bundle export, DTD validation (`--strict`) |
| `validate` | Validate JSON | Path resolution, media probing, warnings |
| `schema` | Output JSON Schema | draft 2020-12 schema for validation |

**Pipeline**: JSON → Parse → Resolve → Probe → Build → Export

### JSON Timeline Format

**Time Strings**: `"3s"`, `"3.5s"`, `"1001/24000s"` (rational)
**Paths**: Relative to JSON file, deduplicated in FCPXML
**MIME Types**: Auto-derived from clip type + file extension

**Example**:
```json
{
  "timeline": {
    "name": "My Project",
    "format": { "width": 1920, "height": 1080, "frameRate": "24" },
    "audio": { "layout": "stereo", "rate": "48kHz" }
  },
  "clips": [
    { "type": "video", "file": "media/intro.mov", "offset": "0s" },
    { "type": "audio", "file": "media/voice.m4a", "offset": "5s", "lane": 1 }
  ]
}
```

---

## Testing

### Test Coverage

- **SwiftSecuenciaTests**: 315 tests (core library)
- **SecuenciaCLITests**: 116 tests (CLI functionality)
- **Total**: 431 tests

### Key Testing Practices

- Use Swift Testing framework (NOT XCTest)
- `@MainActor` for SwiftData/UI tests
- `#expect` macro for assertions
- SwiftFijos for fixture management

### Fixture Locations

- **DTD Files**: `Fixtures/FCPXMLv1_8.dtd` through `FCPXMLv1_13.dtd`
- **Test Media**: `Tests/SecuenciaCLITests/Fixtures/media/`
  - `test-video.mov`, `test-audio.m4a`, `test-audio.wav`, `test-image.png`

---

## SwiftData Concurrency

### Core Principles

1. **Pass IDs, not objects** - Use `persistentModelID` across actors
2. **Read-only background** - Background threads never modify data
3. **@ModelActor for safety** - Automatic isolation (BackgroundAudioExporter)
4. **Parallel I/O** - TaskGroup for file writes
5. **Progress thread-safe** - Foundation.Progress works across actors

### Example Pattern

```swift
// Main thread: Create timeline
let timeline = try await converter.convertToTimeline(...)
modelContext.insert(timeline)
try modelContext.save()
let timelineID = timeline.persistentModelID  // Pass ID, not object

// Background thread: Export
let outputURL = try await Task.detached(priority: .high) {
    let exporter = BackgroundAudioExporter(modelContainer: container)
    return try await exporter.exportAudio(
        timelineID: timelineID,  // ID, not object
        to: destinationURL,
        progress: progress
    )
}.value
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| SwiftCompartido | development | TypedDataStorage (asset storage) |
| SwiftFijos | development | Test fixture management |
| swift-argument-parser | 1.7.0 | CLI argument parsing |
| swift-timecode | 3.0.0 | Timecode arithmetic |
| WebVTT | 1.0.0+ | Timing data export |
| ZIPFoundation | 0.9.20 | Bundle compression |

---

## Code Style

### Swift 6.2 Features
- **Strict Concurrency**: All targets use `-enable-upcoming-feature StrictConcurrency`
- **Actor Isolation**: Explicit `@MainActor`, `@ModelActor`
- **Sendable Conformance**: Required for types crossing actor boundaries
- **Typed Throws**: Use where appropriate

### Naming Conventions
- **Types**: PascalCase (`Timeline`, `FCPXMLExporter`)
- **Properties/Functions**: camelCase (`exportAudio`, `timelineID`)
- **Platform checks**: `#if os(macOS)` (NOT `@available(macOS ...)`)

### SwiftLint
- Line length: 120 characters
- Large tuples: Max 2 elements
- Enforced: See `.swiftlint.yml`

---

## Common Tasks

### Adding CLI Command

1. Create `NewCommand.swift` in `Sources/SecuenciaCLICore/Commands/`
2. Make struct and members `public`
3. Conform to `AsyncParsableCommand` or `ParsableCommand`
4. Register in `Sources/SecuenciaCLI/Secuencia.swift` subcommands
5. Add tests in `Tests/SecuenciaCLITests/NewCommandTests.swift`
6. Import `@testable import SecuenciaCLICore` (NOT `SecuenciaCLI`)

### Adding FCPXML Element

1. Create model in `Sources/SwiftSecuencia/Models/`
2. Wrap in `#if os(macOS)` if FCPXML-specific
3. Conform to `FCPXMLElement` protocol
4. Implement `xmlElement()` → XMLElement
5. Add to exporter generation logic
6. Add tests

---

## Troubleshooting

### "Cannot find module 'SecuenciaCLI'"
- **Fix**: Import `@testable import SecuenciaCLICore` in tests
- **Reason**: Executables can't be imported, only libraries

### "Schema resource not found"
- **Fix**: Use `SchemaResource.schemaURL` instead of `Bundle.module`
- **Reason**: Resource is in SecuenciaCLICore bundle, not test bundle

### CI macOS Version Mismatch
- **Fix**: Use `macos-26` (NEVER `macos-15` or earlier)
- **iOS Sim**: `platform=iOS Simulator,name=iPhone 17,OS=26.1` (NOT `OS=latest`)

### Audio File Extension Wrong
- **Issue**: audio/mp4 getting `.mp4` instead of `.m4a`
- **Fix**: Check SwiftDataAssetProvider.fileExtension() logic
- **Should**: Return `.m4a` for `audio/mp4`, `.mp4` for `video/mp4`

---

## Version & Release Info

**Current**: 2.0.2-dev (post-CLI architecture refactor)
**Previous**: 2.0.1 (CI fixes), 2.0.0 (CLI implementation)

### Versioning
- **Major**: Architectural changes, new major features
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes only

See **CHANGELOG.md** for full release history.

---

## Key Documentation

- **CLI Architecture**: Docs/CLI-ARCHITECTURE.md (detailed implementation)
- **Concurrency**: Docs/CONCURRENCY-ARCHITECTURE.md
- **FCPXML Reference**: Docs/FCPXML-Reference.md
- **FCPXML Elements**: Docs/FCPXML-Elements.md
- **Pipeline License**: PIPELINE-LICENSE.md (MIT License, Reuel Kim)

---

## Quick Reference

```bash
# Build & Test
xcodebuild build -scheme SwiftSecuencia-Package -destination 'platform=macOS'
xcodebuild test -scheme SwiftSecuencia-Package -destination 'platform=macOS'

# CLI Usage
secuencia build timeline.json
secuencia build --bundle --format-version 1.11 timeline.json
secuencia validate timeline.json
secuencia schema > schema.json
```

**Repository**: https://github.com/intrusive-memory/SwiftSecuencia
**Swift**: 6.2+
**macOS**: 26.0+
**iOS**: 26.0+ (audio export only)

---

**End of AGENTS.md** - For detailed implementation docs, see `Docs/` directory.
