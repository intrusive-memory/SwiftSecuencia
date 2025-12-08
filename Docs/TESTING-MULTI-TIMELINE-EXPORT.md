# Testing Methodology: Multiple Timeline Export

**Status**: Draft
**Created**: 2025-12-06
**Target Coverage**: 80%+ of new code
**Related**: REQUIREMENTS-MULTI-TIMELINE-EXPORT.md

## Overview

This document defines the comprehensive testing strategy for the Multiple Timeline Export feature. The goal is to achieve 80%+ code coverage with all tests passing before merging to development.

## Test Coverage Goals

### Overall Coverage Target: 80%+

**New Code to Test**:
- `FCPXMLExporter.exportMultiTimeline()` method
- Chapter range calculation logic
- Clip filtering and distribution
- Offset re-timing logic
- Multi-project XML generation

**Minimum Coverage Requirements**:
- Unit tests: 85%+ (core logic)
- Integration tests: 75%+ (full export workflows)
- Edge cases: 100% (all edge cases must be tested)

## Test Organization

### File Structure

```
Tests/SwiftSecuenciaTests/
├── MultiTimelineExportTests.swift           # Main test suite
├── ChapterRangeCalculationTests.swift       # Chapter range logic
├── ClipDistributionTests.swift              # Clip filtering tests
├── OffsetRetimingTests.swift                # Re-timing logic tests
├── MultiTimelineIntegrationTests.swift      # Full export tests
└── TestUtilities.swift                       # Shared helpers (existing)
```

## Test Suite Breakdown

### 1. Chapter Range Calculation Tests

**File**: `ChapterRangeCalculationTests.swift`
**Coverage Target**: 90%+
**Purpose**: Test the logic that calculates time ranges for each chapter

#### Test Cases

##### TC-1.1: No Chapter Markers (Fallback)
```swift
@Test func noChapterMarkersFallsBackToSingleTimeline() async throws
```
- **Setup**: Timeline with no chapter markers
- **Expected**: Returns single ChapterRange covering entire timeline
- **Validates**: FR-5 (empty timeline handling)

##### TC-1.2: Single Chapter Marker at Zero
```swift
@Test func singleChapterMarkerAtZero() async throws
```
- **Setup**: Timeline with one chapter at 0s
- **Expected**: Single ChapterRange from 0s to timeline.duration
- **Validates**: EC-1 (single chapter marker)

##### TC-1.3: Single Chapter Marker Not at Zero
```swift
@Test func singleChapterMarkerNotAtZero() async throws
```
- **Setup**: Timeline 120s, chapter at 30s
- **Expected**: Single ChapterRange from 0s to 120s (includes pre-chapter content)
- **Validates**: FR-6 (pre-chapter content inclusion)

##### TC-1.4: Multiple Chapter Markers
```swift
@Test func multipleChapterMarkersCreatesCorrectRanges() async throws
```
- **Setup**: Timeline 300s, chapters at 0s, 90s, 180s
- **Expected**:
  - Range 1: 0s-90s (duration 90s)
  - Range 2: 90s-180s (duration 90s)
  - Range 3: 180s-300s (duration 120s)
- **Validates**: FR-1 (chapter splitting), FR-8 (duration calculation)

##### TC-1.5: Chapter Markers Out of Order
```swift
@Test func chapterMarkersOutOfOrderAreSorted() async throws
```
- **Setup**: Chapters at 120s, 0s, 60s (unsorted)
- **Expected**: Sorted to 0s, 60s, 120s; correct ranges calculated
- **Validates**: NFR-3 (validation)

##### TC-1.6: Chapter Marker Beyond Timeline Duration
```swift
@Test func chapterMarkerBeyondTimelineDurationIsIgnored() async throws
```
- **Setup**: Timeline 120s, chapters at 0s, 60s, 200s
- **Expected**: Only use 0s and 60s chapters; 200s ignored
- **Validates**: EC-2 (chapter beyond timeline end)

##### TC-1.7: Duplicate Chapter Start Times
```swift
@Test func duplicateChapterStartTimesUseFirstOccurrence() async throws
```
- **Setup**: Chapters at 0s ("Intro"), 60s ("Main"), 60s ("Duplicate")
- **Expected**: Two ranges: 0s-60s ("Intro"), 60s-end ("Main")
- **Validates**: EC-3 (duplicate times)

