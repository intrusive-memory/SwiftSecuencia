# Timecode Synchronization Implementation Plan

## Overview

This document outlines the implementation plan for adding timing data generation to SwiftSecuencia's audio export functionality using WebVTT (primary) and JSON (optional) formats. The implementation follows a phased approach with clear milestones and quality gates.

**Key Technologies**:
- **swift-webvtt-parser** for WebVTT generation (W3C compliant)
- **Foundation.JSONEncoder** for optional JSON export
- **AVFoundation** for precise audio timing

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Audio Export Flow                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ForegroundAudioExporter / BackgroundAudioExporter          │
│                         │                                    │
│                         ├──► Build AVMutableComposition     │
│                         │                                    │
│                         ├──► WebVTTGenerator                │
│                         │    │                               │
│                         │    ├─► Extract clip timing        │
│                         │    ├─► Calculate start/end times  │
│                         │    ├─► Fetch character metadata   │
│                         │    ├─► Build WebVTT cues          │
│                         │    └─► Generate .vtt file         │
│                         │                                    │
│                         ├──► TimingDataGenerator (optional) │
│                         │    │                               │
│                         │    ├─► Build TimingSegment array  │
│                         │    ├─► Create TimingData          │
│                         │    └─► Generate .timing.json      │
│                         │                                    │
│                         ├──► Export M4A (AVAssetExportSession)
│                         │                                    │
│                         └──► Write .vtt and/or .json files  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Timeline/AudioElements
        │
        ├──► Build AVMutableComposition
        │    └──► Composition tracks with time ranges
        │
        ├──► WebVTTGenerator (primary)
        │    ├──► Extract clips in timeline order
        │    ├──► Calculate cumulative start times
        │    ├──► Fetch asset metadata (character, text)
        │    └──► Build WebVTT using swift-webvtt-parser
        │         │
        │         ├──► Create cues with timing ranges
        │         ├──► Add voice tags for characters
        │         ├──► Generate WebVTT string
        │         └──► Write to .vtt file
        │
        └──► TimingDataGenerator (optional, if .json requested)
             ├──► Extract clips in timeline order
             ├──► Build TimingSegment array
             ├──► Create TimingData object
             ├──► Encode to JSON
             └──► Write to .timing.json file
```

---

## Implementation Phases

### Phase 1: Dependencies & Core Models (2-3 hours)

**Goal**: Add swift-webvtt-parser dependency and define data models.

#### Tasks

1. **Update Package.swift**
   - Add swift-webvtt-parser dependency
   - Version: 1.0.0+

2. **Create TimingDataFormat enum**
   - Location: `Sources/SwiftSecuencia/Export/TimingDataFormat.swift`
   - Define format selection enum

3. **Create TimingData.swift (JSON)**
   - Location: `Sources/SwiftSecuencia/Export/TimingData.swift`
   - Define `TimingData`, `TimingSegment`, `TimingMetadata` structs
   - Implement Codable conformance
   - Add convenience initializers

#### Implementation

**1. Update Package.swift:**

```swift
// Package.swift

dependencies: [
    .package(url: "https://github.com/SwiftCompartido/swift-typed-data-storage.git", from: "1.0.0"),
    .package(url: "https://github.com/mihai8804858/swift-webvtt-parser.git", from: "1.0.0"),  // NEW
]

targets: [
    .target(
        name: "SwiftSecuencia",
        dependencies: [
            .product(name: "TypedDataStorage", package: "swift-typed-data-storage"),
            .product(name: "WebVTTParser", package: "swift-webvtt-parser"),  // NEW
        ]
    ),
]
```

**2. Create TimingDataFormat enum:**

```swift
// Sources/SwiftSecuencia/Export/TimingDataFormat.swift

import Foundation

/// Format options for timing data export
public enum TimingDataFormat: Sendable {
    /// No timing data (default)
    case none

    /// WebVTT format only (recommended for web players)
    case webvtt

    /// JSON format only (advanced use cases)
    case json

    /// Both WebVTT and JSON formats
    case both
}
```

**3. Create TimingData.swift (JSON):**

```swift
// Sources/SwiftSecuencia/Export/TimingData.swift

