# Atomicity Analysis - Context Window Risk Assessment

This document identifies tasks that are too large and proposes atomic splits.

---

## Risk Assessment Scale

- 🟢 **SAFE** (< 300 lines context) - Single file, clear scope, minimal dependencies
- 🟡 **MODERATE** (300-800 lines) - Multiple files or complex logic, manageable
- 🔴 **HIGH RISK** (> 800 lines) - Large production files, multiple concerns, should split

---

## Sprint 1: CLI Scaffold

### Task 1: Package.swift setup
**Risk**: 🟢 SAFE (~20 lines)
**Verdict**: Keep as-is

### Task 2: Secuencia.swift entry point
**Risk**: 🟢 SAFE (~30 lines)
**Verdict**: Keep as-is

### Task 3: BuildCommand stub
**Risk**: 🟢 SAFE (~40 lines)
**Verdict**: Keep as-is

### Task 4: TimelineDefinition models
**Risk**: 🟡 MODERATE (~150 lines - 5 structs + enum)
**Context**: ClipDefinition, TimelineConfig, FormatConfig, AudioConfig, ClipType, TimelineDefinition
**Verdict**: Keep as-is (simple Codable structs, no complex logic)

### Task 5: TimelineDefinition tests
**Risk**: 🟢 SAFE (~80 lines)
**Verdict**: Keep as-is

**Sprint 1 Total**: 🟢 SAFE - No splits needed

---

## Sprint 2: JSON parsing and time string parsing

All tasks are single-purpose parsers with dedicated test files.

**Sprint 2 Total**: 🟢 SAFE - No splits needed

---

## Sprint 3: File resolution and media probing

### Task 1: FileResolver
**Risk**: 🟡 MODERATE (~120 lines for 2 methods)
**Concerns**:
- `resolve()` - file path resolution with validation
- `deduplicateAssets()` - UUID mapping with SHA256
**Split Proposal**: ✅ **SPLIT RECOMMENDED**

**Task 1a: File path resolution**
- Create FileResolver struct
- Implement `resolve(definition:relativeTo:)` method only
- Validates paths, throws on missing files
- Returns definition with absolute paths
- Test: relative paths, absolute paths, missing files

**Task 1b: Asset deduplication**
- Add `deduplicateAssets(in:)` method to FileResolver
- Implement deterministic UUID generation (Appendix B)
- Test: same path → same UUID, different paths → different UUIDs

### Task 2: MediaProbe
**Risk**: 🟡 MODERATE (~150 lines for 3 methods)
**Concerns**:
- `duration(of:)` - async AVAsset probing
- `mimeType(of:)` - extension mapping
- `probeMissingDurations(in:)` - iteration + probing
**Split Proposal**: ✅ **SPLIT RECOMMENDED**

**Task 2a: MIME type detection**
- Create MediaProbe struct
- Implement `mimeType(of:)` method only
- Extension → MIME type mapping (see table in plan)
- Test: all extensions from table, unknown extension

**Task 2b: Duration probing**
- Add `duration(of:)` method to MediaProbe
- AVAsset async API
- Test: defer to Sprint 8 (requires real media)

**Task 2c: Batch duration probing**
- Add `probeMissingDurations(in:)` method
- Iterates clips, probes missing durations
- Test: defer to Sprint 8 (requires real media)

### Updated Sprint 3 Task List

1. **Task 1a**: File path resolution
2. **Task 1b**: Asset deduplication with deterministic UUIDs
3. **Task 2a**: MIME type detection from file extensions
4. **Task 2b**: Single file duration probing with AVAsset
5. **Task 2c**: Batch duration probing for timeline definitions
6. **Task 3**: Create test fixtures (unchanged)
7. **Task 4**: FileResolver tests (split into 4a and 4b)
8. **Task 5**: MediaProbe tests (split into 5a, 5b, 5c)
9. **Task 6**: Update BuildCommand to print summary (unchanged)

**Sprint 3 Total**: 🟡 MODERATE - **Split into 9 tasks** (was 6)

---

## Sprint 4: AssetProvider protocol

All tasks are cleanly separated by type (protocol, two implementations, tests).

**Sprint 4 Total**: 🟢 SAFE - No splits needed

---

## Sprint 5: Refactor exporters to use AssetProvider

### Task 1: Modify FCPXMLExporter
**Risk**: 🔴 **HIGH RISK** (~400 lines existing + 100 lines new)
**Concerns**:
- Read existing export() method (~200 lines)
- Add new export(assetProvider:) method (~100 lines)
- Update asset generation logic (~50 lines)
- Keep backward compat wrapper (~20 lines)
**Split Proposal**: ✅ **SPLIT REQUIRED**

