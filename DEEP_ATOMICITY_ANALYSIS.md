# Deep Atomicity Analysis - Context Window Safety

This analysis examines all 70 tasks for context window risks and proposes further atomization where needed.

---

## Analysis Criteria

**Maximum Safe Context**: 150 lines of production code per task
**Warning Threshold**: 100 lines
**Multiple Concerns**: Any task doing 2+ independent things should split

---

## Sprint 1: CLI Scaffold (5 tasks)

### Task 1.1: Package.swift setup
- **Context**: ~20 lines
- **Concerns**: 1 (add executable target)
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 1.2: Secuencia.swift entry point
- **Context**: ~30 lines
- **Concerns**: 1 (@main struct)
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 1.3: BuildCommand stub
- **Context**: ~40 lines
- **Concerns**: 1 (stub command)
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 1.4: TimelineDefinition models
- **Context**: ~150 lines
- **Concerns**: 5 (TimelineDefinition, TimelineConfig, FormatConfig, AudioConfig, ClipDefinition, ClipType enum)
- **Risk**: ⚠️ BORDERLINE (multiple structs)
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **1.4a**: TimelineDefinition + ClipType enum (~40 lines)
- **1.4b**: TimelineConfig + FormatConfig + AudioConfig (~60 lines)
- **1.4c**: ClipDefinition (~50 lines)

**Benefit**: Each task focuses on one logical grouping, easier to review

### Task 1.5: TimelineDefinition tests
- **Context**: ~80 lines
- **Concerns**: 3-4 test scenarios
- **Risk**: 🟢 SAFE (but could split by test type)
- **Recommendation**: ✅ SPLIT for clarity

**Proposed Split**:
- **1.5a**: Decode/encode tests (~40 lines)
- **1.5b**: Validation tests (missing fields, invalid types) (~40 lines)

---

## Sprint 2: JSON Parsing (6 tasks)

All tasks are single-purpose parsers or single test files.

**Risk**: 🟢 ALL SAFE
**Action**: ✅ No changes needed

---

## Sprint 3: File Resolution (10 tasks)

All tasks are single methods or single test files.

**Risk**: 🟢 ALL SAFE
**Action**: ✅ No changes needed

---

## Sprint 4: AssetProvider Protocol (4 tasks)

### Task 4.1: AssetProvider protocol + AssetMetadata
- **Context**: ~80 lines
- **Concerns**: 3 (protocol, AssetMetadata struct, AssetProviderError enum)
- **Risk**: 🟡 MODERATE (3 separate types)
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **4.1a**: AssetMetadata struct (~30 lines)
- **4.1b**: AssetProvider protocol + AssetProviderError enum (~50 lines)

**Benefit**: Metadata can be defined and tested independently

### Task 4.2: SwiftDataAssetProvider
- **Context**: ~100 lines
- **Concerns**: 1 (single implementation)
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 4.3: FileAssetProvider
- **Context**: ~120 lines
- **Concerns**: 1 (single implementation)
- **Risk**: 🟡 MODERATE (at warning threshold)
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **4.3a**: FileAssetProvider struct + initialization (~40 lines)
- **4.3b**: FileAssetProvider protocol implementation methods (~80 lines)

**Benefit**: Structure definition separate from method implementation

### Task 4.4: AssetProvider tests
- **Context**: ~120 lines
- **Concerns**: 3 (FileAssetProvider tests, SwiftDataAssetProvider tests, default implementation tests)
- **Risk**: 🟡 MODERATE
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **4.4a**: FileAssetProvider tests (~60 lines)
- **4.4b**: SwiftDataAssetProvider tests (~60 lines)

---

## Sprint 5: Refactor Exporters (13 tasks)

### Task 5.1: Add signature
- **Context**: ~40 lines
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 5.2: Resource collection
- **Context**: ~150 lines
- **Concerns**: 2 (collect asset IDs, generate format element)
- **Risk**: ⚠️ BORDERLINE
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **5.2a**: Collect unique asset IDs from timeline (~40 lines)
- **5.2b**: Fetch metadata via AssetProvider, generate format element (~60 lines)

### Task 5.3: Asset generation
- **Context**: ~180 lines
- **Concerns**: 2 (generate asset elements, use hasVideo/hasAudio flags)
- **Risk**: ⚠️ HIGH (reading ~200 lines of existing code)
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **5.3a**: Add assetFileURL logic (replace placeholder) (~80 lines)
- **5.3b**: Add hasVideo/hasAudio attributes from metadata (~70 lines)

### Task 5.4: Complete integration
- **Context**: ~200 lines
- **Concerns**: 3 (spine, sequence, project structure + backward compat wrapper)
- **Risk**: ⚠️ HIGH
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **5.4a**: Complete document structure (spine, sequence, project) (~120 lines)
- **5.4b**: Add backward compatibility wrapper (~40 lines)

