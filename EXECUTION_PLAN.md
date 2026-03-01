# EXECUTION PLAN — Operation Pipeline Exodus (Iteration 02)

**Mission:** Replace the embedded Pipeline module in SwiftSecuencia with the pipeline-neo dependency for FCPXML generation.

**Branch:** `mission/pipeline-exodus/01`
**Starting Commit:** `44d7ec4` (SwiftSecuencia v2.0.0 - CLI Implementation)
**Previous Iteration:** `mission/pipeline-exodus/00` (see `OPERATION_PIPELINE_EXODUS_01_BRIEF.md` for lessons learned)
**Target Completion:** 8-10 sorties (vs 37 in iteration 0)

---

## Lessons Carried Forward

### What Worked in Iteration 01 (Keep These)
1. **Adapter extension pattern** - `timeline.toPipelineNeoTimeline()`
2. **FileAssetProvider** for testing - fast, no SwiftData overhead
3. **Three-tier error taxonomy** - `FCPXMLExportError`, `FCPXMLBundleExportError`, `FCPXMLValidationError`
4. **iOS compatibility** via `#if os(macOS)` guards

### What Failed in Iteration 01 (Fix These)
1. **No API exploration** - Sortie 0 is MANDATORY research sprint
2. **ResourceMap retrofitted** - Build it into adapters from day one
3. **Regex XML processing** - Use `XMLDocument` to remove invalid `<library name="...">` attribute
4. **False metadata conclusion** - Pipeline Neo DOES export metadata; verify with integration test
5. **Over-planning** - Target file-level deliverables, not function-level
6. **No exit criteria** - Define "done" before starting

---

## Mission Exit Criteria

This migration is complete when:

- [ ] All FCPXML export functionality works via pipeline-neo dependency
- [ ] All existing tests pass (migrated to use `PipelineNeo.` namespacing)
- [ ] DTD validation passes (r-prefixed resource IDs, no invalid attributes)
- [ ] Metadata export verified (markers, keywords, ratings - integration test confirms)
- [ ] iOS build succeeds with FCPXML excluded (`#if os(macOS)`)
- [ ] CI pipeline passes
- [ ] No embedded Pipeline module code remains

---

## Sortie 0: API Exploration & Research

**Model:** Sonnet
**Priority:** CRITICAL — This 30-minute investment prevents 34 DTD validation failures
**Estimated Context:** 20% (research, no code changes)

### Objectives

Read pipeline-neo source code and understand its behavior BEFORE writing adapters.

### Tasks

1. **Read Pipeline Neo source:**
   - `FCPXMLExporter.swift` (lines 1-400) - full export logic
   - Note lines 143-158: metadata serialization (markers, keywords, ratings, etc.)
   - Note lines 179-193: clip-level metadata serialization
   - Note `formatResourceID = "r1"` constant - confirms r-prefixed ID requirement

2. **Catalog type collisions:**
   - List all public types in Pipeline Neo that collide with SwiftSecuencia
   - Known collisions: `Timeline`, `Marker`, `ChapterMarker`, `Keyword`, `Rating`, `Metadata`, `ColorSpace`, `ClipPlacement`, `RippleInsertResult`, `ClipShift`, `RippleLaneOption`
   - Decide: Use `PipelineNeo.` qualified names in production code, type aliases in tests

3. **Export sample timeline WITH metadata:**
   - Create minimal test: Timeline with 2 clips, 1 marker, 1 keyword
   - Pass to `PipelineNeo.FCPXMLExporter.export()`
   - Save output to `sortie-0-sample-output.fcpxml`

4. **Validate against DTD:**
   - Run `xmllint --dtdvalid` on sample output
   - Document any validation failures
   - Confirm: Resource IDs must match `r\d+` pattern (e.g., `"r1"`, `"r2"`)
   - Confirm: `<library>` element does NOT accept `name` attribute (upstream bug)

5. **Document findings:**
   - ResourceMap requirements: UUID → `"r1"`, `"r2"`, etc. in sorted order
   - Empty timeline behavior: `PipelineNeo.FCPXMLExporter` throws for empty timelines
   - Library name bug: Must be removed via `XMLDocument`, not regex
   - Metadata export: CONFIRMED working (lines 143-193 of `FCPXMLExporter.swift`)
   - CMTime timescale: Pipeline Neo uses 600, old module used 24000 (both valid)