**Task 1a: Add AssetProvider export method signature**
- Add new `export(timeline:assetProvider:...)` method to FCPXMLExporter
- Stub implementation that throws "Not implemented"
- No changes to existing export(timeline:modelContext:) yet
- Test: verify method exists and throws

**Task 1b: Implement resource collection with AssetProvider**
- In new method: collect unique asset IDs from timeline.clips
- Call assetProvider.assetMetadata(for:) for each
- Generate format element (unchanged from existing)
- Test: verify asset metadata collection works

**Task 1c: Implement asset element generation with AssetProvider**
- Generate asset elements using assetProvider.assetFileURL(for:)
- Use metadata.hasVideo and metadata.hasAudio flags
- Replace placeholder URLs with real file:/// URLs
- Test: verify asset elements have correct URLs and flags

**Task 1d: Complete FCPXMLExporter integration**
- Complete the new export method with full document structure
- Add backward compat wrapper using SwiftDataAssetProvider
- Test: verify new method produces valid FCPXML
- Test: verify old method still works (backward compat)

### Task 2: Modify FCPXMLBundleExporter
**Risk**: 🔴 **HIGH RISK** (~700 lines existing + 200 lines new)
**Concerns**:
- Read existing exportBundle() method (~400 lines)
- Add new exportBundle(assetProvider:) method (~200 lines)
- Add convertAudioToM4A() method (Appendix D, ~100 lines)
- Update media export logic (~100 lines)
- Fallback chain logic (~50 lines)
**Split Proposal**: ✅ **SPLIT REQUIRED**

**Task 2a: Add audio conversion helper**
- Add private `convertAudioToM4A(from:to:)` method (Appendix D)
- No integration yet, just the standalone method
- Test: create minimal test that converts a .wav fixture to .m4a

**Task 2b: Add AssetProvider export method signature**
- Add new `exportBundle(timeline:assetProvider:...)` method
- Stub implementation that throws "Not implemented"
- No changes to existing method yet
- Test: verify method exists and throws

**Task 2c: Implement bundle structure creation**
- In new method: create .fcpxmld directory structure
- Create Media/ subdirectory
- No media copying yet
- Test: verify directory structure created

**Task 2d: Implement media export with AssetProvider**
- Implement media file copying for video/image
- Implement M4A detection and copy
- Implement audio conversion for non-M4A
- Use assetProvider.assetFileURL(for:) with fallback to assetData
- Log warning when fallback to assetData is used
- Test: verify M4A copied, non-M4A converted, video/image copied

**Task 2e: Complete FCPXMLBundleExporter integration**
- Generate Info.fcpxml using FCPXMLExporter with relative paths
- Generate Info.plist
- Add backward compat wrapper
- Test: full bundle export with FileAssetProvider
- Test: verify old method still works

### Updated Sprint 5 Task List

1. **Task 1a**: FCPXMLExporter - Add AssetProvider method signature
2. **Task 1b**: FCPXMLExporter - Resource collection
3. **Task 1c**: FCPXMLExporter - Asset element generation
4. **Task 1d**: FCPXMLExporter - Complete integration + backward compat
5. **Task 2a**: FCPXMLBundleExporter - Add audio conversion helper
6. **Task 2b**: FCPXMLBundleExporter - Add AssetProvider method signature
7. **Task 2c**: FCPXMLBundleExporter - Bundle structure creation
8. **Task 2d**: FCPXMLBundleExporter - Media export logic
9. **Task 2e**: FCPXMLBundleExporter - Complete integration + backward compat
10. **Task 3**: Update FCPXMLExportTests (for tasks 1a-1d)
11. **Task 4**: Update FCPXMLBundleExportTests (for tasks 2a-2e)
12. **Task 5**: Run FULL test suite (regression check)

**Sprint 5 Total**: 🔴 HIGH RISK - **Split into 12 tasks** (was 5)

**IMPORTANT**: Tasks 1a-1d should be done sequentially (build incrementally). Same for 2a-2e.

---

## Sprint 6: SwiftData bootstrap and timeline builder

### Task 1: SwiftDataBootstrap
**Risk**: 🟢 SAFE (~60 lines)
**Verdict**: Keep as-is

### Task 2: TimelineBuilder
**Risk**: 🔴 **HIGH RISK** (~250 lines)
**Concerns**:
- Create Timeline
- Map FormatConfig → VideoFormat (with frame rate parsing)
- Map AudioConfig → AudioLayout + AudioRate
- Build FileAssetProvider and populate entries
- Process non-marker clips (parse offset/duration, create TimelineClip)
- Process marker clips (parse offset, create Marker/ChapterMarker)
**Split Proposal**: ✅ **SPLIT REQUIRED**

