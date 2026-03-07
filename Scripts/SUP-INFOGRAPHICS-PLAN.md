# Mission Supervisor Infographics Plan
## Operation Pipeline Exodus — Episode 01

**Project**: Casting Software Spells
**Episode**: EP01
**Timeline Source**: `/Volumes/brick/casting-software-spells/EP01/SUP-Report.fcpxml`
**Target Resolution**: 4096×2160 (4K DCI)
**Font Resources**: Font Awesome 5 Pro (Light, Regular, Solid)

---

## Timing Structure

All timings are derived from the FCPXML timeline. Each chapter has precise start/duration.

| Chapter | Start (s) | Duration (s) | Marker Name |
|---------|-----------|--------------|-------------|
| CH01 | 0.000 | 17.408 | Opening |
| CH02 | 17.408 | 16.043 | Mission Briefing |
| CH03 | 33.451 | 21.248 | Mission Zero: The Mess |
| CH04 | 54.699 | 25.301 | Discovery: Resource IDs |
| CH05 | 80.000 | 27.691 | Discovery: Library Bug |
| CH06 | 107.691 | 18.816 | Discovery: Empty Timelines |
| CH07 | 126.507 | 24.917 | Discovery: Metadata Correction |
| CH08 | 151.424 | 25.088 | Discovery: Time Format |
| CH09 | 176.512 | 26.197 | Discovery: Type Collisions |
| CH10 | 202.709 | 28.117 | Process Failures |
| CH11 | 230.826 | 24.192 | What Worked |
| CH12 | 255.018 | 15.232 | Verdict: Roll It Flat |
| CH13 | 270.250 | 23.381 | Mission One: Clean Slate |
| CH14 | 293.631 | 27.691 | Sortie Zero: Research |
| CH15 | 321.322 | 31.147 | Sorties One Through Eight |
| CH16 | 352.469 | 18.048 | Current Status |
| CH17 | 370.517 | 21.803 | Closing |

**Total Duration**: 392.32 seconds (6 minutes 32 seconds)

---

## Design System

### Typography
- **Headings**: HelveticaNeue-CondensedBold (mission-critical data)
- **Body**: HelveticaNeue-Light (supporting text)
- **Emphasis**: HelveticaNeue-Bold (callouts)
- **Icons**: Font Awesome 5 Pro Solid/Light

### Color Palette
- **Mission Red**: RGB(230, 90, 80) — Warnings, critical stats
- **Operator Green**: RGB(76, 230, 102) — Success, completed items
- **Intel Blue**: RGB(80, 180, 230) — Information, data points
- **Caution Yellow**: RGB(255, 204, 51) — In-progress, pending
- **Neutral Gray**: RGB(180, 180, 180) — Secondary text
- **Command White**: RGB(255, 255, 255) — Primary text

### Layout Zones (4096×2160)
- **Left Panel**: x=150 to x=1400 (infographics primary)
- **Center Panel**: x=1400 to x=2696 (main title card from existing script)
- **Right Panel**: x=2696 to x=3946 (sortie grid from existing script)

---

## Chapter-by-Chapter Infographics

### CH01 — OPENING (0s → 17.408s)

**Visual Elements**:
- Mission Supervisor badge/insignia (Font Awesome: `fa-user-shield`)
- Text: "MISSION SUPERVISOR"
- Text: "FIELD REPORT COMMENCING"

**Layout**:
- Badge icon at x=600, y=200, size=120px
- Title below badge, centered on left panel

**Animation**:
- Fade in: 0s → 1s
- Hold: 1s → 16s
- Fade out: 16s → 17.408s

---

### CH02 — MISSION BRIEFING (17.408s → 33.451s)

**Visual Elements**:
- Objective summary graphic
- "Pipeline → Pipeline Neo" swap diagram
- Text callout: "Should've been a Tuesday"

**Layout**:
- Top section (y=600): "OBJECTIVE: LIBRARY SWAP"
- Middle (y=400): Pipeline (old) → Pipeline Neo (new) with arrow
- Bottom (y=200): "Should've been a Tuesday" in italic Helvetica Light
- Icon: `fa-exchange-alt` (swap icon)

