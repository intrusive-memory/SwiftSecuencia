# Sortie 0: Type Collision Catalog

**Date:** 2026-03-01
**Branch:** mission/pipeline-exodus/01
**Source:** PipelineNeo checkout at `.build/checkouts/pipeline-neo/`

---

## Confirmed Type Collisions

These types exist in BOTH `SwiftSecuencia` module and `PipelineNeo` module with the same name.

| Type Name | SwiftSecuencia Location | PipelineNeo Location | Notes |
|-----------|------------------------|----------------------|-------|
| `Timeline` | `Sources/SwiftSecuencia/Timeline/Timeline.swift` | `Sources/PipelineNeo/Timeline/Timeline.swift` | SS is `@Model final class`; PN is `struct` |
| `TimelineClip` | `Sources/SwiftSecuencia/Timeline/TimelineClip.swift` | `Sources/PipelineNeo/Timeline/TimelineClip.swift` | SS is `@Model final class`; PN is `struct` |
| `Marker` | `Sources/SwiftSecuencia/Timeline/Marker.swift` | `Sources/PipelineNeo/Annotations/Marker.swift` | Both are `struct` |
| `ChapterMarker` | `Sources/SwiftSecuencia/Timeline/ChapterMarker.swift` | `Sources/PipelineNeo/Annotations/ChapterMarker.swift` | Both are `struct` |
| `Keyword` | `Sources/SwiftSecuencia/Timeline/Keyword.swift` | `Sources/PipelineNeo/Annotations/Keyword.swift` | Both are `struct` |
| `Rating` | `Sources/SwiftSecuencia/Timeline/Rating.swift` | `Sources/PipelineNeo/Annotations/Rating.swift` | Both are `struct` |
| `Metadata` | `Sources/SwiftSecuencia/Timeline/Metadata.swift` | `Sources/PipelineNeo/Annotations/Metadata.swift` | Both are `struct` |
| `ColorSpace` | `Sources/SwiftSecuencia/Format/ColorSpace.swift` | `Sources/PipelineNeo/Format/ColorSpace.swift` | Both are `enum` |
| `ClipPlacement` | `Sources/SwiftSecuencia/Timeline/Timeline.swift:620` | `Sources/PipelineNeo/Timeline/Timeline.swift:737` | SS adds `Codable`; PN does not |
| `RippleInsertResult` | `Sources/SwiftSecuencia/Timeline/Timeline.swift:655` | `Sources/PipelineNeo/Timeline/Timeline.swift:698` | Both are `struct` |
| `ClipShift` | `Sources/SwiftSecuencia/Timeline/Timeline.swift:664` | `Sources/PipelineNeo/Timeline/Timeline.swift:713` | Both are `struct` |
| `RippleLaneOption` | `Sources/SwiftSecuencia/Timeline/Timeline.swift:640` | `Sources/PipelineNeo/Timeline/Timeline.swift:682` | Both are `enum` |
| `FCPXMLExporter` | `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift:56` | `Sources/PipelineNeo/Export/FCPXMLExporter.swift:44` | Different implementations |
| `FCPXMLExportError` | `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift:462` | `Sources/PipelineNeo/Export/FCPXMLExporter.swift:26` | Different cases |
| `FCPXMLBundleExporter` | `Sources/SwiftSecuencia/Export/FCPXMLBundleExporter.swift:91` | `Sources/PipelineNeo/Export/FCPXMLBundleExporter.swift:35` | Different implementations |
| `FCPXMLVersion` | `Sources/Pipeline/FCPXMLVersion.swift:38` | `Sources/PipelineNeo/Classes/FCPXMLVersion.swift:37` | Embedded Pipeline module |
| `ValidationError` | `Sources/SwiftSecuencia/Validation/ValidationError.swift` | `Sources/PipelineNeo/Validation/ValidationError.swift` | Different structure |
| `ValidationWarning` | `Sources/SwiftSecuencia/Validation/ValidationError.swift` | `Sources/PipelineNeo/Validation/ValidationError.swift` | Different structure |
| `ValidationResult` | `Sources/SwiftSecuencia/Validation/ValidationResult.swift` | `Sources/PipelineNeo/Validation/ValidationResult.swift` | Same purpose |
| `TimelineError` | `Sources/SwiftSecuencia/Errors/TimelineError.swift` | `Sources/PipelineNeo/Errors/TimelineError.swift` | Different cases |
| `FCPXMLDTDValidator` | `Sources/SwiftSecuencia/Validation/FCPXMLDTDValidator.swift` | `Sources/PipelineNeo/Utilities/FCPXMLDTDValidator.swift` | Both are `struct` |
| `FCPXMLValidator` | `Sources/SwiftSecuencia/Validation/FCPXMLValidator.swift` | (PipelineNeo has `FCPXMLValidator` too) | Both are `struct` |
| `FCPXMLElementType` | `Sources/Pipeline/FCPXMLElementType.swift` | `Sources/PipelineNeo/...` | Embedded Pipeline module |
| `FCPXMLUtility` | `Sources/Pipeline/FCPXMLUtility.swift` | `Sources/PipelineNeo/Classes/FCPXMLUtility.swift` | Embedded Pipeline module |