import Foundation

/// Timing data for audio segments, enabling synchronized transcript display
public struct TimingData: Codable, Sendable {
    /// Schema version (currently "1.0")
    public let version: String

    /// Audio filename (e.g., "screenplay.m4a")
    public let audioFile: String

    /// Total audio duration in seconds
    public let duration: Double

    /// Array of timed segments
    public let segments: [TimingSegment]

    public init(version: String = "1.0", audioFile: String, duration: Double, segments: [TimingSegment]) {
        self.version = version
        self.audioFile = audioFile
        self.duration = duration
        self.segments = segments
    }

    /// Generate file URL for timing data based on audio URL
    public static func fileURL(for audioURL: URL) -> URL {
        audioURL.appendingPathExtension("timing.json")
    }

    /// Write timing data to JSON file
    public func write(to url: URL) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}

/// A single timed segment (dialogue line or audio clip)
public struct TimingSegment: Codable, Sendable {
    /// Unique identifier (typically clip UUID)
    public let id: String

    /// Start time in seconds from beginning of audio
    public let startTime: Double

    /// End time in seconds from beginning of audio
    public let endTime: Double

    /// Text content of the segment (if available)
    public let text: String?

    /// Optional metadata (character, lane, etc.)
    public let metadata: TimingMetadata?

    public init(id: String, startTime: Double, endTime: Double, text: String? = nil, metadata: TimingMetadata? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.metadata = metadata
    }
}

/// Optional metadata for timing segments
public struct TimingMetadata: Codable, Sendable {
    /// Character name (from Fountain screenplay)
    public let character: String?

    /// Timeline lane number
    public let lane: Int?

    /// Clip UUID
    public let clipId: String?

    public init(character: String? = nil, lane: Int? = nil, clipId: String? = nil) {
        self.character = character
        self.lane = lane
        self.clipId = clipId
    }
}
```

#### Tests

- `TimingDataFormatTests.swift` (enum cases)
- `TimingDataModelTests.swift` (UT-2.1 through UT-2.3)
- `TimingDataFileExportTests.swift` (UT-5.1, UT-5.3)

#### Quality Gate

- [ ] Package dependency resolves correctly
- [ ] All model tests passing
- [ ] JSON round-trip encoding/decoding works
- [ ] File I/O helper methods tested

---

### Phase 2: WebVTT Generator (3-4 hours)

**Goal**: Implement WebVTT generation using swift-webvtt-parser.

#### Tasks

1. **Create WebVTTGenerator.swift**
   - Location: `Sources/SwiftSecuencia/Export/WebVTTGenerator.swift`
   - Implement `generateWebVTT(from:modelContext:)` for Timeline
   - Implement `generateWebVTT(from:audioElements:)` for direct export
   - Extract metadata and apply voice tags for characters

2. **Handle edge cases**
   - Empty timelines
   - Clips with gaps
   - Overlapping clips (multi-lane) with separate cues
   - Missing metadata (graceful fallback)

#### Implementation

```swift
// Sources/SwiftSecuencia/Export/WebVTTGenerator.swift

import Foundation
import SwiftData
import SwiftCompartido
import WebVTTParser

/// Generates WebVTT timing data from Timeline or audio elements
struct WebVTTGenerator {
    private let parser = WebVTTParser()

    /// Generate WebVTT from Timeline
    func generateWebVTT(
        from timeline: Timeline,
        modelContext: ModelContext
    ) async throws -> String {
        let clips = timeline.clips.sorted { $0.offset < $1.offset }

        let vtt = WebVTT {
            // Add header note
            note {
                plain("Screenplay: \(timeline.name)")
            }

            for (index, clip) in clips.enumerated() {
                let startTime = clip.offset.seconds
                let endTime = startTime + clip.duration.seconds

                // Fetch asset metadata
                let asset = try? await clip.fetchAsset(modelContext: modelContext)
                let character = asset?.metadata["character"] as? String
                let text = asset?.metadata["text"] as? String

                // Build cue with voice tag if character available
                cue(identifier: "\(index + 1)", timing: startTime...endTime) {
                    if let character = character, let text = text {
                        voice(character) {
                            plain(text)
                        }
                    } else if let text = text {
                        plain(text)
                    }
                }
            }
        }

        return try parser.print(vtt)
    }

