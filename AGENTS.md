# AI Agent Development Guidelines for SwiftSecuencia

**Last Updated**: 2026-02-11
**Version**: 2.0.1
**AI Agents**: This document is the single source of truth for Claude, Gemini, and other AI development assistants.

---

## Project Overview

SwiftSecuencia is a Swift library and command-line tool for professional media timeline generation and export to Final Cut Pro FCPXML format.

**Core Capabilities**:
1. **Timeline Generation** - Type-safe SwiftData models with multi-lane support
2. **FCPXML Export** (macOS only) - Standalone `.fcpxml` and `.fcpxmld` bundles
3. **M4A Audio Export** (macOS + iOS) - High-performance audio rendering
4. **CLI Tool** - JSON-to-FCPXML conversion with validation

**Platforms**:
- **macOS 26.0+** - Full support (FCPXML + audio export)
- **iOS 26.0+** - Partial support (audio export only)

**Repository**: https://github.com/intrusive-memory/SwiftSecuencia
**Language**: Swift 6.2
**Concurrency**: Swift 6 strict concurrency enabled

---

## Critical Platform Rules

### ⚠️ NEVER Lower Platform Versions

**Package.swift platforms MUST remain**:
```swift
platforms: [
    .macOS(.v26),  // NEVER lower
    .iOS(.v26)     // NEVER lower
]
```

**Why**:
- Final Cut Pro for iPad does NOT support FCPXML import/export
- XMLDocument API is macOS-only (Foundation on iOS lacks XML DOM)
- Library was designed from ground-up for macOS 26+ and Swift 6.2

### Platform-Specific Features

**macOS-Only** (wrapped in `#if os(macOS)`):
- `FCPXMLExporter` - Uses XMLDocument
- `FCPXMLBundleExporter` - Uses XMLDocument
- `GenerateFCPXMLBundleIntent` - Depends on FCPXML export
- `FCPXMLValidator` / `FCPXMLDTDValidator` - Uses XMLDocument
- **Pipeline library** - All FCPXML manipulation
- **CLI tool** (`secuencia`) - Full build/validate/schema commands

**Cross-Platform** (iOS + macOS):
- `Timeline` / `TimelineClip` - SwiftData models
- `BackgroundAudioExporter` - M4A export with UI responsiveness
- `ForegroundAudioExporter` - M4A export maximum speed
- `ExportTimelineAudioIntent` - Audio export App Intent
- All timing types (`Timecode`, `FrameRate`)
- All format types (`VideoFormat`, `AudioLayout`, `AudioRate`)

### Availability Rules

1. **NEVER add `@available` for versions below minimum**
   - ❌ WRONG: `@available(macOS 12.0, *)`
   - ✅ CORRECT: No `@available` needed (Package.swift enforces)

2. **Use `#if os(macOS)` for FCPXML features**
   - ✅ CORRECT: Wrap FCPXMLExporter in `#if os(macOS)`
   - ✅ CORRECT: Leave audio exporters cross-platform

---

## Build System: xcodebuild ONLY

**CRITICAL**: NEVER use `swift build` or `swift test`. ALWAYS use `xcodebuild`.

### Rationale
- SourceKit-LSP integration requires Xcode build system
- CI/CD uses xcodebuild for consistency
- XcodeBuildMCP tools are configured for this project

### Standard Commands

```bash
# Build
xcodebuild build -scheme SwiftSecuencia -destination 'platform=macOS'

# Test (all tests)
xcodebuild test -scheme SwiftSecuencia -destination 'platform=macOS'

# Test (specific suite)
xcodebuild test -scheme SwiftSecuencia -destination 'platform=macOS' \
  -only-testing:SecuenciaCLITests

# Build CLI product
xcodebuild build -scheme secuencia -destination 'platform=macOS'
```

### CI/CD
- **GitHub Actions**: Uses `macos-26` runner (NEVER use older versions)
- **Branch**: `development` for active work, `main` for releases
- **iOS Simulator**: `platform=iOS Simulator,name=iPhone 17,OS=26.1` (NOT `OS=latest`)