**Animation**:
- Fade in: 17.408s → 18.5s
- Hold: 18.5s → 32.5s
- Fade out: 32.5s → 33.451s

---

### CH03 — MISSION ZERO: THE MESS (33.451s → 54.699s)

**Key Stats to Visualize**:
- 30+ commits
- 24 of 37 sorties executed
- "Over-engineering" callout

**Visual Elements**:
1. **Progress Bar**:
   - Total: 37 sorties
   - Completed: 24 sorties (65%)
   - Color: Caution Yellow (incomplete mission)

2. **Stat Cards**:
   - Card 1: "30+ COMMITS" (Mission Red)
   - Card 2: "24/37 SORTIES" (Caution Yellow)
   - Card 3: "OVER-ENGINEERED" (Mission Red)

**Layout**:
- Top (y=700): Large text "ITERATION ZERO: THE MESS"
- Middle (y=450): Progress bar (24/37) with percentage
- Bottom (y=200): Three stat cards in a row

**Icons**:
- `fa-code-branch` (commits)
- `fa-fighter-jet` (sorties)
- `fa-exclamation-triangle` (warning)

---

### CH04 — DISCOVERY: RESOURCE IDS (54.699s → 80.000s)

**Key Points**:
- FCPXML DTD requires r-prefixed IDs
- r1, r2, r3 (correct) vs UUIDs (incorrect)
- "Read the manual" message

**Visual Elements**:
1. **Comparison Table**:
   ```
   ✗ UUID: "abc-123-def-456"
   ✓ DTD Spec: "r1", "r2", "r3"
   ```

2. **Callout**: "RTFM: 10 minutes → 4 sorties saved"

**Layout**:
- Top (y=700): "DISCOVERY: RESOURCE IDs"
- Middle (y=450): Comparison table (wrong vs right)
- Bottom (y=200): "Read the manual" callout with book icon

**Icons**:
- `fa-times-circle` (wrong)
- `fa-check-circle` (correct)
- `fa-book` (manual)

---

### CH05 — DISCOVERY: LIBRARY NAME BUG (80.000s → 107.691s)

**Key Points**:
- Invalid `name` attribute on `<library>` element
- Regex on XML (bad) → XMLDocument (good)

**Visual Elements**:
1. **XML Snippet** (mock):
   ```xml
   <library name="invalid">  ← DTD violation
   ```

2. **Evolution**:
   ```
   ✗ Regex on XML
   ✓ XMLDocument (civilized)
   ```

**Layout**:
- Top (y=700): "DISCOVERY: LIBRARY NAME BUG"
- Middle (y=450): XML snippet with annotation
- Bottom (y=200): Regex vs XMLDocument comparison

**Icons**:
- `fa-bug` (bug)
- `fa-file-code` (XML)
- `fa-magic` (XMLDocument fix)

---

### CH06 — DISCOVERY: EMPTY TIMELINES (107.691s → 126.507s)

**Key Points**:
- Pipeline Neo throws exception on empty timelines
- Guard clause: bypass Pipeline Neo for zero clips

**Visual Elements**:
1. **Flowchart**:
   ```
   Timeline → Clip count == 0?
              ├─ Yes → Hand-craft FCPXML
              └─ No → Pipeline Neo export
   ```

2. **Callout**: "Not elegant. But correct."

**Layout**:
- Top (y=700): "DISCOVERY: EMPTY TIMELINES"
- Middle (y=450): Simple flowchart diagram
- Bottom (y=200): "Not elegant. But correct." in italics

**Icons**:
- `fa-project-diagram` (flowchart)
- `fa-shield-alt` (guard clause)

---

### CH07 — DISCOVERY: METADATA CORRECTION (126.507s → 151.424s)

**Key Points**:
- False conclusion: "Pipeline Neo does not export metadata"
- Truth: Lines 143-193 of FCPXMLExporter.swift handle metadata
- Metadata types: Markers, Keywords, Ratings

**Visual Elements**:
1. **Assumption vs Verification**:
   ```
   ✗ ASSUMED: "No metadata export"
   ✓ VERIFIED: Lines 143-193 handle metadata
   ```

2. **Metadata Types**:
   - Markers
   - Keywords
   - Ratings

