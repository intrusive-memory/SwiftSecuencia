# Sortie 0: API Exploration & Research Notes

**Date:** 2026-03-01
**Branch:** mission/pipeline-exodus/01
**Iteration:** 02
**Researcher:** Sortie 0 (Sonnet)

---

## Summary of Findings

This document records all findings from reading Pipeline Neo source code and validating against the FCPXML DTD. All findings are based on direct source code analysis of the pipeline-neo checkout at:

`.build/checkouts/pipeline-neo/Sources/PipelineNeo/`

---

## 1. ResourceMap Requirements

### Format Resource ID
`FCPXMLExporter.formatResourceID = "r1"` (static constant, line 49 of `FCPXMLExporter.swift`).

The format resource is ALWAYS assigned ID `"r1"`. This is hardcoded in the exporter.

### Asset Resource IDs
Assets must be assigned `"r2"`, `"r3"`, `"r4"`, etc. Asset IDs are passed in via `[FCPXMLExportAsset]` — the caller is responsible for assigning them. Pipeline Neo does NOT auto-assign resource IDs.

**Implication for ResourceMap (Sortie 2):**
- `r1` is always the format resource
- `r2`, `r3`, ... are assets, assigned by the caller in the order provided
- ResourceMap must track: one entry for format (`r1`) and sequential entries for each asset UUID

### Validation Note
The DTD validates `asset-clip ref="..."` against the `IDREF` type, which requires the referenced `id` to exist in the document. The r-prefixed pattern (`r1`, `r2`, etc.) satisfies this. Custom strings like `asset-001` would also work, but the convention established by Pipeline Neo and used throughout is the r-prefix pattern.

---

## 2. Export Logic Flow

### `FCPXMLExporter.export()` — Complete Flow

Located at: `.build/checkouts/pipeline-neo/Sources/PipelineNeo/Export/FCPXMLExporter.swift`

1. **Empty timeline guard** (line 75): Throws `FCPXMLExportError.invalidTimeline(reason: "Timeline has no clips")` if `timeline.clips.isEmpty`. This is a hard error — Pipeline Neo cannot export empty timelines.

2. **Asset reference validation** (lines 79-83): Validates each `TimelineClip.assetRef` exists in the provided `assets` array. Throws `FCPXMLExportError.missingAsset(assetId:)` on first mismatch.

3. **Format resource element** (lines 85-111): Creates `<format id="r1" name="..." frameDuration="..." width="..." height="..."/>`. Default format is `hd1080p` at 24000 timescale if `timeline.format` is nil.

4. **Asset resource elements** (lines 113-131): Creates `<asset id="..." name="..." duration="..." hasVideo="..." hasAudio="..."><media-rep kind="original-media" src="..."/></asset>`. Uses `asset.relativePath` if set, otherwise `asset.src.absoluteString`.

5. **Timeline-level metadata** (lines 143-158): Adds to `<sequence>`:
   - `timeline.markers` → `<marker>` elements
   - `timeline.chapterMarkers` → `<chapter-marker>` elements
   - `timeline.keywords` → `<keyword>` elements
   - `timeline.ratings` → `<rating>` elements
   - `timeline.metadata` → `<metadata>` element

   **CRITICAL BUG: These are added BEFORE the spine (line 196: `sequence.addChild(spine)`). The DTD requires `sequence = (note?, spine, metadata?)`. Markers, keywords, and ratings are NOT valid children of `<sequence>` per the v1.11 DTD. This will cause DTD validation failures.**

6. **Clip elements** (lines 162-194): Creates `<asset-clip>` elements for each clip, sorted by offset then lane. Clip-level markers/keywords/ratings/metadata are added as children of `<asset-clip>` (lines 179-193). **These ARE valid per DTD** (`asset-clip` accepts `%marker_item;*`).

7. **Document tree** (lines 200-218): Builds `<fcpxml><resources/><library name="..."><event/></library></fcpxml>`.

   **CRITICAL BUG: `<library>` element gets a `name` attribute added (line 209). The FCPXML DTD v1.11 defines `<!ELEMENT library (event | smart-collection)*>` with only `location` and `colorProcessing` attributes — NOT `name`. This invalid attribute causes DTD validation to fail.**

---

## 3. DTD Validation Results

### Test File Validated
`sortie-0-sample-output.fcpxml` (manually constructed sample)

### DTD Used
`Final_Cut_Pro_XML_DTD_version_1.11.dtd` (from pipeline-neo bundled DTDs)

