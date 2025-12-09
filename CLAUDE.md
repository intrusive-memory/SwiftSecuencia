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
- `BackgroundAudioExporter` - M4A export on background thread (UI responsive)
- `ForegroundAudioExporter` - M4A export on main thread (maximum speed)
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

### Phase 8: Audio Export with Concurrency (✅ COMPLETED)
- [x] `BackgroundAudioExporter` using @ModelActor for safe SwiftData concurrency
- [x] `ForegroundAudioExporter` with two export paths (Timeline-based and direct)
- [x] Direct export API: `exportAudioDirect()` skips Timeline creation (19% faster)
- [x] Timeline building on main thread (metadata only, no audio data)
- [x] Background export with `.high` priority for maximum performance
- [x] Foreground export with parallel I/O and optimized FileHandle writes
- [x] FileHandle pre-allocation on macOS (reduces fragmentation)
- [x] AVFoundation optimization: `audioTimePitchAlgorithm = .varispeed`
- [x] Persistent identifier-based model passing across actor boundaries
- [x] Parallel file I/O optimization (3-10x faster than serial writes)
- [x] Non-blocking progress updates with fire-and-forget MainActor dispatch
- [x] Read-only SwiftData access from background thread
- [x] 237 total tests passing
- **Status**: v1.0.7 (December 2025)

## Audio Export: Foreground vs Background

SwiftSecuencia provides two audio exporters with different performance trade-offs and architectures:

### BackgroundAudioExporter (UI Responsiveness)
**Use when**: User needs to interact with UI during export, large timelines (100+ clips)

```swift
let exporter = BackgroundAudioExporter(modelContainer: container)
let outputURL = try await exporter.exportAudio(
    timelineID: timelineID,
    to: destinationURL,
    progress: progress
)
```

**Architecture**:
```
audioElements → Timeline → persist to SwiftData → export on background thread
```

**Characteristics**:
- Runs on background thread with `.high` priority
- Uses @ModelActor for safe SwiftData concurrency
- UI remains fully responsive during export
- Progress updates via fire-and-forget MainActor dispatch
- Parallel file I/O for optimal performance
- Creates Timeline object for potential reuse
- Best for: large timelines, background processing, UI interaction required

**Performance**: ~12 seconds for 50 clips, 2.5 min duration

---

### ForegroundAudioExporter (Maximum Speed)
**Use when**: Export speed is critical, UI blocking acceptable, user actively waiting

SwiftSecuencia provides **two export methods** for foreground export:

#### 1. Direct Export API (FASTEST - Recommended)

```swift
@MainActor
let exporter = ForegroundAudioExporter()
let outputURL = try await exporter.exportAudioDirect(
    audioElements: audioFiles,  // TypedDataStorage array
    modelContext: modelContext,
    to: destinationURL,
    progress: progress
)
```

**Architecture**:
```
audioElements → export directly ⚡
```

**Optimizations**:
- ✅ Skips Timeline object creation
- ✅ Skips SwiftData persistence (no disk I/O overhead)
- ✅ FileHandle with pre-allocation (faster writes)
- ✅ `audioTimePitchAlgorithm = .varispeed` (fastest encoding)
- ✅ Direct sequencing from audio elements
- ✅ Parallel file I/O with `.high` priority

**Performance**: ~8.1 seconds for 50 clips, 2.5 min duration
**Speedup**: 19% faster than Timeline-based export

---

#### 2. Timeline-Based Export (Backward Compatible)

```swift
@MainActor
let exporter = ForegroundAudioExporter()
let outputURL = try await exporter.exportAudio(
    timeline: timeline,
    modelContext: modelContext,
    to: destinationURL,
    progress: progress
)
```

**Architecture**:
```
audioElements → Timeline → export
```

**Use when**: You already have a Timeline object and want to export it

**Performance**: ~10 seconds for 50 clips, 2.5 min duration

---

### Performance Comparison

| Export Method | Time (50 clips) | UI Blocking | Use Case |
|---------------|-----------------|-------------|----------|
| **Background** | ~12s | ❌ No | Large timelines, UI interaction needed |
| **Foreground (Direct)** | ~8.1s | ✅ Yes | Maximum speed, user waiting |
| **Foreground (Timeline)** | ~10s | ✅ Yes | Export existing Timeline |

**Speedup Summary**:
- Direct export is **33% faster** than background export
- Direct export is **19% faster** than Timeline-based foreground export

---

### When to Use Each

| Scenario | Recommended Export |
|----------|-------------------|
| **Large timelines (100+ clips)** | Background |
| **User needs UI during export** | Background |
| **Maximum speed critical** | Foreground (Direct) ⚡ |
| **Small/medium timelines (< 100)** | Foreground (Direct) |
| **Export existing Timeline** | Foreground (Timeline) |
| **Background processing** | Background |
| **User actively waiting** | Foreground (Direct) |

---

### Architecture Philosophy

**Two export modes, two architectures:**

