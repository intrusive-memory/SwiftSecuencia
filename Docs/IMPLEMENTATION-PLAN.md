# SwiftSecuencia Implementation Plan

## Overview

This document outlines a phased, testable implementation approach with quality gates for each phase. Each phase builds upon the previous and must pass all quality gates before proceeding.

---

## Phase 1: Core Time & Format Types

**Goal**: Establish foundational types for time representation and video formats.

**Branch**: `phase-1-core-types`

### Deliverables

| File | Description |
|------|-------------|
| `Sources/SwiftSecuencia/Timing/Timecode.swift` | Rational time representation |
| `Sources/SwiftSecuencia/Timing/FrameRate.swift` | Frame rate enum with common rates |
| `Sources/SwiftSecuencia/Format/VideoFormat.swift` | Video format configuration |
| `Sources/SwiftSecuencia/Format/AudioLayout.swift` | Audio layout enum |
| `Sources/SwiftSecuencia/Format/AudioRate.swift` | Audio sample rate enum |
| `Sources/SwiftSecuencia/Format/ColorSpace.swift` | Color space enum |
| `Tests/SwiftSecuenciaTests/TimecodeTests.swift` | Timecode unit tests |
| `Tests/SwiftSecuenciaTests/VideoFormatTests.swift` | Format unit tests |

### Implementation Details

#### Timecode
```swift
public struct Timecode: Sendable, Equatable, Hashable, Codable, Comparable {
    public let value: Int64
    public let timescale: Int32

    public var seconds: Double
    public var fcpxmlString: String

    public static let zero: Timecode

    // Initializers
    public init(value: Int64, timescale: Int32)
    public init(seconds: Double, preferredTimescale: Int32 = 600)
    public init(frames: Int, frameRate: FrameRate)

    // Arithmetic
    public static func + (lhs: Timecode, rhs: Timecode) -> Timecode
    public static func - (lhs: Timecode, rhs: Timecode) -> Timecode
}
```

#### FrameRate
```swift
public enum FrameRate: Sendable, Equatable, Hashable, Codable {
    case fps23_98
    case fps24
    case fps25
    case fps29_97
    case fps30
    case fps50
    case fps59_94
    case fps60
    case custom(frameDuration: Timecode)

    public var frameDuration: Timecode
    public var framesPerSecond: Double
}
```

#### VideoFormat
```swift
public struct VideoFormat: Sendable, Equatable, Hashable {
    public let width: Int
    public let height: Int
    public let frameRate: FrameRate
    public let colorSpace: ColorSpace

    // Presets
    public static let hd1080p2398: VideoFormat
    public static let hd1080p24: VideoFormat
    public static let hd1080p25: VideoFormat
    public static let hd1080p2997: VideoFormat
    public static let hd1080p30: VideoFormat
    public static let uhd4k2398: VideoFormat
    public static let uhd4k24: VideoFormat

    // Computed
    public var frameDuration: Timecode
    public var aspectRatio: Double
    public var fcpxmlFormatName: String
}
```

### Quality Gates

| Gate | Criteria | Validation |
|------|----------|------------|
| **QG-1.1** | All unit tests pass | `swift test --filter Phase1` |
| **QG-1.2** | Code coverage ≥ 95% for Timecode | Coverage report |
| **QG-1.3** | Code coverage ≥ 90% for VideoFormat | Coverage report |
| **QG-1.4** | No compiler warnings | `swift build 2>&1 \| grep warning` |
| **QG-1.5** | Timecode FCPXML strings match spec | Manual verification against FCPXML-Reference.md |
| **QG-1.6** | All types are Sendable | Compiler enforced |

### Test Cases (from TESTING.md)
- UT-1.1: Timecode initialization
- UT-1.2: FCPXML string formatting
- UT-1.3: Timecode arithmetic
- UT-2.1: Format presets
- UT-2.2: Custom formats

### Exit Criteria
- [ ] All QG-1.x gates pass
- [ ] PR approved and merged to `development`
- [ ] Tagged as `v0.1.0-alpha.1`

---

## Phase 2: Timeline Data Structure

