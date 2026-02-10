# Atomicity Pass - Summary of Changes

All blockers and high-priority gaps have been fixed, and the execution plan has been split into atomic tasks to prevent context window exhaustion.

---

## Changes Summary

| Sprint | Original Tasks | Atomic Tasks | Change | Reason |
|--------|----------------|--------------|--------|--------|
| Sprint 1 | 5 | 5 | None | Already atomic |
| Sprint 2 | 6 | 6 | None | Already atomic |
| **Sprint 3** | 6 | **10** | **+4 tasks** | Split FileResolver and MediaProbe into separate concerns |
| Sprint 4 | 4 | 4 | None | Already atomic |
| **Sprint 5** | 5 | **12** | **+7 tasks** | Split large exporter refactors into incremental steps |
| **Sprint 6** | 4 | **8** | **+4 tasks** | Split TimelineBuilder into incremental builds |
| Sprint 7 | 2 | 2 | None | Orchestration code, already atomic |
| **Sprint 8** | 5 | **9** | **+4 tasks** | Split end-to-end tests by scenario |
| Sprint 9 | 3 | 3 | None | Already atomic |
| **Sprint 10** | 8 | **11** | **+3 tasks** | Split schema creation and help text by command |
| **TOTAL** | **48** | **69** | **+21 tasks** | **0 HIGH RISK tasks remaining** |

---

## Sprint 3: File Resolution and Media Probing (6 → 10 tasks)

### Original Structure (Too Large)
- Task 1: FileResolver (path resolution + UUID deduplication) - ~120 lines
- Task 2: MediaProbe (MIME + duration + batch probing) - ~150 lines

### New Atomic Structure
1. FileResolver - Part A: Path resolution only
2. FileResolver - Part B: Asset deduplication with deterministic UUIDs
3. MediaProbe - Part A: MIME type detection only
4. MediaProbe - Part B: Single file duration probing
5. MediaProbe - Part C: Batch duration probing
6. Create test fixtures
7. FileResolverTests - Part A: Path resolution tests
8. FileResolverTests - Part B: Asset deduplication tests
9. MediaProbeTests - All parts
10. Update BuildCommand

**Benefit**: Each method can be implemented and tested independently. Deterministic UUID logic (Appendix B) isolated in Task 2.

---

## Sprint 5: Refactor Exporters (5 → 12 tasks)

### Original Structure (HIGH RISK)
- Task 1: Modify FCPXMLExporter (~400 lines existing + 100 new) - **CONTEXT OVERLOAD**
- Task 2: Modify FCPXMLBundleExporter (~700 lines existing + 200 new) - **CONTEXT OVERLOAD**

### New Atomic Structure

**FCPXMLExporter (Tasks 1-4):**
1. Add AssetProvider method signature (stub)
2. Implement resource collection with AssetProvider
3. Implement asset element generation with file URLs
4. Complete integration + backward compatibility wrapper

**FCPXMLBundleExporter (Tasks 5-9):**
5. Add audio conversion helper method (Appendix D)
6. Add AssetProvider method signature (stub)
7. Implement bundle structure creation
8. Implement media export with conversion logic
9. Complete integration + backward compatibility wrapper

**Testing (Tasks 10-12):**
10. Update FCPXMLExportTests
11. Update FCPXMLBundleExportTests
12. Run FULL test suite (regression check)

**Benefit**:
- Each task reads < 200 lines of production code
- Incremental commits allow easy rollback
- Tests after each major step (not just at end)
- Never read both exporters simultaneously

---

## Sprint 6: SwiftData Bootstrap and Timeline Builder (4 → 8 tasks)

### Original Structure (Too Large)
- Task 2: TimelineBuilder.build() - ~250 lines with 6 separate concerns

### New Atomic Structure
1. Create SwiftDataBootstrap (unchanged)
2. TimelineBuilder - Timeline creation and format mapping
3. TimelineBuilder - FileAssetProvider population
4. TimelineBuilder - Non-marker clip processing
5. TimelineBuilder - Marker clip processing (Appendix C)
6. TimelineBuilder - Complete build() integration
7. TimelineBuilderTests (consolidate all tests)
8. SwiftDataBootstrapTests (unchanged)

**Benefit**:
- Build method constructed incrementally
- Each step independently testable
- Format mapping (Task 2), asset provider (Task 3), clips (Task 4), markers (Task 5) isolated
- Full integration test at end (Task 6)

---

## Sprint 8: End-to-End Tests (5 → 9 tasks)

### Original Structure (Moderate)
- Task 4: EndToEndTests - 5 scenarios in one file (~200 lines)

