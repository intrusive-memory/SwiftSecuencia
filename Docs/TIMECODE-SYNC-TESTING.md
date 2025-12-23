# Timecode Synchronization Testing Plan

## Test Strategy

This testing plan ensures timing data generation meets accuracy, performance, and reliability requirements. Tests are organized into unit, integration, and validation layers.

---

## Unit Tests

### UT-1: WebVTT Generation

**Test Suite**: `WebVTTGenerationTests`

#### UT-1.1: Basic WebVTT Generation

```swift
@Test func generateBasicWebVTT() async throws {
    let parser = WebVTTParser()

    let vtt = WebVTT {
        cue(identifier: "1", timing: 0.0...3.2) {
            plain("ALICE: Hello, world!")
        }

        cue(identifier: "2", timing: 3.5...7.8) {
            plain("BOB: How are you?")
        }
    }

    let contents = try parser.print(vtt)

    #expect(contents.contains("WEBVTT"))
    #expect(contents.contains("00:00:00.000 --> 00:00:03.200"))
    #expect(contents.contains("ALICE: Hello, world!"))
    #expect(contents.contains("00:00:03.500 --> 00:00:07.800"))
    #expect(contents.contains("BOB: How are you?"))
}
```

#### UT-1.2: WebVTT Voice Tags

```swift
@Test func generateWebVTTWithVoiceTags() async throws {
    let parser = WebVTTParser()

    let vtt = WebVTT {
        cue(identifier: "1", timing: 0.0...3.0) {
            voice("ALICE") {
                plain("Hello!")
            }
        }
    }

    let contents = try parser.print(vtt)

    #expect(contents.contains("<v ALICE>Hello!</v>"))
}
```

#### UT-1.3: WebVTT File Write

```swift
@Test func writeWebVTTToFile() async throws {
    let parser = WebVTTParser()

    let vtt = WebVTT {
        cue(identifier: "1", timing: 0.0...5.0) {
            plain("Test line")
        }
    }

    let contents = try parser.print(vtt)

    let tempDir = FileManager.default.temporaryDirectory
    let vttURL = tempDir.appendingPathComponent("test.vtt")

    try contents.write(to: vttURL, atomically: true, encoding: .utf8)

    #expect(FileManager.default.fileExists(atPath: vttURL.path))

    let readBack = try String(contentsOf: vttURL)
    #expect(readBack == contents)

    // Cleanup
    try? FileManager.default.removeItem(at: vttURL)
}
```

---

### UT-2: TimingData JSON Model

**Test Suite**: `TimingDataJSONModelTests`

#### UT-2.1: Codable Serialization

```swift
@Test func timingDataEncodesToJSON() async throws {
    let segment = TimingSegment(
        id: "line-1",
        startTime: 0.0,
        endTime: 3.2,
        text: "Hello, world!",
        metadata: TimingMetadata(character: "ALICE", lane: 1)
    )

    let timingData = TimingData(
        version: "1.0",
        audioFile: "test.m4a",
        duration: 10.0,
        segments: [segment]
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonData = try encoder.encode(timingData)

    #expect(jsonData.count > 0)

    // Verify round-trip
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(TimingData.self, from: jsonData)
    #expect(decoded.segments.count == 1)
    #expect(decoded.segments[0].id == "line-1")
    #expect(decoded.segments[0].startTime == 0.0)
}
```

#### UT-2.2: Optional Metadata

```swift
@Test func timingSegmentSupportsOptionalMetadata() async throws {
    let segment1 = TimingSegment(
        id: "line-1",
        startTime: 0.0,
        endTime: 3.0,
        text: "Hello",
        metadata: nil  // No metadata
    )

    let segment2 = TimingSegment(
        id: "line-2",
        startTime: 3.0,
        endTime: 6.0,
        text: "World",
        metadata: TimingMetadata(character: "BOB", lane: nil)  // Partial metadata
    )

    #expect(segment1.metadata == nil)
    #expect(segment2.metadata?.character == "BOB")
    #expect(segment2.metadata?.lane == nil)
}
```

#### UT-2.3: Schema Validation