**Task 2a: Timeline creation and format mapping**
- Create TimelineBuilder struct
- Implement Timeline creation from definition.timeline.name
- Map FormatConfig → VideoFormat (using FrameRateParser)
- Map AudioConfig → AudioLayout + AudioRate
- Test: verify Timeline has correct format settings

**Task 2b: FileAssetProvider population**
- Build FileAssetProvider from assetMap
- For each unique file: create FileAssetEntry with metadata
- Derive hasVideo/hasAudio from MIME type
- Test: verify provider has one entry per unique file
- Test: verify metadata (name, mimeType, hasVideo, hasAudio)

**Task 2c: Non-marker clip processing**
- Iterate non-marker clips from definition
- Parse offset and duration via TimeStringParser
- Look up asset UUID from assetMap
- Create TimelineClip with all properties (lane, volume, opacity)
- Append to timeline
- Test: verify clips created with correct offsets, durations, lanes

**Task 2d: Marker clip processing**
- Iterate marker clips from definition
- Parse offset via TimeStringParser
- Create Marker or ChapterMarker based on markerType (Appendix C)
- Append to timeline.markers or timeline.chapterMarkers
- Test: verify markers added at correct offsets
- Test: verify chapter vs standard marker types

**Task 2e: Complete build() method**
- Integrate all pieces: Timeline + FileAssetProvider + clips + markers
- Return (Timeline, FileAssetProvider) tuple
- Test: full integration with 2-clip definition
- Test: mixed sequential and dual dialogue (if applicable)

### Updated Sprint 6 Task List

1. **Task 1**: SwiftDataBootstrap (unchanged)
2. **Task 2a**: TimelineBuilder - Timeline creation and format mapping
3. **Task 2b**: TimelineBuilder - FileAssetProvider population
4. **Task 2c**: TimelineBuilder - Non-marker clip processing
5. **Task 2d**: TimelineBuilder - Marker clip processing
6. **Task 2e**: TimelineBuilder - Complete build() integration
7. **Task 3**: TimelineBuilder tests (split across 2a-2e)
8. **Task 4**: SwiftDataBootstrap tests (unchanged)

**Sprint 6 Total**: 🟡 MODERATE - **Split into 8 tasks** (was 4)

---

## Sprint 7: Build command integration

### Task 1: Complete BuildCommand.run()
**Risk**: 🟡 MODERATE (~150 lines)
**Concerns**: 8-step pipeline, but mostly method calls
**Verdict**: Keep as-is (orchestration code, each step is a simple method call)

### Task 2: BuildCommand tests
**Risk**: 🟢 SAFE (~80 lines)
**Verdict**: Keep as-is

**Sprint 7 Total**: 🟢 SAFE - No splits needed

---

## Sprint 8: End-to-end tests with real media fixtures

### Task 4: EndToEndTests
**Risk**: 🟡 MODERATE (~200 lines - 5 test scenarios)
**Concerns**: Each test scenario is independent
**Split Proposal**: ✅ **SPLIT RECOMMENDED** (for clarity, not risk)

**Task 4a: Simple timeline export test**
- Test: simple-timeline.json → FCPXML
- Verify: fcpxml version, asset count, format element, clip offsets

**Task 4b: Multi-lane audio test**
- Test: audio clip on lane -1
- Verify: lane assignment in spine structure

**Task 4c: Marker export test**
- Test: markers-timeline.json → FCPXML
- Verify: chapter-marker elements at correct offsets

**Task 4d: Bundle export test**
- Test: simple-timeline.json → .fcpxmld bundle
- Verify: directory structure, Info.fcpxml, Media/ files
- Verify: M4A file size matches source (not transcoded)

**Task 4e: Auto-duration probing test**
- Test: auto-duration.json → media probing
- Verify: durations within tolerance (+/- 0.1s)

### Task 5: ErrorHandlingTests
**Risk**: 🟢 SAFE (~100 lines - 5 error scenarios)
**Verdict**: Keep as single file (all error cases, logical grouping)

### Updated Sprint 8 Task List

1. **Task 1**: Check for ffmpeg (unchanged)
2. **Task 2**: Create test media fixtures (unchanged)
3. **Task 3**: Create JSON fixture files (unchanged)
4. **Task 4a**: Simple timeline export test
5. **Task 4b**: Multi-lane audio test
6. **Task 4c**: Marker export test
7. **Task 4d**: Bundle export test
8. **Task 4e**: Auto-duration probing test
9. **Task 5**: ErrorHandlingTests (unchanged)