---

## Architecture

### Directory Structure

```
SwiftSecuencia/
├── Sources/
│   ├── SwiftSecuencia/        # Core library (macOS + iOS)
│   │   ├── Models/            # Timeline, Timecode, FrameRate
│   │   ├── Export/            # FCPXMLExporter, audio exporters
│   │   ├── Protocols/         # FCPXMLElement, AssetProvider
│   │   └── AppIntents/        # Shortcuts integration
│   ├── SecuenciaCLI/          # CLI tool (macOS only)
│   │   ├── Commands/          # Build, Validate, Schema
│   │   ├── Models/            # TimelineDefinition, ClipDefinition
│   │   ├── Pipeline/          # FileResolver, MediaProbe, TimelineBuilder
│   │   ├── SwiftData/         # SwiftDataBootstrap
│   │   └── Resources/         # schema.json
│   └── Pipeline/              # FCPXML manipulation (MIT License)
├── Tests/
│   ├── SwiftSecuenciaTests/   # Core library tests
│   └── SecuenciaCLITests/     # CLI tests with fixtures
├── Fixtures/                  # DTD files, test media
├── Docs/                      # Architecture documentation
└── Package.swift
```

### Key Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| SwiftCompartido | development | Asset storage (TypedDataStorage) |
| SwiftFijos | development | Test fixture management |
| swift-argument-parser | 1.7.0 | CLI argument parsing |
| swift-timecode | 3.0.0 | Timecode arithmetic |
| WebVTT | 1.0.0+ | WebVTT timing data generation |
| ZIPFoundation | 0.9.20 | Bundle compression |
| universal | 5.3.0 | Cross-platform utilities |

---

## CLI Implementation (v1.1.0)

### Three Subcommands

#### 1. `secuencia build` - Generate FCPXML
Converts JSON timeline definition to FCPXML:
- Standalone `.fcpxml` file (default)
- `.fcpxmld` bundle with embedded media (`--bundle`)
- FCPXML version selection (`--format-version 1.8-1.13`)
- DTD validation (`--strict`)

**Pipeline**: JSON → Parse → Resolve → Probe → Build → Export

**Key Files**:
- `BuildCommand.swift` - Main build logic
- `FCPXMLExporter.swift` - Standalone FCPXML generation
- `FCPXMLBundleExporter.swift` - Bundle export with media

#### 2. `secuencia validate` - Validate JSON
Validates JSON timeline without generating FCPXML:
- Parses JSON structure
- Resolves file paths (relative to JSON file)
- Probes media durations (ffprobe)
- Reports: clip counts, assets, duration, lanes
- Warnings: short clips, overlaps, gaps

**Key Files**:
- `ValidateCommand.swift` - Validation logic
- `FileResolver.swift` - Path resolution
- `MediaProbe.swift` - Duration probing

#### 3. `secuencia schema` - Output JSON Schema
Outputs JSON Schema (draft 2020-12) for timeline definitions:
- Complete schema for programmatic validation
- Includes all configuration types and enums
- Examples for time string formats

**Key Files**:
- `SchemaCommand.swift` - Schema output
- `Resources/schema.json` - JSON Schema (4.8KB)

### JSON Timeline Schema

**Time String Formats**:
- Integer: `"3s"`, `"120s"`
- Decimal: `"3.5s"`, `"10.25s"`
- Rational: `"1001/24000s"` (FCPXML format)

**File Path Resolution**:
- Relative paths resolved to JSON file's directory
- Absolute paths used as-is
- Deduplication: Same file → same FCPXML asset

**MIME Type Derivation**:
- `video` + `.mov` → `video/quicktime`, hasVideo + hasAudio
- `audio` + `.m4a` → `audio/mp4`, hasAudio only
- `image` + `.png` → `image/png`, hasVideo only
- `marker` → no file, no MIME type

### CLI Test Fixtures

**Location**: `Tests/SecuenciaCLITests/Fixtures/`