```swift
@Test func timingDataJSONMatchesExpectedSchema() async throws {
    let timingData = TimingData(
        version: "1.0",
        audioFile: "test.m4a",
        duration: 10.0,
        segments: [
            TimingSegment(
                id: "line-1",
                startTime: 0.0,
                endTime: 3.0,
                text: "Test",
                metadata: TimingMetadata(character: "ALICE", lane: 1)
            )
        ]
    )

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(timingData)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    #expect(json?["version"] as? String == "1.0")
    #expect(json?["audioFile"] as? String == "test.m4a")
    #expect(json?["duration"] as? Double == 10.0)

    let segments = json?["segments"] as? [[String: Any]]
    #expect(segments?.count == 1)
    #expect(segments?[0]["id"] as? String == "line-1")
    #expect(segments?[0]["startTime"] as? Double == 0.0)
    #expect(segments?[0]["endTime"] as? Double == 3.0)
    #expect(segments?[0]["text"] as? String == "Test")
}
```

---

### UT-3: WebVTT Generator

**Test Suite**: `WebVTTGeneratorTests`

#### UT-3.1: Generate WebVTT from Timeline

```swift
@Test func generateWebVTTFromTimeline() async throws {
    let modelContext = ModelContext(container)

    let clip = TimelineClip(
        id: UUID(),
        assetId: "asset-1",
        offset: Timecode(seconds: 0),
        duration: Timecode(seconds: 5),
        lane: 0
    )

    let timeline = Timeline(name: "Test", videoFormat: .hd1080p(frameRate: .fps24))
    timeline.appendClip(clip)

    let generator = WebVTTGenerator()
    let webvtt = try await generator.generateWebVTT(from: timeline, modelContext: modelContext)

    #expect(webvtt.contains("WEBVTT"))
    #expect(webvtt.contains("00:00:00.000 --> 00:00:05.000"))
}
```

#### UT-3.2: WebVTT with Character Voice Tags

```swift
@Test func generateWebVTTWithCharacterNames() async throws {
    let modelContext = ModelContext(container)

    // Create asset with character metadata
    let asset = TypedDataStorage(
        id: UUID(),
        data: Data(),
        mimeType: "audio/mpeg",
        metadata: ["character": "ALICE", "text": "Hello, world!"]
    )
    modelContext.insert(asset)
    try modelContext.save()

    let clip = TimelineClip(
        id: UUID(),
        assetId: asset.id.uuidString,
        offset: Timecode(seconds: 0),
        duration: Timecode(seconds: 3),
        lane: 0
    )

    let timeline = Timeline(name: "Test", videoFormat: .hd1080p(frameRate: .fps24))
    timeline.appendClip(clip)

    let generator = WebVTTGenerator()
    let webvtt = try await generator.generateWebVTT(from: timeline, modelContext: modelContext)

    #expect(webvtt.contains("<v ALICE>Hello, world!</v>"))
}
```

---

### UT-4: Timing Data Generator (JSON)

**Test Suite**: `TimingDataGeneratorTests`

#### UT-4.1: Single Clip Timeline

```swift
@Test func generateTimingDataForSingleClip() async throws {
    let clip = TimelineClip(
        id: UUID(),
        assetId: "asset-1",
        offset: Timecode(seconds: 0),
        duration: Timecode(seconds: 5),
        lane: 0
    )

    let timeline = Timeline(name: "Test", videoFormat: .hd1080p(frameRate: .fps24))
    timeline.appendClip(clip)

    let generator = TimingDataGenerator()
    let segments = try await generator.generateSegments(from: timeline, modelContext: modelContext)

    #expect(segments.count == 1)
    #expect(segments[0].startTime == 0.0)
    #expect(segments[0].endTime == 5.0)
    #expect(segments[0].id == clip.id.uuidString)
}
```

#### UT-4.2: Multi-Clip Timeline