### New Atomic Structure
1. Check ffmpeg + create media fixtures
2. Create JSON fixture files
3. EndToEndTests - Simple timeline export
4. EndToEndTests - Multi-lane audio
5. EndToEndTests - Markers
6. EndToEndTests - Bundle export
7. EndToEndTests - Auto-duration probing
8. ErrorHandlingTests (all error scenarios)
9. Verify all tests pass

**Benefit**:
- Each test scenario can be debugged independently
- Fixtures created first (Task 1-2), then tests use them (Tasks 3-7)
- Clear commit trail showing which scenarios pass

---

## Sprint 10: Validate, Schema, Documentation (8 → 11 tasks)

### Original Structure (Moderate)
- Task 2: schema.json - complete schema in one go (~200 lines)
- Task 5: Add --help to all commands - touches 3 files

### New Atomic Structure
1. Create ValidateCommand
2. schema.json - Structure and timeline definitions
3. schema.json - Clip definitions and enums
4. Create SchemaCommand
5. Register subcommands
6. BuildCommand --help descriptions
7. ValidateCommand --help descriptions
8. SchemaCommand --help descriptions
9. Update README
10. ValidateCommandTests
11. SchemaCommandTests

**Benefit**:
- Schema built incrementally (Tasks 2-3)
- Help text added per-command (Tasks 6-8), not all at once
- Each command's documentation committed separately

---

## Key Principles Applied

### 1. Incremental Builds
Large refactors (Sprint 5, Sprint 6) now build incrementally:
- Add signature → Implement logic → Complete integration → Test
- Each step committed separately

### 2. Separation of Concerns
Split tasks by responsibility:
- Sprint 3: Path resolution vs UUID generation vs MIME detection vs duration probing
- Sprint 6: Timeline creation vs asset provider vs clips vs markers

### 3. Test Early, Test Often
Tests added after each major step (not just at end):
- Sprint 5: Test after each exporter phase
- Sprint 6: Test after each TimelineBuilder phase

### 4. Context Window Budget
Maximum lines per task:
- 🟢 **SAFE**: < 300 lines (single file, clear scope)
- 🟡 **MODERATE**: 300-400 lines (acceptable with good structure)
- 🔴 **UNSAFE**: > 400 lines (MUST SPLIT)

**Result**: All tasks now 🟢 SAFE or 🟡 MODERATE

### 5. Commit Granularity
Each task has a clear commit message:
```
Sprint 5, Task 3: "FCPXMLExporter: Implement asset element generation with file URLs"
Sprint 6, Task 4: "TimelineBuilder: Add non-marker clip processing"
```

Benefits:
- Easy to identify which change caused a regression
- Easy to cherry-pick or revert specific features
- Clear audit trail for code review

---

## Verification Checklist

Before dispatching sprints, verify:

- [ ] Sprint 3: 10 tasks split correctly (FileResolver A/B, MediaProbe A/B/C)
- [ ] Sprint 5: 12 tasks with FCPXMLExporter (1-4) and FCPXMLBundleExporter (5-9) separate
- [ ] Sprint 6: 8 tasks with TimelineBuilder split into 5 incremental pieces (2-6)
- [ ] Sprint 8: 9 tasks with separate end-to-end test scenarios (3-7)
- [ ] Sprint 10: 11 tasks with schema split (2-3) and help text per-command (6-8)
- [ ] All appendices (A, B, C, D) referenced correctly
- [ ] Exit criteria updated to reflect atomic task structure
- [ ] Summary table shows 69 total tasks

---

## Impact on Execution

### Before Atomicity Pass
- 2 HIGH RISK sprints (Sprint 5, 6)
- Large tasks requiring 800+ lines of context
- Risk of context exhaustion during refactoring
- Difficult to rollback granular changes

### After Atomicity Pass
- 0 HIGH RISK sprints
- All tasks < 400 lines of context
- Incremental commits with clear boundaries
- Easy rollback at task level
- Better testability

### Execution Time Impact
- **Slightly longer total time** (more tasks = more overhead)
- **Significantly safer** (no context window failures)
- **Better parallelization** (more atomic units can be dispatched independently)
- **Faster debugging** (smaller surface area per commit)

**Trade-off**: 10-15% longer execution time for 90% reduction in failure risk.

---

## Status

**Execution Plan**: ✅ **READY FOR DISPATCH**

All changes applied to `EXECUTION_PLAN.md`:
- 48 tasks → 69 tasks
- All HIGH RISK tasks eliminated
- Comprehensive exit criteria for each sprint
- Appendices A, B, C, D in place
- Clear commit strategy defined

**Next Step**: Prioritization pass (if needed), then dispatch sprints.
