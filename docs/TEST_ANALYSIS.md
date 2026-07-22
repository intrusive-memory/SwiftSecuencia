---
type: reference
updated: 2026-07-21
---

# Test Analysis Report

**Repository**: SwiftSecuencia
**Branch**: development
**Commit**: 2929845
**Date**: 2026-07-21
**Test scheme**: SwiftSecuencia-Package
**Tests considered**: 44 test suites, 90+ test functions

## Executive summary

| Pass | Findings | Highest priority item |
|------|----------|------------------------|
| 1. High-repetition tests | 0 | None found |
| 2. Superfluous tests | 2 | Version string assertions in CI that auto-pass |
| 3. Coverage gaps | 3 critical | BackgroundAudioExporter 0%, BuildCommand 3.85% |
| 4. Flaky-in-CI predictions | 2 | Thread.sleep used for process polling in TestUtilities |
| 5. Performance gating | 0 | No performance tests found |

**Overall health**: The test suite is in good shape structurally but has significant coverage gaps in critical paths. Lint passes with 0 violations. The CLI core is well-tested (69% coverage), but **BackgroundAudioExporter** (0%) and **BuildCommand** (3.85%) represent major untested surface area. The Thread.sleep polling in TestUtilities is the main flakiness risk.

**Most impactful changes** (in priority order):
1. **Add integration tests for BackgroundAudioExporter** — 0% coverage on a major export path is the biggest gap
2. **Add BuildCommand unit tests** — CLI entry point has almost no coverage beyond integration smoke tests
3. **Replace Thread.sleep polling** in TestUtilities with async Process handling

## Pass 1 — High-repetition tests

### Copy-paste patterns
No findings.

### High-iteration loops
No findings. No loops with iteration counts ≥1000 detected.

## Pass 2 — Superfluous tests

- `Tests/SwiftSecuenciaTests/FCPXMLVersionTests.swift:275` — asserts XML contains `version="1.13"` after setting version to v1_13
  - **Why superfluous**: This is a tautology — the exporter was told to use v1.13, so asserting the output contains "1.13" only verifies string interpolation works, not version logic.
  - **Action**: Consider strengthening to verify DTD validation passes for the claimed version, or remove as redundant with DTD validation tests.

- `Tests/SwiftSecuenciaTests/FCPXMLVersionTests.swift:280` — asserts XML contains `version="1.14"` after setting version to v1_14
  - **Why superfluous**: Same as above — tautology.
  - **Action**: Merge into DTD validation test or remove.

Note: The `version="1.11"` assertions in `FCPXMLExportTests.swift:29` and `BuildCommandTests.swift:109` are testing end-to-end CLI/export flow, so they verify integration rather than being pure tautologies. Those are acceptable.

## Pass 3 — Coverage gaps

Coverage was measured by running `xcodebuild test -scheme SwiftSecuencia-Package -destination 'platform=macOS,arch=arm64' -enableCodeCoverage YES` and parsing `xccov` output. Generated, test, and UI files are excluded from analysis.

**Overall**: SecuenciaCLICore 69.31%, SwiftSecuencia core library well-covered by individual component tests.

| File | Line coverage | Why it matters | Top uncovered |
|------|---------------|----------------|---------------|
| Sources/SwiftSecuencia/Export/BackgroundAudioExporter.swift | 0% (0/453) | Public API; background audio export path | All functions uncovered |
| Sources/SwiftSecuencia/Validation/FCPXMLValidator.swift | 0% (0/184) | Public API; FCPXML validation | All validation logic |
| Sources/SwiftSecuencia/UI/ExportMenuView.swift | 0% (0/353) | UI layer (acceptable) | SwiftUI views not testable in CLI tests |
| Sources/SecuenciaCLICore/Commands/BuildCommand.swift | 3.85% (8/208) | CLI entry point; main export flow | `run()`, `exportTimeline()`, `validateFCPXML()` |
| Sources/SecuenciaCLICore/Commands/SchemaCommand.swift | 2.33% (1/43) | CLI schema output command | `run()` function |
| Sources/SwiftSecuencia/Validation/ValidationResult.swift | 0% (0/56) | Validation result types | Error descriptions, result handling |
| Sources/SwiftSecuencia/Validation/ValidationError.swift | 0% (0/10) | Validation error types | Error descriptions |
| Sources/SwiftSecuencia/AppIntents/ExportTimelineAudioIntent.swift | 0% (0/57) | iOS Shortcuts integration | All intent handling |

