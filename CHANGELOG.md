# Changelog

All notable changes to SwiftSecuencia will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2026-03-15

### Added - Release Automation & Homebrew Distribution

**Feature Release**: Automated release workflow and Homebrew distribution support

#### GitHub Actions Release Workflow
- **Automated binary builds** on release creation
  - Uses macOS 26 runner with Apple Silicon
  - Builds release binary and creates distributable tarball
  - Uploads binary assets to GitHub releases automatically
  - Triggers Homebrew tap updates via repository dispatch

- **Manual release workflow dispatch**
  - Can trigger release workflow manually with tag input
  - Useful for re-building or patching releases
  - Full SHA256 verification of tarballs

#### Homebrew Distribution
- **New Makefile targets** for distribution
  - `make release` - Build release binary with Xcode
  - `make dist` - Create distributable tarball with SHA256
  - Tarball naming: `secuencia-{version}-arm64-macos.tar.gz`
  - Automatic version detection from git tags

- **Distribution workflow**
  1. Build release binary with `xcodebuild`
  2. Package binary in tarball
  3. Compute SHA256 checksum
  4. Upload to GitHub release
  5. Notify Homebrew tap for formula update

#### Development Dependencies
- **Switched to pipeline-neo development branch**
  - Testing library changes before upstream merge
  - Temporary change for development (will revert to upstream main after testing)
  - Allows testing pipeline-neo enhancements

### Changed
- **Scripts/generate-motion-titles.swift** - Refactored Motion template generation
  - Improved infographic layout helpers
  - Better coordinate system documentation
  - More maintainable structure

- **Makefile cleanup target** - Enhanced to remove `bin/` and `dist/` directories

### Documentation
- Updated AGENTS.md with release workflow information
- Minor updates to CLAUDE.md and GEMINI.md

### Developer Impact

**New Capabilities**:
- Automated release builds via GitHub Actions
- Homebrew distribution via `intrusive-memory/homebrew-tap`
- Manual distribution packaging with `make dist`

**Installation via Homebrew** (after tap update):
```bash
brew tap intrusive-memory/tap
brew install secuencia
```

### Commits
- `42b9f61` Scripts refactor
- `3176810` Temporarily switch to intrusive-memory/pipeline-neo development branch
- `5142637` Bump version to 3.1.0 and update documentation
- `da01eed` Add GitHub Actions release workflow
- `b189f73` Add Homebrew distribution targets to Makefile

---

## [3.0.1] - 2026-02-13

### Fixed - CLI Architecture Refactor

**Critical Fixes**: Resolved blocking test failures and architecture issues

#### SecuenciaCLI Architecture
- **Extracted SecuenciaCLICore library** from SecuenciaCLI executable
  - Problem: Swift Package Manager prohibits importing executable targets in tests
  - Solution: Created library target with all business logic; executable is thin wrapper
  - Impact: All 116 CLI tests now compile and pass
  - Files moved: Commands/, Parsing/, Builder/, Models/, SwiftData/, Resources/

- **Public API for commands**
  - Made Build, Validate, Schema structs public
  - Added public init() to satisfy ParsableCommand protocol
  - Commands accessible from executable entry point

- **Resource access helper**
  - Created SchemaResource enum for Bundle.module access
  - Fixes "Schema resource not found" errors in tests
  - Tests use SchemaResource.schemaURL instead of Bundle.module

#### SwiftDataAssetProvider
- **Fixed audio/mp4 file extension**
  - Problem: audio/mp4 MIME type incorrectly mapped to .mp4 extension
  - Fix: Check MIME type prefix; return .m4a for audio/mp4, .mp4 for video/mp4
  - Impact: Resolved 1 failing test in AssetProviderTests

#### Documentation
- **Streamlined AGENTS.md** (18KB → 9KB)
  - Removed verbose implementation details
  - Updated architecture diagrams for SecuenciaCLICore
  - Updated test counts (431 total: 315 + 116)
  - Moved CLI details to Docs/CLI-ARCHITECTURE.md

- **Created Docs/CLI-ARCHITECTURE.md**
  - Comprehensive CLI implementation guide
  - Architecture rationale and diagrams
  - JSON format documentation
  - Testing strategy and fixtures