```swift
@Test func generateTimingDataForMultipleClips() async throws {
    let clip1 = TimelineClip(
        id: UUID(),
        assetId: "asset-1",
        offset: Timecode(seconds: 0),
        duration: Timecode(seconds: 3),
        lane: 0
    )

    let clip2 = TimelineClip(
        id: UUID(),
        assetId: "asset-2",
        offset: Timecode(seconds: 3.5),  // 0.5s gap
        duration: Timecode(seconds: 4),
        lane: 0
    )

    let timeline = Timeline(name: "Test", videoFormat: .hd1080p(frameRate: .fps24))
    timeline.appendClip(clip1)
    timeline.appendClip(clip2)

    let generator = TimingDataGenerator()
    let segments = try await generator.generateSegments(from: timeline, modelContext: modelContext)

    #expect(segments.count == 2)
    #expect(segments[0].startTime == 0.0)
    #expect(segments[0].endTime == 3.0)
    #expect(segments[1].startTime == 3.5)
    #expect(segments[1].endTime == 7.5)
}
```

#### UT-4.3: Multi-Lane Timeline

```swift
@Test func generateTimingDataForMultipleLanes() async throws {
    let clip1 = TimelineClip(
        id: UUID(),
        assetId: "asset-1",
        offset: Timecode(seconds: 0),
        duration: Timecode(seconds: 5),
        lane: 1  // Lane 1
    )

    let clip2 = TimelineClip(
        id: UUID(),
        assetId: "asset-2",
        offset: Timecode(seconds: 2),  // Overlaps with clip1
        duration: Timecode(seconds: 4),
        lane: 2  // Lane 2
    )

    let timeline = Timeline(name: "Test", videoFormat: .hd1080p(frameRate: .fps24))
    timeline.appendClip(clip1)
    timeline.appendClip(clip2)

    let generator = TimingDataGenerator()
    let segments = try await generator.generateSegments(from: timeline, modelContext: modelContext)

    #expect(segments.count == 2)

    // Segments should overlap
    #expect(segments[0].startTime == 0.0)
    #expect(segments[0].endTime == 5.0)
    #expect(segments[1].startTime == 2.0)
    #expect(segments[1].endTime == 6.0)

    // Metadata should include lane
    #expect(segments[0].metadata?.lane == 1)
    #expect(segments[1].metadata?.lane == 2)
}
```

#### UT-4.4: Empty Timeline

```swift
@Test func generateTimingDataForEmptyTimeline() async throws {
    let timeline = Timeline(name: "Empty", videoFormat: .hd1080p(frameRate: .fps24))

    let generator = TimingDataGenerator()
    let segments = try await generator.generateSegments(from: timeline, modelContext: modelContext)

    #expect(segments.isEmpty)
}
```

---

### UT-5: File Export

**Test Suite**: `TimingDataFileExportTests`

#### UT-5.1: JSON File Creation

```swift
@Test func exportTimingDataToJSONFile() async throws {
    let timingData = TimingData(
        version: "1.0",
        audioFile: "test.m4a",
        duration: 10.0,
        segments: [
            TimingSegment(
                id: "line-1",
                startTime: 0.0,
                endTime: 5.0,
                text: "Test line",
                metadata: nil
            )
        ]
    )

    let tempDir = FileManager.default.temporaryDirectory
    let audioURL = tempDir.appendingPathComponent("test.m4a")
    let timingURL = timingData.fileURL(for: audioURL)

    #expect(timingURL.lastPathComponent == "test.m4a.timing.json")

    // Export to file
    try await timingData.write(to: timingURL)

    // Verify file exists
    #expect(FileManager.default.fileExists(atPath: timingURL.path))

    // Verify contents
    let data = try Data(contentsOf: timingURL)
    let decoded = try JSONDecoder().decode(TimingData.self, from: data)
    #expect(decoded.segments.count == 1)

    // Cleanup
    try? FileManager.default.removeItem(at: timingURL)
}
```

#### UT-5.2: File Naming Convention

```swift
@Test func webVTTFileURLFollowsNamingConvention() async throws {
    let audioURL1 = URL(fileURLWithPath: "/path/screenplay.m4a")
    let vttURL1 = audioURL1.deletingPathExtension().appendingPathExtension("vtt")
    #expect(vttURL1.lastPathComponent == "screenplay.vtt")

    let audioURL2 = URL(fileURLWithPath: "/path/My Audio.m4a")
    let vttURL2 = audioURL2.deletingPathExtension().appendingPathExtension("vtt")
    #expect(vttURL2.lastPathComponent == "My Audio.vtt")
}
```