**Goal**: Implement timeline and clip management without FCPXML generation.

**Branch**: `phase-2-timeline`

**Depends On**: Phase 1

### Deliverables

| File | Description |
|------|-------------|
| `Sources/SwiftSecuencia/Timeline/Timeline.swift` | Main timeline struct |
| `Sources/SwiftSecuencia/Timeline/TimelineClip.swift` | Clip representation |
| `Sources/SwiftSecuencia/Timeline/ClipPlacement.swift` | Placement result type |
| `Sources/SwiftSecuencia/Timeline/RippleTypes.swift` | Ripple insert types |
| `Sources/SwiftSecuencia/Errors/TimelineError.swift` | Timeline-specific errors |
| `Tests/SwiftSecuenciaTests/TimelineTests.swift` | Timeline unit tests |
| `Tests/SwiftSecuenciaTests/RippleInsertTests.swift` | Ripple insert tests |

### Implementation Details

#### Timeline (Core Operations)
```swift
public struct Timeline: Sendable {
    public let format: VideoFormat
    public let audioLayout: AudioLayout
    public let audioRate: AudioRate

    private var clips: [TimelineClip]

    // State queries
    public var startTime: Timecode { get }
    public var endTime: Timecode { get }
    public var duration: Timecode { get }
    public var clipCount: Int { get }
    public var laneRange: ClosedRange<Int> { get }
    public var isEmpty: Bool { get }

    // Initialization
    public init(format: VideoFormat, audioLayout: AudioLayout = .stereo, audioRate: AudioRate = .rate48k)
}
```

#### Timeline (Clip Operations - No SwiftCompartido Yet)
```swift
extension Timeline {
    // Internal clip type for Phase 2 testing
    // Will be replaced with TypedDataStorage in Phase 3

    public mutating func appendClip(
        id: String,
        duration: Timecode,
        lane: Int = 0
    ) -> ClipPlacement

    public mutating func insertClip(
        id: String,
        duration: Timecode,
        at offset: Timecode,
        lane: Int? = nil
    ) -> ClipPlacement

    public mutating func insertClipWithRipple(
        id: String,
        duration: Timecode,
        at offset: Timecode,
        lane: Int = 0,
        rippleLanes: RippleLaneOption = .all
    ) -> RippleInsertResult

    // Queries
    public func placement(for clipID: String) -> ClipPlacement?
    public func allPlacements() -> [ClipPlacement]
    public func placements(inLane lane: Int) -> [ClipPlacement]
    public func placements(overlapping range: Range<Timecode>) -> [ClipPlacement]
}
```

### Quality Gates

| Gate | Criteria | Validation |
|------|----------|------------|
| **QG-2.1** | All Phase 1 tests still pass | `swift test --filter Phase1` |
| **QG-2.2** | All Phase 2 tests pass | `swift test --filter Phase2` |
| **QG-2.3** | Timeline code coverage ≥ 90% | Coverage report |
| **QG-2.4** | Append places clips sequentially | UT-3.2 |
| **QG-2.5** | Insert supports overlapping clips | UT-3.5 |
| **QG-2.6** | Ripple shifts correct clips | UT-3.8, UT-3.9 |
| **QG-2.7** | Query methods return correct results | UT-3.6, UT-3.7 |
| **QG-2.8** | Lane auto-assignment works | UT-3.5 (autoAssignLaneForOverlap) |

### Test Cases (from TESTING.md)
- UT-3.1: Empty timeline state
- UT-3.2: Sequential clip placement
- UT-3.3: Clip placement return value
- UT-3.4: Insert at specific timecode
- UT-3.5: Overlapping clips
- UT-3.6: Query clip information
- UT-3.7: List and filter clips
- UT-3.8: Ripple insert
- UT-3.9: Ripple lane options

### Exit Criteria
- [ ] All QG-2.x gates pass
- [ ] PR approved and merged to `development`
- [ ] Tagged as `v0.1.0-alpha.2`

---

## Phase 3: SwiftCompartido Integration

**Goal**: Integrate with TypedDataStorage for asset management.