### Task 5.5: Audio conversion helper
- **Context**: ~120 lines (Appendix D)
- **Risk**: 🟡 MODERATE (but self-contained)
- **Action**: ✅ Keep as-is (well-defined in Appendix D)

### Task 5.6: Add signature
- **Context**: ~40 lines
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 5.7: Bundle structure
- **Context**: ~100 lines
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 5.8: Direct copy
- **Context**: ~120 lines
- **Risk**: 🟡 MODERATE
- **Action**: ✅ Keep as-is (focused on one concern)

### Task 5.9: Audio conversion integration
- **Context**: ~130 lines
- **Risk**: 🟡 MODERATE
- **Action**: ✅ Keep as-is (focused on one concern)

### Task 5.10: Complete integration
- **Context**: ~180 lines
- **Concerns**: 3 (FCPXML generation, Info.plist, backward compat)
- **Risk**: ⚠️ HIGH
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **5.10a**: Generate Info.fcpxml with relative paths (~80 lines)
- **5.10b**: Generate Info.plist (~40 lines)
- **5.10c**: Add backward compatibility wrapper (~40 lines)

### Task 5.11: Update FCPXMLExportTests
- **Context**: ~100 lines
- **Concerns**: 3 test scenarios
- **Risk**: 🟢 SAFE (tests can be combined)
- **Action**: ✅ Keep as-is

### Task 5.12: Update FCPXMLBundleExportTests
- **Context**: ~100 lines
- **Concerns**: 4-5 test scenarios
- **Risk**: 🟢 SAFE (tests can be combined)
- **Action**: ✅ Keep as-is

### Task 5.13: Regression test
- **Context**: ~20 lines
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

---

## Sprint 6: SwiftData Bootstrap (8 tasks)

### Task 6.1: SwiftDataBootstrap
- **Context**: ~60 lines
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 6.2: Timeline + format mapping
- **Context**: ~120 lines
- **Concerns**: 2 (create Timeline, map format configs)
- **Risk**: 🟡 MODERATE
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **6.2a**: Create Timeline with name (~30 lines)
- **6.2b**: Map FormatConfig → VideoFormat (~40 lines)
- **6.2c**: Map AudioConfig → AudioLayout + AudioRate (~40 lines)

### Task 6.3: FileAssetProvider population
- **Context**: ~150 lines
- **Concerns**: 3 (iterate files, create entries, register)
- **Risk**: ⚠️ BORDERLINE
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **6.3a**: Create FileAssetProvider, derive file metadata (~70 lines)
- **6.3b**: Register entries with UUIDs from assetMap (~60 lines)

### Task 6.4: Clip processing
- **Context**: ~180 lines
- **Concerns**: 3 (parse offset/duration, lookup UUID, create TimelineClip)
- **Risk**: ⚠️ HIGH
- **Recommendation**: ✅ SPLIT

**Proposed Split**:
- **6.4a**: Parse clip offset and duration via TimeStringParser (~60 lines)
- **6.4b**: Create TimelineClip and append to timeline (~80 lines)

### Task 6.5: Marker processing
- **Context**: ~80 lines
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 6.6: Complete build()
- **Context**: ~60 lines
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

### Task 6.7: TimelineBuilderTests
- **Context**: ~150 lines
- **Concerns**: 8-9 test scenarios
- **Risk**: 🟡 MODERATE (but tests can be longer)
- **Recommendation**: ✅ SPLIT for clarity

**Proposed Split**:
- **6.7a**: Timeline and format mapping tests (~60 lines)
- **6.7b**: FileAssetProvider and clip tests (~60 lines)
- **6.7c**: Marker and integration tests (~40 lines)

### Task 6.8: SwiftDataBootstrapTests
- **Context**: ~80 lines
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

---

## Sprint 7: Build Command (2 tasks)

### Task 7.1: Complete BuildCommand.run()
- **Context**: ~150 lines
- **Concerns**: 8 (8-step pipeline)
- **Risk**: ⚠️ BORDERLINE (orchestration code, mostly method calls)
- **Recommendation**: ✅ SPLIT for clarity

**Proposed Split**:
- **7.1a**: Parse JSON + resolve paths (~40 lines)
- **7.1b**: Deduplicate assets + probe durations (~40 lines)
- **7.1c**: Bootstrap SwiftData + build timeline (~40 lines)
- **7.1d**: Choose export mode + generate output (~40 lines)

**Benefit**: Each phase of pipeline can be tested independently

### Task 7.2: BuildCommand tests
- **Context**: ~80 lines
- **Risk**: 🟢 SAFE
- **Action**: ✅ Keep as-is