    /// Generate WebVTT from audio elements (direct export)
    func generateWebVTT(
        from audioElements: [TypedDataStorage],
        modelContext: ModelContext
    ) async throws -> String {
        var cumulativeTime: Double = 0.0
        var cues: [(index: Int, start: Double, end: Double, character: String?, text: String?)] = []

        // First pass: collect timing and metadata
        for (index, element) in audioElements.enumerated() {
            // Get duration directly from metadata to avoid expensive I/O
            guard let duration = element.durationSeconds else {
                throw AudioExportError.invalidAudioData(assetId: element.id, reason: "Missing duration metadata")
            }

            let startTime = cumulativeTime
            let endTime = cumulativeTime + duration

            let character = element.metadata["character"] as? String
            let text = element.metadata["text"] as? String

            cues.append((index: index + 1, start: startTime, end: endTime, character: character, text: text))

            cumulativeTime += duration
        }

        // Second pass: build WebVTT
        let vtt = WebVTT {
            for cue in cues {
                cue(identifier: "\(cue.index)", timing: cue.start...cue.end) {
                    if let character = cue.character, let text = cue.text {
                        voice(character) {
                            plain(text)
                        }
                    } else if let text = cue.text {
                        plain(text)
                    }
                }
            }
        }

        return try parser.print(vtt)
    }
}
```

#### Tests

- `WebVTTGenerationTests.swift` (UT-1.1 through UT-1.3)
- `WebVTTGeneratorTests.swift` (UT-3.1, UT-3.2)

#### Quality Gate

- [ ] All WebVTT generator tests passing
- [ ] Handles empty timelines
- [ ] Handles multi-lane timelines with separate cues
- [ ] Character voice tags render correctly
- [ ] WebVTT validates against W3C spec

---

### Phase 3: JSON Generator (Optional) (2-3 hours)

**Goal**: Implement optional JSON timing data generation.

#### Tasks

1. **Create TimingDataGenerator.swift**
   - Location: `Sources/SwiftSecuencia/Export/TimingDataGenerator.swift`
   - Implement `generateSegments(from:modelContext:)` for Timeline
   - Implement `generateSegments(from:audioElements:)` for direct export
   - Extract metadata from TypedDataStorage assets

2. **Handle edge cases**
   - Empty timelines
   - Clips with gaps
   - Overlapping clips (multi-lane)
   - Missing metadata

#### Implementation

```swift
// Sources/SwiftSecuencia/Export/TimingDataGenerator.swift

import Foundation
import SwiftData
import SwiftCompartido

/// Generates JSON timing data from Timeline or audio elements
struct TimingDataGenerator {

    /// Generate timing segments from a Timeline
    func generateSegments(
        from timeline: Timeline,
        modelContext: ModelContext
    ) async throws -> [TimingSegment] {
        var segments: [TimingSegment] = []

        let clips = timeline.clips.sorted { $0.offset < $1.offset }

        for clip in clips {
            let startTime = clip.offset.seconds
            let endTime = startTime + clip.duration.seconds

            let asset = try await clip.fetchAsset(modelContext: modelContext)
            let text = asset?.metadata["text"] as? String
            let character = asset?.metadata["character"] as? String

            let metadata = TimingMetadata(
                character: character,
                lane: clip.lane,
                clipId: clip.id.uuidString
            )

            let segment = TimingSegment(
                id: clip.id.uuidString,
                startTime: startTime,
                endTime: endTime,
                text: text,
                metadata: metadata
            )

            segments.append(segment)
        }

        return segments
    }