##### TC-1.8: Chapter Marker Names
```swift
@Test func emptyChapterNamesGenerateUntitledNames() async throws
```
- **Setup**: Chapters with empty `value` properties
- **Expected**: Names like "Untitled Chapter 1", "Untitled Chapter 2"
- **Validates**: FR-3 (timeline naming)

### 2. Clip Distribution Tests

**File**: `ClipDistributionTests.swift`
**Coverage Target**: 85%+
**Purpose**: Test clip filtering logic for chapter ranges

#### Test Cases

##### TC-2.1: Clip Entirely Within Chapter Range
```swift
@Test func clipEntirelyWithinChapterRangeIsIncluded() async throws
```
- **Setup**: Chapter 0s-60s, clip at 10s duration 20s
- **Expected**: Clip included in chapter timeline
- **Validates**: FR-4 (clip distribution)

##### TC-2.2: Clip Starts in Range, Ends After
```swift
@Test func clipStartsInRangeEndsAfterIsIncluded() async throws
```
- **Setup**: Chapter 0s-60s, clip at 50s duration 20s (ends at 70s)
- **Expected**: Clip included in full (no trimming)
- **Validates**: FR-4 (overlapping clips), EC-6 (spanning clip)

##### TC-2.3: Clip Starts Before Range
```swift
@Test func clipStartsBeforeRangeIsNotIncluded() async throws
```
- **Setup**: Chapter 60s-120s, clip at 50s duration 20s (ends at 70s)
- **Expected**: Clip NOT included (starts in previous chapter)
- **Validates**: FR-4 (clip ownership based on start time)

##### TC-2.4: Clip Exactly at Chapter Boundary (Start)
```swift
@Test func clipAtChapterBoundaryStartIsIncluded() async throws
```
- **Setup**: Chapter 60s-120s, clip at 60s duration 10s
- **Expected**: Clip included (starts exactly at chapter start)
- **Validates**: FR-4 (inclusive start boundary)

##### TC-2.5: Clip Exactly at Chapter Boundary (End)
```swift
@Test func clipAtChapterBoundaryEndIsNotIncluded() async throws
```
- **Setup**: Chapter 0s-60s, clip at 60s duration 10s
- **Expected**: Clip NOT included (belongs to next chapter)
- **Validates**: FR-4 (exclusive end boundary)

##### TC-2.6: Multi-Lane Filtering (Lane 0 Only)
```swift
@Test func onlyLaneZeroClipsAreIncluded() async throws
```
- **Setup**: Chapter 0s-60s with clips:
  - Clip A: lane 0, 10s-20s
  - Clip B: lane 1, 15s-25s
  - Clip C: lane -1, 20s-30s
  - Clip D: lane 0, 40s-50s
- **Expected**: Only Clip A and D included
- **Validates**: FR-4 (primary lane only)

##### TC-2.7: Empty Chapter (No Clips)
```swift
@Test func emptyChapterRangeCreatesEmptySpine() async throws
```
- **Setup**: Chapter 60s-120s, no lane 0 clips in that range
- **Expected**: Timeline created with empty `<spine>` element
- **Validates**: EC-4 (empty chapter)

##### TC-2.8: Multiple Clips in Chapter
```swift
@Test func multipleClipsInChapterAreSortedByOffset() async throws
```
- **Setup**: Chapter 0s-60s, clips at 40s, 10s, 30s, 20s
- **Expected**: Clips in spine sorted: 10s, 20s, 30s, 40s
- **Validates**: FR-4 (clip ordering)

### 3. Offset Re-timing Tests

**File**: `OffsetRetimingTests.swift`
**Coverage Target**: 90%+
**Purpose**: Test clip offset re-timing logic

#### Test Cases

##### TC-3.1: First Chapter (Starts at 0s)
```swift
@Test func firstChapterClipsHaveUnchangedOffsets() async throws
```
- **Setup**: Chapter 0s-60s, clips at 0s, 10s, 30s
- **Expected**: Offsets remain 0s, 10s, 30s (no shift needed)
- **Validates**: Offset re-timing for first chapter