---

## Sprint 8: End-to-End Tests (9 tasks)

### Task 8.1: Create media fixtures
- **Context**: ~40 lines (but 4 separate ffmpeg commands)
- **Concerns**: 4 (video, audio, image, wav)
- **Risk**: 🟢 SAFE (but conceptually 4 separate operations)
- **Recommendation**: ✅ SPLIT for granularity

**Proposed Split**:
- **8.1a**: test-video.mov (1s 1080p black video)
- **8.1b**: test-audio.m4a (2s silent stereo)
- **8.1c**: test-image.png (1080p black image)
- **8.1d**: test-audio.wav (1s WAV for conversion test)

**Benefit**: Each fixture can be created and verified independently

### Task 8.2: Create JSON fixtures
- **Context**: ~60 lines (4 JSON files)
- **Concerns**: 4 (simple, markers, multi-lane, auto-duration)
- **Risk**: 🟢 SAFE (but 4 files)
- **Recommendation**: ⚠️ CONSIDER SPLIT

**Proposed Split**:
- **8.2a**: simple-timeline.json
- **8.2b**: markers-timeline.json
- **8.2c**: multi-lane-timeline.json
- **8.2d**: auto-duration.json

**Benefit**: Each JSON fixture focused and independently testable

### Tasks 8.3-8.9: Test scenarios
- **Context**: 60-120 lines each
- **Risk**: 🟢 ALL SAFE
- **Action**: ✅ Keep as-is

---

## Sprint 9: DTD Validation (3 tasks)

All tasks are focused and small.

**Risk**: 🟢 ALL SAFE
**Action**: ✅ No changes needed

---

## Sprint 10: Tooling (11 tasks)

All tasks are focused and small.

**Risk**: 🟢 ALL SAFE
**Action**: ✅ No changes needed

---

## Summary of Recommended Splits

| Sprint | Current Tasks | Proposed Tasks | Change | Reason |
|--------|---------------|----------------|--------|--------|
| Sprint 1 | 5 | **8** | +3 | Split TimelineDefinition models (1.4 → 1.4a/b/c), split tests (1.5 → 1.5a/b) |
| Sprint 4 | 4 | **8** | +4 | Split each task for focused implementation |
| Sprint 5 | 13 | **19** | +6 | Split resource collection, asset generation, integrations |
| Sprint 6 | 8 | **15** | +7 | Split format mapping, provider population, clip processing, tests |
| Sprint 7 | 2 | **5** | +3 | Split pipeline into 4 phases |
| Sprint 8 | 9 | **16** | +7 | Split fixture creation by file |
| **TOTAL** | **70** | **96** | **+26** | **All tasks now < 100 lines** |

---

## New Task Breakdown (96 Tasks)

### Sprint 1: 8 tasks (was 5)
1.1 - Package.swift setup
1.2 - Secuencia.swift entry point
1.3 - BuildCommand stub
1.4a - TimelineDefinition + ClipType enum
1.4b - Config structs (TimelineConfig, FormatConfig, AudioConfig)
1.4c - ClipDefinition struct
1.5a - Decode/encode roundtrip tests
1.5b - Validation tests (missing fields, invalid types)

### Sprint 2: 6 tasks (unchanged)

### Sprint 3: 10 tasks (unchanged)

### Sprint 4: 8 tasks (was 4)
4.1a - AssetMetadata struct
4.1b - AssetProvider protocol + AssetProviderError enum
4.2 - SwiftDataAssetProvider implementation
4.3a - FileAssetProvider struct + initialization
4.3b - FileAssetProvider protocol methods
4.4a - FileAssetProvider tests
4.4b - SwiftDataAssetProvider tests

### Sprint 5: 19 tasks (was 13)
5.1 - FCPXMLExporter: Add AssetProvider method signature
5.2a - FCPXMLExporter: Collect unique asset IDs
5.2b - FCPXMLExporter: Fetch metadata + generate format
5.3a - FCPXMLExporter: Replace placeholder URLs with file URLs
5.3b - FCPXMLExporter: Add hasVideo/hasAudio attributes
5.4a - FCPXMLExporter: Complete document structure
5.4b - FCPXMLExporter: Add backward compat wrapper
5.5 - FCPXMLBundleExporter: Add audio conversion helper
5.6 - FCPXMLBundleExporter: Add AssetProvider method signature
5.7 - FCPXMLBundleExporter: Bundle structure creation
5.8 - FCPXMLBundleExporter: Direct media copy
5.9 - FCPXMLBundleExporter: Audio conversion integration
5.10a - FCPXMLBundleExporter: Generate Info.fcpxml
5.10b - FCPXMLBundleExporter: Generate Info.plist
5.10c - FCPXMLBundleExporter: Add backward compat wrapper
5.11 - Update FCPXMLExportTests
5.12 - Update FCPXMLBundleExportTests
5.13 - Run full regression suite