**Layout**:
- Top (y=700): "DISCOVERY: METADATA CORRECTION"
- Middle (y=450): Assumed vs Verified comparison
- Bottom (y=200): List of metadata types with icons

**Icons**:
- `fa-times` (wrong assumption)
- `fa-check` (verified truth)
- `fa-bookmark` (markers)
- `fa-tags` (keywords)
- `fa-star` (ratings)

---

### CH08 — DISCOVERY: TIME FORMAT (151.424s → 176.512s)

**Key Points**:
- CMTime timescale: 24,000 (old) vs 600 (new)
- Both represent same durations
- Tests failed on string matching, not value comparison

**Visual Elements**:
1. **Timescale Comparison**:
   ```
   Old: 24000/24000s = 1.0s
   New: 600/600s = 1.0s
   Same value, different representation
   ```

2. **Lesson**: "Compare seconds, not strings"

**Layout**:
- Top (y=700): "DISCOVERY: TIME FORMAT"
- Middle (y=450): Timescale comparison table
- Bottom (y=200): Lesson callout

**Icons**:
- `fa-clock` (time)
- `fa-equals` (equality)

---

### CH09 — DISCOVERY: TYPE COLLISIONS (176.512s → 202.709s)

**Key Points**:
- Identical type names in SwiftSecuencia and Pipeline Neo
- Types: Timeline, Marker, ChapterMarker, Keyword
- Qualified names: PipelineNeo.Timeline vs SwiftSecuencia.Timeline
- Context budget overruns

**Visual Elements**:
1. **Colliding Types List**:
   ```
   Timeline
   Marker
   ChapterMarker
   Keyword
   ```

2. **Qualification Example**:
   ```
   PipelineNeo.Timeline
   SwiftSecuencia.Timeline
   ```

3. **Impact**: "Context budget killer"

**Layout**:
- Top (y=700): "DISCOVERY: TYPE COLLISIONS"
- Middle (y=450): List of colliding types
- Bottom (y=200): "Context budget overruns" warning

**Icons**:
- `fa-exclamation-triangle` (warning)
- `fa-memory` (context budget)

---

### CH10 — PROCESS FAILURES (202.709s → 230.826s)

**Key Stats**:
- 37 sorties planned → 10-12 meaningful units (overhead: ~70%)
- Context overruns: Sorties 3, 6, 7, 22
- Sortie 22: 142% overrun

**Visual Elements**:
1. **Overhead Visualization**:
   ```
   37 total sorties
   ├─ 10-12 meaningful (32%)
   └─ 25-27 overhead (68%)
   ```

2. **Context Overrun Graph** (bar chart):
   - S3: overrun indicator
   - S6: overrun indicator
   - S7: overrun indicator
   - S22: **142%** (highlighted in Mission Red)

**Layout**:
- Top (y=700): "PROCESS FAILURES"
- Middle (y=450): Overhead pie chart or bar
- Bottom (y=200): Context overrun graph

**Icons**:
- `fa-chart-bar` (stats)
- `fa-exclamation-circle` (overrun warning)

---

### CH11 — WHAT WORKED (230.826s → 255.018s)

**Key Patterns**:
- Adapter extension pattern ✓
- FileAssetProvider ✓
- 3-tier error taxonomy ✓
- iOS compatibility (os-macOS guards) ✓

**Visual Elements**:
1. **Success Checklist**:
   ```
   ✓ Adapter extension pattern
   ✓ FileAssetProvider
   ✓ 3-tier error taxonomy
   ✓ iOS compatibility
   ```

2. **Subtitle**: "Patterns that earned their place"

**Layout**:
- Top (y=700): "WHAT WORKED"
- Middle (y=450): Checklist with green checkmarks
- Bottom (y=200): Subtitle

**Icons**:
- `fa-check-circle` (success, Operator Green)

---

### CH12 — VERDICT: ROLL IT FLAT (255.018s → 270.250s)

**Key Concepts**:
- "Rodillo Liso" (The Smooth Roller)
- Discard code, keep knowledge
- Harvest is the product

**Visual Elements**:
1. **Roller Icon**: Large `fa-road` or `fa-level-up-alt` (representing flattening)

2. **Verdict**:
   ```
   ✗ Code (discard)
   ✓ Knowledge (keep)
   ```