### Command Used
```bash
cp ".build/checkouts/pipeline-neo/Sources/PipelineNeo/FCPXML DTDs/Final_Cut_Pro_XML_DTD_version_1.11.dtd" /tmp/fcpxml_1_11.dtd
xmllint --dtdvalid /tmp/fcpxml_1_11.dtd sortie-0-sample-output.fcpxml
```

### Validation Result: PASS (after manual correction)
The sample FCPXML validates cleanly when:
1. `<library>` has NO `name` attribute
2. Markers/keywords/ratings are placed inside `<asset-clip>` NOT as children of `<sequence>`
3. `<sequence>` has only `(note?, spine, metadata?)` children

### DTD-Identified Pipeline Neo Bugs

**Bug 1: Library `name` attribute (CONFIRMED)**
- DTD: `<!ELEMENT library (event | smart-collection)*>` with only `location` and `colorProcessing` attributes
- Pipeline Neo adds: `library.addStringAttribute(name: "name", value: libraryName)` (line 209)
- Fix: After export, parse XML as `XMLDocument`, find `<library>` element, call `.removeAttribute(forName: "name")`, re-serialize

**Bug 2: Sequence-level marker/keyword/rating placement (CONFIRMED)**
- DTD: `<!ELEMENT sequence (note?, spine, metadata?)>`
- Pipeline Neo adds markers/keywords/ratings before the spine (lines 143-158)
- These element types (`marker`, `keyword`, `rating`, `chapter-marker`) are NOT valid children of `<sequence>` per the DTD
- Fix options:
  a. Patch in our adapter layer (omit timeline-level markers from sequence)
  b. Submit fix to pipeline-neo upstream
  c. Strip sequence-level markers post-export via XMLDocument

**Note:** For `asset-clip` elements, markers ARE valid. DTD: `<!ELEMENT asset-clip (note?, %timing-params;, %intrinsic-params;, (%anchor_item;)*, (%marker_item;)*, ...)>` where `%marker_item; = "(marker | chapter-marker | rating | keyword | analysis-marker)"`.

---

## 4. Empty Timeline Behavior

Pipeline Neo's `FCPXMLExporter.export()` throws immediately for empty timelines:
```swift
if timeline.clips.isEmpty {
    throw FCPXMLExportError.invalidTimeline(reason: "Timeline has no clips")
}
```

**Implication for Sortie 5 (SwiftSecuenciaExporter):**
- The exporter must check for empty timelines BEFORE calling Pipeline Neo
- Return a hand-crafted minimal FCPXML string (bypass Pipeline Neo entirely)
- Minimal valid FCPXML for empty timeline:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<fcpxml version="1.11">
    <resources>
        <format id="r1" name="FFVideoFormat1080p2398" frameDuration="1001/24000s" width="1920" height="1080"/>
    </resources>
    <library>
        <event name="Empty Event">
            <project name="Empty Project">
                <sequence format="r1" duration="0s" tcStart="0s">
                    <spine/>
                </sequence>
            </project>
        </event>
    </library>