| Mode | Architecture | Why |
|------|--------------|-----|
| **Background** | audioElements → Timeline → persist → export | Save Timeline for potential reuse, UI responsive |
| **Foreground** | audioElements → export directly | Maximum speed, skip all overhead |

This design matches the use case perfectly:
- **Background**: Preserve work, keep UI responsive, Timeline available for reuse
- **Foreground**: Maximum speed, sacrifice nothing for performance

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

## Concurrency Architecture

SwiftSecuencia uses two distinct concurrency architectures optimized for different use cases. See `Docs/CONCURRENCY-ARCHITECTURE.md` for complete diagrams.

### Background Export Architecture (UI Responsive)

**Two-phase approach with Timeline persistence:**

**Phase 1: Main Thread (30%)**
- Show save dialog immediately (no blocking)
- Build Timeline with metadata only (no audio data loaded)
- Insert and save Timeline to SwiftData
- Extract `persistentModelID` for background handoff

**Phase 2: Background Thread (70%)**
- Initialize `BackgroundAudioExporter` with `@ModelActor`
- Fetch Timeline by persistent ID (read-only SwiftData access)
- Batch fetch all audio assets (optimized)
- Write to temporary files in parallel (TaskGroup)
- Build AVMutableComposition and export to M4A
- Run with `.high` priority for maximum performance

**Example:**
```swift
// Phase 1: Main thread builds timeline metadata
let timeline = try await converter.convertToTimeline(
    screenplayName: "My Script",
    audioElements: audioFiles,
    progress: progress
)
modelContext.insert(timeline)
try modelContext.save()

// Phase 2: Background thread exports audio
let outputURL = try await Task.detached(priority: .high) {
    let exporter = BackgroundAudioExporter(modelContainer: container)
    return try await exporter.exportAudio(
        timelineID: timeline.persistentModelID,
        to: destinationURL,
        progress: progress
    )
}.value
```

---

### Foreground Export Architecture (Maximum Speed)

**Direct export path that skips Timeline creation:**

**Single Phase: Main Thread (100%)**
- Show save dialog immediately
- Load audio data directly from TypedDataStorage elements
- Write files in parallel with FileHandle optimization
- Build AVMutableComposition with direct sequencing
- Export to M4A with `.varispeed` algorithm

**Example:**
```swift
@MainActor
let exporter = ForegroundAudioExporter()
let outputURL = try await exporter.exportAudioDirect(
    audioElements: audioFiles,
    modelContext: modelContext,
    to: destinationURL,
    progress: progress
)
```

**Performance Optimizations**:
- ✅ No Timeline creation (saves ~0.2s)
- ✅ No SwiftData persistence (saves ~0.5s disk I/O)
- ✅ FileHandle with pre-allocation (saves ~0.2s)
- ✅ `audioTimePitchAlgorithm = .varispeed` (saves ~0.1s)
- ✅ Direct audio sequencing (saves ~0.5s)
- **Total savings: ~1.9s (19%)**

---

### Key Concurrency Principles

1. **Pass IDs, not objects**: Use `persistentModelID` to cross actor boundaries (Background only)
2. **Read-only SwiftData access**: Background thread never modifies data
3. **Lazy audio loading**: Load audio on-demand, write to temp files, release memory
4. **@ModelActor for safety**: Automatic SwiftData concurrency management (Background only)
5. **Progress reporting**: Foundation.Progress is thread-safe by design
6. **Parallel I/O**: Both exporters use TaskGroup for parallel file writes
7. **FileHandle optimization**: Pre-allocate files on macOS for faster writes

## Code Style

- Use Swift 6.2 language features
- Mark types as `Sendable` where appropriate
- Use `@MainActor` only when necessary
- Prefer `async/await` for file I/O operations
- Use `@ModelActor` for background SwiftData operations
- Document public APIs with DocC-compatible comments
- Use `#expect` macro for Swift Testing assertions

## Common Patterns

### Using ExportMenuView in Your UI

`ExportMenuView` is a reusable SwiftUI component for adding export functionality to your app. The caller is responsible for providing progress reporting.

```swift
import SwiftUI
import SwiftSecuencia

struct ContentView: View {
    @State private var exportProgress = Progress(totalUnitCount: 100)
    let document: MyDocument  // Must conform to ExportableDocument

    var body: some View {
        NavigationStack {
            // Your main content
            Text("Document: \(document.exportName)")

            // Show progress if export is active
            if exportProgress.fractionCompleted > 0 && !exportProgress.isFinished {
                VStack {
                    ProgressView(exportProgress)
                        .progressViewStyle(.linear)
                    Text(exportProgress.localizedDescription ?? "Exporting...")
                        .font(.caption)
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ExportMenuView(
                    document: document,
                    progress: exportProgress  // Caller provides Progress
                )
            }
        }
    }
}
```

**Key Points:**
- **Caller provides Progress**: Pass a `Progress` object to track export operations
- **Caller provides UI**: Use any progress indicator you prefer (ProgressView, custom UI, etc.)
- **Optional progress**: Pass `nil` if you don't need progress tracking
- **Thread-safe**: Foundation.Progress is thread-safe and can be updated from background threads

