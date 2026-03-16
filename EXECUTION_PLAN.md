---
feature_name: OPERATION SPECIFICATION PARADE
starting_point_commit: 7e74cc49f6898b1fd01682c5ac42857e94541c6d
mission_branch: mission/specification-parade/03
iteration: 3
---

# EXECUTION_PLAN — FCPXML Audit Remediation

**Mission:** Bring SwiftSecuencia's FCPXML documentation and library code into alignment with the current Apple FCPXML spec (v1.8–v1.14), prioritizing correctness of generated output.

**Source Plan:** `~/.claude/plans/inherited-sprouting-twilight.md`

---

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Context

An audit revealed:
- Reference doc is outdated (targets v1.11, current is v1.14)
- Doc examples contradict code and Apple conventions
- Library missing attributes on generated elements (`tcFormat`, `audioLayout`, `audioRate`)
- CLI version mapping doesn't expose v1.14 despite PipelineNeo supporting it

**Key Decisions Required:**
1. Should default version move from 1.11 to 1.13?
2. Should UHD format name be `FFVideoFormat2160p2398` or `FFVideoFormat3840x2160p2398`?

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| SwiftSecuencia | . | 7 | 1 | none (sequential within unit) |

---

## Sortie 0: Current State Verification & Format Name Testing

**Priority**: 23.5 — CRITICAL research foundation (blocks all 6 downstream sorties, establishes format decisions)
**Agent**: Supervising (has DTD validation step)
**Estimated effort**: 13 turns (26% of budget)

**Entry criteria**:
- [ ] First sortie — no prerequisites

**Tasks**:
1. Read current `Docs/FCPXML-Reference.md` and catalog all discrepancies mentioned in audit
2. Read current `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift` exporter logic for sequence attributes
3. Read `Sources/SwiftSecuencia/Format/VideoFormat.swift` format naming logic (lines 84-98)
4. Read `Sources/SwiftSecuencia/Format/FrameRate.swift` frame rate suffix logic (lines 124-151)
5. **CRITICAL**: Generate test FCPXML with UHD format `FFVideoFormat2160p2398` and validate with `xmllint --dtdvalid` against v1.13 DTD
6. Document findings: Does `FFVideoFormat2160p2398` validate? Or does it need `FFVideoFormat3840x2160p2398`?
7. Catalog current sequence element attributes vs. what's missing (`tcFormat`, `audioLayout`, `audioRate`)

**Deliverables**:
- [ ] `sortie-0-audit-findings.md` — Current state documentation
- [ ] `sortie-0-uhd-format-test.fcpxml` — Test output for format name validation
- [ ] `sortie-0-dtd-validation-result.txt` — DTD validation result

**Exit criteria**:
- [ ] All discrepancies cataloged with file/line references
- [ ] UHD format name decision made (keep `2160p` or change to `3840x2160p`)
- [ ] Missing sequence attributes documented
- [ ] DTD validation result recorded (pass/fail for current format naming)

**Model:** Sonnet
**Complexity score:** 10 (research + validation)

---

## Sortie 1: Documentation Fixes (Phase 1)

**Priority**: 2.5 — Documentation only (no code dependencies)
**Agent**: Sub-agent (no build steps, can run in parallel with Sortie 2)
**Estimated effort**: 11 turns (22% of budget)

**Entry criteria**:
- [ ] Sortie 0 complete — audit findings documented
- [ ] Format name decision made (from Sortie 0 validation)

**Tasks**:
1. **Update version info** (`Docs/FCPXML-Reference.md` lines 7-8):
   - Change "Current Version: 1.11" → "Current Version: 1.14"
   - Change "Supported Versions: 1.6 through 1.11" → "Supported Versions: 1.8 through 1.14"
   - Add version history table (1.11→1.14 with FCP versions and dates)

2. **Fix format name pattern** (lines 60-103):
   - Correct pattern to `FFVideoFormat{resolution}{field}{fps}`
   - Document standard resolution shorthand (1080, 720, 2160) vs full WxH for non-standard
   - Fix fps suffix examples: `2398`, `2997`, `5994` for NTSC; `24`, `25`, `30`, `50`, `60` for clean rates
   - Update examples table to match code behavior