</fcpxml>
```

---

## 5. Library Name Bug — XMLDocument Fix Approach

The correct approach (do NOT use regex):

```swift
// After exporter.export() returns xmlString:
let doc = try XMLDocument(xmlString: xmlString, options: .nodePreserveAll)
if let library = doc.rootElement()?.elements(forName: "library").first {
    library.removeAttribute(forName: "name")
}
let fixedXML = doc.xmlString(options: .nodePrettyPrint)
```

Key points:
- `XMLDocument` is Foundation class, available on macOS
- `XMLElement.removeAttribute(forName:)` is the safe API
- `doc.rootElement()` returns the `<fcpxml>` element
- Must navigate: `fcpxml` → `library` (not inside resources, which goes first)
- Re-serialize with `doc.xmlString` or `doc.xmlData`

---

## 6. Metadata Export Confirmation

**CONFIRMED: Pipeline Neo DOES export metadata at both timeline and clip levels.**

### Timeline Level (sequence children)
Source: `FCPXMLExporter.swift` lines 143-158:
```swift
for marker in timeline.markers {
    sequence.addChild(marker.xmlElement())
}
for chapterMarker in timeline.chapterMarkers {
    sequence.addChild(chapterMarker.xmlElement())
}
for keyword in timeline.keywords {
    sequence.addChild(keyword.xmlElement())
}
for rating in timeline.ratings {
    sequence.addChild(rating.xmlElement())
}
if let metadata = timeline.metadata, !metadata.isEmpty {
    sequence.addChild(metadata.xmlElement())
}
```

### Clip Level (asset-clip children)
Source: `FCPXMLExporter.swift` lines 179-193:
```swift
for marker in clip.markers {
    clipEl.addChild(marker.xmlElement())
}
for chapterMarker in clip.chapterMarkers {
    clipEl.addChild(chapterMarker.xmlElement())
}
for keyword in clip.keywords {
    clipEl.addChild(keyword.xmlElement())
}
for rating in clip.ratings {
    clipEl.addChild(rating.xmlElement())
}
if let metadata = clip.metadata, !metadata.isEmpty {
    clipEl.addChild(metadata.xmlElement())
}
```

**The false conclusion from Iteration 01 was wrong — Pipeline Neo DOES export metadata.**

**However, timeline-level markers/keywords/ratings (not metadata) will cause DTD validation failures** because `<sequence>` does not accept these as children. The `<metadata>` element IS valid as a sequence child (it's the last optional element in `(note?, spine, metadata?)`).

**Correction 2026-03-01: `<metadata>` is valid in `<sequence>`. Only `<marker>`, `<keyword>`, `<rating>`, and `<chapter-marker>` are problematic at the sequence level.**

---

## 7. CMTime Timescale

Pipeline Neo uses **timescale 600** for general time calculations.

Source: `.build/checkouts/pipeline-neo/Sources/PipelineNeo/Implementations/TimecodeConverter.swift`
```swift
return CMTime(seconds: seconds, preferredTimescale: 600)
```

The old embedded Pipeline module used timescale 24000. Both are valid; they produce the same rational number.

FCPXML time string format: `"value/timescaleS"` (e.g. `"1001/24000s"` or `"5/6s"` = 600-base equivalent).

The `FCPXMLUtility.fcpxmlTime(fromCMTime:)` method calls `TimecodeConverter.fcpxmlTime(fromCMTime:)` which outputs: `"\(time.value)/\(time.timescale)s"` (line 71 of `TimecodeConverter.swift`).

**Implication:** When converting SwiftSecuencia `Timecode` to `CMTime` for Pipeline Neo, use timescale 600 for consistency with Pipeline Neo's internal calculations.

---

## 8. Pipeline Neo Public API Surface (Export-Relevant Types)

### `FCPXMLExporter` (Primary export type)
```swift
public struct FCPXMLExporter: Sendable {
    public var version: FCPXMLVersion
    public static let formatResourceID = "r1"

    public init(version: FCPXMLVersion = .default)

    public func export(
        timeline: Timeline,
        assets: [FCPXMLExportAsset],
        libraryName: String = "Exported Library",
        eventName: String = "Exported Event",
        projectName: String? = nil
    ) throws -> String
}
```

### `FCPXMLExportAsset`
```swift
public struct FCPXMLExportAsset: Sendable, Equatable {
    public var id: String          // Must be "r2", "r3", etc.
    public var name: String?
    public var src: URL            // Absolute URL to media file
    public var duration: CMTime?   // Optional
    public var hasVideo: Bool
    public var hasAudio: Bool
    public var relativePath: String? // Used for bundle src (e.g. "Media/clip.mov")
}
```

### `Timeline` (for export)
```swift
public struct Timeline: Sendable, Equatable {
    public var name: String
    public var format: TimelineFormat?
    public var clips: [TimelineClip]
    public var markers: [Marker]
    public var chapterMarkers: [ChapterMarker]
    public var keywords: [Keyword]
    public var ratings: [Rating]
    public var metadata: Metadata?
}
```

### `TimelineClip` (for export)
```swift
public struct TimelineClip: Sendable, Equatable {
    public var name: String?
    public var assetRef: String    // Must match FCPXMLExportAsset.id
    public var offset: CMTime
    public var duration: CMTime
    public var start: CMTime       // Trim start (default .zero)
    public var lane: Int           // 0=primary, positive=above, negative=below
    public var isVideoDisabled: Bool
    public var markers: [Marker]
    public var chapterMarkers: [ChapterMarker]
    public var keywords: [Keyword]
    public var ratings: [Rating]
    public var metadata: Metadata?
}
```

### `TimelineFormat`
```swift
public struct TimelineFormat: Sendable, Equatable {
    public var width: Int
    public var height: Int
    public var frameDuration: CMTime
    public var colorSpace: ColorSpace   // NOTE: PipelineNeo.ColorSpace, NOT SS.ColorSpace
    public var interlaced: Bool

    // Presets:
    public static func hd1080p(frameDuration: CMTime, colorSpace: ColorSpace = .rec709) -> TimelineFormat
    public static func hd720p(...) -> TimelineFormat
    public static func uhd4K(...) -> TimelineFormat
    public static func dci4K(...) -> TimelineFormat
}
```

### `FCPXMLBundleExporter`
```swift
public struct FCPXMLBundleExporter: Sendable {
    public var version: FCPXMLVersion
    public var includeMedia: Bool