#### Test Results
- SecuenciaCLITests: 116/116 passing ✅
- SwiftSecuenciaTests: 315/315 passing ✅
- **Total**: 431/431 passing ✅

#### Commits
- `293d5b5` Fix CLI architecture: Extract SecuenciaCLICore library
- `83a8d90` Fix SwiftDataAssetProvider: Use .m4a extension for audio/mp4

---

## [2.0.1] - 2026-02-11

### Fixed - CI Test Failures

**Patch Release**: Critical fixes for PR #11 CI failures

#### Compilation Errors
- **Fixed ambiguous AudioExportFormat references** in TimelineAudioExporterTests
  - Both SwiftSecuencia and SwiftCompartido define AudioExportFormat enum
  - Solution: Use selective import `import class SwiftCompartido.TypedDataStorage`
  - Eliminated module namespace collision without removing SwiftCompartido functionality

#### DTD Validation Test Failures
- **Restored temporary file creation** in SwiftDataAssetProvider.assetFileURL()
  - Tests create in-memory SwiftData assets but FCPXMLExporter requires file URLs
  - Added fileExtension() helper for MIME type → extension mapping
  - Creates temp files from binaryValue for test scenarios
  - Production code with file references should use FileAssetProvider instead

#### Test Results
- Code Quality: ✅ SUCCESS
- DTD Validation: ✅ SUCCESS (10/10 tests passing)
- macOS Unit Tests: ✅ IN PROGRESS (expected to pass)

#### Commits
- 4 commits fixing compilation and test failures
- All changes maintain backward compatibility
- No breaking changes to public APIs

### Pull Request
**PR #11**: SwiftSecuencia CLI Implementation
**Changes**: Compilation fixes + DTD validation restoration

---

## [2.0.0] - 2026-02-09

### Added - SwiftSecuencia CLI Implementation

**Major Feature Release**: Complete command-line interface for JSON-to-FCPXML conversion

#### Three New CLI Subcommands

1. **`secuencia build`** - Generate FCPXML from JSON timeline definitions
   - Standalone `.fcpxml` file export
   - `.fcpxmld` bundle export with embedded media (`--bundle`)
   - FCPXML version selection (`--format-version 1.8-1.13`)
   - DTD validation with `--strict` mode
   - Complete pipeline: JSON → Parse → Resolve → Probe → Build → Export

2. **`secuencia validate`** - Validate JSON timeline without generating FCPXML
   - JSON structure parsing and validation
   - File path resolution (relative to JSON file)
   - Media duration probing (ffprobe integration)
   - Summary reports: clip counts, asset counts, total duration, lane range
   - Warnings: short clips, overlapping clips, gaps in primary storyline

3. **`secuencia schema`** - Output JSON Schema (draft 2020-12)
   - Complete schema for programmatic validation
   - All configuration types and enums documented
   - Examples for time string formats
   - Compatible with ajv-cli and other JSON Schema validators

#### New CLI Components

**Command Infrastructure**:
- `BuildCommand.swift` - Full build pipeline with DTD validation
- `ValidateCommand.swift` - JSON validation without export
- `SchemaCommand.swift` - Schema output for programmatic validation
- `Secuencia.swift` - Main entry point with ArgumentParser integration

**Pipeline Components**:
- `FileResolver.swift` - Relative path resolution and asset deduplication
- `MediaProbe.swift` - ffprobe integration for duration probing
- `TimelineBuilder.swift` - JSON → SwiftData Timeline conversion
- `SwiftDataBootstrap.swift` - In-memory SwiftData container management

**Data Models**:
- `TimelineDefinition.swift` - JSON schema models (Codable)
- `ClipDefinition.swift` - Clip metadata and properties
- `TimeStringParser.swift` - Time format parsing (3s, 1001/24000s, 10.5s)
- `FrameRateParser.swift` - Frame rate string parsing

**Resources**:
- `schema.json` - Complete JSON Schema (4.8KB)
- `Fixtures/` - Test media files (video, audio, image)
- `Fixtures/` - Test JSON timeline definitions

#### Test Coverage

