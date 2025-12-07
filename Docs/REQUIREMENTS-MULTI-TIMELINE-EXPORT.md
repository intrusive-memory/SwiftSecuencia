# Requirements: Multiple Timeline Export (Feature #1)

**Status**: Draft
**Created**: 2025-12-06
**Target Version**: v1.1.0

## Overview

Enable SwiftSecuencia to export a single Timeline into multiple FCPXML timelines/projects, with each timeline corresponding to a chapter defined by ChapterMarker objects. This allows users to split long-form content into separate projects for easier editing and organization.

## Use Cases

1. **Long-Form Content Organization**: Split a 2-hour interview into chapter-based projects for easier navigation in FCP
2. **Scene-Based Editing**: Convert a multi-scene timeline into separate projects per scene
3. **Batch Processing**: Process individual chapters separately (e.g., color grading, audio mixing)
4. **Chapter Delivery**: Export individual chapters as standalone timelines for delivery or review

## Functional Requirements

### FR-1: Chapter Marker-Based Splitting

**Description**: The export system shall split timelines based on ChapterMarker objects attached to the Timeline.

**Behavior**:
- The Timeline's `chapterMarkers` array defines the split points
- Each ChapterMarker's `start` time defines the beginning of a new timeline
- The ChapterMarker's `value` (title) becomes the name of the exported project
- Chapter markers must be sorted by start time (ascending)

**Example**:
```swift
timeline.chapterMarkers = [
    ChapterMarker(start: Timecode.zero, value: "Introduction"),
    ChapterMarker(start: Timecode(seconds: 120), value: "Chapter 1"),
    ChapterMarker(start: Timecode(seconds: 300), value: "Chapter 2")
]
```

This creates 3 projects:
- "Introduction" (0s - 120s)
- "Chapter 1" (120s - 300s)
- "Chapter 2" (300s - end)

### FR-2: FCPXML Structure

**Description**: The exported FCPXML shall use a single library, single event, multiple projects structure.

**Structure**:
```xml
<fcpxml version="1.13">
  <resources>
    <!-- Shared resources for all timelines -->
    <format id="r1" .../>
    <asset id="r2" .../>
    <asset id="r3" .../>
  </resources>
  <library>
    <event name="{eventName}">
      <project name="Introduction">
        <sequence format="r1" duration="120s" tcStart="0s">
          <spine>
            <!-- Clips from 0s-120s, re-timed to start at 0s -->
          </spine>
        </sequence>
      </project>
      <project name="Chapter 1">
        <sequence format="r1" duration="180s" tcStart="0s">
          <spine>
            <!-- Clips from 120s-300s, re-timed to start at 0s -->
          </spine>
        </sequence>
      </project>
      <project name="Chapter 2">
        <sequence format="r1" duration="{duration}" tcStart="0s">
          <spine>
            <!-- Clips from 300s-end, re-timed to start at 0s -->
          </spine>
        </sequence>
      </project>
    </event>
  </library>
</fcpxml>
```

### FR-3: Timeline Naming

**Description**: Each exported project shall be named using the ChapterMarker's `value` property directly.

**Rules**:
- Project name = ChapterMarker.value (no prefix, no original timeline name)
- If ChapterMarker.value is empty, use "Untitled Chapter {index}" (1-based)
- Chapter marker values should be sanitized if they contain invalid XML characters

**Examples**:
- ChapterMarker(value: "Introduction") → `<project name="Introduction">`
- ChapterMarker(value: "") → `<project name="Untitled Chapter 1">`

### FR-4: Clip Distribution Logic

**Description**: Clips shall be distributed to timelines based on their time range, with specific handling for clips that span chapter boundaries.

**Rules**:
1. **Primary Lane Only (lane 0)**: Only clips on lane 0 are included in the chapter-split export
2. **Overlapping Clips Included**: A clip is included in a timeline if ANY part of it overlaps with the chapter's time range
3. **No Clip Trimming**: Clips are included in their entirety (not trimmed at chapter boundaries)
4. **Clip Ownership**: Each clip is included in only ONE timeline—the timeline where the clip's start time falls
5. **Offset Re-timing**: All clips in each timeline are re-timed so the chapter start becomes 0s

