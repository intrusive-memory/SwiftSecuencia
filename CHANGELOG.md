# Changelog

All notable changes to SwiftSecuencia will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.3]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.3
[1.0.2]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.2
[1.0.1]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.1
[1.0.0]: https://github.com/intrusive-memory/SwiftSecuencia/releases/tag/v1.0.0
