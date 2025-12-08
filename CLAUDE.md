# Claude Development Guidelines for SwiftSecuencia

## Project Overview

SwiftSecuencia is a Swift library for generating and exporting Final Cut Pro X timelines via FCPXML. The library provides type-safe Swift APIs that model the FCPXML document structure and includes FCPXML manipulation capabilities from the Pipeline library.

**Platforms**:
- **macOS 26.0+** - Full support (FCPXML export + audio export)
- **iOS 26.0+** - Partial support (audio export only via `TimelineAudioExporter`)

## Pipeline Integration

SwiftSecuencia includes code from the [Pipeline](https://github.com/reuelk/pipeline) project by Reuel Kim (MIT License). Pipeline's FCPXML manipulation code has been integrated into the `Sources/Pipeline/` directory with modifications for Swift 6.2 and macOS 26.0+ compatibility. See `PIPELINE-LICENSE.md` for full attribution.

## ⚠️ CRITICAL: Platform Version Enforcement

### Minimum Versions

- **macOS**: 26.0+ (enforced)
- **iOS**: 26.0+ (audio export only)

### Platform-Specific Features

**macOS-Only Features** (wrapped in `#if os(macOS)`):
- `FCPXMLExporter` - Uses XMLDocument (macOS-only API)
- `FCPXMLBundleExporter` - Uses XMLDocument
- `GenerateFCPXMLBundleIntent` - Depends on FCPXML export
- `FCPXMLValidator` / `FCPXMLDTDValidator` - Uses XMLDocument
- **Pipeline library** - All FCPXML manipulation

**Cross-Platform Features** (iOS 26+ and macOS 26+):
- `Timeline` / `TimelineClip` - SwiftData models
- `TimelineAudioExporter` - M4A export using AVFoundation
- `ExportTimelineAudioIntent` - Audio export App Intent
- All timing types (`Timecode`, `FrameRate`)
- All format types (`VideoFormat`, `AudioLayout`, etc.)

### Rules for Platform Versions

1. **NEVER add `@available` attributes** for versions below the minimum
   - ❌ WRONG: `@available(macOS 12.0, *)`
   - ✅ CORRECT: No `@available` needed (package enforces minimums)

2. **Use `#if os(macOS)` for FCPXML features**
   - ✅ CORRECT: Wrap FCPXMLExporter and related code in `#if os(macOS)`
   - ✅ CORRECT: Leave TimelineAudioExporter cross-platform (no guards)

3. **Package.swift platforms**
   ```swift
   platforms: [
       .macOS(.v26),
       .iOS(.v26)  // Audio export only
   ]
   ```

4. **User-facing messages** must reflect platform requirements
   - ✅ macOS: "Requires macOS 26"
   - ✅ iOS: "Audio export only, requires iOS 26"

### Why This Matters

- Final Cut Pro for iPad does not support FCPXML import/export (macOS-only)
- XMLDocument API is not available on iOS
- Audio export (AVFoundation) works on both platforms

**DO NOT lower the minimum versions. DO NOT add FCPXML export to iOS (not possible).**

## Architecture

### Directory Structure

```
SwiftSecuencia/
├── Sources/SwiftSecuencia/
│   ├── SwiftSecuencia.swift          # Main entry point, version info
│   ├── Models/                        # FCPXML element models
│   │   ├── FCPXMLDocument.swift      # Root document model
│   │   ├── Resources/                 # Resource types
│   │   │   ├── Format.swift
│   │   │   ├── Asset.swift
│   │   │   ├── Effect.swift
│   │   │   └── Media.swift
│   │   ├── Organization/              # Organizational elements
│   │   │   ├── Library.swift
│   │   │   ├── Event.swift
│   │   │   └── Project.swift
│   │   ├── Timeline/                  # Timeline elements
│   │   │   ├── Sequence.swift
│   │   │   ├── Spine.swift
│   │   │   └── Clips/
│   │   ├── Adjustments/               # Effect adjustments
│   │   └── Metadata/                  # Markers, keywords, metadata
│   ├── Timing/                        # Time representation
│   │   ├── Timecode.swift
│   │   └── FrameRate.swift
│   ├── Export/                        # XML generation
│   │   └── FCPXMLExporter.swift
│   └── Protocols/                     # Shared protocols
│       └── FCPXMLElement.swift
├── Tests/SwiftSecuenciaTests/
├── Fixtures/                          # Test fixtures (DTD files, etc.)
│   ├── FCPXMLv1_8.dtd
│   ├── FCPXMLv1_9.dtd
│   ├── FCPXMLv1_10.dtd
│   ├── FCPXMLv1_11.dtd
│   ├── FCPXMLv1_12.dtd
│   └── FCPXMLv1_13.dtd
├── Docs/
│   ├── FCPXML-Reference.md           # Comprehensive FCPXML docs
│   └── FCPXML-Elements.md            # Element quick reference
├── Package.swift
├── README.md
└── CLAUDE.md
```

### Design Principles

1. **Type Safety**: Use Swift's type system to prevent invalid FCPXML structures
2. **Immutability by Default**: Prefer value types (structs) with `let` properties
3. **Builder Pattern**: Support fluent APIs for complex object construction
4. **Protocol-Oriented**: Define protocols for common behaviors (e.g., `FCPXMLElement`)
5. **Codable Support**: Enable JSON/Plist serialization of timeline structures

### Key Protocols

```swift
/// Protocol for all FCPXML elements that can be serialized to XML
protocol FCPXMLElement {
    /// Generate the XML element representation
    func xmlElement() -> XMLElement
}

/// Protocol for elements with timing information
protocol TimedElement {
    var offset: Timecode? { get }
    var start: Timecode? { get }
    var duration: Timecode { get }
}

/// Protocol for elements that can contain child clips
protocol ClipContainer {
    var clips: [any ClipElement] { get }
}
```

## FCPXML Version Support

The library targets FCPXML version 1.11 by default but supports export to versions 1.8-1.11. When implementing features:

1. Check if the feature exists in all supported versions
2. Document version-specific behavior
3. Gracefully handle features not available in older versions

## Time Representation

FCPXML uses rational numbers for time (e.g., `1001/30000s` for 29.97fps). The `Timecode` type handles this:

```swift
struct Timecode: Sendable, Equatable, Hashable, Codable {
    let value: Int64      // Numerator
    let timescale: Int32  // Denominator

    // Convenience initializers
    init(seconds: Double, preferredTimescale: Int32 = 600)
    init(frames: Int, frameRate: FrameRate)
    init(value: Int64, timescale: Int32)

    // FCPXML string format (e.g., "1001/30000s")
    var fcpxmlString: String
}
```

## Common Frame Rates

| Frame Rate | Frame Duration | Notes |
|------------|----------------|-------|
| 23.98 fps | 1001/24000s | NTSC film |
| 24 fps | 100/2400s | True 24 |
| 25 fps | 100/2500s | PAL |
| 29.97 fps | 1001/30000s | NTSC video |
| 30 fps | 100/3000s | True 30 |
| 50 fps | 100/5000s | PAL high frame rate |
| 59.94 fps | 1001/60000s | NTSC high frame rate |
| 60 fps | 100/6000s | True 60 |

## XML Generation

Use Foundation's `XMLDocument` and `XMLElement` for XML generation:

```swift
extension AssetClip: FCPXMLElement {
    func xmlElement() -> XMLElement {
        let element = XMLElement(name: "asset-clip")
        element.addAttribute(XMLNode.attribute(withName: "ref", stringValue: ref) as! XMLNode)
        if let offset = offset {
            element.addAttribute(XMLNode.attribute(withName: "offset", stringValue: offset.fcpxmlString) as! XMLNode)
        }
        // ... add other attributes
        return element
    }
}
```

## Testing Guidelines

1. **Unit Tests**: Test individual model types and their XML output
2. **Integration Tests**: Test complete document generation
3. **Validation Tests**: Validate generated XML against FCPXML DTD
4. **Round-Trip Tests**: Import generated XML into FCP and verify

### Example Test

```swift
@Test func assetClipGeneratesValidXML() async throws {
    let clip = AssetClip(
        ref: "r2",
        offset: Timecode(seconds: 0),
        duration: Timecode(seconds: 30)
    )

    let xml = clip.xmlElement()
    #expect(xml.name == "asset-clip")
    #expect(xml.attribute(forName: "ref")?.stringValue == "r2")
    #expect(xml.attribute(forName: "duration")?.stringValue == "30s")
}
```

## Implementation Status

### Phase 1: Core Types (✅ COMPLETED)
- [x] `Timecode` type with rational time and FCPXML string formatting
- [x] `FrameRate` enum with standard video frame rates
- [x] `VideoFormat`, `ColorSpace`, `AudioLayout`, `AudioRate` types
- [x] SwiftData models: `Timeline` and `TimelineClip`
- [x] Clip operations: append, insert, ripple insert
- [x] Clip queries: by lane, time range, ID
- [x] 107 unit tests passing
- **Status**: Merged to development (commit: 6a55c7e)

### Phase 2: Timeline Data Structure (✅ COMPLETED)
- [x] Timeline clip management and sorting
- [x] Multi-lane support (lane 0 primary, positive/negative lanes)
- [x] Time range calculations and overlap detection
- [x] Timecode comparison and arithmetic operations
- [x] All tests passing (165 total)
- **Status**: Merged to development via PR #2

### Phase 3: SwiftCompartido Integration (✅ COMPLETED)
- [x] Asset validation in `TimelineClip` (validateAsset, fetchAsset)
- [x] Content type detection (isAudioClip, isVideoClip, isImageClip)
- [x] MIME type compatibility enforcement
- [x] Timeline asset query helpers (allAssets, audioAssets, videoAssets, imageAssets)
- [x] Asset reference validation (validateAllAssets, clips(withAssetId:))
- [x] 15 new integration tests
- **Status**: Merged to development (commit: d01527c, b85d727)

### Phase 4: FCPXML Generation and Export (✅ COMPLETED)
- [x] `FCPXMLExporter` with complete document structure
- [x] Resources section (format and asset elements)
- [x] Library > Event > Project > Sequence > Spine hierarchy
- [x] Asset-clip generation with all attributes
- [x] Resource ID management system
- [x] Multi-lane export support
- [x] XML validation and structure tests
- [x] 11 comprehensive export tests
- [x] 165 total tests passing
- **Status**: Merged to development (commit: 4fa91cb)

### Phase 5: Bundle Export (✅ COMPLETED)
- [x] `.fcpxmld` bundle structure (Info.plist + Info.fcpxml + Media/)
- [x] Embedded media support with async file export
- [x] Media folder organization with UUID-based filenames
- [x] Info.plist generation with CFBundle* metadata
- [x] File extension mapping from MIME types
- [x] Relative asset path generation (Media/filename)
- [x] Optional media inclusion (includeMedia parameter)
- [x] 10 comprehensive bundle export tests
- [x] 175 total tests passing
- **Status**: Merged to development (commit: 7026d46)

### Phase 6: Quality & Infrastructure (✅ COMPLETED)
- [x] DTD validation system with SwiftFijos fixture management
- [x] Improved SwiftLint rules for platform enforcement
- [x] Centralized Fixtures/ directory for test resources
- [x] 211 total tests passing
- **Status**: v1.0.2 (December 2025)

### Phase 7: Progress Reporting (✅ COMPLETED)
- [x] Foundation.Progress API integration for export tracking
- [x] Progress reporting across all export phases (bundle, media, FCPXML, plist)
- [x] Per-asset progress updates during media export
- [x] Cancellation support with FCPXMLExportError.cancelled
- [x] Localized progress descriptions for user feedback
- [x] 4 new comprehensive progress tests
- [x] 215 total tests passing
- **Status**: v1.0.3 (December 2025)

### Future Enhancements (Planned)
- [ ] Transitions and effects
- [ ] Advanced clip adjustments (transform, crop, volume)
- [ ] Compound clips
- [ ] Multicam clips
- [ ] Title elements

## FCPXML Reference

See the documentation in `Docs/`:
- `FCPXML-Reference.md` - Comprehensive format documentation
- `FCPXML-Elements.md` - Quick reference for all elements

## Resources

- [Apple FCPXML Reference](https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference)
- [FCP Cafe Developer Resources](https://fcp.cafe/developers/fcpxml/)
- [FCPXML DTD (v1.8)](https://github.com/CommandPost/CommandPost/blob/develop/src/extensions/cp/apple/fcpxml/dtd/FCPXMLv1_8.dtd)

## Code Style

- Use Swift 6.2 language features
- Mark types as `Sendable` where appropriate
- Use `@MainActor` only when necessary
- Prefer `async/await` for file I/O operations
- Document public APIs with DocC-compatible comments
- Use `#expect` macro for Swift Testing assertions

## Common Patterns

### Resource IDs

FCPXML uses ID references (e.g., "r1", "r2") to link elements. The library should:
1. Auto-generate unique IDs when not provided
2. Validate ID uniqueness within a document
3. Resolve references during export

```swift
class ResourceIDGenerator {
    private var counter = 0

    func nextID(prefix: String = "r") -> String {
        counter += 1
        return "\(prefix)\(counter)"
    }
}
```

### Optional vs Required Attributes

Follow FCPXML DTD for attribute requirements:
- Use `Optional<T>` for attributes marked `#IMPLIED` in DTD
- Use non-optional for attributes marked `#REQUIRED`
- Provide sensible defaults where the DTD specifies them