##### TC-3.2: Second Chapter (Re-time from Chapter Start)
```swift
@Test func secondChapterClipsAreRetimed() async throws
```
- **Setup**: Chapter 60s-120s, clips at 60s, 70s, 90s
- **Expected**: Offsets become 0s, 10s, 30s (shifted back by 60s)
- **Validates**: Offset re-timing formula (newOffset = clip.offset - chapterStart)

##### TC-3.3: Third Chapter with Large Offset
```swift
@Test func thirdChapterWithLargeOffsetRetimesCorrectly() async throws
```
- **Setup**: Chapter 3600s-4200s (1 hour in), clips at 3610s, 3700s
- **Expected**: Offsets become 10s, 100s
- **Validates**: Re-timing with large timecode values

##### TC-3.4: Source Start Unchanged
```swift
@Test func sourceStartRemainsUnchanged() async throws
```
- **Setup**: Chapter 60s-120s, clip at 70s with sourceStart=5s
- **Expected**: newOffset=10s, sourceStart=5s (unchanged)
- **Validates**: FR-4 (sourceStart preservation)

##### TC-3.5: Duration Unchanged
```swift
@Test func clipDurationRemainsUnchanged() async throws
```
- **Setup**: Chapter 60s-120s, clip at 70s duration 25s
- **Expected**: newOffset=10s, duration=25s (unchanged)
- **Validates**: FR-4 (duration preservation)

##### TC-3.6: Clip Name Unchanged
```swift
@Test func clipNameRemainsUnchanged() async throws
```
- **Setup**: Clip with name="My Clip" in second chapter
- **Expected**: Clip retains name attribute in re-timed timeline
- **Validates**: Clip metadata preservation

### 4. Resource Management Tests

**File**: `MultiTimelineExportTests.swift` (section)
**Coverage Target**: 85%+
**Purpose**: Test shared resource generation

#### Test Cases

##### TC-4.1: Single Resources Section
```swift
@Test func multiTimelineExportHasSingleResourcesSection() async throws
```
- **Setup**: 3 chapters, 5 unique assets
- **Expected**: Exactly one `<resources>` element in FCPXML
- **Validates**: FR-7 (shared resources section)

##### TC-4.2: Format Resource Shared
```swift
@Test func formatResourceIsSharedAcrossTimelines() async throws
```
- **Setup**: 3 chapters using same video format
- **Expected**: One `<format id="r1">` resource, all sequences reference "r1"
- **Validates**: FR-7 (resource sharing)

##### TC-4.3: Asset Resources Deduplicated
```swift
@Test func assetResourcesAreDeduplicatedAcrossChapters() async throws
```
- **Setup**: Asset A used in chapters 1 and 3, Asset B in chapter 2
- **Expected**: Two `<asset>` elements (A and B), referenced by ID
- **Validates**: FR-7 (asset deduplication)

##### TC-4.4: Resource ID Uniqueness
```swift
@Test func resourceIDsAreUnique() async throws
```
- **Setup**: Multi-timeline export with 10 assets
- **Expected**: All resource IDs are unique (r1, r2, ..., r11)
- **Validates**: Resource ID generation

### 5. XML Structure Tests

**File**: `MultiTimelineExportTests.swift` (section)
**Coverage Target**: 90%+
**Purpose**: Test generated FCPXML structure

#### Test Cases

##### TC-5.1: Library > Event > Projects Hierarchy
```swift
@Test func multiTimelineExportHasCorrectHierarchy() async throws
```
- **Setup**: 3 chapters
- **Expected**:
  ```xml
  <fcpxml version="1.13">
    <resources>...</resources>
    <library>
      <event name="Test Event">
        <project name="Chapter 1">...</project>
        <project name="Chapter 2">...</project>
        <project name="Chapter 3">...</project>
      </event>
    </library>
  </fcpxml>
  ```
- **Validates**: FR-2 (FCPXML structure)

##### TC-5.2: Project Names from Chapter Values
```swift
@Test func projectNamesMatchChapterValues() async throws
```
- **Setup**: Chapters "Introduction", "Main Content", "Conclusion"
- **Expected**: Three `<project>` elements with matching names
- **Validates**: FR-3 (timeline naming)