    /// Generate timing segments from audio elements (direct export)
    func generateSegments(
        from audioElements: [TypedDataStorage],
        modelContext: ModelContext
    ) async throws -> [TimingSegment] {
        var segments: [TimingSegment] = []
        var cumulativeTime: Double = 0.0

        for element in audioElements {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(element.fileExtension)

            try await element.writeData(to: tempURL)

            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration).seconds

            let text = element.metadata["text"] as? String
            let character = element.metadata["character"] as? String

            let metadata = TimingMetadata(
                character: character,
                lane: nil,
                clipId: element.id.uuidString
            )

            let segment = TimingSegment(
                id: element.id.uuidString,
                startTime: cumulativeTime,
                endTime: cumulativeTime + duration,
                text: text,
                metadata: metadata
            )

            segments.append(segment)
            cumulativeTime += duration

            try? FileManager.default.removeItem(at: tempURL)
        }

        return segments
    }
}
```

#### Tests

- `TimingDataGeneratorTests.swift` (UT-4.1 through UT-4.4)

#### Quality Gate

- [ ] All JSON generator tests passing
- [ ] Handles empty timelines
- [ ] Handles multi-lane timelines
- [ ] Extracts metadata correctly

---

### Phase 4: Foreground Exporter Integration (2-3 hours)

**Goal**: Add timing data generation to `ForegroundAudioExporter`.

#### Tasks

1. **Update ExportResult struct**
   - Add `webvttURL: URL?` property
   - Add `jsonURL: URL?` property

2. **Update ForegroundAudioExporter.swift**
   - Add `timingDataFormat` parameter to `exportAudioDirect()`
   - Add `timingDataFormat` parameter to `exportAudio()`
   - Generate WebVTT and/or JSON based on format selection
   - Write files concurrently if both formats requested
   - Return file URLs in result

#### Implementation

```swift
// Sources/SwiftSecuencia/Export/ForegroundAudioExporter.swift

public struct ExportResult {
    public let audioURL: URL
    public let webvttURL: URL?
    public let jsonURL: URL?

    public init(audioURL: URL, webvttURL: URL? = nil, jsonURL: URL? = nil) {
        self.audioURL = audioURL
        self.webvttURL = webvttURL
        self.jsonURL = jsonURL
    }
}

@MainActor
public func exportAudioDirect(
    audioElements: [TypedDataStorage],
    modelContext: ModelContext,
    to destinationURL: URL,
    timingDataFormat: TimingDataFormat = .none,  // NEW parameter
    progress: Progress? = nil
) async throws -> ExportResult {

    // ... existing composition building code ...

    var webvttURL: URL? = nil
    var jsonURL: URL? = nil

    // Generate timing data based on format
    switch timingDataFormat {
    case .none:
        break

    case .webvtt:
        webvttURL = try await generateWebVTT(
            audioElements: audioElements,
            audioURL: destinationURL,
            modelContext: modelContext
        )

    case .json:
        jsonURL = try await generateJSON(
            audioElements: audioElements,
            audioURL: destinationURL,
            modelContext: modelContext
        )

    case .both:
        // Generate both formats concurrently
        async let webvtt = generateWebVTT(
            audioElements: audioElements,
            audioURL: destinationURL,
            modelContext: modelContext
        )
        async let json = generateJSON(
            audioElements: audioElements,
            audioURL: destinationURL,
            modelContext: modelContext
        )

        webvttURL = try await webvtt
        jsonURL = try await json
    }

    return ExportResult(audioURL: destinationURL, webvttURL: webvttURL, jsonURL: jsonURL)
}

private func generateWebVTT(
    audioElements: [TypedDataStorage],
    audioURL: URL,
    modelContext: ModelContext
) async throws -> URL {
    let generator = WebVTTGenerator()
    let webvtt = try await generator.generateWebVTT(
        from: audioElements,
        modelContext: modelContext
    )

    let outputURL = audioURL.deletingPathExtension().appendingPathExtension("vtt")
    try webvtt.write(to: outputURL, atomically: true, encoding: .utf8)

    return outputURL
}