#### UT-5.3: JSON File Naming Convention

```swift
@Test func timingDataFileURLFollowsNamingConvention() async throws {
    let audioURL1 = URL(fileURLWithPath: "/path/screenplay.m4a")
    let timingURL1 = TimingData.fileURL(for: audioURL1)
    #expect(timingURL1.lastPathComponent == "screenplay.m4a.timing.json")

    let audioURL2 = URL(fileURLWithPath: "/path/My Audio.m4a")
    let timingURL2 = TimingData.fileURL(for: audioURL2)
    #expect(timingURL2.lastPathComponent == "My Audio.m4a.timing.json")
}
```

---

## Integration Tests

### IT-1: Foreground Export Integration

**Test Suite**: `ForegroundExporterTimingDataTests`

#### IT-1.1: Direct Export with WebVTT

```swift
@Test func exportAudioDirectWithWebVTT() async throws {
    let modelContext = ModelContext(container)

    // Create test audio elements
    let audioElements = try await createTestAudioElements(count: 3)

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("test-\(UUID()).m4a")

    let exporter = ForegroundAudioExporter()
    let result = try await exporter.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: outputURL,
        timingDataFormat: .webvtt,  // WebVTT format
        progress: nil
    )

    // Verify audio file exists
    #expect(FileManager.default.fileExists(atPath: result.audioURL.path))

    // Verify WebVTT file exists
    #expect(result.webvttURL != nil)
    #expect(FileManager.default.fileExists(atPath: result.webvttURL!.path))

    // Verify WebVTT content
    let contents = try String(contentsOf: result.webvttURL!)
    #expect(contents.contains("WEBVTT"))
    #expect(contents.contains("00:00:00.000"))

    // Cleanup
    try? FileManager.default.removeItem(at: result.audioURL)
    try? FileManager.default.removeItem(at: result.webvttURL!)
}
```

#### IT-1.2: Direct Export with Both Formats

```swift
@Test func exportAudioDirectWithBothFormats() async throws {
    let modelContext = ModelContext(container)

    // Create test audio elements
    let audioElements = try await createTestAudioElements(count: 3)

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("test-\(UUID()).m4a")

    let exporter = ForegroundAudioExporter()
    let result = try await exporter.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: outputURL,
        timingDataFormat: .both,  // Both formats
        progress: nil
    )

    // Verify audio file exists
    #expect(FileManager.default.fileExists(atPath: result.audioURL.path))

    // Verify WebVTT file exists
    #expect(result.webvttURL != nil)
    #expect(FileManager.default.fileExists(atPath: result.webvttURL!.path))

    // Verify JSON file exists
    #expect(result.jsonURL != nil)
    #expect(FileManager.default.fileExists(atPath: result.jsonURL!.path))

    // Verify WebVTT content
    let vttContents = try String(contentsOf: result.webvttURL!)
    #expect(vttContents.contains("WEBVTT"))

    // Verify JSON content
    let jsonData = try Data(contentsOf: result.jsonURL!)
    let timingData = try JSONDecoder().decode(TimingData.self, from: jsonData)
    #expect(timingData.segments.count == 3)

    // Cleanup
    try? FileManager.default.removeItem(at: result.audioURL)
    try? FileManager.default.removeItem(at: result.webvttURL!)
    try? FileManager.default.removeItem(at: result.jsonURL!)
}
```

#### IT-1.3: Timeline-Based Export with WebVTT