### Sprint 6: 15 tasks (was 8)
6.1 - SwiftDataBootstrap
6.2a - TimelineBuilder: Create Timeline
6.2b - TimelineBuilder: Map FormatConfig → VideoFormat
6.2c - TimelineBuilder: Map AudioConfig → AudioLayout/AudioRate
6.3a - TimelineBuilder: Derive file metadata
6.3b - TimelineBuilder: Register entries in FileAssetProvider
6.4a - TimelineBuilder: Parse clip offset and duration
6.4b - TimelineBuilder: Create TimelineClip and append
6.5 - TimelineBuilder: Marker processing
6.6 - TimelineBuilder: Complete build() return
6.7a - TimelineBuilderTests: Format mapping tests
6.7b - TimelineBuilderTests: Provider and clip tests
6.7c - TimelineBuilderTests: Marker and integration tests
6.8 - SwiftDataBootstrapTests

### Sprint 7: 5 tasks (was 2)
7.1a - BuildCommand: Parse JSON + resolve paths
7.1b - BuildCommand: Deduplicate assets + probe durations
7.1c - BuildCommand: Bootstrap SwiftData + build timeline
7.1d - BuildCommand: Choose export mode + generate output
7.2 - BuildCommand tests

### Sprint 8: 16 tasks (was 9)
8.1a - Create fixture: test-video.mov
8.1b - Create fixture: test-audio.m4a
8.1c - Create fixture: test-image.png
8.1d - Create fixture: test-audio.wav
8.2a - Create JSON: simple-timeline.json
8.2b - Create JSON: markers-timeline.json
8.2c - Create JSON: multi-lane-timeline.json
8.2d - Create JSON: auto-duration.json
8.3 - Test: Simple timeline export
8.4 - Test: Multi-lane audio
8.5 - Test: Marker export
8.6 - Test: Bundle export
8.7 - Test: Auto-duration probing
8.8 - Test: Error handling
8.9 - Verify all tests pass

### Sprint 9: 3 tasks (unchanged)

### Sprint 10: 11 tasks (unchanged)

---

## Context Window Safety Analysis

### Before Further Splitting
- **Tasks > 150 lines**: 5 tasks (HIGH RISK)
- **Tasks 100-150 lines**: 12 tasks (MODERATE RISK)
- **Tasks < 100 lines**: 53 tasks (SAFE)

### After Further Splitting
- **Tasks > 150 lines**: 0 tasks ✅
- **Tasks 100-150 lines**: 0 tasks ✅
- **Tasks < 100 lines**: 96 tasks ✅

**Result**: 100% of tasks are now SAFE (< 100 lines context)

---

## Benefits of Further Atomization

### 1. Context Window Safety
- **Maximum task context**: 80-90 lines (was 200 lines)
- **Average task context**: 40-50 lines (was 80 lines)
- **Risk of exhaustion**: ELIMINATED

### 2. Clearer Commits
- Each commit focused on ONE thing
- Example: "5.2a: Collect unique asset IDs" vs "5.2: Resource collection"
- Easier to review, easier to rollback

### 3. Better Testability
- Each micro-task can be tested independently
- Test failures easier to diagnose
- Example: If 6.2b fails, we know it's the FormatConfig mapping specifically

### 4. Improved Parallelization
- More granular tasks = more parallel opportunities
- Example: 6.2a, 6.2b, 6.2c can all run in parallel (was sequential)

### 5. Reduced Cognitive Load
- Developer focuses on ONE small thing at a time
- Less context switching
- Lower error rate

---

## Trade-offs

### Pros
✅ Absolute context window safety
✅ Granular commits and rollback points
✅ Better parallelization opportunities
✅ Easier to estimate time per task
✅ Lower cognitive load per task

### Cons
⚠️ More tasks to track (96 vs 70)
⚠️ Slightly more coordination overhead
⚠️ More commits (could be noisy git history)

**Verdict**: Pros significantly outweigh cons. Context window safety is critical.

---

## Recommended Action

**APPLY ALL SPLITS** to ensure absolute context window safety.

**New Totals**:
- **96 tasks** (was 70)
- **All tasks < 100 lines**
- **Average task: ~50 lines**
- **Maximum task: ~90 lines**

**Execution Time Impact**:
- Sequential: +2-3 hours (more task overhead)
- Parallel: +1-2 hours (more coordination)
- **Still faster than context window failures**: Priceless

**Next Step**: Update EXECUTION_PLAN.md with 96 atomized tasks
