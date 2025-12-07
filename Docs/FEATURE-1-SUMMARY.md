# Feature #1: Multiple Timeline Export - Summary

**Created**: 2025-12-06
**Status**: Ready for Implementation
**Target Version**: v1.1.0

## Quick Overview

Export a single Timeline with chapter markers into multiple FCPXML projects within one FCPXML file. Each ChapterMarker creates a separate project/timeline in Final Cut Pro.

## Documentation

1. **[REQUIREMENTS-MULTI-TIMELINE-EXPORT.md](REQUIREMENTS-MULTI-TIMELINE-EXPORT.md)** - Complete requirements specification
2. **[TESTING-MULTI-TIMELINE-EXPORT.md](TESTING-MULTI-TIMELINE-EXPORT.md)** - Testing methodology and test cases

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Split Criteria | Chapter Markers | Existing ChapterMarker type, user-friendly |
| FCPXML Structure | 1 Library → 1 Event → N Projects | Standard FCP organization pattern |
| Timeline Naming | Chapter Title Only | Simple, clean naming |
| Clip Logic | Include Overlapping Clips | No trimming, full clips preserved |
| No Chapters | Fallback to Single Timeline | Graceful degradation |
| Multi-lane | Primary Lane Only (lane 0) | Simplifies initial implementation |
| Pre-Chapter Content | Always Include from 0s | Don't lose content before first chapter |
| Resources | Shared Section | Efficiency, smaller file size |
| Clip Timing | Re-time from 0s | Each chapter timeline starts at 0s |

## API

```swift
extension FCPXMLExporter {
    public mutating func exportMultiTimeline(
        timeline: Timeline,
        modelContext: SwiftData.ModelContext,
        libraryName: String = "Exported Library",
        eventName: String = "Exported Event"
    ) throws -> String
}
```

## Example Usage

```swift
// Create timeline with chapter markers
let timeline = Timeline(name: "Full Interview")
timeline.chapterMarkers = [
    ChapterMarker(start: Timecode.zero, value: "Introduction"),
    ChapterMarker(start: Timecode(seconds: 120), value: "Main Discussion"),
    ChapterMarker(start: Timecode(seconds: 600), value: "Q&A"),
    ChapterMarker(start: Timecode(seconds: 900), value: "Closing")
]

// Add clips (lane 0 only will be exported)
timeline.appendClip(clip1)
timeline.appendClip(clip2)
// ... more clips

// Export to multi-timeline FCPXML
var exporter = FCPXMLExporter(version: .v1_13)
let xml = try exporter.exportMultiTimeline(
    timeline: timeline,
    modelContext: context,
    eventName: "Interview Project"
)

// Result: 4 projects in one event
// - "Introduction" (0s-120s, clips re-timed to start at 0s)
// - "Main Discussion" (120s-600s, clips re-timed to start at 0s)
// - "Q&A" (600s-900s, clips re-timed to start at 0s)
// - "Closing" (900s-end, clips re-timed to start at 0s)
```

## Testing Summary

- **48 test cases** across 8 categories
- **80%+ code coverage** target
- **100% edge case coverage** required
- Test files:
  - ChapterRangeCalculationTests.swift (8 tests)
  - ClipDistributionTests.swift (8 tests)
  - OffsetRetimingTests.swift (6 tests)
  - MultiTimelineExportTests.swift (12 tests)
  - MultiTimelineIntegrationTests.swift (8 tests)
  - DTD validation tests (3 tests)
  - Edge case tests (6 tests)

## Implementation Checklist

### Phase 1: Core Logic
- [ ] `ChapterRange` struct
- [ ] `calculateChapterRanges()` function
- [ ] Chapter marker sorting and validation
- [ ] Write tests for chapter range calculation (8 tests)

### Phase 2: Clip Distribution
- [ ] Clip filtering logic (lane 0 only)
- [ ] Boundary condition handling
- [ ] Offset re-timing implementation
- [ ] Write clip distribution tests (8 tests)
- [ ] Write offset re-timing tests (6 tests)

### Phase 3: Export Method
- [ ] `exportMultiTimeline()` method skeleton
- [ ] Resource generation (shared section)
- [ ] Multi-project XML generation
- [ ] Integration with existing Pipeline API
- [ ] Write resource management tests (4 tests)
- [ ] Write XML structure tests (5 tests)