```swift
@Test func exportAudioFromTimelineWithTimingData() async throws {
    let modelContext = ModelContext(container)

    // Create timeline with clips
    let timeline = Timeline(name: "Test", videoFormat: .hd1080p(frameRate: .fps24))
    let clip1 = TimelineClip(
        id: UUID(),
        assetId: "asset-1",
        offset: Timecode(seconds: 0),
        duration: Timecode(seconds: 5),
        lane: 0
    )
    timeline.appendClip(clip1)

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("test-\(UUID()).m4a")

    let exporter = ForegroundAudioExporter()
    let result = try await exporter.exportAudio(
        timeline: timeline,
        modelContext: modelContext,
        to: outputURL,
        timingDataFormat: .webvtt,
        progress: nil
    )

    // Verify WebVTT data
    #expect(result.webvttURL != nil)
    let contents = try String(contentsOf: result.webvttURL!)
    #expect(contents.contains("WEBVTT"))

    // Cleanup
    try? FileManager.default.removeItem(at: result.audioURL)
    try? FileManager.default.removeItem(at: result.webvttURL!)
}
```

#### IT-1.4: Disabled Timing Data

```swift
@Test func exportAudioWithoutTimingData() async throws {
    let modelContext = ModelContext(container)
    let audioElements = try await createTestAudioElements(count: 2)

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("test-\(UUID()).m4a")

    let exporter = ForegroundAudioExporter()
    let result = try await exporter.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: outputURL,
        timingDataFormat: .none,  // Disabled
        progress: nil
    )

    // Verify audio file exists
    #expect(FileManager.default.fileExists(atPath: result.audioURL.path))

    // Verify no timing data files
    #expect(result.webvttURL == nil)
    #expect(result.jsonURL == nil)

    // Cleanup
    try? FileManager.default.removeItem(at: result.audioURL)
}
```

---

### IT-2: Background Export Integration

**Test Suite**: `BackgroundExporterTimingDataTests`

#### IT-2.1: Background Export with WebVTT

```swift
@Test func backgroundExportWithWebVTT() async throws {
    let modelContext = ModelContext(container)

    // Create and persist timeline
    let timeline = Timeline(name: "Test", videoFormat: .hd1080p(frameRate: .fps24))
    let clip1 = TimelineClip(
        id: UUID(),
        assetId: "asset-1",
        offset: Timecode(seconds: 0),
        duration: Timecode(seconds: 5),
        lane: 0
    )
    timeline.appendClip(clip1)
    modelContext.insert(timeline)
    try modelContext.save()

    let timelineID = timeline.persistentModelID

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("test-\(UUID()).m4a")

    let exporter = BackgroundAudioExporter(modelContainer: container)
    let result = try await exporter.exportAudio(
        timelineID: timelineID,
        to: outputURL,
        timingDataFormat: .webvtt,
        progress: nil
    )

    // Verify WebVTT data
    #expect(result.webvttURL != nil)
    let contents = try String(contentsOf: result.webvttURL!)
    #expect(contents.contains("WEBVTT"))

    // Cleanup
    try? FileManager.default.removeItem(at: result.audioURL)
    try? FileManager.default.removeItem(at: result.webvttURL!)
}
```

---

## Validation Tests

### VT-1: Timing Accuracy

**Test Suite**: `TimingAccuracyTests`

#### VT-1.1: Verify Timing Precision

```swift
@Test func timingDataAccuracyWithinTolerance() async throws {
    let modelContext = ModelContext(container)

    // Create audio elements with known durations
    let audioElements = [
        createAudioElement(duration: 3.0),   // Exactly 3 seconds
        createAudioElement(duration: 5.5),   // Exactly 5.5 seconds
        createAudioElement(duration: 2.25)   // Exactly 2.25 seconds
    ]

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("test-\(UUID()).m4a")

    let exporter = ForegroundAudioExporter()
    let result = try await exporter.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: outputURL,
        includeTimingData: true,
        progress: nil
    )

    // Load timing data
    let data = try Data(contentsOf: result.timingDataURL!)
    let timingData = try JSONDecoder().decode(TimingData.self, from: data)

    let tolerance = 0.1  // ±100ms

    // Verify segment 1: 0.0 - 3.0
    #expect(abs(timingData.segments[0].startTime - 0.0) < tolerance)
    #expect(abs(timingData.segments[0].endTime - 3.0) < tolerance)

    // Verify segment 2: 3.0 - 8.5
    #expect(abs(timingData.segments[1].startTime - 3.0) < tolerance)
    #expect(abs(timingData.segments[1].endTime - 8.5) < tolerance)

    // Verify segment 3: 8.5 - 10.75
    #expect(abs(timingData.segments[2].startTime - 8.5) < tolerance)
    #expect(abs(timingData.segments[2].endTime - 10.75) < tolerance)

    // Cleanup
    try? FileManager.default.removeItem(at: result.audioURL)
    try? FileManager.default.removeItem(at: result.timingDataURL!)
}
```