**Sprint 8 Total**: 🟢 SAFE - **Split into 9 tasks** (was 5)

---

## Sprint 9: DTD validation

### Task 2: DTDValidationTests
**Risk**: 🟡 MODERATE (~150 lines - 7 test scenarios)
**Verdict**: Keep as single file (all validation tests, logical grouping)

**Sprint 9 Total**: 🟢 SAFE - No splits needed

---

## Sprint 10: Validate command, schema, and documentation

### Task 2: schema.json
**Risk**: 🟡 MODERATE (~200 lines JSON Schema)
**Concerns**: Complete schema with all definitions
**Split Proposal**: ✅ **SPLIT RECOMMENDED**

**Task 2a: Schema structure and timeline definition**
- Create schema.json with $schema, $id, title
- Define top-level structure (timeline, clips)
- Define TimelineConfig, FormatConfig, AudioConfig
- Test: validate example JSON decodes successfully

**Task 2b: Schema clip definitions and enums**
- Define ClipDefinition with all fields
- Define all enum values (type, markerType, colorSpace, layout, rate, frameRate)
- Add descriptions and examples for time strings
- Test: schema validates simple-timeline.json from Sprint 8

### Task 5: Add --help descriptions
**Risk**: 🟡 MODERATE (~100 lines across 3 commands)
**Concerns**: Touch Build, Validate, Schema commands
**Split Proposal**: ✅ **SPLIT RECOMMENDED**

**Task 5a: BuildCommand --help descriptions**
- Add help text to all BuildCommand arguments and options
- inputFile, output, bundle, formatVersion, strict

**Task 5b: ValidateCommand --help descriptions**
- Add help text to ValidateCommand arguments

**Task 5c: SchemaCommand --help descriptions**
- Add help text to SchemaCommand (if any arguments)

### Updated Sprint 10 Task List

1. **Task 1**: ValidateCommand implementation (unchanged)
2. **Task 2a**: schema.json - Structure and timeline definitions
3. **Task 2b**: schema.json - Clip definitions and enums
4. **Task 3**: SchemaCommand implementation (unchanged)
5. **Task 4**: Register subcommands (unchanged)
6. **Task 5a**: BuildCommand --help descriptions
7. **Task 5b**: ValidateCommand --help descriptions
8. **Task 5c**: SchemaCommand --help descriptions
9. **Task 6**: Update README (unchanged)
10. **Task 7**: ValidateCommand tests (unchanged)
11. **Task 8**: SchemaCommand tests (unchanged)

**Sprint 10 Total**: 🟡 MODERATE - **Split into 11 tasks** (was 8)

---

## Summary of Atomicity Changes

| Sprint | Original Tasks | Atomic Tasks | Change | Risk Before | Risk After |
|--------|----------------|--------------|--------|-------------|------------|
| Sprint 1 | 5 | 5 | None | 🟢 SAFE | 🟢 SAFE |
| Sprint 2 | 6 | 6 | None | 🟢 SAFE | 🟢 SAFE |
| Sprint 3 | 6 | 9 | +3 split | 🟡 MODERATE | 🟢 SAFE |
| Sprint 4 | 4 | 4 | None | 🟢 SAFE | 🟢 SAFE |
| Sprint 5 | 5 | 12 | +7 split | 🔴 HIGH RISK | 🟡 MODERATE |
| Sprint 6 | 4 | 8 | +4 split | 🔴 HIGH RISK | 🟡 MODERATE |
| Sprint 7 | 2 | 2 | None | 🟢 SAFE | 🟢 SAFE |
| Sprint 8 | 5 | 9 | +4 split | 🟡 MODERATE | 🟢 SAFE |
| Sprint 9 | 3 | 3 | None | 🟢 SAFE | 🟢 SAFE |
| Sprint 10 | 8 | 11 | +3 split | 🟡 MODERATE | 🟢 SAFE |
| **TOTAL** | **48** | **69** | **+21** | 2 HIGH RISK | 0 HIGH RISK |

---

## Key Improvements

1. **Eliminated HIGH RISK tasks**: Sprint 5 and 6 broken into incremental steps
2. **Sequential builds**: Large refactors now build incrementally with tests at each step
3. **Better testability**: Each atomic task has clear test criteria
4. **Reduced context**: No single task requires reading >400 lines of production code
5. **Better rollback**: Smaller commits allow easier rollback if issues arise

---

## Next Step: Generate Updated Sprint Specifications

The original EXECUTION_PLAN.md needs to be rewritten with these atomic task breakdowns.