3. **Quote**: "The harvest is the product, not the code"

**Layout**:
- Top (y=700): "RODILLO LISO" with roller icon
- Middle (y=450): Code vs Knowledge comparison
- Bottom (y=200): Quote in italics

**Icons**:
- `fa-road` (roller)
- `fa-trash-alt` (discard)
- `fa-brain` (knowledge)

---

### CH13 — MISSION ONE: CLEAN SLATE (270.250s → 293.631s)

**Key Comparison**:
- Iteration 0: 37 sorties
- Iteration 1: 9 sorties
- All lessons from the mess baked in from day 1

**Visual Elements**:
1. **Iteration Comparison**:
   ```
   Iteration 0: 37 sorties (chaotic)
   Iteration 1: 9 sorties (planned)
   ```

2. **Lessons Applied**:
   - ResourceMap from day 1
   - Metadata adapters included
   - DTD validation upfront

**Layout**:
- Top (y=700): "ITERATION 1: CLEAN SLATE"
- Middle (y=450): Iteration comparison (37 → 9)
- Bottom (y=200): "Lessons applied from day 1"

**Icons**:
- `fa-broom` (clean slate)
- `fa-map` (roadmap)

---

### CH14 — SORTIE ZERO: RESEARCH (293.631s → 321.322s)

**Key Points**:
- Research phase: mandatory
- Read Pipeline Neo source before writing adapters
- 30 minutes reading → 34 failures prevented

**Visual Elements**:
1. **Research Checklist**:
   ```
   □ Read Pipeline Neo source
   □ Catalog type collisions
   □ Export sample timeline
   □ Validate against DTD
   ```

2. **ROI**: "30 min → 34 failures prevented"

**Layout**:
- Top (y=700): "SORTIE ZERO: RESEARCH"
- Middle (y=450): Research checklist
- Bottom (y=200): ROI stat

**Icons**:
- `fa-book-open` (reading)
- `fa-search` (research)
- `fa-lightbulb` (insight)

---

### CH15 — SORTIES ONE THROUGH EIGHT (321.322s → 352.469s)

**Key Points**:
- 9 sorties total (S0-S8)
- File-level deliverables
- Machine-verifiable exit criteria

**Visual Elements**:
1. **Sortie List** (compact):
   ```
   S0: API Exploration
   S1: Package Setup
   S2: ResourceMap Architecture
   S3: Timeline & Metadata Adapters
   S4: Asset Provider Wrapper
   S5: SwiftSecuenciaExporter
   S6: SwiftSecuenciaBundleExporter
   S7: Test Migration & Metadata
   S8: CI & CLI Updates
   ```

2. **All status**: PENDING (Caution Yellow)

**Layout**:
- Top (y=700): "SORTIES 1-8: EXECUTION PLAN"
- Middle (y=450 → y=100): Sortie list (vertical stack)

**Icons**:
- `fa-list-ol` (ordered list)
- `fa-circle` (pending status indicator)

---

### CH16 — CURRENT STATUS (352.469s → 370.517s)

**Key Points**:
- Mission status: All 9 sorties PENDING
- Execution plan: LOCKED
- Exit criteria: DEFINED

**Visual Elements**:
1. **Status Dashboard**:
   ```
   MISSION STATUS: PENDING
   EXECUTION PLAN: LOCKED
   EXIT CRITERIA: DEFINED
   ```

2. **All sorties**: Yellow pending indicator

**Layout**:
- Top (y=700): "CURRENT MISSION STATUS"
- Middle (y=450): Dashboard with 3 status rows
- Bottom (y=200): "We know what done looks like"

**Icons**:
- `fa-clipboard-check` (status)
- `fa-lock` (locked)
- `fa-bullseye` (defined criteria)

---

### CH17 — CLOSING (370.517s → 392.320s)

**Key Message**:
- "Verification is not a feature you add later"
- "Structural difference between working and convincing"

**Visual Elements**:
1. **Final Quote**:
   ```
   "Verification is structural,
   not optional."
   ```

2. **Sign-off**: "SUPERVISOR OUT" with `fa-power-off` icon

**Layout**:
- Top (y=700): Final quote (large, centered)
- Bottom (y=200): "SUPERVISOR OUT" with power-off icon