##### TC-5.3: Sequence Duration Per Chapter
```swift
@Test func sequenceDurationsMatchChapterDurations() async throws
```
- **Setup**: Chapters 0s-90s, 90s-180s, 180s-300s
- **Expected**:
  - Sequence 1: `duration="90s"`
  - Sequence 2: `duration="90s"`
  - Sequence 3: `duration="120s"`
- **Validates**: FR-8 (timeline duration calculation)

##### TC-5.4: Sequence tcStart Always 0s
```swift
@Test func sequenceTcStartIsAlwaysZero() async throws
```
- **Setup**: 3 chapters starting at various times
- **Expected**: All sequences have `tcStart="0s"`
- **Validates**: FR-4 (clips re-timed to start at 0s)

##### TC-5.5: Valid XML Parsing
```swift
@Test func multiTimelineExportGeneratesValidXML() async throws
```
- **Setup**: Multi-timeline export
- **Expected**: XML can be parsed by XMLDocument without errors
- **Validates**: XML well-formedness

### 6. Integration Tests

**File**: `MultiTimelineIntegrationTests.swift`
**Coverage Target**: 75%+
**Purpose**: Full end-to-end export workflows

#### Test Cases

##### TC-6.1: Complete 3-Chapter Export
```swift
@Test func completeThreeChapterExport() async throws
```
- **Setup**:
  - Timeline 300s total
  - Chapters: "Intro" (0s), "Main" (90s), "Outro" (240s)
  - 10 clips distributed across timeline (lane 0 only)
  - 3 different assets
- **Expected**:
  - 3 projects in one event
  - Correct clip distribution (verify counts per project)
  - All clips re-timed correctly
  - Shared resources
  - Valid XML structure
- **Validates**: Full FR-1 through FR-8

##### TC-6.2: Single Chapter Export
```swift
@Test func singleChapterExportMatchesSingleTimelineExport() async throws
```
- **Setup**: Timeline with one chapter marker at 0s
- **Expected**: Output matches standard `export()` result (structure-wise)
- **Validates**: EC-1 (single chapter)

##### TC-6.3: No Chapters Fallback
```swift
@Test func noChaptersFallsBackToStandardExport() async throws
```
- **Setup**: Timeline with no chapter markers
- **Expected**: Output matches standard `export()` exactly
- **Validates**: FR-5 (fallback behavior)

##### TC-6.4: Pre-Chapter Content Inclusion
```swift
@Test func preChapterContentIsIncluded() async throws
```
- **Setup**:
  - Timeline 180s
  - First chapter at 30s (not 0s)
  - Clips at 0s, 10s, 20s, 40s, 50s
- **Expected**:
  - First timeline includes clips at 0s, 10s, 20s (pre-chapter)
  - And clips at 40s, 50s (post-chapter start)
- **Validates**: FR-6 (pre-chapter content)

##### TC-6.5: Multi-Lane Timeline (Lane 0 Only Export)
```swift
@Test func multiLaneTimelineExportsLaneZeroOnly() async throws
```
- **Setup**: Timeline with clips on lanes -2, -1, 0, 1, 2, 3
- **Expected**: Only lane 0 clips appear in any exported project
- **Validates**: FR-4 (primary lane only)

##### TC-6.6: Asset References Across Chapters
```swift
@Test func assetReferencedInMultipleChaptersWorks() async throws
```
- **Setup**:
  - Asset A used in chapters 1, 2, 3
  - Asset B used only in chapter 2
- **Expected**:
  - One `<asset>` for A, one for B
  - All clips correctly reference asset IDs
- **Validates**: FR-7 (shared resources)

##### TC-6.7: Empty Middle Chapter
```swift
@Test func emptyMiddleChapterGeneratesValidTimeline() async throws
```
- **Setup**:
  - Chapters at 0s, 60s, 120s
  - Clips in chapters 1 and 3, but none in chapter 2
- **Expected**:
  - 3 projects generated
  - Chapter 2 has empty `<spine>`
  - Valid XML structure
- **Validates**: EC-4 (empty chapter)

