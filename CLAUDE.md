# Claude Development Guidelines for SwiftSecuencia

## Project Overview

SwiftSecuencia is a Swift library for generating and exporting Final Cut Pro X timelines via FCPXML. The library provides type-safe Swift APIs that model the FCPXML document structure.

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

## Implementation Priority

### Phase 1: Core Structure
- [ ] `Timecode` type with FCPXML string formatting
- [ ] `FCPXMLDocument` root model
- [ ] `Resources` container (Format, Asset)
- [ ] `Library`, `Event`, `Project` hierarchy
- [ ] `Sequence` and `Spine`
- [ ] `AssetClip` and `Gap`
- [ ] Basic XML export

### Phase 2: Clip Types
- [ ] `Clip` (container)
- [ ] `RefClip`
- [ ] `SyncClip`
- [ ] `Transition`
- [ ] `Audition`

### Phase 3: Media Elements
- [ ] `Video` element
- [ ] `Audio` element
- [ ] `Title` element
- [ ] Audio channel mapping

### Phase 4: Adjustments
- [ ] `AdjustTransform`
- [ ] `AdjustCrop`
- [ ] `AdjustVolume`
- [ ] `AdjustBlend`
- [ ] Keyframe animation

### Phase 5: Metadata & Markers
- [ ] `Marker`
- [ ] `ChapterMarker`
- [ ] `Keyword`
- [ ] `Rating`
- [ ] Custom metadata

### Phase 6: Advanced Features
- [ ] Multicam clips
- [ ] Effects and filters
- [ ] Smart collections
- [ ] Time remapping
- [ ] Rate conforming

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