private func generateJSON(
    audioElements: [TypedDataStorage],
    audioURL: URL,
    modelContext: ModelContext
) async throws -> URL {
    let generator = TimingDataGenerator()
    let segments = try await generator.generateSegments(
        from: audioElements,
        modelContext: modelContext
    )

    let asset = AVURLAsset(url: audioURL)
    let duration = try await asset.load(.duration).seconds

    let timingData = TimingData(
        audioFile: audioURL.lastPathComponent,
        duration: duration,
        segments: segments
    )

    let outputURL = TimingData.fileURL(for: audioURL)
    try await timingData.write(to: outputURL)

    return outputURL
}
```

#### Tests

- `ForegroundExporterTimingDataTests.swift` (IT-1.1 through IT-1.4)

#### Quality Gate

- [ ] Direct export with WebVTT works
- [ ] Direct export with JSON works
- [ ] Direct export with both formats works
- [ ] Timeline export with timing data works
- [ ] Disabled timing data doesn't create files
- [ ] Backward compatibility maintained (.none is default)

---

### Phase 5: Background Exporter Integration (2-3 hours)

**Goal**: Add timing data generation to `BackgroundAudioExporter`.

#### Tasks

1. **Update BackgroundAudioExporter.swift**
   - Add `timingDataFormat` parameter to `exportAudio()`
   - Generate timing data on background thread
   - Write .vtt and/or .json files
   - Return timing data URLs in result

2. **Handle concurrency**
   - Ensure SwiftData reads are safe on background thread
   - Use @ModelActor context for asset fetching

#### Implementation

```swift
// Sources/SwiftSecuencia/Export/BackgroundAudioExporter.swift

@ModelActor
public func exportAudio(
    timelineID: PersistentIdentifier,
    to destinationURL: URL,
    timingDataFormat: TimingDataFormat = .none,  // NEW parameter
    progress: Progress? = nil
) async throws -> ExportResult {

    // ... existing export code ...

    var webvttURL: URL? = nil
    var jsonURL: URL? = nil

    // Generate timing data based on format
    guard timingDataFormat != .none else {
        return ExportResult(audioURL: destinationURL, webvttURL: nil, jsonURL: nil)
    }

    guard let timeline = modelContext.model(for: timelineID) as? Timeline else {
        throw FCPXMLExportError.assetNotFound(timelineID.uriRepresentation().absoluteString)
    }

    switch timingDataFormat {
    case .none:
        break

    case .webvtt:
        webvttURL = try await generateWebVTT(
            timeline: timeline,
            audioURL: destinationURL,
            modelContext: modelContext
        )

    case .json:
        jsonURL = try await generateJSON(
            timeline: timeline,
            audioURL: destinationURL,
            modelContext: modelContext
        )

    case .both:
        async let webvtt = generateWebVTT(
            timeline: timeline,
            audioURL: destinationURL,
            modelContext: modelContext
        )
        async let json = generateJSON(
            timeline: timeline,
            audioURL: destinationURL,
            modelContext: modelContext
        )

        webvttURL = try await webvtt
        jsonURL = try await json
    }

    return ExportResult(audioURL: destinationURL, webvttURL: webvttURL, jsonURL: jsonURL)
}

private func generateWebVTT(
    timeline: Timeline,
    audioURL: URL,
    modelContext: ModelContext
) async throws -> URL {
    let generator = WebVTTGenerator()
    let webvtt = try await generator.generateWebVTT(
        from: timeline,
        modelContext: modelContext
    )

    let outputURL = audioURL.deletingPathExtension().appendingPathExtension("vtt")
    try webvtt.write(to: outputURL, atomically: true, encoding: .utf8)

    return outputURL
}