**Branch**: `phase-3-swiftcompartido`

**Depends On**: Phase 2

### Deliverables

| File | Description |
|------|-------------|
| `Sources/SwiftSecuencia/Assets/Asset.swift` | FCPXML asset representation |
| `Sources/SwiftSecuencia/Assets/AssetRegistry.swift` | Asset ID management |
| `Sources/SwiftSecuencia/Assets/MediaMetadata.swift` | Extracted media properties |
| `Sources/SwiftSecuencia/Integration/TypedDataStorageExtensions.swift` | TypedDataStorage helpers |
| `Sources/SwiftSecuencia/Errors/AssetError.swift` | Asset-specific errors |
| `Tests/SwiftSecuenciaTests/AssetTests.swift` | Asset creation tests |
| `Tests/SwiftSecuenciaTests/IntegrationTests.swift` | SwiftCompartido integration |

### Implementation Details

#### Asset
```swift
public struct Asset: Sendable, Identifiable {
    public let id: String                    // e.g., "r1", "r2"
    public let name: String
    public let storageID: UUID               // Source TypedDataStorage.id
    public let src: URL                      // Media file URL
    public let duration: Timecode
    public let hasVideo: Bool
    public let hasAudio: Bool
    public let format: String?               // Reference to format ID
    public let audioChannels: Int?
    public let audioRate: Int?
    public let mimeType: String
}
```

#### Timeline + TypedDataStorage
```swift
extension Timeline {
    // Replace Phase 2 internal methods with TypedDataStorage versions

    @MainActor
    public mutating func append(_ storage: TypedDataStorage) throws -> ClipPlacement

    @MainActor
    public mutating func insert(
        _ storage: TypedDataStorage,
        at offset: Timecode,
        lane: Int? = nil
    ) throws -> ClipPlacement

    @MainActor
    public mutating func insertWithRipple(
        _ storage: TypedDataStorage,
        at offset: Timecode,
        lane: Int = 0,
        rippleLanes: RippleLaneOption = .all
    ) throws -> RippleInsertResult

    // Query by storage ID
    public func placement(for storageID: UUID) -> ClipPlacement?
}
```

#### MediaMetadata Extraction
```swift
public struct MediaMetadata: Sendable {
    public let duration: Timecode
    public let audioChannels: Int?
    public let audioSampleRate: Int?
    public let videoWidth: Int?
    public let videoHeight: Int?
    public let mimeType: String

    // Extract from TypedDataStorage properties
    @MainActor
    public static func from(_ storage: TypedDataStorage) throws -> MediaMetadata

    // Extract from binary data using AVFoundation (fallback)
    public static func probe(data: Data, mimeType: String) async throws -> MediaMetadata
}
```

### Quality Gates

| Gate | Criteria | Validation |
|------|----------|------------|
| **QG-3.1** | All Phase 1 & 2 tests still pass | `swift test` |
| **QG-3.2** | Asset creation from TypedDataStorage works | UT-4.1, UT-4.2, UT-4.3 |
| **QG-3.3** | Timeline accepts TypedDataStorage | IT-1.1, IT-1.2 |
| **QG-3.4** | Duration extracted correctly | Verify against test files |
| **QG-3.5** | Missing metadata handled gracefully | Error cases tested |
| **QG-3.6** | Asset IDs are unique per document | Unit test |
| **QG-3.7** | MainActor isolation correct | Compiler enforced |

### Test Cases
- UT-4.1: Asset from audio TypedDataStorage
- UT-4.2: Asset from video TypedDataStorage
- UT-4.3: Asset from image TypedDataStorage
- IT-1.1: TypedDataStorage to Timeline
- IT-1.2: Multiple TypedDataStorage records

### Exit Criteria
- [ ] All QG-3.x gates pass
- [ ] PR approved and merged to `development`
- [ ] Tagged as `v0.2.0-alpha.1`

---

## Phase 4: FCPXML Generation

**Goal**: Generate valid FCPXML documents from Timeline.

**Branch**: `phase-4-fcpxml`

**Depends On**: Phase 3

### Deliverables