**Icons**:
- `fa-shield-check` (verification)
- `fa-power-off` (sign-off)

---

## Motion Template Implementation Notes

### Font Awesome Icon Integration

To use Font Awesome 5 Pro icons in Motion templates:

1. **Icon as Text**:
   - Set font to "Font Awesome 5 Pro Solid" (or Light/Regular)
   - Use Unicode character for icon (e.g., `\uf007` for user icon)
   - Or use private use area characters directly

2. **Icon Unicode Reference**:
   - Search Font Awesome documentation for icon names
   - Find Unicode codepoint
   - Insert as text in Motion text layer

Example mapping:
- `fa-user-shield`: `\uf505`
- `fa-exchange-alt`: `\uf362`
- `fa-fighter-jet`: `\uf0fb`
- `fa-book`: `\uf02d`
- `fa-check-circle`: `\uf058`
- `fa-times-circle`: `\uf057`

### Animation Timing

All infographics should follow this timing pattern:
- **Fade In**: 0.5-1.0 seconds
- **Hold**: Duration of chapter minus fade in/out
- **Fade Out**: 0.5-1.0 seconds

Synchronize fade-out with chapter transition to avoid jarring cuts.

### Layer Organization

In generated `.moti` files:
1. **Layer 1**: Title Card (existing — center panel)
2. **Layer 2**: Sortie Grid (existing — right panel)
3. **Layer 3**: Chapter Infographics (NEW — left panel)

Each chapter gets its own text nodes within Layer 3, with timing offset to match FCPXML markers.

---

## Next Steps

1. **Prototype**: Generate one chapter's infographics (suggest CH03 — The Mess) to validate design
2. **Review**: Confirm visual style, layout, and timing
3. **Expand**: Generate all 17 chapters
4. **Integrate**: Add to existing `generate-motion-titles.swift` script
5. **Test**: Import into FCP, verify sync with audio

---

## Font Awesome 5 Pro Icon Cheat Sheet

Commonly needed icons for this project:

| Icon Name | Unicode | Category |
|-----------|---------|----------|
| `fa-user-shield` | `\uf505` | Mission/Authority |
| `fa-exchange-alt` | `\uf362` | Swap/Transfer |
| `fa-fighter-jet` | `\uf0fb` | Sorties |
| `fa-code-branch` | `\uf126` | Git Commits |
| `fa-exclamation-triangle` | `\uf071` | Warning |
| `fa-book` | `\uf02d` | Manual/Docs |
| `fa-check-circle` | `\uf058` | Success/Correct |
| `fa-times-circle` | `\uf057` | Error/Wrong |
| `fa-bug` | `\uf188` | Bug |
| `fa-file-code` | `\uf1c9` | XML/Code |
| `fa-shield-alt` | `\uf3ed` | Guard/Protection |
| `fa-clock` | `\uf017` | Time |
| `fa-memory` | `\uf538` | Context/Memory |
| `fa-chart-bar` | `\uf080` | Stats/Metrics |
| `fa-brain` | `\uf5dc` | Knowledge |
| `fa-road` | `\uf018` | Roller/Flattening |
| `fa-broom` | `\uf51a` | Clean Slate |
| `fa-search` | `\uf002` | Research |
| `fa-lightbulb` | `\uf0eb` | Insight |
| `fa-list-ol` | `\uf0cb` | Ordered List |
| `fa-lock` | `\uf023` | Locked |
| `fa-bullseye` | `\uf140` | Target/Criteria |
| `fa-power-off` | `\uf011` | Sign-off |

---

## Design Mockup Priority

**Phase 1 (Prototype)**:
- CH03 (The Mess) — Stats-heavy, good test case
- CH10 (Process Failures) — Complex visualization
- CH12 (Roll It Flat) — Iconic/conceptual

**Phase 2 (Core Discoveries)**:
- CH04-CH09 (All discovery chapters)

**Phase 3 (Mission Arc)**:
- CH01-CH02 (Opening)
- CH11-CH17 (Resolution)

---

**Document Version**: 1.0
**Created**: 2026-03-02
**Author**: Claude (Sonnet 4.5)
**Project**: SwiftSecuencia / Casting Software Spells