### Deliverables

- [ ] `sortie-0-research-notes.md` - Findings document
- [ ] `sortie-0-sample-output.fcpxml` - Sample export for reference
- [ ] `sortie-0-type-collisions.md` - List of naming collisions and resolution strategy

### Exit Criteria

- [ ] All Pipeline Neo public types cataloged
- [ ] ResourceMap format documented (`r1`, `r2`, etc.)
- [ ] Empty timeline behavior documented
- [ ] Library name bug documented with XMLDocument fix approach
- [ ] Metadata export confirmed working (not a Pipeline Neo limitation)

---

## Sortie 1: Package Setup & Dependency Migration

**Model:** Sonnet
**Estimated Context:** 30%

### Objectives

Add pipeline-neo dependency and remove the embedded Pipeline module.

### Tasks

1. **Update Package.swift:**
   ```swift
   .package(url: "https://github.com/stovak/pipeline-neo.git", from: "2.3.1")
   ```
   - Add to target dependencies: `.product(name: "PipelineNeo", package: "pipeline-neo")`
   - Add platform restriction: `.when(platforms: [.macOS])`

2. **Remove embedded Pipeline module:**
   - Delete `Sources/Pipeline/` directory
   - Remove Pipeline target from Package.swift
   - Update all imports: `import Pipeline` → (remove, will use PipelineNeo later)

3. **Verify clean state:**
   - Run `xcodebuild -resolvePackageDependencies`
   - Confirm pipeline-neo fetched successfully
   - Confirm build fails with expected errors (Pipeline types missing)

### Deliverables

- [ ] `Package.swift` updated
- [ ] `Sources/Pipeline/` removed
- [ ] Dependency resolution succeeds

### Exit Criteria

- [ ] `xcodebuild -resolvePackageDependencies` succeeds
- [ ] pipeline-neo v2.3.1 in package graph
- [ ] No embedded Pipeline code remains
- [ ] Build fails with expected "Cannot find type 'Timeline'" errors (to be fixed in Sortie 3)

---

## Sortie 2: ResourceMap Architecture

**Model:** Sonnet
**Estimated Context:** 40%

### Objectives

Build the ResourceMap pattern into the adapter layer from day one (not retrofitted).

### Tasks

1. **Create `ResourceMap.swift`:**
   ```swift
   /// Maps UUIDs to FCPXML-compliant resource IDs (r1, r2, r3, ...)
   public struct ResourceMap {
       private let formatID: String = "r1"
       private var assetIDs: [UUID: String] = [:]

       public init()

       public func formatResourceID() -> String { formatID }

       public mutating func registerAsset(_ uuid: UUID) -> String
       public func assetResourceID(for uuid: UUID) -> String?
   }
   ```

2. **Implement registration logic:**
   - Format is always `"r1"`
   - Assets are `"r2"`, `"r3"`, `"r4"`, ... in sorted UUID order
   - Thread-safe for concurrent access (use `actor` if needed)

3. **Write tests:**
   - Format ID is always `"r1"`
   - Assets get sequential IDs starting from `"r2"`
   - Same UUID returns same ID on repeated calls
   - UUIDs sorted deterministically

### Deliverables

- [ ] `Sources/SwiftSecuencia/Adapters/ResourceMap.swift`
- [ ] `Tests/SwiftSecuenciaTests/ResourceMapTests.swift`

### Exit Criteria

- [ ] All ResourceMap tests pass
- [ ] Format ID is `"r1"`
- [ ] Asset IDs are `"r2"+` in sorted order
- [ ] Registration is idempotent

---

## Sortie 3: Timeline & Metadata Adapters

**Model:** Sonnet
**Estimated Context:** 60%

### Objectives