### Direct Export Without UI

For programmatic exports without `ExportMenuView`, use the exporters directly:

**M4A Audio Export (Foreground - FASTEST):**
```swift
@MainActor
func exportAudioForeground() async throws {
    let progress = Progress(totalUnitCount: 100)

    // Direct export - skips Timeline creation for maximum speed
    let exporter = ForegroundAudioExporter()
    let outputURL = try await exporter.exportAudioDirect(
        audioElements: audioFiles,  // TypedDataStorage array
        modelContext: modelContext,
        to: destinationURL,
        progress: progress
    )

    // ~8.1 seconds for 50 clips (19% faster than Timeline-based)
}
```

**M4A Audio Export (Background - UI Responsive):**
```swift
@MainActor
func exportAudioBackground() async throws {
    let progress = Progress(totalUnitCount: 100)

    // Phase 1: Build timeline on main thread (metadata only)
    let converter = ScreenplayToTimelineConverter()
    let timeline = try await converter.convertToTimeline(
        screenplayName: "My Script",
        audioElements: audioFiles,
        videoFormat: .hd1080p(frameRate: .fps24),
        progress: Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 30)
    )

    // Save to SwiftData
    modelContext.insert(timeline)
    try modelContext.save()

    // Phase 2: Export on background thread
    let container = modelContext.container
    let timelineID = timeline.persistentModelID

    let outputURL = try await Task.detached(priority: .high) {
        let exporter = BackgroundAudioExporter(modelContainer: container)
        return try await exporter.exportAudio(
            timelineID: timelineID,
            to: destinationURL,
            progress: Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 70)
        )
    }.value

    // ~12 seconds for 50 clips (UI stays responsive)
}
```

**FCPXML Bundle Export (macOS only):**
```swift
@MainActor
func exportFCPXMLBundle() async throws {
    let progress = Progress(totalUnitCount: 100)

    // Build timeline on main thread
    let converter = ScreenplayToTimelineConverter()
    let timeline = try await converter.convertToTimeline(
        screenplayName: "My Script",
        audioElements: audioFiles,
        videoFormat: .hd1080p(frameRate: .fps24),
        progress: Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 30)
    )

    modelContext.insert(timeline)
    try modelContext.save()

    // Export FCPXML bundle
    var exporter = FCPXMLBundleExporter(includeMedia: true)
    let bundleURL = try await exporter.exportBundle(
        timeline: timeline,
        modelContext: modelContext,
        to: parentDirectory,
        bundleName: "MyProject",
        libraryName: "SwiftSecuencia Export",
        eventName: "My Script",
        progress: Progress(totalUnitCount: 100, parent: progress, pendingUnitCount: 70)
    )
}
```

### Progress Reporting Best Practices

**1. Create Progress on Main Thread:**
```swift
@State private var exportProgress = Progress(totalUnitCount: 100)
```

**2. Pass to Export Functions:**
```swift
ExportMenuView(document: document, progress: exportProgress)
```

**3. Observe Progress Updates:**
```swift
// Option 1: SwiftUI ProgressView (automatic)
ProgressView(exportProgress)

// Option 2: KVO observation
exportProgress.observe(\.fractionCompleted) { progress, _ in
    print("Export \(Int(progress.fractionCompleted * 100))% complete")
}

// Option 3: Polling in Task
Task {
    while !exportProgress.isFinished {
        print(exportProgress.localizedDescription ?? "Exporting...")
        try? await Task.sleep(for: .milliseconds(100))
    }
}
```

**4. Handle Cancellation:**
```swift
Button("Cancel Export") {
    exportProgress.cancel()
}
```

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

---

## Performance Documentation

For detailed performance analysis and optimization documentation, see:

- **`Docs/EFFECTIVENESS-EVALUATION.md`** - Comprehensive evaluation of all 3 core functions
  - Timeline generation: 10/10 effectiveness
  - FCPXML export: 10/10 effectiveness, 7/10 efficiency
  - M4A audio export: 10/10 effectiveness, 9.5/10 efficiency
  - Overall grade: A+ (95/100)

- **`Docs/FOREGROUND-EXPORT-ANALYSIS.md`** - Complete execution path analysis
  - Bottleneck identification and solutions
  - Performance breakdown by phase
  - Optimization opportunities

- **`Docs/OPTION-A-IMPLEMENTATION.md`** - Direct export API implementation details
  - Architecture decisions
  - Performance improvements (19% speedup)
  - Backward compatibility notes

- **`Docs/EVALUATION-SUMMARY.md`** - Executive summary
  - Quick reference for decision makers
  - Performance comparison tables
  - Recommendations

**Quick Performance Reference:**

| Export Method | Time (50 clips) | Speedup vs Background |
|---------------|-----------------|----------------------|
| Background Export | ~12s | Baseline |
| Foreground (Direct) | ~8.1s | **33% faster** ⚡ |
| Foreground (Timeline) | ~10s | 17% faster |