| File | Description |
|------|-------------|
| `Sources/SwiftSecuencia/FCPXML/FCPXMLDocument.swift` | Root document model |
| `Sources/SwiftSecuencia/FCPXML/FCPXMLResources.swift` | Resources container |
| `Sources/SwiftSecuencia/FCPXML/FCPXMLLibrary.swift` | Library element |
| `Sources/SwiftSecuencia/FCPXML/FCPXMLEvent.swift` | Event element |
| `Sources/SwiftSecuencia/FCPXML/FCPXMLProject.swift` | Project element |
| `Sources/SwiftSecuencia/FCPXML/FCPXMLSequence.swift` | Sequence element |
| `Sources/SwiftSecuencia/FCPXML/FCPXMLSpine.swift` | Spine element |
| `Sources/SwiftSecuencia/FCPXML/FCPXMLAssetClip.swift` | Asset-clip element |
| `Sources/SwiftSecuencia/FCPXML/FCPXMLGap.swift` | Gap element |
| `Sources/SwiftSecuencia/FCPXML/Protocols/FCPXMLElement.swift` | XML generation protocol |
| `Sources/SwiftSecuencia/FCPXML/FCPXMLGenerator.swift` | Timeline → FCPXML conversion |
| `Tests/SwiftSecuenciaTests/FCPXMLTests.swift` | XML generation tests |

### Implementation Details

#### FCPXMLElement Protocol
```swift
public protocol FCPXMLElement: Sendable {
    func xmlElement() -> XMLElement
}
```

#### FCPXMLDocument
```swift
public struct FCPXMLDocument: Sendable {
    public let version: String
    public var resources: FCPXMLResources
    public var library: FCPXMLLibrary?

    public init(version: String = "1.11")

    public func xmlDocument() -> XMLDocument
    public func xmlString(prettyPrint: Bool = true) throws -> String
}
```

#### FCPXMLGenerator
```swift
public struct FCPXMLGenerator {
    public let timeline: Timeline
    public let projectName: String
    public let eventName: String
    public let libraryName: String?

    public init(
        timeline: Timeline,
        projectName: String,
        eventName: String = "Event",
        libraryName: String? = nil
    )

    public func generate(mediaBasePath: URL? = nil) throws -> FCPXMLDocument
}
```

### Quality Gates

| Gate | Criteria | Validation |
|------|----------|------------|
| **QG-4.1** | All previous phase tests pass | `swift test` |
| **QG-4.2** | Generated XML is well-formed | XMLDocument parsing |
| **QG-4.3** | Document structure matches FCPXML spec | UT-5.1 |
| **QG-4.4** | Asset elements have correct attributes | UT-5.2 |
| **QG-4.5** | Asset-clip elements have correct timing | UT-5.3 |
| **QG-4.6** | Sequence contains spine with clips | UT-5.4 |
| **QG-4.7** | Multi-lane clips use correct lane attribute | Manual verification |
| **QG-4.8** | Overlapping clips render correctly | Manual verification |

### Test Cases
- UT-5.1: Document structure
- UT-5.2: Asset element attributes
- UT-5.3: Asset-clip element attributes
- UT-5.4: Sequence and spine

### Exit Criteria
- [ ] All QG-4.x gates pass
- [ ] Generated XML validated against sample FCPXMLs
- [ ] PR approved and merged to `development`
- [ ] Tagged as `v0.3.0-alpha.1`

---

## Phase 5: Bundle Export

**Goal**: Export complete .fcpbundle packages with embedded media.

**Branch**: `phase-5-bundle`

**Depends On**: Phase 4

### Deliverables

| File | Description |
|------|-------------|
| `Sources/SwiftSecuencia/Export/FCPBundleExporter.swift` | Main export class |
| `Sources/SwiftSecuencia/Export/ExportOptions.swift` | Export configuration |
| `Sources/SwiftSecuencia/Export/ExportProgress.swift` | Progress reporting |
| `Sources/SwiftSecuencia/Export/BundleStructure.swift` | Bundle file layout |
| `Sources/SwiftSecuencia/Errors/ExportError.swift` | Export-specific errors |
| `Tests/SwiftSecuenciaTests/BundleExportTests.swift` | Bundle export tests |