**Algorithm**:
```
For each chapter range [chapterStart, chapterEnd):
  1. Find all clips on lane 0 where:
     - clip.offset >= chapterStart
     - clip.offset < chapterEnd (or chapterEnd is timeline.duration for last chapter)
  2. For each included clip:
     - newOffset = clip.offset - chapterStart
     - duration = clip.duration (unchanged)
     - sourceStart = clip.sourceStart (unchanged)
```

**Example**:
```
Original Timeline (120s total):
- Clip A: offset=0s,    duration=50s,  lane=0
- Clip B: offset=50s,   duration=40s,  lane=0
- Clip C: offset=90s,   duration=40s,  lane=0  (spans chapter boundary)
- Clip D: offset=100s,  duration=10s,  lane=1  (excluded - not lane 0)

Chapter Markers:
- "Intro": start=0s
- "Main":  start=90s

Result:
Timeline "Intro" (0s-90s, duration=90s):
  - Clip A: offset=0s,  duration=50s
  - Clip B: offset=50s, duration=40s

Timeline "Main" (90s-120s, duration=30s):
  - Clip C: offset=0s,  duration=40s  (re-timed from 90s, full clip included)
```

### FR-5: Empty Timeline Handling

**Description**: If a timeline has no chapter markers, the export shall fall back to standard single-timeline export.

**Behavior**:
- If `timeline.chapterMarkers.isEmpty`, use existing FCPXMLExporter.export() behavior
- No error is thrown
- A single project is created with the timeline's name

### FR-6: Pre-Chapter Content

**Description**: Content before the first chapter marker shall always be included in the first timeline.

**Behavior**:
- The first timeline starts at 0s
- The first timeline ends at the second chapter marker's start time (or timeline.duration if only one chapter)
- If the first chapter marker does NOT start at 0s, the first timeline includes content from [0s, firstChapterStart)

**Example**:
```
Timeline duration: 180s
Chapter markers:
- "Main Content": start=30s
- "Conclusion": start=150s

Result:
Timeline "Main Content":  0s-150s  (includes 30s of pre-chapter content)
Timeline "Conclusion":    150s-180s
```

### FR-7: Resource Management

**Description**: All timelines shall share a single `<resources>` section containing all formats and assets.

**Behavior**:
- Generate one `<resources>` section at the document level
- Include the format resource once (referenced by all sequences)
- Include each asset resource once (even if used by multiple timelines)
- Resource IDs are unique across the entire document
- Each timeline's `<sequence>` references shared resources via ID

**Example**:
```xml
<resources>
  <format id="r1" name="FFVideoFormat1080p2398" .../>
  <asset id="r2" src="file://..." name="Interview.mov" .../>
  <asset id="r3" src="file://..." name="B-Roll.mov" .../>
</resources>
<!-- Both projects reference r1, r2, r3 as needed -->
```

### FR-8: Timeline Duration Calculation

**Description**: Each exported timeline's duration shall be calculated based on its chapter range.

**Calculation**:
```
For chapter index i:
  startTime = chapterMarkers[i].start
  endTime = (i+1 < chapterMarkers.count)
            ? chapterMarkers[i+1].start
            : timeline.duration

  timelineDuration = endTime - startTime
```

**FCPXML Attributes**:
```xml
<sequence
  format="r1"
  duration="{timelineDuration}"
  tcStart="0s">
  <!-- Clips re-timed to start at 0s -->
</sequence>
```

## Non-Functional Requirements

### NFR-1: Performance

- Splitting shall not significantly degrade export performance
- Resource generation shall be done once (shared across timelines)
- Clip filtering and re-timing shall use efficient algorithms (O(n log n) or better)

### NFR-2: API Design

- The multi-timeline export shall be a new method: `exportMultiTimeline()`
- It shall not modify existing `export()` behavior
- The API shall follow SwiftSecuencia's existing patterns (mutating struct, async/throws)

**Proposed API**:
```swift
public mutating func exportMultiTimeline(
    timeline: Timeline,
    modelContext: SwiftData.ModelContext,
    libraryName: String = "Exported Library",
    eventName: String = "Exported Event"
) throws -> String
```

### NFR-3: Validation

- Chapter markers should be validated (non-empty, sorted by start time)
- Warning or error if chapter markers are out of order
- Graceful handling of edge cases (e.g., all chapter markers at 0s)

### NFR-4: Testing