private func generateJSON(
    timeline: Timeline,
    audioURL: URL,
    modelContext: ModelContext
) async throws -> URL {
    let generator = TimingDataGenerator()
    let segments = try await generator.generateSegments(
        from: timeline,
        modelContext: modelContext
    )

    let asset = AVURLAsset(url: audioURL)
    let duration = try await asset.load(.duration).seconds

    let timingData = TimingData(
        audioFile: audioURL.lastPathComponent,
        duration: duration,
        segments: segments
    )

    let outputURL = TimingData.fileURL(for: audioURL)
    try await timingData.write(to: outputURL)

    return outputURL
}
```

#### Tests

- `BackgroundExporterTimingDataTests.swift` (IT-2.1)

#### Quality Gate

- [ ] Background export with timing data works
- [ ] No SwiftData concurrency errors
- [ ] Progress reporting includes timing data phase

---

### Phase 6: Validation & Testing (3-4 hours)

**Goal**: Comprehensive testing and validation.

#### Tasks

1. **WebVTT validation tests**
   - Validate output against W3C specification
   - Test voice tag rendering
   - Verify timestamp formatting

2. **Timing accuracy tests**
   - Compare timing data to actual audio playback positions
   - Verify ±100ms precision requirement
   - Test with varying clip lengths

3. **Edge case tests**
   - Very short clips (< 1 second)
   - Large timelines (100+ clips)
   - Empty timelines
   - Missing metadata

4. **Performance benchmarks**
   - Measure overhead (target < 5%)
   - Test with 50-clip timeline
   - Profile memory usage

#### Tests

- `TimingAccuracyTests.swift` (VT-1.1, VT-1.2)
- `TimingDataEdgeCaseTests.swift` (VT-2.1, VT-2.2)
- `TimingDataPerformanceTests.swift` (PT-1.1)

#### Quality Gate

- [ ] All tests passing (90%+ coverage)
- [ ] WebVTT validates against W3C spec
- [ ] Timing accuracy within ±100ms
- [ ] Performance overhead < 5%
- [ ] No memory leaks

---

### Phase 7: UI Integration (1-2 hours)

**Goal**: Add timing data option to ExportMenuView.

#### Tasks

1. **Update ExportMenuView**
   - Add picker for timing data format selection
   - Options: None, WebVTT, JSON, Both
   - Pass format to export functions
   - Show timing data files in completion message

2. **Update ExportableDocument protocol**
   - Add optional `timingDataFormat` property

#### Implementation

```swift
// Sources/SwiftSecuencia/Views/ExportMenuView.swift

@State private var timingDataFormat: TimingDataFormat = .none

var body: some View {
    Menu {
        Section("Export Options") {
            Picker("Timing Data", selection: $timingDataFormat) {
                Text("None").tag(TimingDataFormat.none)
                Text("WebVTT").tag(TimingDataFormat.webvtt)
                Text("JSON").tag(TimingDataFormat.json)
                Text("Both").tag(TimingDataFormat.both)
            }
        }

        Section("Export Formats") {
            Button("Export M4A Audio") {
                Task {
                    await exportM4A(timingDataFormat: timingDataFormat)
                }
            }

            // ... other export options
        }
    }
}