### Implementation Details

#### FCPBundleExporter
```swift
public actor FCPBundleExporter {
    public let timeline: Timeline

    public init(timeline: Timeline)

    public func export(
        to url: URL,
        projectName: String,
        options: ExportOptions = .default
    ) async throws

    public func export(
        to url: URL,
        projectName: String,
        options: ExportOptions = .default,
        progress: @escaping (ExportProgress) -> Void
    ) async throws
}
```

#### ExportOptions
```swift
public struct ExportOptions: Sendable {
    public var fcpxmlVersion: String
    public var includeChecksum: Bool
    public var eventName: String
    public var libraryLocation: URL?

    public static let `default`: ExportOptions
}
```

#### ExportProgress
```swift
public struct ExportProgress: Sendable {
    public let phase: ExportPhase
    public let fractionComplete: Double
    public let currentItem: String?

    public enum ExportPhase: Sendable {
        case preparing
        case copyingMedia(index: Int, total: Int)
        case generatingXML
        case writingBundle
        case complete
    }
}
```

### Bundle Structure
```
MyProject.fcpbundle/
├── Info.plist
│   └── Contains: bundle identifier, version, creation date
├── MyProject.fcpxml
│   └── Contains: FCPXML with relative media paths
└── Media/
    ├── {asset-id-1}.mp3
    ├── {asset-id-2}.wav
    └── {asset-id-3}.m4a
```

### Quality Gates

| Gate | Criteria | Validation |
|------|----------|------------|
| **QG-5.1** | All previous phase tests pass | `swift test` |
| **QG-5.2** | Bundle directory created correctly | IT-2.1 |
| **QG-5.3** | Media files copied to bundle | IT-2.2 |
| **QG-5.4** | FCPXML references media correctly | IT-2.3 |
| **QG-5.5** | Info.plist valid | Property list validation |
| **QG-5.6** | Progress callbacks fire correctly | Unit test |
| **QG-5.7** | Export is cancellable | Unit test |
| **QG-5.8** | Failed export cleans up partial files | Unit test |

### Test Cases
- IT-2.1: Complete bundle structure
- IT-2.2: Media files copied
- IT-2.3: FCPXML references media
- IT-3.1: 100 clips performance
- IT-3.2: Export performance

### Exit Criteria
- [ ] All QG-5.x gates pass
- [ ] Bundle opens in Finder as package
- [ ] PR approved and merged to `development`
- [ ] Tagged as `v0.4.0-alpha.1`

---

## Phase 6: Validation & Final Cut Pro Testing

**Goal**: Validate generated bundles import successfully into Final Cut Pro.

**Branch**: `phase-6-validation`

**Depends On**: Phase 5

### Deliverables

| File | Description |
|------|-------------|
| `Sources/SwiftSecuencia/Validation/FCPXMLValidator.swift` | Pre-export validation |
| `Sources/SwiftSecuencia/Validation/ValidationResult.swift` | Validation results |
| `Sources/SwiftSecuencia/Validation/ValidationError.swift` | Validation errors |
| `Tests/SwiftSecuenciaTests/ValidationTests.swift` | Validation tests |
| `Tests/Resources/test-audio.mp3` | Test audio file |
| `Tests/Resources/test-video.mp4` | Test video file |

### Implementation Details

#### FCPXMLValidator
```swift
public struct FCPXMLValidator {
    public init()

    public func validate(_ document: FCPXMLDocument) -> ValidationResult
    public func validate(_ timeline: Timeline) -> ValidationResult
}
```

#### ValidationResult
```swift
public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [ValidationError]
    public let warnings: [ValidationWarning]
}
```

#### Validation Checks
- All asset references resolve
- All time values are non-negative
- Clip durations match asset durations (or are trimmed)
- No overlapping clips on same lane (warning only)
- Required elements present
- Attribute values within valid ranges

### Quality Gates