- Unit tests for clip distribution logic
- Unit tests for offset re-timing
- Integration tests for complete multi-timeline export
- XML validation against FCPXML DTD
- Manual FCP import testing with multi-chapter timelines

## API Specification

### New Method: FCPXMLExporter.exportMultiTimeline()

```swift
extension FCPXMLExporter {
    /// Exports a timeline to FCPXML format with multiple projects based on chapter markers.
    ///
    /// If the timeline has no chapter markers, this falls back to standard single-timeline export.
    ///
    /// ## Structure
    ///
    /// The exported FCPXML contains:
    /// - One `<resources>` section (shared by all timelines)
    /// - One `<library>` element
    /// - One `<event>` element
    /// - Multiple `<project>` elements (one per chapter)
    ///
    /// ## Chapter Splitting
    ///
    /// - Each ChapterMarker defines the start of a new timeline
    /// - Timeline names are taken from ChapterMarker.value
    /// - Only lane 0 clips are included
    /// - Clips are re-timed so each chapter starts at 0s
    ///
    /// - Parameters:
    ///   - timeline: The timeline to export.
    ///   - modelContext: The model context to fetch assets from.
    ///   - libraryName: Name for the library element (default: "Exported Library").
    ///   - eventName: Name for the event element (default: "Exported Event").
    /// - Returns: FCPXML string representation with multiple projects.
    /// - Throws: Export errors if timeline is invalid or assets are missing.
    public mutating func exportMultiTimeline(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        libraryName: String = "Exported Library",
        eventName: String = "Exported Event"
    ) throws -> String
}
```

### Supporting Types

```swift
/// Represents a chapter range for export.
struct ChapterRange {
    let index: Int              // 0-based chapter index
    let name: String            // Chapter marker value
    let startTime: Timecode     // Chapter start (in original timeline)
    let endTime: Timecode       // Chapter end (in original timeline)
    let duration: Timecode      // Chapter duration (endTime - startTime)
}
```

## Edge Cases

### EC-1: Single Chapter Marker
- **Scenario**: Timeline has exactly one chapter marker at 0s
- **Expected**: Export as single timeline with chapter name
- **Rationale**: One chapter = one timeline

### EC-2: Chapter Marker After Timeline End
- **Scenario**: Chapter marker with start > timeline.duration
- **Expected**: Ignore out-of-range chapter markers, log warning
- **Rationale**: Invalid data should not cause export failure

### EC-3: Duplicate Chapter Marker Times
- **Scenario**: Multiple chapter markers with identical start times
- **Expected**: Use first occurrence, log warning about duplicates
- **Rationale**: Deterministic behavior, inform user of issue

### EC-4: Empty Chapter (No Clips)
- **Scenario**: A chapter range contains no lane 0 clips
- **Expected**: Export timeline with empty spine (valid FCPXML)
- **Rationale**: User may intentionally create empty chapters for structure

### EC-5: Chapter Marker at Non-Zero Start
- **Scenario**: First chapter marker is at 30s (not 0s)
- **Expected**: First timeline starts at 0s, includes pre-chapter content
- **Rationale**: Per FR-6, always include content from 0s

### EC-6: Overlapping Clip at Boundary
- **Scenario**: Clip starts before chapter boundary, ends after
- **Expected**: Clip is included in the timeline where it starts (full duration)
- **Rationale**: Per FR-4, no trimming, ownership based on start time

## Testing Strategy

### Unit Tests

1. **Chapter Range Calculation**
   - Test with 0, 1, 2, N chapter markers
   - Test pre-chapter content inclusion
   - Test last chapter extends to timeline end

2. **Clip Distribution**
   - Test clips entirely within chapter range
   - Test clips at chapter boundaries
   - Test clips spanning boundaries
   - Test multi-lane filtering (lane 0 only)

3. **Offset Re-timing**
   - Test clips re-timed from chapter start to 0s
   - Test sourceStart preservation
   - Test duration preservation

4. **Resource Management**
   - Test single resources section generation
   - Test shared resource ID references

### Integration Tests

1. **Complete Export**
   - Timeline with 3 chapters, 10 clips
   - Validate XML structure (library > event > projects)
   - Validate resource sharing
   - Validate clip counts per timeline

2. **Edge Cases**
   - Export with no chapter markers (fallback)
   - Export with single chapter
   - Export with empty chapter

