# Implementation & Testing Methodology: Multiple Timeline Export

**Status**: Draft
**Created**: 2025-12-06
**Target Version**: v1.1.0
**Related Documents**:
- REQUIREMENTS-MULTI-TIMELINE-EXPORT.md
- TESTING-MULTI-TIMELINE-EXPORT.md

## Overview

This document defines the **step-by-step implementation methodology** for the Multiple Timeline Export feature, specifying what gets built when, what gets tested when, and how to ensure 80%+ code coverage throughout development.

## Development Philosophy

### Test-Driven Development (TDD)

We will follow a **strict TDD approach**:
1. ✅ **Write tests first** (they will fail - that's expected)
2. ✅ **Implement just enough code** to make tests pass
3. ✅ **Refactor** while keeping tests green
4. ✅ **Verify coverage** after each phase
5. ✅ **No code without tests**

### Incremental Development

Build the feature in **6 phases**, each with:
- Clear deliverables
- Specific test cases
- Coverage targets
- Exit criteria

## Implementation Phases

---

## Phase 1: Foundation - Chapter Range Calculation

**Duration Estimate**: Day 1
**Coverage Target**: 90%+
**Test File**: `ChapterRangeCalculationTests.swift`

### What We're Building

A `ChapterRange` struct and helper functions to calculate time ranges from chapter markers.

### Implementation Order

#### Step 1.1: Create Supporting Types (15 min)

**File**: `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift`

```swift
/// Represents a chapter range for multi-timeline export.
struct ChapterRange: Sendable, Equatable {
    let index: Int              // 0-based chapter index
    let name: String            // Chapter marker value or "Untitled Chapter N"
    let startTime: Timecode     // Chapter start in original timeline
    let endTime: Timecode       // Chapter end in original timeline
    let duration: Timecode      // endTime - startTime
}
```

**Tests to Write First**: None yet (just a struct)

#### Step 1.2: Write Chapter Range Calculation Tests (30 min)

**File**: `Tests/SwiftSecuenciaTests/ChapterRangeCalculationTests.swift`

Create the test file with **8 test cases**:

```swift
import Testing
import Foundation
@testable import SwiftSecuencia

@Suite("Chapter Range Calculation")
struct ChapterRangeCalculationTests {

    @Test("No chapter markers returns empty array")
    func noChapterMarkersReturnsEmpty() async throws {
        // Timeline with no chapters
        // Expected: empty array []
    }

    @Test("Single chapter at zero")
    func singleChapterAtZero() async throws {
        // Timeline 120s, chapter at 0s "Intro"
        // Expected: [ChapterRange(0, "Intro", 0s, 120s, 120s)]
    }

    @Test("Single chapter not at zero includes pre-content")
    func singleChapterNotAtZero() async throws {
        // Timeline 120s, chapter at 30s "Main"
        // Expected: [ChapterRange(0, "Main", 0s, 120s, 120s)]
        // Note: Starts at 0s, not 30s (includes pre-chapter content)
    }

    @Test("Multiple chapters create correct ranges")
    func multipleChaptersCreateCorrectRanges() async throws {
        // Timeline 300s, chapters at 0s, 90s, 180s
        // Expected: 3 ranges (0-90s, 90-180s, 180-300s)
    }

    @Test("Chapter markers out of order are sorted")
    func outOfOrderMarkersAreSorted() async throws {
        // Chapters at 120s, 0s, 60s (unsorted)
        // Expected: Sorted to 0s, 60s, 120s
    }

    @Test("Chapter beyond timeline duration is ignored")
    func chapterBeyondDurationIgnored() async throws {
        // Timeline 120s, chapters at 0s, 60s, 200s
        // Expected: Only 0s and 60s used
    }

    @Test("Duplicate chapter times use first occurrence")
    func duplicateTimesUseFirst() async throws {
        // Chapters at 0s "A", 60s "B", 60s "C"
        // Expected: Two ranges with "A" and "B" (C ignored)
    }

    @Test("Empty chapter name generates untitled name")
    func emptyNameGeneratesUntitled() async throws {
        // Chapter with value=""
        // Expected: name="Untitled Chapter 1"
    }
}
```

**Run tests**: They should all fail (function doesn't exist yet)

#### Step 1.3: Implement Chapter Range Calculation (1 hour)

**File**: `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift`

Add the function:

```swift
extension FCPXMLExporter {
    /// Calculates chapter ranges from timeline's chapter markers.
    ///
    /// - Parameters:
    ///   - timeline: The timeline with chapter markers.
    /// - Returns: Array of chapter ranges, or empty if no chapters.
    private func calculateChapterRanges(timeline: Timeline) -> [ChapterRange] {
        // Handle empty case
        guard !timeline.chapterMarkers.isEmpty else {
            return []
        }

        // Sort and filter chapters
        let sortedChapters = timeline.chapterMarkers
            .filter { $0.start < timeline.duration }  // Ignore out-of-range
            .sorted { $0.start < $1.start }

        // Remove duplicates (keep first occurrence)
        var uniqueChapters: [ChapterMarker] = []
        var seenTimes: Set<Timecode> = []
        for chapter in sortedChapters {
            if !seenTimes.contains(chapter.start) {
                uniqueChapters.append(chapter)
                seenTimes.insert(chapter.start)
            }
        }

        // Calculate ranges
        var ranges: [ChapterRange] = []
        for (index, chapter) in uniqueChapters.enumerated() {
            // Start time: always use chapter start (even if first chapter is not at 0)
            // But we want first range to start at 0s to include pre-chapter content
            let startTime = (index == 0) ? .zero : chapter.start

            // End time: next chapter start, or timeline duration
            let endTime = (index + 1 < uniqueChapters.count)
                ? uniqueChapters[index + 1].start
                : timeline.duration

            let duration = endTime - startTime

            // Name: use chapter value, or generate untitled
            let name = chapter.value.isEmpty
                ? "Untitled Chapter \(index + 1)"
                : chapter.value

            ranges.append(ChapterRange(
                index: index,
                name: name,
                startTime: startTime,
                endTime: endTime,
                duration: duration
            ))
        }

        return ranges
    }
}
```

**Run tests**: All 8 tests should now pass

#### Step 1.4: Verify Coverage (10 min)

```bash
swift test --filter ChapterRangeCalculationTests --enable-code-coverage
```

**Expected**: 90%+ coverage on `calculateChapterRanges()`

### Phase 1 Exit Criteria

- [x] `ChapterRange` struct created
- [x] `calculateChapterRanges()` function implemented
- [x] 8 tests written and passing
- [x] 90%+ coverage on chapter range calculation
- [x] No compiler warnings

---

## Phase 2: Clip Distribution Logic

**Duration Estimate**: Day 1-2
**Coverage Target**: 85%+
**Test File**: `ClipDistributionTests.swift`

### What We're Building

Logic to filter and distribute clips to the correct chapter timeline based on their time range.

### Implementation Order

#### Step 2.1: Write Clip Distribution Tests (45 min)

**File**: `Tests/SwiftSecuenciaTests/ClipDistributionTests.swift`

Create **8 test cases**:

```swift
@Suite("Clip Distribution")
struct ClipDistributionTests {

    @Test("Clip entirely within range is included")
    func clipWithinRangeIncluded() async throws

    @Test("Clip starts in range, ends after is included")
    func clipSpanningBoundaryIncluded() async throws

    @Test("Clip starts before range is not included")
    func clipBeforeRangeExcluded() async throws

    @Test("Clip at chapter start boundary is included")
    func clipAtStartBoundaryIncluded() async throws

    @Test("Clip at chapter end boundary is excluded")
    func clipAtEndBoundaryExcluded() async throws

    @Test("Only lane 0 clips are included")
    func onlyLaneZeroIncluded() async throws

    @Test("Empty chapter range returns no clips")
    func emptyChapterReturnsNoClips() async throws

    @Test("Multiple clips sorted by offset")
    func multipleClipsSorted() async throws
}
```

**Run tests**: Should fail (function doesn't exist)

#### Step 2.2: Implement Clip Filtering Function (1 hour)

**File**: `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift`

```swift
extension FCPXMLExporter {
    /// Filters clips for a specific chapter range.
    ///
    /// Only includes clips on lane 0 that start within the chapter range.
    ///
    /// - Parameters:
    ///   - timeline: The timeline containing clips.
    ///   - chapterRange: The chapter range to filter for.
    /// - Returns: Array of clips for this chapter, sorted by offset.
    private func clipsForChapter(
        timeline: Timeline,
        chapterRange: ChapterRange
    ) -> [TimelineClip] {
        return timeline.clips
            .filter { $0.lane == 0 }  // Only lane 0
            .filter { clip in
                // Clip must start within chapter range
                // Inclusive start, exclusive end
                clip.offset >= chapterRange.startTime
                    && clip.offset < chapterRange.endTime
            }
            .sorted { $0.offset < $1.offset }
    }
}
```

**Run tests**: All 8 tests should pass

#### Step 2.3: Verify Coverage (10 min)

```bash
swift test --filter ClipDistributionTests --enable-code-coverage
```

**Expected**: 85%+ coverage on `clipsForChapter()`

### Phase 2 Exit Criteria

- [x] `clipsForChapter()` function implemented
- [x] 8 tests written and passing
- [x] 85%+ coverage on clip distribution
- [x] Lane filtering works correctly
- [x] Boundary conditions handled

---

## Phase 3: Offset Re-timing Logic

**Duration Estimate**: Day 2
**Coverage Target**: 90%+
**Test File**: `OffsetRetimingTests.swift`

### What We're Building

Logic to re-time clips so each chapter timeline starts at 0s.

### Implementation Order

#### Step 3.1: Write Offset Re-timing Tests (30 min)

**File**: `Tests/SwiftSecuenciaTests/OffsetRetimingTests.swift`

Create **6 test cases**:

```swift
@Suite("Offset Re-timing")
struct OffsetRetimingTests {

    @Test("First chapter clips unchanged")
    func firstChapterUnchanged() async throws

    @Test("Second chapter clips re-timed")
    func secondChapterRetimed() async throws

    @Test("Large offset values re-time correctly")
    func largeOffsetsRetimed() async throws

    @Test("Source start preserved")
    func sourceStartPreserved() async throws

    @Test("Duration unchanged")
    func durationUnchanged() async throws

    @Test("Clip name preserved")
    func clipNamePreserved() async throws
}
```

**Run tests**: Should fail

#### Step 3.2: Create Retimed Clip Representation (30 min)

**File**: `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift`

```swift
/// A clip with re-timed offset for export.
struct RetimedClip {
    let clip: TimelineClip
    let newOffset: Timecode

    init(clip: TimelineClip, chapterStartTime: Timecode) {
        self.clip = clip
        self.newOffset = clip.offset - chapterStartTime
    }
}

extension FCPXMLExporter {
    /// Re-times clips for a chapter (shifts offsets by chapter start).
    ///
    /// - Parameters:
    ///   - clips: Clips to re-time.
    ///   - chapterRange: The chapter range.
    /// - Returns: Array of re-timed clips.
    private func retimeClips(
        _ clips: [TimelineClip],
        for chapterRange: ChapterRange
    ) -> [RetimedClip] {
        return clips.map { clip in
            RetimedClip(clip: clip, chapterStartTime: chapterRange.startTime)
        }
    }
}
```

**Run tests**: All 6 tests should pass

#### Step 3.3: Verify Coverage (10 min)

```bash
swift test --filter OffsetRetimingTests --enable-code-coverage
```

**Expected**: 90%+ coverage

### Phase 3 Exit Criteria

- [x] `RetimedClip` struct created
- [x] `retimeClips()` function implemented
- [x] 6 tests written and passing
- [x] 90%+ coverage
- [x] Source start and duration preserved

---

## Phase 4: Multi-Project XML Generation

**Duration Estimate**: Day 2-3
**Coverage Target**: 85%+
**Test Files**: `MultiTimelineExportTests.swift`

### What We're Building

The main `exportMultiTimeline()` method and XML generation for multiple projects.

### Implementation Order

#### Step 4.1: Write Resource Management Tests (20 min)

**File**: `Tests/SwiftSecuenciaTests/MultiTimelineExportTests.swift`

Create **4 test cases** in a suite:

```swift
@Suite("Resource Management")
struct ResourceManagementTests {

    @Test("Single resources section")
    func singleResourcesSection() async throws

    @Test("Format resource shared")
    func formatResourceShared() async throws

    @Test("Asset resources deduplicated")
    func assetsDeduplicated() async throws

    @Test("Resource IDs unique")
    func resourceIDsUnique() async throws
}
```

#### Step 4.2: Write XML Structure Tests (30 min)

Add **5 more test cases** to the same file:

```swift
@Suite("XML Structure")
struct XMLStructureTests {

    @Test("Correct hierarchy")
    func correctHierarchy() async throws

    @Test("Project names from chapters")
    func projectNamesFromChapters() async throws

    @Test("Sequence durations match chapters")
    func sequenceDurationsMatch() async throws

    @Test("Sequence tcStart always zero")
    func tcStartAlwaysZero() async throws

    @Test("Valid XML parsing")
    func validXMLParsing() async throws
}
```

**Run tests**: Should fail

#### Step 4.3: Implement exportMultiTimeline() Skeleton (30 min)

**File**: `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift`

```swift
extension FCPXMLExporter {
    /// Exports a timeline to FCPXML with multiple projects based on chapter markers.
    ///
    /// If the timeline has no chapter markers, falls back to standard export.
    ///
    /// - Parameters:
    ///   - timeline: The timeline to export.
    ///   - modelContext: The model context to fetch assets from.
    ///   - libraryName: Library name (default: "Exported Library").
    ///   - eventName: Event name (default: "Exported Event").
    /// - Returns: FCPXML string with multiple projects.
    /// - Throws: Export errors.
    public mutating func exportMultiTimeline(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        libraryName: String = "Exported Library",
        eventName: String = "Exported Event"
    ) throws -> String {
        // 1. Check for chapter markers (fallback if empty)
        let chapterRanges = calculateChapterRanges(timeline: timeline)

        if chapterRanges.isEmpty {
            // Fallback to standard export
            return try export(
                timeline: timeline,
                modelContext: modelContext,
                libraryName: libraryName,
                eventName: eventName
            )
        }

        // 2. Generate shared resources (format + assets)
        var resourceMap = ResourceMap()
        let resourceElements = try generateSharedResources(
            timeline: timeline,
            modelContext: modelContext,
            resourceMap: &resourceMap
        )

        // 3. Generate projects for each chapter
        var projectElements: [XMLElement] = []
        for chapterRange in chapterRanges {
            let project = try generateProjectForChapter(
                chapterRange: chapterRange,
                timeline: timeline,
                modelContext: modelContext,
                resourceMap: resourceMap
            )
            projectElements.append(project)
        }

        // 4. Build event > projects structure
        let event = XMLElement(name: "event")
        event.addAttribute(XMLNode.attribute(withName: "name", stringValue: eventName) as! XMLNode)
        projectElements.forEach { event.addChild($0) }

        // 5. Create FCPXML document
        let doc = XMLDocument(
            resources: resourceElements,
            events: [event],
            fcpxmlVersion: version
        )

        return doc.fcpxmlString
    }
}
```

#### Step 4.4: Implement Helper Functions (1.5 hours)

```swift
extension FCPXMLExporter {
    /// Generates shared resources for all chapters.
    private mutating func generateSharedResources(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        resourceMap: inout ResourceMap
    ) throws -> [XMLElement] {
        var elements: [XMLElement] = []

        // Format resource
        let format = timeline.videoFormat ?? VideoFormat.hd1080p(frameRate: .fps23_98)
        let formatElement = try generateFormatElement(format: format, resourceMap: &resourceMap)
        elements.append(formatElement)

        // Asset resources
        let assets = timeline.allAssets(in: modelContext)
        for asset in assets {
            let assetElement = try generateAssetElement(asset: asset, resourceMap: &resourceMap)
            elements.append(assetElement)
        }

        return elements
    }

    /// Generates a project element for a chapter.
    private func generateProjectForChapter(
        chapterRange: ChapterRange,
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        resourceMap: ResourceMap
    ) throws -> XMLElement {
        // Filter clips for this chapter
        let chapterClips = clipsForChapter(timeline: timeline, chapterRange: chapterRange)

        // Re-time clips
        let retimedClips = retimeClips(chapterClips, for: chapterRange)

        // Create project element
        let project = XMLElement(name: "project")
        project.addAttribute(XMLNode.attribute(withName: "name", stringValue: chapterRange.name) as! XMLNode)

        // Create sequence
        let sequence = try generateSequenceForChapter(
            chapterRange: chapterRange,
            retimedClips: retimedClips,
            resourceMap: resourceMap
        )

        project.addChild(sequence)
        return project
    }

    /// Generates a sequence element for a chapter.
    private func generateSequenceForChapter(
        chapterRange: ChapterRange,
        retimedClips: [RetimedClip],
        resourceMap: ResourceMap
    ) throws -> XMLElement {
        let sequence = XMLElement(name: "sequence")

        // Reference format
        guard let formatID = resourceMap.formatID else {
            throw FCPXMLExportError.missingFormat
        }
        sequence.addAttribute(XMLNode.attribute(withName: "format", stringValue: formatID) as! XMLNode)
        sequence.addAttribute(XMLNode.attribute(withName: "duration", stringValue: chapterRange.duration.fcpxmlString) as! XMLNode)
        sequence.addAttribute(XMLNode.attribute(withName: "tcStart", stringValue: "0s") as! XMLNode)

        // Create spine
        let spine = try generateSpineForChapter(retimedClips: retimedClips, resourceMap: resourceMap)
        sequence.addChild(spine)

        return sequence
    }

    /// Generates a spine element with re-timed clips.
    private func generateSpineForChapter(
        retimedClips: [RetimedClip],
        resourceMap: ResourceMap
    ) throws -> XMLElement {
        let spine = XMLElement(name: "spine")

        for retimedClip in retimedClips {
            let clipElement = try generateAssetClipElement(
                clip: retimedClip.clip,
                offset: retimedClip.newOffset,
                resourceMap: resourceMap
            )
            spine.addChild(clipElement)
        }

        return spine
    }

    /// Generates an asset-clip element with custom offset.
    private func generateAssetClipElement(
        clip: TimelineClip,
        offset: Timecode,
        resourceMap: ResourceMap
    ) throws -> XMLElement {
        guard let assetID = resourceMap.assetIDs[clip.assetStorageId] else {
            throw FCPXMLExportError.missingAsset(assetId: clip.assetStorageId)
        }

        let element = XMLElement(name: "asset-clip")
        element.addAttribute(XMLNode.attribute(withName: "ref", stringValue: assetID) as! XMLNode)

        if let name = clip.name {
            element.addAttribute(XMLNode.attribute(withName: "name", stringValue: name) as! XMLNode)
        }

        element.addAttribute(XMLNode.attribute(withName: "offset", stringValue: offset.fcpxmlString) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "duration", stringValue: clip.duration.fcpxmlString) as! XMLNode)

        if clip.sourceStart != .zero {
            element.addAttribute(XMLNode.attribute(withName: "start", stringValue: clip.sourceStart.fcpxmlString) as! XMLNode)
        }

        if clip.isVideoDisabled {
            element.addAttribute(XMLNode.attribute(withName: "enabled", stringValue: "0") as! XMLNode)
        }

        return element
    }
}
```

**Run tests**: All 9 tests should pass

#### Step 4.5: Verify Coverage (10 min)

```bash
swift test --filter MultiTimelineExportTests --enable-code-coverage
```

**Expected**: 85%+ coverage

### Phase 4 Exit Criteria

- [x] `exportMultiTimeline()` implemented
- [x] Shared resources generation working
- [x] Multi-project XML generation working
- [x] 9 tests passing
- [x] 85%+ coverage
- [x] Valid XML structure

---

## Phase 5: Integration & Edge Cases

**Duration Estimate**: Day 3-4
**Coverage Target**: 75%+ (integration), 100% (edge cases)
**Test Files**: `MultiTimelineIntegrationTests.swift`

### What We're Building

End-to-end integration tests and all edge case validations.

### Implementation Order

#### Step 5.1: Write Integration Tests (1 hour)

**File**: `Tests/SwiftSecuenciaTests/MultiTimelineIntegrationTests.swift`

Create **8 integration test cases**:

```swift
@Suite("Multi-Timeline Integration")
struct MultiTimelineIntegrationTests {

    @Test("Complete 3-chapter export")
    func complete3ChapterExport() async throws

    @Test("Single chapter matches single export")
    func singleChapterMatchesSingle() async throws

    @Test("No chapters fallback")
    func noChaptersFallback() async throws

    @Test("Pre-chapter content included")
    func preChapterContentIncluded() async throws

    @Test("Multi-lane exports lane 0 only")
    func multiLaneExportsLaneZero() async throws

    @Test("Asset referenced in multiple chapters")
    func assetInMultipleChapters() async throws

    @Test("Empty middle chapter")
    func emptyMiddleChapter() async throws

    @Test("Large timeline with many chapters")
    func largeTimelineManychapters() async throws
}
```

**Run tests**: May fail initially, debug and fix

#### Step 5.2: Write Edge Case Tests (45 min)

Add to the same file:

```swift
@Suite("Edge Cases")
struct EdgeCaseTests {

    @Test("EC-1: Single chapter marker")
    func ec1_singleChapter() async throws

    @Test("EC-2: Chapter beyond timeline")
    func ec2_chapterBeyondTimeline() async throws

    @Test("EC-3: Duplicate chapter times")
    func ec3_duplicateTimes() async throws

    @Test("EC-4: Empty chapter")
    func ec4_emptyChapter() async throws

    @Test("EC-5: Chapter at non-zero start")
    func ec5_nonZeroStart() async throws

    @Test("EC-6: Overlapping clip at boundary")
    func ec6_overlappingClip() async throws
}
```

**Run tests**: Debug any failures

#### Step 5.3: DTD Validation Tests (30 min)

Add validation tests:

```swift
@Suite("DTD Validation")
struct DTDValidationTests {

    @Test("Validates against FCPXML 1.11")
    func validatesV1_11() async throws

    @Test("Validates against FCPXML 1.12")
    func validatesV1_12() async throws

    @Test("Validates against FCPXML 1.13")
    func validatesV1_13() async throws
}
```

#### Step 5.4: Fix Issues & Refine (2 hours)

- Debug failing tests
- Fix edge cases
- Ensure all 48 tests pass

#### Step 5.5: Verify Coverage (15 min)

```bash
swift test --enable-code-coverage
```

**Expected**:
- Integration tests: 75%+
- Edge cases: 100%
- Overall new code: 80%+

### Phase 5 Exit Criteria

- [x] 8 integration tests passing
- [x] 6 edge case tests passing (100% coverage)
- [x] 3 DTD validation tests passing
- [x] All 48 total tests passing
- [x] 80%+ overall coverage

---

## Phase 6: Documentation & Polish

**Duration Estimate**: Day 4
**Coverage Target**: N/A (documentation)

### What We're Building

DocC documentation, examples, and final polish.

### Tasks

#### Step 6.1: Add DocC Documentation (1 hour)

Add comprehensive documentation to `exportMultiTimeline()`:

```swift
/// Exports a timeline to FCPXML with multiple projects based on chapter markers.
///
/// This method splits a single timeline into multiple Final Cut Pro projects,
/// with each project corresponding to a chapter marker. The resulting FCPXML
/// contains one library, one event, and multiple projects.
///
/// ## Chapter-Based Splitting
///
/// Each ``ChapterMarker`` in the timeline's ``Timeline/chapterMarkers`` array
/// defines the start of a new project. The project name is taken from the
/// chapter marker's ``ChapterMarker/value`` property.
///
/// ```swift
/// let timeline = Timeline(name: "Interview")
/// timeline.chapterMarkers = [
///     ChapterMarker(start: .zero, value: "Introduction"),
///     ChapterMarker(start: Timecode(seconds: 120), value: "Main Discussion"),
///     ChapterMarker(start: Timecode(seconds: 600), value: "Q&A")
/// ]
///
/// var exporter = FCPXMLExporter(version: .v1_13)
/// let xml = try exporter.exportMultiTimeline(
///     timeline: timeline,
///     modelContext: context
/// )
/// // Result: 3 projects in one event
/// ```
///
/// ## Clip Distribution
///
/// Only clips on **lane 0** (primary storyline) are included in the export.
/// Clips are assigned to projects based on their start time:
/// - A clip is included if it starts within the chapter's time range
/// - Clips are included in their entirety (no trimming at boundaries)
/// - Clips are re-timed so each project starts at 0s
///
/// ## Fallback Behavior
///
/// If the timeline has no chapter markers, this method falls back to the
/// standard ``export(timeline:modelContext:libraryName:eventName:projectName:)``
/// behavior and exports a single project.
///
/// ## Resource Sharing
///
/// All projects share a single `<resources>` section containing formats and
/// assets. This reduces file size and ensures consistency across projects.
///
/// - Parameters:
///   - timeline: The timeline to export with chapter markers.
///   - modelContext: The SwiftData model context for fetching assets.
///   - libraryName: Name for the library element (default: "Exported Library").
///   - eventName: Name for the event element (default: "Exported Event").
/// - Returns: FCPXML string representation with multiple projects.
/// - Throws: ``FCPXMLExportError`` if export fails.
///
/// ## Topics
///
/// ### Related Types
/// - ``ChapterMarker``
/// - ``Timeline``
/// - ``FCPXMLVersion``
///
/// ### Errors
/// - ``FCPXMLExportError``
public mutating func exportMultiTimeline(...) throws -> String
```

#### Step 6.2: Update README.md (30 min)

Add multi-timeline export example to README:

```markdown
### Multi-Timeline Export

Export a timeline with chapter markers as multiple Final Cut Pro projects:

\`\`\`swift
import SwiftSecuencia
import SwiftData

// Create timeline with chapters
let timeline = Timeline(name: "Full Interview")
timeline.chapterMarkers = [
    ChapterMarker(start: .zero, value: "Introduction"),
    ChapterMarker(start: Timecode(seconds: 120), value: "Main Content"),
    ChapterMarker(start: Timecode(seconds: 600), value: "Conclusion")
]

// Add clips
timeline.appendClip(...)

// Export to multi-project FCPXML
var exporter = FCPXMLExporter(version: .v1_13)
let xml = try exporter.exportMultiTimeline(
    timeline: timeline,
    modelContext: context,
    eventName: "Interview Project"
)

// Result: 3 projects in one event
// - "Introduction" (0s-120s)
// - "Main Content" (120s-600s)
// - "Conclusion" (600s-end)
\`\`\`
```

#### Step 6.3: Update CHANGELOG.md (15 min)

```markdown
## [1.1.0] - 2025-12-XX

### Added
- Multi-timeline export based on chapter markers
- New `FCPXMLExporter.exportMultiTimeline()` method
- Support for splitting timelines into multiple projects
- Automatic clip re-timing for chapter-based timelines
```

#### Step 6.4: SwiftLint Check (10 min)

```bash
swiftlint lint Sources/SwiftSecuencia/Export/
```

Fix any violations.

#### Step 6.5: Final Test Run (10 min)

```bash
swift test
```

Ensure all 48 tests pass.

### Phase 6 Exit Criteria

- [x] DocC documentation added
- [x] README.md updated with examples
- [x] CHANGELOG.md updated
- [x] SwiftLint clean
- [x] All tests passing
- [x] Ready for PR

---

## Testing Schedule Summary

| Phase | Test File | Test Count | Coverage | Day |
|-------|-----------|-----------|----------|-----|
| 1 | ChapterRangeCalculationTests.swift | 8 | 90% | 1 |
| 2 | ClipDistributionTests.swift | 8 | 85% | 1-2 |
| 3 | OffsetRetimingTests.swift | 6 | 90% | 2 |
| 4 | MultiTimelineExportTests.swift | 9 | 85% | 2-3 |
| 5 | MultiTimelineIntegrationTests.swift | 17 | 75%/100% | 3-4 |
| 6 | Documentation | 0 | N/A | 4 |
| **Total** | **5 test files** | **48 tests** | **80%+** | **4 days** |

## Coverage Tracking

### After Each Phase

Run coverage and check:

```bash
swift test --enable-code-coverage
xcrun llvm-cov report \
  .build/debug/SwiftSecuenciaPackageTests.xctest/Contents/MacOS/SwiftSecuenciaPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata
```

### Coverage Checkpoints

| Checkpoint | Target | Files |
|------------|--------|-------|
| Phase 1 complete | 90%+ | ChapterRange calculation |
| Phase 2 complete | 85%+ | Clip distribution |
| Phase 3 complete | 90%+ | Offset re-timing |
| Phase 4 complete | 85%+ | XML generation |
| Phase 5 complete | 80%+ overall | All new code |

## Test Execution Order

### During Development (TDD)

For each component:
1. ✅ Write test (it fails)
2. ✅ Write minimal code to pass
3. ✅ Run test (it passes)
4. ✅ Refactor
5. ✅ Run test again (still passes)
6. ✅ Check coverage
7. ✅ Add more tests if <target%

### Before Each Commit

```bash
# Run all tests
swift test

# Check coverage
swift test --enable-code-coverage

# Lint check
swiftlint lint
```

### Before PR

```bash
# Full test suite
swift test --parallel

# Coverage report
swift test --enable-code-coverage
# Generate HTML report and verify 80%+

# SwiftLint
swiftlint lint --strict

# Build in release mode
swift build -c release
```

## What Gets Tested When

### Phase 1 (Day 1 Morning)
**What**: Chapter range calculation
**Tests**: 8 tests
- No chapters
- Single chapter variations
- Multiple chapters
- Edge cases (out of order, duplicates, beyond duration)

### Phase 2 (Day 1 Afternoon)
**What**: Clip filtering logic
**Tests**: 8 tests
- Clips within/outside ranges
- Boundary conditions
- Lane filtering
- Sorting

### Phase 3 (Day 2 Morning)
**What**: Offset re-timing
**Tests**: 6 tests
- First chapter (no change)
- Subsequent chapters (re-timed)
- Preservation of other attributes

### Phase 4 (Day 2 Afternoon - Day 3 Morning)
**What**: Multi-project XML generation
**Tests**: 9 tests
- Resource management
- XML structure
- Shared resources

### Phase 5 (Day 3 Afternoon - Day 4 Morning)
**What**: End-to-end workflows + edge cases
**Tests**: 17 tests
- Integration scenarios
- All 6 edge cases
- DTD validation

### Phase 6 (Day 4 Afternoon)
**What**: Documentation
**Tests**: None (polish phase)

## Continuous Integration

### GitHub Actions Workflow

The existing CI should run:

```yaml
- name: Run Tests
  run: swift test --parallel

- name: Check Coverage
  run: |
    swift test --enable-code-coverage
    # Add coverage check script

- name: Lint
  run: swiftlint lint --strict
```

## Success Metrics

### Quantitative
- ✅ 48/48 tests passing
- ✅ 80%+ code coverage
- ✅ 0 SwiftLint violations
- ✅ 0 compiler warnings
- ✅ DTD validation passes (3/3 versions)

### Qualitative
- ✅ Clean, readable code
- ✅ Well-documented API
- ✅ Comprehensive test coverage
- ✅ Edge cases handled
- ✅ Manual FCP import works

## Risk Mitigation

### If Coverage < 80%

1. Identify uncovered code paths
2. Add targeted tests
3. Refactor if code is untestable
4. Repeat until 80%+

### If Tests Fail in CI

1. Run locally with same environment
2. Check for race conditions
3. Fix tests or code
4. Verify locally before re-pushing

### If Manual FCP Test Fails

1. Export sample FCPXML
2. Validate against DTD
3. Compare to working example
4. Debug XML structure
5. Add regression test

## References

- REQUIREMENTS-MULTI-TIMELINE-EXPORT.md
- TESTING-MULTI-TIMELINE-EXPORT.md
- FEATURE-1-SUMMARY.md
- Swift Testing Documentation
- FCPXML DTD files (Fixtures/)