Implement adapter extensions with ResourceMap integration from the start. **Include metadata adapters** (they are NOT dead code - see corrected Discovery #4 from brief).

### Tasks

1. **Create `TimelineAdapters.swift`:**
   - `Timeline.toPipelineNeoTimeline(resourceMap:) -> PipelineNeo.Timeline`
   - `VideoFormat.toPipelineNeoTimelineFormat(resourceMap:) -> PipelineNeo.TimelineFormat`
   - `TimelineClip.toPipelineNeoTimelineClip(resourceMap:, assetProvider:) -> PipelineNeo.TimelineClip`

2. **Create metadata adapters:**
   - `Marker.toPipelineNeoMarker() -> PipelineNeo.Marker`
   - `ChapterMarker.toPipelineNeoChapterMarker() -> PipelineNeo.ChapterMarker`
   - `Keyword.toPipelineNeoKeyword() -> PipelineNeo.Keyword`
   - `Rating.toPipelineNeoRating() -> PipelineNeo.Rating`
   - `Metadata.toPipelineNeoMetadata() -> PipelineNeo.Metadata`

3. **Reference implementation from iteration 0:**
   - See `mission/pipeline-exodus/00:Sources/SwiftSecuencia/Adapters/TimelineAdapters.swift`
   - Reuse the adapter pattern (it worked)
   - ADD ResourceMap parameter to all methods that need it
   - Keep metadata adapters (do NOT skip them)

### Deliverables

- [ ] `Sources/SwiftSecuencia/Adapters/TimelineAdapters.swift`
- [ ] All adapters accept `resourceMap:` where needed
- [ ] Metadata adapters included (markers, keywords, ratings)

### Exit Criteria

- [ ] All adapter methods compile
- [ ] ResourceMap parameter on asset-related adapters
- [ ] No raw UUIDs passed to Pipeline Neo (all go through ResourceMap)
- [ ] Metadata adapters present and compiling

---

## Sortie 4: Asset Provider Wrapper

**Model:** Opus
**Estimated Context:** 70%

### Objectives

Wrap SwiftData asset access for pipeline-neo with ResourceMap integration.

### Tasks

1. **Create `PipelineNeoAssetProvider.swift`:**
   - Implement `PipelineNeo.AssetProvider` protocol
   - Fetch assets from SwiftData ModelContext
   - Convert to `PipelineNeo.Asset` using ResourceMap
   - Handle missing assets gracefully

2. **Create `FileAssetProvider.swift` (for testing):**
   - In-memory registry: `[UUID: FileAssetEntry]`
   - No SwiftData dependency
   - Fast, lightweight for unit tests

3. **Reference implementation:**
   - See `mission/pipeline-exodus/00:Sources/SwiftSecuencia/Adapters/PipelineNeoAssetProvider.swift`
   - Keep the efficient batching pattern
   - Ensure ResourceMap is used for asset ID conversion

### Deliverables

- [ ] `Sources/SwiftSecuencia/Adapters/PipelineNeoAssetProvider.swift`
- [ ] `Tests/SwiftSecuenciaTests/Helpers/FileAssetProvider.swift`

### Exit Criteria

- [ ] AssetProvider wrapper compiles
- [ ] FileAssetProvider available for tests
- [ ] Asset IDs converted via ResourceMap (`"r2"`, `"r3"`, etc.)

---

## Sortie 5: SwiftSecuenciaExporter (Core Bridge)

**Model:** Opus
**Estimated Context:** 80%

### Objectives

Implement the core FCPXML exporter with empty-timeline guard, library name fix via XMLDocument, and error mapping.

### Tasks

1. **Create `SwiftSecuenciaExporter.swift`:**
   ```swift
   @MainActor
   public struct SwiftSecuenciaExporter {
       public func exportFCPXML(
           timeline: Timeline,
           projectName: String,
           eventName: String,
           assetProvider: PipelineNeo.AssetProvider
       ) async throws -> String
   }
   ```

2. **Build ResourceMap:**
   - `buildResourceMap(timeline:, assetProvider:)` helper
   - Assign `"r1"` to format
   - Assign `"r2"+` to assets in sorted UUID order

3. **Empty timeline guard:**
   - If timeline has no clips, return hand-crafted minimal FCPXML string
   - Bypass Pipeline Neo (it throws on empty timelines)
   - Reference: `mission/pipeline-exodus/00` implementation

4. **Library name fix (XMLDocument, NOT regex):**
   - After Pipeline Neo export, parse FCPXML as `XMLDocument`
   - Find `<library>` element
   - Remove `name` attribute using `XMLElement.removeAttribute(forName:)`
   - Re-serialize to string

5. **Error mapping:**
   - Create `ExportErrorMapping.swift`
   - Map Pipeline Neo errors → `FCPXMLExportError` cases
   - Use `remappingExportErrors(_:)` boundary function
   - Reference: `mission/pipeline-exodus/00:Sources/SwiftSecuencia/Export/ExportErrorMapping.swift`

### Deliverables

- [ ] `Sources/SwiftSecuencia/Export/SwiftSecuenciaExporter.swift`
- [ ] `Sources/SwiftSecuencia/Export/ExportErrorMapping.swift`
- [ ] Empty timeline guard implemented
- [ ] Library name fix via XMLDocument

### Exit Criteria

- [ ] Exporter compiles
- [ ] Empty timeline returns valid minimal FCPXML
- [ ] Library name attribute removed via XMLDocument (not regex)
- [ ] Error mapping prevents Pipeline Neo errors from leaking

---

## Sortie 6: SwiftSecuenciaBundleExporter

**Model:** Sonnet
**Estimated Context:** 60%

### Objectives

Implement .fcpbundle export with media file coordination and library name post-processing.

### Tasks

1. **Create `SwiftSecuenciaBundleExporter.swift`:**
   - Bundle structure: `{name}.fcpbundle/` with `Info.fcpxml` and `Media/`
   - Use `SwiftSecuenciaExporter` for FCPXML generation
   - Copy media files from SwiftData to `Media/` directory
   - Post-process `Info.fcpxml` to remove library name attribute

2. **Media file coordination:**
   - Fetch asset binary data from ModelContext
   - Write to bundle with r-prefixed filenames (`r2.m4a`, `r3.wav`, etc.)
   - Update asset `src` paths in FCPXML to relative `Media/` paths

3. **Library name post-processing:**
   - Read `Info.fcpxml` after creation
   - Parse as XMLDocument
   - Remove `<library name="...">` attribute
   - Rewrite file

### Deliverables

- [ ] `Sources/SwiftSecuencia/Export/SwiftSecuenciaBundleExporter.swift`

### Exit Criteria

- [ ] Bundle exporter compiles
- [ ] Creates `.fcpbundle/` directory structure
- [ ] Copies media files to `Media/`
- [ ] FCPXML has relative media paths
- [ ] Library name attribute removed from `Info.fcpxml`

---

## Sortie 7: Test Migration & Metadata Integration

**Model:** Sonnet (may need Opus if context overruns)
**Estimated Context:** 90%

### Objectives

Migrate existing tests and ADD metadata integration test to verify Pipeline Neo exports metadata correctly.

### Tasks

1. **Update test imports:**
   - Add `import PipelineNeo` to all test files
   - Use type aliases for colliding types:
     ```swift
     typealias PNTimeline = PipelineNeo.Timeline
     typealias PNMarker = PipelineNeo.Marker
     // ... etc.
     ```
   - Create `Tests/SwiftSecuenciaTests/Helpers/PipelineNeoTypeAliases.swift` for shared aliases

2. **Migrate test files:**
   - `FCPXMLExportTests.swift` → use `SwiftSecuenciaExporter`
   - `FCPXMLBundleExportTests.swift` → use `SwiftSecuenciaBundleExporter`
   - `TimelineAdapterTests.swift` → test adapters with ResourceMap
   - `AssetProviderAdapterTests.swift` → test FileAssetProvider

3. **ADD metadata integration test (CRITICAL):**
   - Create timeline with markers, keywords, ratings
   - Pass through full adapter → exporter pipeline
   - Assert metadata appears in FCPXML output
   - This verifies Pipeline Neo DOES export metadata (corrects false conclusion from iteration 0)

4. **DTD validation tests:**
   - Validate resource IDs are r-prefixed (`r1`, `r2`, etc.)
   - Validate no `<library name="...">` attribute
   - Use `xmllint --dtdvalid` if available

### Deliverables

- [ ] `Tests/SwiftSecuenciaTests/Helpers/PipelineNeoTypeAliases.swift`
- [ ] All test files updated with type aliases
- [ ] Metadata integration test (NEW - verifies Pipeline Neo exports metadata)
- [ ] DTD validation tests

### Exit Criteria

- [ ] All tests pass
- [ ] Metadata integration test confirms markers/keywords/ratings appear in FCPXML
- [ ] DTD validation passes (r-prefixed IDs, no library name attribute)
- [ ] No namespace collision errors

---

## Sortie 8: CI & CLI Updates

**Model:** Haiku
**Estimated Context:** 30%

### Objectives

Update build commands, validation commands, and CI pipeline.

### Tasks

1. **Update CLI commands:**
   - `build` command uses `SwiftSecuenciaExporter`
   - `validate` command uses `SwiftSecuenciaExporter` + DTD validation

2. **Update GitHub Actions:**
   - Ensure `macos-26` runner
   - Run tests: `make test` (uses xcodebuild)
   - Run validation: `make validate` (if exists)

3. **iOS compatibility:**
   - Verify iOS build succeeds with FCPXML excluded
   - `#if os(macOS)` guards in place
   - Pipeline Neo dependency platform-restricted

### Deliverables

- [ ] CLI commands updated
- [ ] CI pipeline updated
- [ ] iOS build verification

### Exit Criteria

- [ ] `make build` succeeds
- [ ] `make test` passes all tests
- [ ] CI pipeline green
- [ ] iOS build succeeds (FCPXML excluded)

---

## Sortie Summary

| Sortie | Task | Model | Context | Deliverables |
|--------|------|-------|---------|--------------|
| 0 | API Exploration & Research | Sonnet | 20% | Research notes, sample output, collision list |
| 1 | Package Setup | Sonnet | 30% | Package.swift, remove Pipeline module |
| 2 | ResourceMap Architecture | Sonnet | 40% | ResourceMap.swift + tests |
| 3 | Timeline & Metadata Adapters | Sonnet | 60% | TimelineAdapters.swift (with metadata) |
| 4 | Asset Provider Wrapper | Opus | 70% | PipelineNeoAssetProvider + FileAssetProvider |
| 5 | SwiftSecuenciaExporter | Opus | 80% | Core exporter + error mapping |
| 6 | SwiftSecuenciaBundleExporter | Sonnet | 60% | Bundle exporter |
| 7 | Test Migration & Metadata | Sonnet | 90% | All tests + metadata integration test |
| 8 | CI & CLI Updates | Haiku | 30% | CLI + CI updates |

**Total:** 9 sorties (vs 37 in iteration 0)

---

## Reference Files from Iteration 0

Preserved on `mission/pipeline-exodus/00` branch:

| File | Purpose |
|------|---------|
| `Sources/SwiftSecuencia/Adapters/TimelineAdapters.swift` | Adapter pattern reference (including metadata) |
| `Sources/SwiftSecuencia/Adapters/PipelineNeoAssetProvider.swift` | Asset conversion pattern |
| `Sources/SwiftSecuencia/Export/SwiftSecuenciaExporter.swift` | Core bridge pattern (with ResourceMap) |
| `Sources/SwiftSecuencia/Export/ExportErrorMapping.swift` | Three-tier error taxonomy |
| `Tests/SwiftSecuenciaTests/PipelineNeoIntegrationTests.swift` | Integration test structure |
| `OPERATION_PIPELINE_EXODUS_01_BRIEF.md` | Lessons learned document |

**Do NOT copy-paste directly.** Use as reference for patterns that worked. All code must be rewritten with ResourceMap from the start.

---

## Success Metrics

- **Sortie completion:** 100% (9/9)
- **Context overruns:** ≤ 2 sorties (vs 7 in iteration 0)
- **Test pass rate:** 100%
- **DTD validation:** 100% pass
- **Metadata export:** Verified in integration test
- **Duration:** Target < 12 hours (vs 36.6 in iteration 0)

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Type naming collisions | Use `PipelineNeo.` qualified names in production, type aliases in tests |
| Context overruns | Use Opus for known expensive sorties (4, 5) |
| Metadata export failures | Sortie 7 includes dedicated integration test |
| DTD validation failures | Sortie 0 validates format BEFORE writing adapters |
| ResourceMap retrofit | Sortie 2 builds ResourceMap BEFORE adapters |