**Media Files**:
- `test-video.mov` - H.264 video with audio
- `test-audio.m4a` - AAC audio
- `test-audio.wav` - PCM audio
- `test-image.png` - PNG image

**JSON Files**:
- `simple-timeline.json` - Basic timeline (3 clips)
- `multi-lane-timeline.json` - Multi-lane audio
- `markers-timeline.json` - Chapter markers
- `auto-duration.json` - Duration probing test

---

## Audio Export Architecture

### Two Exporters, Two Use Cases

#### BackgroundAudioExporter (UI Responsive)
**Use when**: Large timelines (100+ clips), UI interaction needed

```swift
let exporter = BackgroundAudioExporter(modelContainer: container)
let outputURL = try await exporter.exportAudio(
    timelineID: timelineID,
    to: destinationURL,
    progress: progress
)
```

**Architecture**:
- Phase 1 (30%): Build Timeline on main thread (metadata only)
- Phase 2 (70%): Export on background thread with `@ModelActor`
- Parallel file I/O (3-10x faster than serial)
- Read-only SwiftData access
- `.high` priority for maximum performance

**Performance**: ~12s for 50 clips, 2.5 min duration

#### ForegroundAudioExporter (Maximum Speed)
**Use when**: Maximum speed critical, UI blocking acceptable

```swift
@MainActor
let exporter = ForegroundAudioExporter()
let outputURL = try await exporter.exportAudioDirect(
    audioElements: audioFiles,  // Direct export (19% faster)
    modelContext: modelContext,
    to: destinationURL,
    progress: progress
)
```

**Architecture**:
- Single phase: Main thread export (no Timeline creation)
- FileHandle with pre-allocation (faster writes)
- `audioTimePitchAlgorithm = .varispeed` (fastest)
- Direct audio sequencing
- Parallel file I/O

**Performance**: ~8.1s for 50 clips, 2.5 min duration

### Timing Data Export (WebVTT/JSON)

**Optional feature** for karaoke-style text synchronization:

```swift
try await exporter.exportAudioDirect(
    audioElements: audioFiles,
    modelContext: modelContext,
    to: destinationURL,
    timingDataFormat: .webvtt  // Or .json, .both, .none
)
```

**File Naming**:
- WebVTT: `screenplay.vtt`
- JSON: `screenplay.m4a.timing.json`

**Use Case**: Synchronized text display in web players (TextTrack API)

---

## Dual Dialogue Support

**Feature**: Simultaneous speaker placement (2+ speakers at same offset)

```swift
let metadata1 = ScreenplayMetadata(
    character: "ALICE",
    dialogue: "We need to talk.",
    dualDialogueGroupId: "group1"  // Same group = simultaneous
)

let metadata2 = ScreenplayMetadata(
    character: "BOB",
    dialogue: "I agree!",
    dualDialogueGroupId: "group1"  // Same group
)

let timeline = try await converter.convertToTimeline(
    screenplayName: "My Script",
    audioElements: [audio1, audio2],
    audioMetadata: [metadata1, metadata2]  // Optional
)
// Result: Both clips at offset 0s on lanes 0 and 1
```

**Key Features**:
- Automatic lane assignment (0, 1, 2, ...)
- Groups placed at same offset
- Offset advances by max duration
- Audio mixed during M4A export
- FCPXML preserves lane attributes

---

## SwiftData Concurrency

### Core Principles

1. **Pass IDs, not objects** - Use `persistentModelID` to cross actor boundaries
2. **Read-only background access** - Background threads never modify data
3. **Lazy loading** - Load audio on-demand, release immediately
4. **@ModelActor for safety** - Automatic SwiftData concurrency (BackgroundAudioExporter)
5. **Progress is thread-safe** - Foundation.Progress works across actors
6. **Parallel I/O** - TaskGroup for parallel file writes

### Example: Background Export