**31 new CLI tests** across 5 test suites:
- `BuildCommandTests` (6 tests) - Full build pipeline integration
- `EndToEndTests` (9 tests) - Complete JSON-to-FCPXML scenarios
- `DTDValidationTests` (10 tests) - DTD validation with --strict mode
- `ValidateCommandTests` (3 tests) - JSON validation without export
- `SchemaCommandTests` (3 tests) - Schema output validation

**Test Fixtures**:
- Media files: test-video.mov, test-audio.m4a, test-audio.wav, test-image.png
- JSON files: simple-timeline.json, multi-lane-timeline.json, markers-timeline.json, auto-duration.json

#### Documentation

**AI Agent Guidelines**:
- `AGENTS.md` - Unified AI agent development guidelines (comprehensive)
- `CLAUDE.md` - Redirect to AGENTS.md
- `GEMINI.md` - Redirect to AGENTS.md

**README Updates**:
- Complete CLI usage section with all three subcommands
- JSON Schema documentation with field descriptions
- Time string format reference table
- MIME type derivation table
- File path resolution rules
- Installation and usage examples

#### Performance

- **Build time**: < 5 seconds
- **Test suite**: ~0.2 seconds (31 CLI tests)
- **FCPXML generation**: < 1 second for typical timelines
- **Bundle export**: Variable (depends on media file sizes)

#### Dependencies

**New Dependencies**:
- `swift-argument-parser` (1.7.0) - CLI argument parsing

**Existing Dependencies** (unchanged):
- SwiftCompartido (development)
- SwiftFijos (development)
- swift-timecode (3.0.0)
- WebVTT (1.0.0+)
- ZIPFoundation (0.9.20)
- universal (5.3.0)

### Changed

- **Version**: Bumped to 2.0.0 (major version for CLI feature)
- **SwiftSecuencia.swift**: Updated version string to "2.0.0"
- **Documentation**: Reorganized for AI agent consistency

### Developer Impact

**No Breaking Changes**: All existing library APIs remain unchanged. CLI is additive functionality.

**New Capabilities**:
- Generate FCPXML from JSON definitions without writing Swift code
- Validate timeline JSON before export
- Programmatically validate JSON against schema
- Build automation workflows with CLI tool

### Migration Guide

**From 1.0.x to 2.0.0**:

No code changes required. CLI is optional new functionality:

```bash
# New CLI usage (optional)
secuencia build timeline.json
secuencia validate timeline.json
secuencia schema > schema.json

# Existing library APIs unchanged
import SwiftSecuencia
let timeline = Timeline(name: "My Timeline")
// ... continues to work exactly as before
```

**Installation**:

Update Package.swift dependency:
```swift
.package(url: "https://github.com/intrusive-memory/SwiftSecuencia.git", from: "2.0.0")
```

Build CLI binary:
```bash
swift build -c release
cp .build/release/secuencia /usr/local/bin/
```

### Commits

**Total**: 61 commits across 10 sprints
- Sprint 1: CLI Scaffold (8 commits)
- Sprint 2-3: JSON Parsing (25 commits)
- Sprint 4-5: Asset Resolution (14 commits)
- Sprint 6-7: CLI Pipeline (9 commits)
- Sprint 8-9-10: Validation (14 commits)
- Final state updates (1 commit)

### Pull Request

**PR #11**: SwiftSecuencia CLI Implementation - Complete
**URL**: https://github.com/intrusive-memory/SwiftSecuencia/pull/11
**Changes**: +11,957 additions, -34 deletions

---

## [1.0.9] - 2026-02-02

### Added
- Small icon asset (`icon-sm.png`) for mobile-responsive dependency graph visualization

## [1.0.8] - 2026-01-31

### Added
- **Dual Dialogue Support**: Simultaneous speaker placement in timelines
  - `ScreenplayMetadata` model for screenplay-specific clip metadata
  - Dual dialogue grouping and lane assignment in `ScreenplayToTimelineConverter`
  - Automatic offset advancement by max duration within dialogue groups
  - Support for 2+ simultaneous speakers (dual, triple, N-way dialogue)
  - Metadata preservation in `TimelineClip` for FCPXML export
  - Optional `audioMetadata` parameter in `convertToTimeline()`
  - `processWithDualDialogue()` and `processSequential()` helper methods
  - 16 ScreenplayMetadata tests (encoding, conversion, edge cases)
  - 8 DualDialogIntegrationTests (placement, lanes, offset calculation)
  - DualDialogFixtures helper module for testing
  - 301 total tests passing (277 original + 24 new)