3. **DTD Validation**
   - Validate exported XML against FCPXML 1.11-1.13 DTDs

### Manual FCP Testing

1. Create test timeline with chapter markers
2. Export using `exportMultiTimeline()`
3. Import into Final Cut Pro
4. Verify:
   - All projects appear in event
   - Clips are correctly placed
   - Playback is correct
   - No missing media

## Implementation Notes

### Algorithm Pseudocode

```swift
func exportMultiTimeline(timeline: Timeline, ...) throws -> String {
    // 1. Check for chapter markers
    if timeline.chapterMarkers.isEmpty {
        return try export(timeline: timeline, ...) // Fallback
    }

    // 2. Sort and validate chapter markers
    let sortedChapters = timeline.chapterMarkers
        .sorted { $0.start < $1.start }
        .filter { $0.start < timeline.duration }

    // 3. Calculate chapter ranges
    let chapterRanges = calculateChapterRanges(
        chapters: sortedChapters,
        timelineDuration: timeline.duration
    )

    // 4. Generate shared resources once
    var resourceMap = ResourceMap()
    let resourceElements = generateResources(
        timeline: timeline,
        modelContext: modelContext,
        resourceMap: &resourceMap
    )

    // 5. Generate projects for each chapter
    var projectElements: [XMLElement] = []
    for chapterRange in chapterRanges {
        let project = generateProjectForChapter(
            chapterRange: chapterRange,
            timeline: timeline,
            resourceMap: resourceMap
        )
        projectElements.append(project)
    }

    // 6. Build final FCPXML structure
    let event = XMLElement(name: "event")
    event.addAttribute(name: "name", value: eventName)
    projectElements.forEach { event.addChild($0) }

    let doc = XMLDocument(
        resources: resourceElements,
        events: [event],
        fcpxmlVersion: version
    )

    return doc.fcpxmlString
}

func calculateChapterRanges(
    chapters: [ChapterMarker],
    timelineDuration: Timecode
) -> [ChapterRange] {
    var ranges: [ChapterRange] = []

    for (index, chapter) in chapters.enumerated() {
        let startTime = chapter.start
        let endTime = (index + 1 < chapters.count)
            ? chapters[index + 1].start
            : timelineDuration
        let duration = endTime - startTime
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

func generateProjectForChapter(
    chapterRange: ChapterRange,
    timeline: Timeline,
    resourceMap: ResourceMap
) -> XMLElement {
    // 1. Filter clips for this chapter (lane 0 only)
    let chapterClips = timeline.clips
        .filter { $0.lane == 0 }
        .filter { $0.offset >= chapterRange.startTime
                  && $0.offset < chapterRange.endTime }
        .sorted { $0.offset < $1.offset }

    // 2. Re-time clips to start at 0s
    let retimedClips = chapterClips.map { clip in
        var newClip = clip
        newClip.offset = clip.offset - chapterRange.startTime
        return newClip
    }

    // 3. Generate XML
    let project = XMLElement(name: "project")
    project.addAttribute(name: "name", value: chapterRange.name)

    let sequence = XMLElement(name: "sequence")
    sequence.addAttribute(name: "format", value: resourceMap.formatID)
    sequence.addAttribute(name: "duration", value: chapterRange.duration.fcpxmlString)
    sequence.addAttribute(name: "tcStart", value: "0s")

    let spine = XMLElement(name: "spine")
    for clip in retimedClips {
        let clipElement = generateAssetClipElement(clip: clip, resourceMap: resourceMap)
        spine.addChild(clipElement)
    }

    sequence.addChild(spine)
    project.addChild(sequence)

    return project
}
```

## Open Questions

None at this time. All requirements have been clarified through user input.

## Related Features

- Feature #2: [To be defined]
- Metadata export (markers, keywords on split timelines)
- Bundle export for multi-timeline documents

## References

- [FCPXML Reference](Docs/FCPXML-Reference.md)
- [FCPXML Elements](Docs/FCPXML-Elements.md)
- FCPXMLExporter: Sources/SwiftSecuencia/Export/FCPXMLExporter.swift
- Timeline: Sources/SwiftSecuencia/Timeline/Timeline.swift
- ChapterMarker: Sources/SwiftSecuencia/Metadata/ChapterMarker.swift