```swift
// Phase 1: Main thread
let timeline = try await converter.convertToTimeline(...)
modelContext.insert(timeline)
try modelContext.save()
let timelineID = timeline.persistentModelID

// Phase 2: Background thread
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

## Pipeline Integration (MIT License)

SwiftSecuencia includes code from the [Pipeline](https://github.com/reuelk/pipeline) project by Reuel Kim (MIT License). Pipeline's FCPXML manipulation code is in `Sources/Pipeline/` with modifications for Swift 6.2 and macOS 26.0+.

**Attribution**: See `PIPELINE-LICENSE.md` for full license.

**Modifications**:
- Swift 6.2 strict concurrency
- macOS 26.0+ APIs
- Sendable conformance
- Actor isolation

---

## Testing Strategy

### Test Suites

| Suite | Tests | Platform | Purpose |
|-------|-------|----------|---------|
| SwiftSecuenciaTests | 277 | macOS + iOS | Core library |
| SecuenciaCLITests | 31 | macOS | CLI functionality |
| **Total** | **308** | — | Full coverage |

### CLI Test Structure

```swift
@Suite("BuildCommand Tests")
struct BuildCommandTests {
    @Test("Export standalone FCPXML from valid JSON")
    @MainActor
    func exportStandaloneFCPXML() async throws {
        // Test full pipeline: JSON → FCPXML
    }
}
```

### Key Testing Tools

- **Swift Testing** framework (not XCTest)
- **SwiftFijos** for fixture management
- **#expect** macro for assertions
- **@MainActor** for UI-dependent tests

### Fixture Management

**Location**: `Fixtures/` (project root)

**DTD Files**: FCPXMLv1_8.dtd through FCPXMLv1_13.dtd

**Access via SwiftFijos**:
```swift
let dtdURL = try Fijos.getFixture("FCPXMLv1_11.dtd")
```

---

## Version Management

### Current Version
- **Library**: 2.0.1 (SwiftSecuencia.swift)
- **Git Tag**: v2.0.1
- **Latest Release**: CI Fixes (Patch)

### Versioning Rules

**Semantic Versioning (semver.org)**:
- **Major**: New major features, architectural changes (e.g., 2.0.0)
- **Minor**: New features, backward compatible (e.g., 2.1.0)
- **Patch**: Bug fixes only (e.g., 2.0.1)

**CLI Implementation = Major Version Bump**:
- Reason: Major new feature (complete CLI tool with 3 subcommands)
- No breaking changes to library APIs (all changes are additive)
- Previous: 1.0.9 → New: 2.0.0

### Release Process

1. Update `SwiftSecuencia.swift` version
2. Update `CHANGELOG.md` with release notes
3. Update `README.md` installation instructions
4. Commit: `"Release v2.0.0"`
5. Tag: `git tag v2.0.0`
6. Push: `git push origin main --tags`
7. Create GitHub release with CHANGELOG excerpt

---

## Code Style

### Swift 6.2 Features
- **Strict Concurrency**: All types marked `Sendable` or non-Sendable
- **Typed Throws**: Use typed error types where possible
- **Actor Isolation**: Explicit `@MainActor` and `@ModelActor`
- **Async/Await**: Preferred over completion handlers

### Naming Conventions
- **Types**: PascalCase (`Timeline`, `FCPXMLExporter`)
- **Properties/Functions**: camelCase (`exportAudio`, `timelineID`)
- **Constants**: camelCase (`defaultFCPXMLVersion`)
- **Private**: Leading underscore optional, use `private` keyword

### SwiftLint Rules
- **Enforced**: See `.swiftlint.yml`
- **Platform checks**: Must use `#if os(macOS)`, NOT `@available(macOS ...)`
- **Large tuples**: Max 2 elements (use struct instead)
- **Line length**: 120 characters

### Documentation
- **Public APIs**: DocC-compatible comments
- **Complex logic**: Inline comments explaining "why"
- **Architecture decisions**: Document in CLAUDE.md or Docs/

---

## Common Tasks

### Adding New CLI Command