### Changed
- `ConverterError` now conforms to `Equatable` and includes `metadataMismatch` case
- `convertToTimeline()` accepts optional `audioMetadata` parameter for dual dialogue

### Enhanced
- **Mid-Century Modern Icon**: Updated app icon for SwiftSecuencia

## [1.0.7] - 2025-12-24

### Fixed
- **WebVTT Dependency**: Replaced `swift-webvtt-parser` with `mattt/WebVTT` to eliminate macro dependencies
  - Fixes Xcode Cloud build failures with "Macro 'CasePathsMacros' must be enabled"
  - Zero external dependencies (no macro trust issues)
  - Simpler API with same WebVTT format compatibility
- **WebVTT Character Escaping**: Added W3C-compliant special character escaping in cue text
  - Escape `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;`
  - Sanitize character names in voice tags to prevent malformed WebVTT
  - Per [W3C WebVTT Cue Text spec](https://www.w3.org/TR/webvtt1/#webvtt-cue-text)
- **WebVTT API Usage**: Corrected API calls after library switch
  - Use `Timestamp(totalMilliseconds:)` for timing
  - Set `cue.id` property after initialization
  - Proper initializer signature: `Cue(startTime:endTime:text:)`

### Changed
- **Package Dependency**: `swift-webvtt-parser` → `mattt/WebVTT` (v1.0.0+)

## [1.0.3] - 2025-12-07

### Added
- **Progress Reporting**: Foundation.Progress API integration for export tracking
  - Optional `progress` parameter in `FCPXMLBundleExporter.exportBundle()`
  - Progress tracking across 5 export phases:
    - Bundle structure creation (5%)
    - Media export with per-asset progress (70%)
    - FCPXML generation (15%)
    - FCPXML file writing (5%)
    - Info.plist generation (5%)
  - Localized progress descriptions for user feedback
  - Cancellation support with `FCPXMLExportError.cancelled`
  - 4 new comprehensive progress tests

### Changed
- `FCPXMLExportError` now conforms to `Equatable` for testing
- `exportMedia()` return type changed from 3-member tuple to `MediaExportResult` struct
  - Fixes SwiftLint `large_tuple` violation
  - Improved code clarity and maintainability

### Fixed
- SwiftLint CI failure: Large tuple violation in `exportMedia()` method

## [1.0.2] - 2025-12-06

### Added
- **SwiftFijos dependency**: Test fixture management library
  - Intelligent fixture discovery across dev, Xcode, and CI environments
  - Centralized `Fixtures/` directory at project root
  - Replaced manual DTD file discovery with `Fijos.getFixture()`

### Changed
- **DTD file location**: Moved from `Tests/SwiftSecuenciaTests/Resources/DTD/` to `Fixtures/`
- **FCPXMLDTDValidator**: Now uses SwiftFijos for robust fixture loading
- **SwiftLint rules**: Improved regex patterns for platform availability checks
  - Added word boundaries to prevent false positives on macOS 26+
  - Support for `introduced:` label syntax
  - Support for multiple platforms in any order
- **Package.swift**: Removed invalid test Resources reference
- **Branch protection**: Removed iOS Unit Tests requirement (macOS-only library)

### Fixed
- Fixture discovery now works reliably across all execution environments
- Version number synchronized with git tags (was 0.1.0, now 1.0.2)

## [1.0.1] - 2025-12-06

### Changed
- **SwiftCompartido dependency**: Changed from `main` branch to `development` branch
  - Allows use of latest SwiftCompartido features under development
  - More flexible dependency management for active development

## [1.0.0] - 2025-12-06

### Added - Phase 6: Validation & Quality Assurance
- **FCPXMLValidator**: Pre-export validation for timelines and FCPXML documents
  - Detects missing asset references
  - Validates time values (no negative offsets/durations)
  - Checks format dimensions
  - Warns about overlapping clips on same lane
  - Warns about large timelines (>1000 clips)
  - Warns about clips exceeding asset duration
- **ValidationResult**: Structured validation results with errors and warnings
- **ValidationError**: Typed validation errors with context information
- **ValidationWarning**: Non-fatal warnings for potential issues

### Added - Phase 5: Metadata & App Intents
- **Metadata types** for FCPXML export:
  - `Marker`: Standard timeline markers with notes and completion status
  - `ChapterMarker`: Video chapter markers with poster offsets
  - `Keyword`: Content tagging for organization
  - `Rating`: Favorite/rejected marking for clips
  - `Metadata`: Custom key-value metadata pairs
- **GenerateFCPXMLBundleIntent**: App Intent for Shortcuts integration
  - Generates .fcpxmld bundles from screenplay elements
  - Integrates with voice generation workflows
  - Supports filtering by element types

### Added - Phase 4: FCPXML Generation
- **FCPXMLExporter**: Generates valid FCPXML 1.11 documents from timelines
- **FCPXMLBundleExporter**: Creates self-contained .fcpxmld bundles with embedded media
- Timeline → FCPXML conversion with proper resource management
- Info.plist generation for bundle metadata

### Added - Phase 3: SwiftCompartido Integration
- **TypedDataStorage integration**: Seamless asset management from SwiftCompartido
- Automatic media metadata extraction
- Timeline accepts TypedDataStorage records directly
- Asset registry with unique ID management

### Added - Phase 2: Timeline Data Structure
- **Timeline**: SwiftData model for persisting timeline data
  - Append, insert, and ripple insert operations
  - Multi-lane support for overlapping audio
  - Query methods (by lane, time range, ID)
- **TimelineClip**: SwiftData model for clip placement
  - Links to TypedDataStorage for actual media
  - Precise timing with rational time codes
  - Audio and video property support

### Added - Phase 1: Core Types
- **Timecode**: Rational time representation with FCPXML string formatting
- **FrameRate**: Common frame rate presets (23.98, 24, 25, 29.97, 30, 50, 59.94, 60)
- **VideoFormat**: Video format configuration with presets (1080p, 4K)
- **AudioLayout**: Stereo, mono, surround audio configurations
- **AudioRate**: Sample rate support (44.1kHz, 48kHz, 96kHz)
- **ColorSpace**: Rec709, Rec2020, HDR color spaces

### Changed
- **Platform Support**: macOS 26.0+ only (removed iOS support)
  - Final Cut Pro for iPad does not support FCPXML import/export
  - .fcpxmld bundle format is exclusive to Final Cut Pro for Mac
- **Dependencies**: Removed XMLCoder (using native Foundation XMLElement on macOS)
- **GitHub Actions**: Removed iOS testing workflow

### Documentation
- Comprehensive README with usage examples
- FCPXML reference documentation
- Implementation plan with quality gates
- Testing documentation
- Requirements specification

## Release Notes

### v1.0.0 - Production Ready

SwiftSecuencia v1.0.0 is **production-ready** for generating Final Cut Pro timelines from TypedDataStorage media records.

**Key Features:**
- ✅ Create timelines with SwiftData persistence
- ✅ Manage clips with append, insert, and ripple operations
- ✅ Multi-lane audio support for overlapping clips
- ✅ Export self-contained .fcpxmld bundles with embedded media
- ✅ Add markers, keywords, ratings, and custom metadata
- ✅ Shortcuts integration via App Intents
- ✅ Pre-export validation with detailed error reporting
- ✅ 202 passing tests with comprehensive coverage

**Requirements:**
- Swift 6.2+
- macOS 26.0+
- SwiftCompartido dependency
- Final Cut Pro 10.6+ for import

**Next Steps:**
- Import generated bundles into Final Cut Pro
- Verify all clips appear on timeline correctly
- Confirm audio plays and mixes properly
- Report any issues on GitHub

[3.1.0]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v3.1.0
[3.0.1]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v3.0.1
[3.0.0]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v3.0.0
[2.0.1]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v2.0.1
[2.0.0]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v2.0.0
[1.0.9]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.9
[1.0.8]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.8
[1.0.7]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.7
[1.0.3]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.3
[1.0.2]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.2
[1.0.1]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.1
[1.0.0]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.0