### Phase 4: Integration & Validation
- [ ] End-to-end integration tests (8 tests)
- [ ] DTD validation tests (3 tests)
- [ ] Edge case tests (6 tests)
- [ ] Code coverage measurement
- [ ] Performance verification

### Phase 5: Documentation & Polish
- [ ] DocC documentation for new API
- [ ] Update README.md with examples
- [ ] Update CHANGELOG.md
- [ ] Create test fixtures for manual FCP testing

## Success Criteria

- [ ] All 48 tests pass
- [ ] 80%+ code coverage on new code
- [ ] DTD validation passes (1.11, 1.12, 1.13)
- [ ] Manual FCP import test successful
- [ ] No SwiftLint violations
- [ ] CI/CD pipeline passes

## Example FCPXML Output

```xml
<fcpxml version="1.13">
  <resources>
    <format id="r1" name="FFVideoFormat1080p2398" frameDuration="1001/24000s" width="1920" height="1080"/>
    <asset id="r2" name="Interview.mov" duration="1200s" hasVideo="1" hasAudio="1">
      <media-rep kind="original-media" src="file:///..."/>
    </asset>
  </resources>
  <library>
    <event name="Interview Project">
      <project name="Introduction">
        <sequence format="r1" duration="120s" tcStart="0s">
          <spine>
            <asset-clip ref="r2" offset="0s" duration="120s"/>
          </spine>
        </sequence>
      </project>
      <project name="Main Discussion">
        <sequence format="r1" duration="480s" tcStart="0s">
          <spine>
            <asset-clip ref="r2" offset="0s" duration="480s" start="120s"/>
          </spine>
        </sequence>
      </project>
      <project name="Q&A">
        <sequence format="r1" duration="300s" tcStart="0s">
          <spine>
            <asset-clip ref="r2" offset="0s" duration="300s" start="600s"/>
          </spine>
        </sequence>
      </project>
      <project name="Closing">
        <sequence format="r1" duration="300s" tcStart="0s">
          <spine>
            <asset-clip ref="r2" offset="0s" duration="300s" start="900s"/>
          </spine>
        </sequence>
      </project>
    </event>
  </library>
</fcpxml>
```

## Edge Cases Covered

1. **No chapter markers** → Fallback to single timeline
2. **Single chapter** → Export as single project
3. **Pre-chapter content** → Included in first timeline
4. **Empty chapters** → Valid timeline with empty spine
5. **Out-of-order chapters** → Sorted automatically
6. **Duplicate chapter times** → First occurrence used
7. **Chapter beyond timeline** → Ignored
8. **Clips spanning boundaries** → Included in full where they start

## Known Limitations (v1.0)

- Only lane 0 clips exported (multi-lane support deferred)
- No automatic chapter naming templates (uses chapter value directly)
- No configurable split strategies (chapters only)
- No bundle export support yet (future enhancement)

## Future Enhancements

- Multi-lane support with configurable lane filtering
- Custom naming templates (e.g., "{timeline} - {index} - {chapter}")
- Multiple split strategies (markers, time intervals, etc.)
- Bundle export (.fcpxmld) for multi-timeline documents
- Chapter marker generation from detected scene changes

## Related Files

**Implementation**:
- Sources/SwiftSecuencia/Export/FCPXMLExporter.swift (modify)

**Models**:
- Sources/SwiftSecuencia/Timeline/Timeline.swift (uses existing)
- Sources/SwiftSecuencia/Metadata/ChapterMarker.swift (uses existing)

**Tests**:
- Tests/SwiftSecuenciaTests/ChapterRangeCalculationTests.swift (new)
- Tests/SwiftSecuenciaTests/ClipDistributionTests.swift (new)
- Tests/SwiftSecuenciaTests/OffsetRetimingTests.swift (new)
- Tests/SwiftSecuenciaTests/MultiTimelineExportTests.swift (new)
- Tests/SwiftSecuenciaTests/MultiTimelineIntegrationTests.swift (new)

## Questions Resolved

All requirements questions have been answered through the clarification process:

✅ Split by chapter markers
✅ Single library > event > multiple projects structure
✅ Timeline names = chapter titles
✅ Include overlapping clips (no trimming)
✅ Fallback to single timeline if no chapters
✅ Primary lane only
✅ Always include pre-chapter content from 0s
✅ Shared resources section
✅ Re-time clips from 0s for each chapter

## Ready to Implement

All documentation is complete. Implementation can begin following the phased approach outlined above.