##### TC-6.8: Large Timeline with Many Chapters
```swift
@Test func largeTimelineWithManyChapters() async throws
```
- **Setup**:
  - Timeline 1800s (30 minutes)
  - 10 chapters (every 3 minutes)
  - 100 clips distributed throughout
- **Expected**:
  - 10 projects created
  - Correct clip distribution (verify sample chapters)
  - Performance acceptable (no timeout)
- **Validates**: NFR-1 (performance), scalability

### 7. DTD Validation Tests

**File**: `MultiTimelineExportTests.swift` (section)
**Coverage Target**: 100%
**Purpose**: Validate against FCPXML DTD

#### Test Cases

##### TC-7.1: Validate Against FCPXML 1.11 DTD
```swift
@Test func multiTimelineExportValidatesAgainstFCPXML_1_11_DTD() async throws
```
- **Setup**: Multi-timeline export with version .v1_11
- **Expected**: XML validates against FCPXMLv1_11.dtd
- **Validates**: XML compliance

##### TC-7.2: Validate Against FCPXML 1.12 DTD
```swift
@Test func multiTimelineExportValidatesAgainstFCPXML_1_12_DTD() async throws
```
- **Setup**: Multi-timeline export with version .v1_12
- **Expected**: XML validates against FCPXMLv1_12.dtd
- **Validates**: XML compliance

##### TC-7.3: Validate Against FCPXML 1.13 DTD
```swift
@Test func multiTimelineExportValidatesAgainstFCPXML_1_13_DTD() async throws
```
- **Setup**: Multi-timeline export with version .v1_13
- **Expected**: XML validates against FCPXMLv1_13.dtd
- **Validates**: XML compliance

### 8. Edge Case Tests

**File**: `MultiTimelineExportTests.swift` (section)
**Coverage Target**: 100%
**Purpose**: Test all documented edge cases

#### Test Cases

##### TC-8.1: EC-1 - Single Chapter Marker
```swift
@Test func edgeCase_singleChapterMarker() async throws
```
- **Documented in**: EC-1
- **Expected**: Single timeline with chapter name

##### TC-8.2: EC-2 - Chapter Beyond Timeline End
```swift
@Test func edgeCase_chapterBeyondTimelineEnd() async throws
```
- **Documented in**: EC-2
- **Expected**: Out-of-range chapters ignored

##### TC-8.3: EC-3 - Duplicate Chapter Times
```swift
@Test func edgeCase_duplicateChapterTimes() async throws
```
- **Documented in**: EC-3
- **Expected**: First occurrence used

##### TC-8.4: EC-4 - Empty Chapter
```swift
@Test func edgeCase_emptyChapter() async throws
```
- **Documented in**: EC-4
- **Expected**: Valid timeline with empty spine

##### TC-8.5: EC-5 - Chapter at Non-Zero Start
```swift
@Test func edgeCase_chapterAtNonZeroStart() async throws
```
- **Documented in**: EC-5
- **Expected**: First timeline includes pre-chapter content

##### TC-8.6: EC-6 - Overlapping Clip at Boundary
```swift
@Test func edgeCase_overlappingClipAtBoundary() async throws
```
- **Documented in**: EC-6
- **Expected**: Clip included in full in chapter where it starts

## Test Implementation Guidelines

### 1. Test Fixtures

Use in-memory SwiftData containers for all tests:

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(
    for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
    configurations: config
)
let context = ModelContext(container)
```

### 2. Helper Functions

Create shared helpers in `TestUtilities.swift`:

```swift
extension TestUtilities {
    /// Creates a test timeline with chapter markers
    static func createTimelineWithChapters(
        name: String,
        duration: Timecode,
        chapters: [(start: Timecode, value: String)],
        context: ModelContext
    ) -> Timeline {
        let timeline = Timeline(name: name)
        timeline.chapterMarkers = chapters.map {
            ChapterMarker(start: $0.start, value: $0.value)
        }
        context.insert(timeline)
        return timeline
    }