    public func exportBundle(
        timeline: Timeline,
        assets: [FCPXMLExportAsset],
        to outputDirectory: URL,
        bundleName: String? = nil,
        libraryName: String = "Exported Library",
        eventName: String = "Exported Event",
        projectName: String? = nil
    ) throws -> URL
}
```

Note: `FCPXMLBundleExporter` creates a `.fcpxmld` bundle (not `.fcpbundle`). Our existing code uses `.fcpbundle`. Check whether Final Cut Pro accepts `.fcpxmld` extension.

---

## 9. FCPXMLVersion

PipelineNeo's `FCPXMLVersion` enum covers versions 1.5 through 1.14. Default is `.v1_14`.

```swift
public enum FCPXMLVersion: String, CaseIterable, Sendable {
    case v1_5, v1_6, v1_7, v1_8, v1_9, v1_10, v1_11, v1_12, v1_13, v1_14
    public static let `default`: FCPXMLVersion = .v1_14
}
```

This collides with SwiftSecuencia's embedded `Pipeline.FCPXMLVersion`. After removing the embedded Pipeline module, the only `FCPXMLVersion` will be `PipelineNeo.FCPXMLVersion`.

---

## 10. Bundle Format Note

PipelineNeo's `FCPXMLBundleExporter` creates `.fcpxmld` bundles (line 66):
```swift
let bundleDir = outputDirectory.appendingPathComponent("\(name).fcpxmld", isDirectory: true)
```

SwiftSecuencia's existing `FCPXMLBundleExporter` in production code uses `.fcpbundle`. Investigation needed to determine which extension Final Cut Pro accepts. Both extensions may be valid.

---

## 11. Sample Output Analysis

`sortie-0-sample-output.fcpxml` was manually constructed to match Pipeline Neo's output pattern. Key characteristics:

1. **Format resource**: `<format id="r1" .../>` — always first in `<resources>`
2. **Asset resources**: `<asset id="r2" ...>` and `<asset id="r3" ...>` — r-prefixed, sequential
3. **Library**: No `name` attribute (DTD-compliant, requires XMLDocument fix post-export)
4. **Sequence**: `(note?, spine, metadata?)` — markers/keywords/ratings at sequence level would fail DTD
5. **Clip-level metadata**: `<marker>`, `<keyword>` inside `<asset-clip>` — valid per DTD

The sample validates cleanly against `Final_Cut_Pro_XML_DTD_version_1.11.dtd`.

---

## 12. Recommendations for Sorties 2-5

### Sortie 2 (ResourceMap)
- Format ID: always `"r1"` (static)
- Asset IDs: `"r2"`, `"r3"`, etc. in deterministic order
- Sort UUIDs before assigning IDs to ensure stable output across runs

### Sortie 3 (Adapters)
- Metadata adapters ARE needed and should NOT be skipped
- Timeline-level markers/keywords/ratings: convert to PipelineNeo types for clip-level attachment but AVOID sequence-level placement (DTD invalid)
- Use `PipelineNeo.` qualified names throughout

### Sortie 4 (Asset Provider)
- Asset IDs must flow through ResourceMap
- `FCPXMLExportAsset.id` must match `TimelineClip.assetRef`
- Set `relativePath` for bundle exports ("Media/filename.ext")

### Sortie 5 (SwiftSecuenciaExporter)
1. Empty timeline guard: return hand-crafted minimal FCPXML before calling Pipeline Neo
2. After Pipeline Neo export: parse as `XMLDocument`, remove `library.name` attribute
3. Consider also stripping sequence-level markers (DTD invalid) or filing issue upstream
4. Use timescale 600 for CMTime conversions

### Sortie 7 (Tests)
- Metadata integration test: verify markers and keywords appear in FCPXML at CLIP level
- DTD validation test: confirm no `<library name="...">` attribute in output
- DTD validation test: confirm resource IDs are r-prefixed

---

## Exit Criteria Verification

- [x] All Pipeline Neo public types cataloged (see `sortie-0-type-collisions.md`)
- [x] ResourceMap format documented (`r1` for format, `r2+` for assets)
- [x] Empty timeline behavior documented (throws `invalidTimeline` error)
- [x] Library name bug documented with XMLDocument fix approach
- [x] Metadata export confirmed working (lines 143-193 of FCPXMLExporter.swift)
- [x] Sample FCPXML validates against DTD (after correcting sequence-level metadata placement)
- [x] DTD validation failures documented (two Pipeline Neo bugs found)