#### VT-1.2: Verify Total Duration

```swift
@Test func timingDataTotalDurationMatchesAudio() async throws {
    let modelContext = ModelContext(container)

    let audioElements = try await createTestAudioElements(count: 5)

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("test-\(UUID()).m4a")

    let exporter = ForegroundAudioExporter()
    let result = try await exporter.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: outputURL,
        includeTimingData: true,
        progress: nil
    )

    // Load timing data
    let data = try Data(contentsOf: result.timingDataURL!)
    let timingData = try JSONDecoder().decode(TimingData.self, from: data)

    // Get actual audio duration
    let asset = AVURLAsset(url: result.audioURL)
    let actualDuration = try await asset.load(.duration).seconds

    let tolerance = 0.1  // ±100ms
    #expect(abs(timingData.duration - actualDuration) < tolerance)

    // Cleanup
    try? FileManager.default.removeItem(at: result.audioURL)
    try? FileManager.default.removeItem(at: result.timingDataURL!)
}
```

---

### VT-2: Edge Cases

**Test Suite**: `TimingDataEdgeCaseTests`

#### VT-2.1: Very Short Clips

```swift
@Test func timingDataForVeryShortClips() async throws {
    let modelContext = ModelContext(container)

    // Create clips with very short durations (< 1 second)
    let audioElements = [
        createAudioElement(duration: 0.1),
        createAudioElement(duration: 0.25),
        createAudioElement(duration: 0.5)
    ]

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("test-\(UUID()).m4a")

    let exporter = ForegroundAudioExporter()
    let result = try await exporter.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: outputURL,
        timingDataFormat: .json,
        progress: nil
    )

    // Verify timing data generated successfully
    #expect(result.jsonURL != nil)
    let data = try Data(contentsOf: result.jsonURL!)
    let timingData = try JSONDecoder().decode(TimingData.self, from: data)
    #expect(timingData.segments.count == 3)

    // Cleanup
    try? FileManager.default.removeItem(at: result.audioURL)
    try? FileManager.default.removeItem(at: result.timingDataURL!)
}
```

#### VT-2.2: Large Timeline (100+ Clips)

```swift
@Test func timingDataForLargeTimeline() async throws {
    let modelContext = ModelContext(container)

    // Create 100 clips
    let audioElements = try await createTestAudioElements(count: 100)

    let tempDir = FileManager.default.temporaryDirectory
    let outputURL = tempDir.appendingPathComponent("test-\(UUID()).m4a")

    let exporter = ForegroundAudioExporter()
    let result = try await exporter.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: outputURL,
        includeTimingData: true,
        progress: nil
    )

    // Verify timing data
    let data = try Data(contentsOf: result.timingDataURL!)
    let timingData = try JSONDecoder().decode(TimingData.self, from: data)
    #expect(timingData.segments.count == 100)

    // Verify file size is reasonable (< 100KB for 100 clips)
    let fileSize = try FileManager.default.attributesOfItem(atPath: result.timingDataURL!.path)[.size] as! Int
    #expect(fileSize < 100_000)

    // Cleanup
    try? FileManager.default.removeItem(at: result.audioURL)
    try? FileManager.default.removeItem(at: result.timingDataURL!)
}
```

---

## Performance Tests

### PT-1: Export Performance Impact

**Test Suite**: `TimingDataPerformanceTests`

#### PT-1.1: Measure Overhead