3. **Fix asset element example** (lines 159-177):
   - Remove `src` from `<asset>` attributes (it's on `<media-rep>` since v1.9)
   - Show `<media-rep>` as required child element
   - Add `media-rep` attribute documentation: `kind`, `sig`, `src`, `suggestedFilename`

4. **Add newer format/asset attributes**:
   - Format element: `projection`, `stereoscopic`, `heroEye` (v1.13+)
   - Asset element: `videoSources`, `colorSpaceOverride`, `projectionOverride`, `stereoscopicOverride`, `heroEyeOverride`, `auxVideoFlags`
   - Mark as optional with version notes

5. **Add version changelog section**:
   - v1.12: `nameOverride` on filters, `optical-flow-frc` frame sampling
   - v1.13: Spatial video (`heroEye`, `adjust-stereo-3D`), `hidden-clip-marker`, high frame rates (90/100/119.88/120)
   - v1.14: AI search (`isRelatedTo`), transcript/visual scope, `match-analysis-type`

6. **Add caption element documentation**:
   - Document `<caption>` element attributes (`name`, `start`, `duration`, `enabled`, `lane`, `offset`, `role`)
   - Child elements (`text`, `text-style-def`, `note`)
   - Include iTT caption example

**Deliverables**:
- [ ] `Docs/FCPXML-Reference.md` updated with all Phase 1 fixes

**Exit criteria**:
- [ ] Version info updated to 1.14 (lines 7-8 modified)
- [ ] Format name pattern section updated (lines 60-103) with correct pattern and examples
- [ ] Asset element example updated (lines 159-177) with media-rep structure
- [ ] Newer attributes documented: format (projection, stereoscopic, heroEye) and asset (6 override attributes)
- [ ] Version changelog section added (v1.12, v1.13, v1.14 entries)
- [ ] Caption element section added with attributes table, child elements list, and iTT caption example

**Model:** Sonnet
**Complexity score:** 8 (documentation work, medium volume)

---

## Sortie 2: Add Missing Sequence Attributes (Phase 2A, 2B)

**Priority**: 9.0 — Core exporter changes (blocks 2 downstream sorties)
**Agent**: Supervising (has build verification)
**Estimated effort**: 11 turns (22% of budget)

**Entry criteria**:
- [ ] Sortie 0 complete — missing attributes cataloged

**Tasks**:
1. **Add `tcFormat` to sequence element**:
   - File: `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift` (line ~368)
   - After setting `tcStart`, add `tcFormat` based on frame rate
   - If `frameRate.isDropFrame` → `"DF"`, otherwise → `"NDF"`
   - Apply to both `generateSequenceElementWithProvider` and `generateSequenceElement` methods

2. **Add `audioLayout` and `audioRate` to sequence element**:
   - Add optional `audioLayout` attribute (default `"stereo"`)
   - Add optional `audioRate` attribute (default `"48k"`)
   - Source from Timeline's audio configuration if available, otherwise use defaults

3. **Verify attributes added correctly**:
   - Check XML structure matches DTD expectations
   - Ensure both export methods (with/without provider) generate attributes

**Deliverables**:
- [ ] `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift` updated with sequence attributes

**Exit criteria**:
- [ ] `tcFormat` attribute added (DF/NDF based on frame rate)
- [ ] `audioLayout` attribute added (default "stereo")
- [ ] `audioRate` attribute added (default "48k")
- [ ] Both export methods updated consistently
- [ ] Code compiles without errors

**Model:** Sonnet
**Complexity score:** 7 (targeted code changes, clear requirements)

---

## Sortie 3: CLI Version Mapping & Default Version (Phase 2C, 2D)

**Priority**: 5.0 — Simple CLI mapping (blocks 1 downstream sortie)
**Agent**: Supervising (has build verification)
**Estimated effort**: 12 turns (24% of budget)
**⚠️ Decision Required**: Default version (1.11 or 1.13) - can decide during execution

**Entry criteria**:
- [ ] Sortie 2 complete — exporter attributes added

**Tasks**:
1. **Expose v1.14 in CLI**:
   - File: `Sources/SecuenciaCLICore/Commands/BuildCommand.swift` (lines 12-22)
   - Add `case "1.14": return .v1_14` to version switch
   - Verify PipelineNeo already supports v1_14

2. **Update default version (if decided)**:
   - File: `Sources/SwiftSecuencia/SwiftSecuencia.swift`
   - If decision is to update: change default from `.v1_11` to `.v1_13`
   - Rationale: v1.13 is backward-compatible with FCP 11+, covers spatial video
   - If decision is to keep 1.11: document rationale (maximum compatibility)

3. **Update version documentation**:
   - Ensure CLI help text reflects v1.14 availability
   - Update any README or CLI docs mentioning supported versions

**Deliverables**:
- [ ] `Sources/SecuenciaCLICore/Commands/BuildCommand.swift` with v1.14 support
- [ ] `Sources/SwiftSecuencia/SwiftSecuencia.swift` default version updated (if decided)

**Exit criteria**:
- [ ] CLI accepts `--version 1.14` flag
- [ ] v1.14 case maps to `.v1_14`
- [ ] Default version set per decision (1.11 or 1.13)
- [ ] Code compiles without errors

**Model:** Haiku
**Complexity score:** 3 (simple code additions)

---

## Sortie 4: Format Name Verification & Fix (Phase 3)

**Priority**: 6.0 — Format verification (blocks tests)
**Agent**: Supervising (has build verification)
**Estimated effort**: 10-12 turns (20-24% of budget)
**Note**: Conditional sortie - decision made by Sortie 0 validation results

**Entry criteria**:
- [ ] Sortie 0 complete — format name validation result available

**Tasks**:
1. **If Sortie 0 validation PASSED** (current format works):
   - No code changes needed
   - Document that `FFVideoFormat2160p2398` is DTD-compliant
   - Skip file modifications

2. **If Sortie 0 validation FAILED** (needs full WxH):
   - File: `Sources/SwiftSecuencia/Format/VideoFormat.swift` (lines 86-87)
   - Change `"2160"` to `"3840x2160"` for standard UHD resolutions
   - Verify DCI formats still use full WxH (4096x2160)

3. **Update format name logic**:
   - Ensure standard resolutions (720p, 1080p) still use shorthand
   - Only change UHD (2160p) if validation requires it

**Deliverables**:
- [ ] `Sources/SwiftSecuencia/Format/VideoFormat.swift` updated (if needed)
- [ ] `sortie-4-format-decision.md` documenting the decision and outcome

**Exit criteria**:
- [ ] Format name decision implemented (change or no-change)
- [ ] If changed: UHD formats use `3840x2160` pattern
- [ ] If unchanged: documented that current naming is DTD-compliant
- [ ] Code compiles without errors

**Model:** Haiku
**Complexity score:** 4 (conditional change, depends on Sortie 0)

---

## Sortie 5: Test Updates (Phase 4)

**Priority**: 5.0 — Test verification (blocks 1 downstream sortie)
**Agent**: Supervising (has make test step)
**Estimated effort**: 14 turns (28% of budget)

**Entry criteria**:
- [ ] Sortie 2 complete — sequence attributes added
- [ ] Sortie 4 complete — format name decision implemented

**Tasks**:
1. **Add test assertions for new sequence attributes**:
   - File: `Tests/SwiftSecuenciaTests/FCPXMLExportTests.swift`
   - Assert `tcFormat` is "DF" for drop-frame, "NDF" for non-drop-frame
   - Assert `audioLayout` is "stereo" (or custom value if set)
   - Assert `audioRate` is "48k" (or custom value if set)
   - Create test timeline with drop-frame and non-drop-frame rates

2. **Update format name tests (if Sortie 4 changed logic)**:
   - File: `Tests/SwiftSecuenciaTests/VideoFormatTests.swift`
   - If format pattern changed: update test assertions for UHD format names
   - Verify `FFVideoFormat2160p2398` or `FFVideoFormat3840x2160p2398` as appropriate
   - Verify other standard formats (720p, 1080p) unchanged

3. **Run full test suite**:
   - Ensure all existing tests still pass
   - New assertions added for new attributes

**Deliverables**:
- [ ] `Tests/SwiftSecuenciaTests/FCPXMLExportTests.swift` with new attribute tests
- [ ] `Tests/SwiftSecuenciaTests/VideoFormatTests.swift` updated (if format changed)

**Exit criteria**:
- [ ] Test assertions for `tcFormat`, `audioLayout`, `audioRate` added
- [ ] Format name tests updated if Sortie 4 changed pattern
- [ ] `make test` passes all tests
- [ ] New tests verify correct attribute generation

**Model:** Sonnet
**Complexity score:** 6 (test logic, multiple scenarios)

---

## Sortie 6: Schema Update (Phase 5, conditional)

**Priority**: 2.0 — Conditional schema update (no dependencies)
**Agent**: Supervising (has build verification)
**Estimated effort**: 10-12 turns (20-24% of budget)

**Entry criteria**:
- [ ] Sortie 3 complete — CLI supports v1.14
- [ ] Sortie 5 complete — tests pass

**Tasks**:
1. **Review schema.json for version references**:
   - File: `Sources/SecuenciaCLICore/Resources/schema.json`
   - Check if any JSON input fields reference FCPXML versions
   - Check if version enum needs updating to include v1.14

2. **Update schema if needed**:
   - Add v1.14 to version enums or validations
   - Update descriptions to reflect v1.8–v1.14 support range
   - Ensure schema matches CLI capabilities

3. **If no changes needed**:
   - Document that schema is version-agnostic or already correct
   - Skip file modification

**Deliverables**:
- [ ] `Sources/SecuenciaCLICore/Resources/schema.json` updated (if needed)
- [ ] `sortie-6-schema-review.md` documenting schema state

**Exit criteria**:
- [ ] Schema reviewed for version references
- [ ] Schema updated if needed, or documented as not requiring changes
- [ ] `make build` succeeds
- [ ] JSON schema validation passes

**Model:** Haiku
**Complexity score:** 2 (conditional, low impact)

---

## Parallelism Structure

**Critical Path**: Sortie 0 → Sortie 2 → Sortie 5 → Sortie 6 (4 sorties)

**Parallel Execution Groups**:
- **Group 1** (Sequential): Sortie 0 (supervising agent - DTD validation)
- **Group 2** (Can run in parallel after Sortie 0):
  - Sortie 1 (sub-agent 1 - documentation, no builds)
  - Sortie 2 (supervising agent - exporter changes with build)
- **Group 3** (Sequential after Sortie 2): Sortie 3, Sortie 4 (both have builds)
- **Group 4** (Sequential after Sortie 3+4): Sortie 5 (supervising - make test)
- **Group 5** (Sequential after Sortie 5): Sortie 6 (supervising - make build)

**Agent Constraints**:
- **Supervising agent**: Handles all sorties with build/test steps (Sorties 0, 2, 3, 4, 5, 6)
- **Sub-agent 1**: Documentation work (Sortie 1 only)

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 1 (SwiftSecuencia) |
| Total sorties | 7 |
| Dependency structure | sequential with 1 parallel opportunity |
| Critical path | 4 sorties (0 → 2 → 5 → 6) |
| Agent allocation | 1 supervising + 1 sub-agent |
| Parallelism potential | Limited (6/7 sorties require builds) |
| Average sortie size | 11.6 turns (23% of 50-turn budget) |
| Estimated execution time | ~3-4 hours (assuming 30 min/sortie avg) |

---

## Open Questions & Missing Documentation

### Unresolved Items

| Sortie | Issue Type | Description | Resolution Strategy |
|--------|-----------|-------------|---------------------|
| 3 | Open question | Default version decision: stay at 1.11 or update to 1.13? | Agent will research compatibility trade-offs and recommend during execution. Not blocking - can decide in Sortie 3. |
| 4 | Conditional | Entire sortie depends on Sortie 0 DTD validation result | Resolved by Sortie 0 - not blocking. If validation passes, sortie becomes no-op. |

**Status**: ✓ Plan is executable - decisions can be made during execution

---

## Mission Exit Criteria

This remediation is complete when:

- [ ] `Docs/FCPXML-Reference.md` updated to v1.14 with corrected examples
- [ ] Sequence elements generate `tcFormat`, `audioLayout`, `audioRate` attributes
- [ ] CLI supports `--version 1.14` flag
- [ ] Default version decision made and implemented (1.11 or 1.13)
- [ ] Format name decision made and implemented (2160p or 3840x2160p)
- [ ] All tests pass with new assertions for sequence attributes
- [ ] Schema.json updated if needed
- [ ] `make build` succeeds
- [ ] `make test` passes
- [ ] `make lint` passes
- [ ] Generated FCPXML validates against v1.13 DTD with `xmllint --dtdvalid`

---

## Out of Scope (Deferred)

These items identified in the audit are **NOT included**:

1. Gap element auto-generation (feature addition, not correctness fix)
2. Caption FCPXML output generation (new feature, only WebVTT export exists)
3. Chapter marker FCPXML output (model exists, output not implemented)
4. v1.14 DTD file extraction from FCP 12.0 app bundle
5. `audioChannels`/`audioRate` on asset elements (optional, low impact)
6. `format` ref on asset elements (optional, FCP infers from context)
7. Spatial video attribute generation (`heroEye`, `stereoscopic`, `adjust-stereo-3D`) — documented only

---

## Verification Steps

1. `make build` — Everything compiles
2. `make test` — All tests pass with new assertions
3. `make lint` — No violations
4. Manual: Generate sample FCPXML and validate with `xmllint --dtdvalid` against v1.13 DTD
5. Spot-check: Import generated FCPXML into Final Cut Pro to confirm it opens correctly