    /// Creates a test clip with asset
    static func createTestClip(
        offset: Timecode,
        duration: Timecode,
        lane: Int = 0,
        sourceStart: Timecode = .zero,
        mimeType: String = "video/mp4",
        context: ModelContext
    ) -> TimelineClip {
        let asset = TypedDataStorage(
            providerId: "test",
            requestorID: UUID().uuidString,
            mimeType: mimeType,
            binaryValue: Data(),
            durationSeconds: duration.seconds
        )
        context.insert(asset)

        return TimelineClip(
            assetStorageId: asset.id,
            offset: offset,
            duration: duration,
            sourceStart: sourceStart,
            lane: lane
        )
    }

    /// Validates XML structure using XPath
    static func validateXMLPath(
        _ xml: String,
        path: String,
        expectedCount: Int
    ) throws {
        let data = xml.data(using: .utf8)!
        let doc = try XMLDocument(data: data)
        let nodes = try doc.nodes(forXPath: path)
        #expect(nodes.count == expectedCount)
    }

    /// Extracts project names from multi-timeline XML
    static func extractProjectNames(from xml: String) throws -> [String] {
        let data = xml.data(using: .utf8)!
        let doc = try XMLDocument(data: data)
        let projectNodes = try doc.nodes(forXPath: "//project")
        return projectNodes.compactMap { node in
            (node as? XMLElement)?.attribute(forName: "name")?.stringValue
        }
    }
}
```

### 3. Assertion Patterns

Use Swift Testing's `#expect` macro:

```swift
// Basic expectations
#expect(xml.contains("<project name=\"Chapter 1\">"))

// Parsed XML validation
let data = xml.data(using: .utf8)!
let doc = try XMLDocument(data: data)
let projects = try doc.nodes(forXPath: "//project")
#expect(projects.count == 3)

// XPath attribute checks
let firstProject = projects[0] as! XMLElement
#expect(firstProject.attribute(forName: "name")?.stringValue == "Introduction")
```

### 4. Test Organization

Group related tests using Swift Testing's test organization:

```swift
@Suite("Chapter Range Calculation")
struct ChapterRangeCalculationTests {
    @Test("No chapter markers falls back")
    func noChapterMarkersFallback() async throws { ... }

    @Test("Single chapter at zero")
    func singleChapterAtZero() async throws { ... }
}

@Suite("Clip Distribution")
struct ClipDistributionTests {
    @Test("Clip within range is included")
    func clipWithinRange() async throws { ... }
}
```

## Coverage Measurement

### Running Tests with Coverage

```bash
# Run tests with code coverage
swift test --enable-code-coverage

# Generate coverage report
xcrun llvm-cov show \
  .build/debug/SwiftSecuenciaPackageTests.xctest/Contents/MacOS/SwiftSecuenciaPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata \
  -format=html \
  -output-dir=coverage-report

# View coverage report
open coverage-report/index.html
```

### Coverage Verification Checklist

- [ ] `FCPXMLExporter.exportMultiTimeline()`: 85%+
- [ ] Chapter range calculation: 90%+
- [ ] Clip distribution logic: 85%+
- [ ] Offset re-timing: 90%+
- [ ] Resource generation: 85%+
- [ ] XML structure generation: 90%+
- [ ] Edge cases: 100%
- [ ] Overall new code: 80%+

## Test Execution Strategy

### Development Workflow

1. **Write Tests First (TDD)**
   - Write test cases for a specific component
   - Run tests (they should fail)
   - Implement the feature
   - Run tests until they pass
   - Refactor if needed

2. **Continuous Testing**
   - Run full test suite before each commit
   - Use `swift test` in pre-commit hook
   - Ensure all tests pass before pushing

3. **Coverage Monitoring**
   - Check coverage after each test addition
   - Identify uncovered code paths
   - Add tests for uncovered areas

### CI/CD Integration

GitHub Actions workflow should:
1. Run `swift test` on every PR
2. Generate coverage report
3. Fail PR if coverage < 80%
4. Comment coverage stats on PR

## Test Data Scenarios

### Scenario 1: Simple 3-Chapter Timeline
- **Duration**: 300s
- **Chapters**: "Intro" (0s), "Main" (90s), "Outro" (240s)
- **Clips**: 6 clips evenly distributed
- **Purpose**: Basic happy path testing