```swift
@Test func timingDataExportOverhead() async throws {
    let modelContext = ModelContext(container)
    let audioElements = try await createTestAudioElements(count: 50)

    let tempDir = FileManager.default.temporaryDirectory

    // Benchmark without timing data
    let startWithout = Date()
    let outputURL1 = tempDir.appendingPathComponent("test-without-\(UUID()).m4a")
    let exporter1 = ForegroundAudioExporter()
    _ = try await exporter1.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: outputURL1,
        includeTimingData: false,
        progress: nil
    )
    let durationWithout = Date().timeIntervalSince(startWithout)

    // Benchmark with timing data
    let startWith = Date()
    let outputURL2 = tempDir.appendingPathComponent("test-with-\(UUID()).m4a")
    let exporter2 = ForegroundAudioExporter()
    _ = try await exporter2.exportAudioDirect(
        audioElements: audioElements,
        modelContext: modelContext,
        to: outputURL2,
        includeTimingData: true,
        progress: nil
    )
    let durationWith = Date().timeIntervalSince(startWith)

    // Calculate overhead percentage
    let overhead = ((durationWith - durationWithout) / durationWithout) * 100

    print("Export without timing data: \(durationWithout)s")
    print("Export with timing data: \(durationWith)s")
    print("Overhead: \(overhead)%")

    // Verify overhead < 5%
    #expect(overhead < 5.0)

    // Cleanup
    try? FileManager.default.removeItem(at: outputURL1)
    try? FileManager.default.removeItem(at: outputURL2)
}
```

---

## Manual Validation Checklist

### MV-1: Web Player Integration

- [ ] Export audio with WebVTT from real Fountain script
- [ ] Load M4A with `<track>` element pointing to .vtt file
- [ ] Verify text highlights in sync with audio playback using TextTrack API
- [ ] Test scrubbing (jumping to different times)
- [ ] Verify overlapping dialogue (multi-lane) with voice tags
- [ ] Test on different browsers (Chrome, Safari, Firefox)
- [ ] Verify mobile responsiveness
- [ ] Test with native video controls (captions button)

### MV-2: Real-World Scenarios

- [ ] Export 10-minute screenplay with 50+ dialogue lines
- [ ] Verify timing accuracy at random points
- [ ] Test with clips of varying lengths (0.5s - 30s)
- [ ] Test with gaps between clips
- [ ] Test with overlapping dialogue (2+ characters speaking)
- [ ] Verify JSON file size is reasonable

### MV-3: Error Handling

- [ ] Verify export succeeds when timing data generation fails
- [ ] Test with corrupted audio assets
- [ ] Test with missing metadata
- [ ] Verify graceful degradation when timing data unavailable

### MV-4: WebVTT Compliance

- [ ] Validate WebVTT output against W3C validator
- [ ] Test with online WebVTT validators
- [ ] Verify voice tags render correctly in browsers
- [ ] Test with screen readers (accessibility)

---

## Test Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| WebVTTGenerator | 100% |
| TimingData models (JSON) | 100% |
| TimingDataGenerator (JSON) | 95% |
| ForegroundAudioExporter (timing) | 90% |
| BackgroundAudioExporter (timing) | 90% |
| File I/O | 85% |
| **Overall** | **90%+** |

---

## Continuous Integration

### CI Requirements

1. **All unit tests must pass** before merge
2. **Integration tests must pass** on macOS 26+ runner
3. **Performance tests must not regress** (< 5% overhead)
4. **JSON validation** against schema must pass

### CI Workflow Addition

```yaml
- name: Test WebVTT Generation
  run: swift test --filter WebVTT

- name: Test Timing Data Generation
  run: swift test --filter TimingData

- name: Validate WebVTT Output
  run: |
    swift test --filter WebVTTValidation

- name: Validate JSON Schema
  run: |
    swift test --filter TimingDataSchemaValidation

- name: Performance Benchmark
  run: swift test --filter TimingDataPerformance
```

---

## References

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [AVFoundation Testing Guide](https://developer.apple.com/documentation/avfoundation)
- [WebVTT Specification (W3C)](https://www.w3.org/TR/webvtt1/)
- [WebVTT Validator](https://quuz.org/webvtt/)
- [swift-webvtt-parser Tests](https://github.com/mihai8804858/swift-webvtt-parser/tree/main/Tests)
- [JSON Schema Validation](https://json-schema.org/)