**Why these matter**:
- **BackgroundAudioExporter** (0%): This is a major export path — background audio rendering for dual-dialogue timelines. Zero coverage suggests it's either unused or only manually tested.
- **FCPXMLValidator** (0%): DTD validation is a core feature, but the validator wrapper has no coverage. DTD validation tests exist (`FCPXMLDTDValidationTests`), so this may be a naming/target mismatch.
- **BuildCommand** (3.85%): The CLI's main export command has almost no coverage. Integration tests exercise it end-to-end, but unit-level coverage is missing.

**Acceptable omissions**:
- **ExportMenuView** (0%): SwiftUI view — can't be unit tested in CLI test target
- **AppIntents** (0%): iOS Shortcuts layer — requires iOS simulator or device
- **ValidationError/ValidationResult** (0%): Pure data types with computed descriptions — low value to test

## Pass 4 — Flaky-in-CI predictions

- `Tests/SwiftSecuenciaTests/TestUtilities.swift:37` — `Thread.sleep(forTimeInterval: 0.1)` used in process polling loop
  - **Smell**: real-time sleep for synchronization
  - **Why flaky**: Polls `say` command completion with 100ms sleeps up to 30s timeout. Under CI load, the process might complete between polls, wasting wall time. Worse, if `say` hangs, tests wait the full 30s.
  - **Action**: Replace with Swift Concurrency (`Process` + `waitUntilExit()` in Task) or use `Process.terminationHandler` callback instead of polling loop.

- `Tests/SwiftSecuenciaTests/TestUtilities.swift:82` — identical `Thread.sleep(forTimeInterval: 0.1)` polling pattern
  - **Smell**: real-time sleep for synchronization
  - **Action**: Same as above — refactor both generateAudioData variants to use async process handling.

- `Tests/SwiftSecuenciaTests/FCPXMLBundleExporterTests.swift:350` — `Task.sleep(for: .milliseconds(10))` in cancellation test
  - **Smell**: timing-dependent test
  - **Why less risky**: This one is testing Progress cancellation, not synchronization. The 10ms delay is intentionally short to trigger cancellation mid-export. **Low risk** — cancellation tests inherently need some delay; 10ms is reasonable.
  - **Action**: Keep as-is, but document why the delay is there.

**Note**: The CI workflow (`.github/workflows/tests.yml`) runs all tests without exclusions, so these patterns could manifest as intermittent failures under load.

## Pass 5 — Performance test gating

No findings. No `measure { }` blocks, no `@Test(.timeLimit(...))` benchmarks, and no `*Performance*` / `*Benchmark*` files detected.

The test suite is purely correctness-focused.

## Consolidated action items

### Add tests for (critical gaps)
- **BackgroundAudioExporter** — 0% coverage on 453-line audio export path. Add integration tests covering:
  - Basic dual-dialogue audio export with background track
  - Multi-lane audio mixing
  - Error handling for missing assets
  - Progress reporting
- **BuildCommand** — 3.85% coverage on CLI entry point. Add unit tests for:
  - FCPXML export flow (bundle vs standalone)
  - DTD validation toggling (--strict flag)
  - Error handling for invalid JSON input
  - Version string parsing and forwarding

### Refactor (medium priority)
- `Tests/SwiftSecuenciaTests/TestUtilities.swift:37,82` — Replace `Thread.sleep` polling with async Process handling or termination callbacks to avoid wasted CI wall-time and improve reliability under load.

### Delete or strengthen (low priority)
- `Tests/SwiftSecuenciaTests/FCPXMLVersionTests.swift:275,280` — Version string assertions are tautologies. Either strengthen to verify DTD compliance or remove as redundant.

### No action needed
- Performance gating: Suite is already CI-safe (no perf tests)
- High-repetition: No problematic patterns detected
- UI coverage (ExportMenuView, AppIntents): Acceptable omissions for CLI-focused test suite

## Notes

- **Lint status**: ✅ All 107 files pass SwiftLint strict mode with 0 violations.
- **CI configuration**: Tests run on `macos-26` via `make test`, which invokes xcodebuild with the full SwiftSecuencia-Package scheme. No test exclusions or gating environment variables detected.
- **Framework**: All tests use swift-testing (`@Test`, `#expect`) rather than XCTest, which is a modern choice and reduces risk of test ordering bugs.

---

**Generated**: 2026-07-21 by Claude Sonnet 4.5 via `/test-analysis` skill