### Scenario 2: Complex Multi-Lane Timeline
- **Duration**: 600s
- **Chapters**: 5 chapters
- **Clips**: 20 clips across lanes -2 to +3
- **Purpose**: Multi-lane filtering validation

### Scenario 3: Sparse Timeline
- **Duration**: 1800s
- **Chapters**: 10 chapters
- **Clips**: Only 5 clips (gaps between chapters)
- **Purpose**: Empty chapter handling

### Scenario 4: Dense Timeline
- **Duration**: 300s
- **Chapters**: 3 chapters
- **Clips**: 50 clips (many overlapping boundaries)
- **Purpose**: Boundary condition testing

### Scenario 5: Edge Case Timeline
- **Duration**: 180s
- **Chapters**: Unsorted, duplicates, out-of-range
- **Clips**: Clips at exact boundaries
- **Purpose**: Edge case validation

## Success Criteria

### Pre-Merge Checklist

- [ ] All 50+ test cases pass
- [ ] Code coverage ≥ 80% on new code
- [ ] No test timeouts or performance issues
- [ ] All edge cases covered
- [ ] DTD validation passes for all FCPXML versions
- [ ] No compiler warnings
- [ ] SwiftLint passes with no violations
- [ ] Tests run successfully in CI/CD

### Quality Gates

1. **Unit Tests**: All pass, 85%+ coverage
2. **Integration Tests**: All pass, 75%+ coverage
3. **DTD Validation**: All pass (1.11, 1.12, 1.13)
4. **Edge Cases**: 100% coverage
5. **Performance**: No test exceeds 5s execution time

## Test Maintenance

### When to Update Tests

- When requirements change (update requirements doc first)
- When bugs are discovered (add regression test)
- When new edge cases are identified
- When FCPXML versions are added

### Test Review Process

- All new tests reviewed in PR
- Test clarity and coverage checked
- Test data scenarios validated
- Helper functions extracted when duplicated

## Appendix A: Test Case Summary

| Category | Test Count | Coverage Target | Priority |
|----------|-----------|-----------------|----------|
| Chapter Range Calculation | 8 | 90% | High |
| Clip Distribution | 8 | 85% | High |
| Offset Re-timing | 6 | 90% | High |
| Resource Management | 4 | 85% | Medium |
| XML Structure | 5 | 90% | High |
| Integration | 8 | 75% | High |
| DTD Validation | 3 | 100% | High |
| Edge Cases | 6 | 100% | High |
| **Total** | **48** | **80%+** | - |

## Appendix B: XPath Validation Patterns

Common XPath patterns for validation:

```swift
// Count projects
"//project"  // Expected: chapter count

// Count clips in first project
"//project[1]/sequence/spine/asset-clip"

// Get project names
"//project/@name"

// Verify shared resources
"//resources/format"  // Expected: 1
"//resources/asset"   // Expected: unique asset count

// Verify sequence attributes
"//sequence/@duration"
"//sequence/@tcStart"

// Count clips with specific lane
"//asset-clip[@lane='0']"
```

## Appendix C: Common Test Assertions

```swift
// XML structure validation
#expect(xml.contains("<fcpxml version=\"1.13\">"))
#expect(xml.contains("<library>"))
#expect(xml.contains("</fcpxml>"))

// Project count
let projectCount = xml.components(separatedBy: "<project").count - 1
#expect(projectCount == expectedChapterCount)

// Clip count in spine
let doc = try XMLDocument(data: xml.data(using: .utf8)!)
let clips = try doc.nodes(forXPath: "//project[1]/sequence/spine/asset-clip")
#expect(clips.count == expectedClipCount)

// Offset validation
let clipElement = clips[0] as! XMLElement
let offset = clipElement.attribute(forName: "offset")?.stringValue
#expect(offset == "0s")  // Re-timed to chapter start

// Duration validation
let sequence = try doc.nodes(forXPath: "//project[1]/sequence").first as! XMLElement
let duration = sequence.attribute(forName: "duration")?.stringValue
#expect(duration == "90s")
```

## References

- REQUIREMENTS-MULTI-TIMELINE-EXPORT.md
- FCPXMLExporter.swift
- Timeline.swift
- ChapterMarker.swift
- Existing test files: FCPXMLExportTests.swift, MetadataTests.swift