---

## Not Colliding (PipelineNeo-Only Types Used in Adapters)

These PipelineNeo types have no equivalent in SwiftSecuencia and will be used directly:

| PipelineNeo Type | Purpose |
|-----------------|---------|
| `PipelineNeo.FCPXMLExportAsset` | Asset descriptor for export pipeline |
| `PipelineNeo.TimelineFormat` | Video format descriptor (distinct from SS's `VideoFormat`) |
| `PipelineNeo.FCPXMLBundleExportError` | Bundle export error |

---

## Resolution Strategy

### Production Code (`Sources/`)
Use fully-qualified `PipelineNeo.` prefix everywhere a PipelineNeo type is referenced:
```swift
// Correct
let pnTimeline = PipelineNeo.Timeline(name: "Project")
let pnMarker = PipelineNeo.Marker(start: ..., value: ...)

// Wrong (ambiguous)
let timeline = Timeline(name: "Project")  // Could be either module
```

### Test Code (`Tests/`)
Use a shared type alias file to reduce verbosity. Create:
`Tests/SwiftSecuenciaTests/Helpers/PipelineNeoTypeAliases.swift`

```swift
// In test targets only, for readability:
typealias PNTimeline = PipelineNeo.Timeline
typealias PNTimelineClip = PipelineNeo.TimelineClip
typealias PNMarker = PipelineNeo.Marker
typealias PNChapterMarker = PipelineNeo.ChapterMarker
typealias PNKeyword = PipelineNeo.Keyword
typealias PNRating = PipelineNeo.Rating
typealias PNMetadata = PipelineNeo.Metadata
typealias PNColorSpace = PipelineNeo.ColorSpace
typealias PNTimelineFormat = PipelineNeo.TimelineFormat
typealias PNFCPXMLExportAsset = PipelineNeo.FCPXMLExportAsset
typealias PNFCPXMLExporter = PipelineNeo.FCPXMLExporter
typealias PNFCPXMLExportError = PipelineNeo.FCPXMLExportError
typealias PNClipPlacement = PipelineNeo.ClipPlacement
typealias PNRippleInsertResult = PipelineNeo.RippleInsertResult
typealias PNClipShift = PipelineNeo.ClipShift
typealias PNRippleLaneOption = PipelineNeo.RippleLaneOption
```

---

## Key Structural Differences (Adapter Implications)

### `Timeline`
- **SwiftSecuencia**: `@Model final class` (SwiftData persistent), uses `Timecode` for timing, stores `VideoFormat` as JSON-encoded `Data`, references `TimelineClip` via SwiftData relationship
- **PipelineNeo**: `struct Sendable` (in-memory), uses `CMTime` for timing, has `TimelineFormat?`, stores `[TimelineClip]` directly

### `TimelineClip`
- **SwiftSecuencia**: `@Model final class` (SwiftData persistent), uses `Timecode` for offset/duration, references asset via `TypedDataStorage` SwiftData relationship
- **PipelineNeo**: `struct Sendable` (in-memory), uses `CMTime` for offset/duration, references asset by `String` ID (e.g. `"r2"`)

### `Marker`
- **SwiftSecuencia**: Has `Codable`, uses `Timecode` for `start`/`duration`
- **PipelineNeo**: No `Codable`, uses `CMTime` for `start`/`duration`, has `completed: Bool` flag

### `Keyword`
- **SwiftSecuencia**: Has `Codable`, uses `Timecode`, `keywords` is a `String` array-like
- **PipelineNeo**: No `Codable`, uses `CMTime`, `value` is `String`

### `Rating`
- **SwiftSecuencia**: Has `Codable`, uses `Timecode`
- **PipelineNeo**: No `Codable`, uses `CMTime`, `value` is `Rating.RatingValue` enum (`favorite`/`rejected`)

### `Metadata`
- **SwiftSecuencia**: Has `Codable`, stores key-value pairs
- **PipelineNeo**: Has `Codable`, same `[String: String]` structure with `entries` dict, includes `Key` constants for Apple's standard keys

### `ColorSpace`
- **SwiftSecuencia**: `enum` with cases like `.rec709`, `.rec2020`, `.hlg`, `.pq`, `.srgb`, `.appleLog`, `.appleLogP3`
- **PipelineNeo**: `enum` with cases `.rec709`, `.rec2020`, `.rec2020HLG`, `.rec2020PQ`, `.sRGB` (5 cases, no appleLog)

---

## Complete Verified Collision List

The known collisions from Iteration 01 brief are CONFIRMED plus additional ones found:

Original list: `Timeline`, `Marker`, `ChapterMarker`, `Keyword`, `Rating`, `Metadata`, `ColorSpace`, `ClipPlacement`, `RippleInsertResult`, `ClipShift`, `RippleLaneOption`

Additional collisions found: `TimelineClip`, `FCPXMLExporter`, `FCPXMLExportError`, `FCPXMLBundleExporter`, `FCPXMLVersion`, `ValidationError`, `ValidationWarning`, `ValidationResult`, `TimelineError`, `FCPXMLDTDValidator`, `FCPXMLValidator`, `FCPXMLElementType`, `FCPXMLUtility`

**Total confirmed collisions: 24 types**