1. Create `NewCommand.swift` in `Sources/SecuenciaCLI/Commands/`
2. Conform to `AsyncParsableCommand` (or `ParsableCommand`)
3. Register in `Secuencia.swift` subcommands array
4. Add tests in `Tests/SecuenciaCLITests/NewCommandTests.swift`
5. Update README.md with usage examples

### Adding FCPXML Element

1. Create model in `Sources/SwiftSecuencia/Models/`
2. Conform to `FCPXMLElement` protocol
3. Implement `xmlElement()` → XMLElement
4. Add to exporter resource/timeline generation
5. Add tests in `Tests/SwiftSecuenciaTests/`

### Performance Optimization

**DO**:
- Profile first (Instruments.app)
- Parallelize independent I/O operations
- Use `.high` priority for user-facing tasks
- Batch SwiftData fetches

**DON'T**:
- Premature optimization
- Block main thread for >100ms
- Hold strong references to large data
- Use `@ModelActor` on main thread

---

## Troubleshooting

### Build Errors

**"Cannot find module 'secuencia'"**
- Fix: Import `SecuenciaCLI`, not `secuencia`
- Reason: `secuencia` is executable, not library

**"Schema not found in Bundle.module"**
- Fix: Ensure `Package.swift` has `.process("Resources/")`
- Reason: Resources not copied to bundle

**Platform version warnings**
- Fix: Check Package.swift platforms (must be .v26)
- Fix: Remove @available attributes below minimum

### Test Failures

**DTD validation tests fail**
- Cause: DTD files not found in Fixtures/
- Fix: Verify SwiftFijos can locate Fixtures/ directory

**CLI tests don't run**
- Cause: Wrong import (should be `SecuenciaCLI`)
- Fix: Update test file imports

### CI/CD Issues

**macOS runner version mismatch**
- Fix: Use `macos-26` in `.github/workflows/test.yml`
- NEVER use `macos-15` or earlier

**iOS Simulator destination fails**
- Fix: Use exact OS version: `OS=26.1` (NOT `OS=latest`)
- Example: `platform=iOS Simulator,name=iPhone 17,OS=26.1`

---

## Security & Credentials

**NEVER**:
- Echo environment variables (`$API_KEY`, etc.)
- Display contents of `.env`, `.p8`, credential files
- Use `printenv` for sensitive variables
- Commit secrets to repository

**ALWAYS**:
- Use existence checks: `test -n "$VAR"`
- Use file existence checks: `test -f "$PATH"`
- Keep secrets in user's secure storage

---

## Related Projects

- **SwiftCompartido**: Asset storage (TypedDataStorage)
- **SwiftFijos**: Test fixture management
- **Pipeline**: FCPXML manipulation (MIT License, Reuel Kim)
- **DAWFileKit**: Alternative FCPXML library (orchetect)

---

## Resources

- **Repository**: https://github.com/intrusive-memory/SwiftSecuencia
- **FCPXML Reference**: Docs/FCPXML-Reference.md
- **FCPXML Elements**: Docs/FCPXML-Elements.md
- **Concurrency Architecture**: Docs/CONCURRENCY-ARCHITECTURE.md
- **Effectiveness Evaluation**: Docs/EFFECTIVENESS-EVALUATION.md
- **Apple FCPXML Docs**: https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference
- **FCP Cafe**: https://fcp.cafe/developers/fcpxml/

---

## Quick Reference

### Build Commands
```bash
xcodebuild build -scheme SwiftSecuencia -destination 'platform=macOS'
xcodebuild test -scheme SwiftSecuencia -destination 'platform=macOS'
xcodebuild build -scheme secuencia -destination 'platform=macOS'
```

### CLI Commands
```bash
secuencia build timeline.json
secuencia build --bundle timeline.json
secuencia validate timeline.json
secuencia schema > schema.json
```

### Version Info
- **Current**: 2.0.1
- **Swift**: 6.2+
- **macOS**: 26.0+
- **iOS**: 26.0+ (audio only)

---

**End of AGENTS.md**