private func exportM4A(timingDataFormat: TimingDataFormat) async {
    // ... existing code ...

    let result = try await exporter.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: destinationURL,
        timingDataFormat: timingDataFormat,
        progress: progress
    )

    if let webvttURL = result.webvttURL {
        print("WebVTT exported to: \(webvttURL)")
    }

    if let jsonURL = result.jsonURL {
        print("JSON exported to: \(jsonURL)")
    }
}
```

#### Quality Gate

- [ ] UI picker works correctly
- [ ] Export completes with selected format(s)
- [ ] User can find .vtt and/or .json files

---

### Phase 8: Documentation & Release (2-3 hours)

**Goal**: Finalize documentation and prepare for release.

#### Tasks

1. **Update README.md**
   - Add timing data feature description
   - Include WebVTT and JSON examples
   - Add web player integration guide
   - Show HTML `<track>` element usage

2. **Update CLAUDE.md**
   - Document new API parameters
   - Add WebVTT and timing data to feature list
   - Document swift-webvtt-parser dependency

3. **Create migration guide**
   - Show before/after code examples
   - Explain backward compatibility (default = .none)

4. **Update CHANGELOG.md**
   - Document new feature
   - List breaking changes (none - backward compatible)

5. **Create web player example**
   - HTML/JS sample code for Daily Dao
   - Show TextTrack API usage
   - Demonstrate karaoke-style highlighting

#### Quality Gate

- [ ] Documentation complete
- [ ] Examples tested
- [ ] Release notes written

---

## Implementation Timeline

| Phase | Duration | Dependencies |
|-------|----------|-------------|
| Phase 1: Dependencies & Core Models | 2-3 hours | None |
| Phase 2: WebVTT Generator | 3-4 hours | Phase 1 |
| Phase 3: JSON Generator (Optional) | 2-3 hours | Phase 1 |
| Phase 4: Foreground Export | 2-3 hours | Phase 1, 2, 3 |
| Phase 5: Background Export | 2-3 hours | Phase 1, 2, 3 |
| Phase 6: Validation | 3-4 hours | Phase 4, 5 |
| Phase 7: UI Integration | 1-2 hours | Phase 4, 5 |
| Phase 8: Documentation | 2-3 hours | All phases |
| **Total** | **17-25 hours** | |

---

## Code Style Guidelines

### Naming Conventions

- **Types**: PascalCase (TimingData, TimingSegment)
- **Properties**: camelCase (startTime, endTime)
- **Methods**: camelCase (generateSegments, write)
- **Parameters**: camelCase (includeTimingData, audioElements)

### Documentation

```swift
/// Generate timing segments from a Timeline
///
/// - Parameters:
///   - timeline: The timeline to extract timing from
///   - modelContext: SwiftData context for asset fetching
/// - Returns: Array of timed segments
/// - Throws: `FCPXMLExportError.assetNotFound` if assets missing
func generateSegments(
    from timeline: Timeline,
    modelContext: ModelContext
) async throws -> [TimingSegment]
```

### Error Handling

```swift
// Timing data generation should not fail the export
do {
    let segments = try await generator.generateSegments(...)
    try await timingData.write(to: outputURL)
    timingDataURL = outputURL
} catch {
    // Log warning but continue
    print("Warning: Failed to generate timing data: \(error)")
    timingDataURL = nil
}
```

---

## Testing Strategy

### Unit Tests (50+ tests)

- Models: Codable, initializers, file I/O
- Generator: Timeline parsing, metadata extraction
- Edge cases: Empty, large, short clips

### Integration Tests (10+ tests)

- Foreground export: Direct and timeline-based
- Background export: Concurrency and SwiftData
- File I/O: JSON writing and reading

### Performance Tests (3+ tests)

- Overhead measurement
- Memory profiling
- Large timeline benchmarks

### Manual Testing

- Export real Fountain screenplay
- Load in web player
- Verify synchronization accuracy

---

## Rollout Plan

### Version 1.1.0 (Initial Release)

- [ ] Core functionality (Phases 1-5)
- [ ] WebVTT support (primary format)
- [ ] JSON support (optional format)
- [ ] Comprehensive tests (Phase 6)
- [ ] Basic documentation

### Version 1.1.1 (Polish)

- [ ] UI integration (Phase 7)
- [ ] Complete documentation (Phase 8)
- [ ] Web player sample code
- [ ] Performance optimizations

### Version 1.2.0 (Future Enhancements)

- [ ] Word-level timing (requires speech recognition)
- [ ] Advanced WebVTT styling (regions, positioning)
- [ ] SRT format support (if requested)

---

## Risk Mitigation

### Risk 1: Timing Inaccuracy

**Mitigation**: Comprehensive validation tests with known audio durations

### Risk 2: Performance Overhead

**Mitigation**: Profile early, optimize generator, run in parallel

### Risk 3: SwiftData Concurrency Issues

**Mitigation**: Use @ModelActor, read-only access, test thoroughly

### Risk 4: Breaking Changes

**Mitigation**: Default parameter values, backward compatible API

---

## Success Criteria

1. **Functionality**: Timing data matches audio within ±100ms
2. **W3C Compliance**: WebVTT validates against specification
3. **Performance**: < 5% overhead when enabled
4. **Reliability**: 0 crashes or export failures
5. **Adoption**: Used in Daily Dao web player with native `<track>` element
6. **Quality**: 90%+ test coverage

---

## References

- [WebVTT Specification (W3C)](https://www.w3.org/TR/webvtt1/)
- [swift-webvtt-parser GitHub](https://github.com/mihai8804858/swift-webvtt-parser)
- [WebVTT API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API)
- [HTML Track Element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/track)
- [AVFoundation Timing](https://developer.apple.com/documentation/avfoundation/avmutablecomposition)
- [JSON Schema](https://json-schema.org/)
- [SwiftSecuencia Architecture](CONCURRENCY-ARCHITECTURE.md)