| Gate | Criteria | Validation |
|------|----------|------------|
| **QG-6.1** | All previous phase tests pass | `swift test` |
| **QG-6.2** | Validator catches missing assets | Unit test |
| **QG-6.3** | Validator catches invalid times | Unit test |
| **QG-6.4** | Valid documents pass validation | Unit test |
| **QG-6.5** | Generated XML valid against DTD | VT-1.1 (xmllint) |
| **QG-6.6** | Bundle imports into FCP without errors | MT-1 (manual) |
| **QG-6.7** | All clips appear on timeline | MT-1 (manual) |
| **QG-6.8** | Audio plays correctly | MT-1 (manual) |

### Manual Test Checklist (MT-1)
- [ ] Export .fcpbundle from SwiftSecuencia
- [ ] Open Final Cut Pro 10.6+
- [ ] File → Import → XML...
- [ ] Select the .fcpbundle
- [ ] Verify: No import errors or warnings
- [ ] Verify: Library created with correct name
- [ ] Verify: Event created with correct name
- [ ] Verify: Project created with timeline
- [ ] Verify: All clips appear on timeline in correct order
- [ ] Verify: Clip durations match expected values
- [ ] Verify: Audio plays correctly
- [ ] Verify: Overlapping clips mix correctly
- [ ] Verify: Timeline duration matches expected total

### Exit Criteria
- [ ] All QG-6.x gates pass
- [ ] Manual FCP import test passes
- [ ] Documentation complete
- [ ] PR approved and merged to `development`
- [ ] Merged to `main`
- [ ] Tagged as `v1.0.0`

---

## Phase Summary

| Phase | Branch | Version Tag | Key Deliverable |
|-------|--------|-------------|-----------------|
| 1 | `phase-1-core-types` | `v0.1.0-alpha.1` | Timecode, VideoFormat |
| 2 | `phase-2-timeline` | `v0.1.0-alpha.2` | Timeline with clip operations |
| 3 | `phase-3-swiftcompartido` | `v0.2.0-alpha.1` | TypedDataStorage integration |
| 4 | `phase-4-fcpxml` | `v0.3.0-alpha.1` | FCPXML document generation |
| 5 | `phase-5-bundle` | `v0.4.0-alpha.1` | .fcpbundle export |
| 6 | `phase-6-validation` | `v1.0.0` | Validation + FCP testing |

---

## Quality Gate Checklist Template

Use this checklist when completing each phase:

```markdown
## Phase X Quality Gate Review

### Automated Checks
- [ ] `swift build` succeeds with no warnings
- [ ] `swift test` passes all tests
- [ ] Code coverage meets threshold
- [ ] All previous phase tests still pass

### Code Quality
- [ ] All public APIs documented
- [ ] All types marked Sendable where appropriate
- [ ] Error handling complete
- [ ] No force unwraps in production code

### Review
- [ ] PR created with clear description
- [ ] Self-review completed
- [ ] All CI checks pass

### Tagging
- [ ] Version tag created
- [ ] CHANGELOG updated
```

---

## Continuous Integration

Each phase PR triggers:

1. **Build Check**: `swift build` on macOS 26
2. **Unit Tests**: All tests for current and previous phases
3. **Code Coverage**: Generate and check thresholds

### CI Configuration

```yaml
# Quality gate enforcement in CI
env:
  COVERAGE_THRESHOLD_TIMECODE: 95
  COVERAGE_THRESHOLD_TIMELINE: 90
  COVERAGE_THRESHOLD_ASSET: 85
  COVERAGE_THRESHOLD_FCPXML: 85
  COVERAGE_THRESHOLD_EXPORT: 80
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| TypedDataStorage actor isolation issues | Phase 3 focuses on this; use @MainActor appropriately |
| FCPXML compatibility with FCP versions | Test with FCP 10.6, 10.7, 10.8 in Phase 6 |
| Large file performance | Phase 5 includes streaming; IT-3.x tests validate |
| SwiftCompartido API changes | Pin to specific version; update as needed |

---

## Definition of Done

A phase is complete when:

1. All deliverables implemented
2. All quality gates pass
3. PR approved and merged to `development`
4. Version tag created
5. No regressions in previous phases
