# SwiftSecuencia Testing Plan

## Overview

This document outlines the testing strategy for SwiftSecuencia, covering unit tests, integration tests, and validation against Final Cut Pro.

---

## Testing Levels

### Level 1: Unit Tests
Fast, isolated tests for individual components. Run on every PR.

### Level 2: Integration Tests
Tests that verify component interactions and SwiftCompartido integration.

### Level 3: Validation Tests
Tests that verify generated FCPXML against DTD and Final Cut Pro import.

### Level 4: Manual Tests
Final Cut Pro import verification (not automated).

---

## Unit Tests

### UT-1: Timecode

#### UT-1.1: Initialization
```swift
@Test func timecodeFromSeconds() {
    let tc = Timecode(seconds: 5.0)
    #expect(tc.seconds == 5.0)
}

@Test func timecodeFromRational() {
    let tc = Timecode(value: 1001, timescale: 24000)
    #expect(abs(tc.seconds - 0.04170833) < 0.0001)
}

@Test func timecodeZero() {
    #expect(Timecode.zero.seconds == 0)
    #expect(Timecode.zero.value == 0)
}
```

#### UT-1.2: FCPXML String Formatting
```swift
@Test func fcpxmlStringWholeSeconds() {
    let tc = Timecode(seconds: 5.0)
    #expect(tc.fcpxmlString == "5s")
}

@Test func fcpxmlStringRational() {
    let tc = Timecode(value: 1001, timescale: 30000)
    #expect(tc.fcpxmlString == "1001/30000s")
}

@Test func fcpxmlStringSimplified() {
    // 2/4 should simplify to 1/2
    let tc = Timecode(value: 2, timescale: 4)
    #expect(tc.fcpxmlString == "1/2s")
}
```

#### UT-1.3: Arithmetic
```swift
@Test func timecodeAddition() {
    let a = Timecode(seconds: 5.0)
    let b = Timecode(seconds: 3.0)
    let sum = a + b
    #expect(sum.seconds == 8.0)
}

@Test func timecodeSubtraction() {
    let a = Timecode(seconds: 5.0)
    let b = Timecode(seconds: 3.0)
    let diff = a - b
    #expect(diff.seconds == 2.0)
}
```

---

### UT-2: VideoFormat

#### UT-2.1: Presets
```swift
@Test func hd1080p2398Preset() {
    let format = VideoFormat.hd1080p2398
    #expect(format.width == 1920)
    #expect(format.height == 1080)
    #expect(format.frameRate == .fps2398)
}

@Test func frameDurationCalculation() {
    let format = VideoFormat.hd1080p24
    #expect(format.frameDuration == Timecode(value: 100, timescale: 2400))
}
```

#### UT-2.2: Custom Formats
```swift
@Test func customFormat() {
    let format = VideoFormat(
        width: 3840,
        height: 2160,
        frameRate: .fps30,
        colorSpace: .rec709
    )
    #expect(format.width == 3840)
    #expect(format.height == 2160)
}
```

---

### UT-3: Timeline

#### UT-3.1: Empty Timeline
```swift
@Test func emptyTimelineState() {
    let timeline = Timeline(format: .hd1080p24)
    #expect(timeline.clips.isEmpty)
    #expect(timeline.startTime == .zero)
    #expect(timeline.endTime == .zero)
    #expect(timeline.duration == .zero)
}
```

#### UT-3.2: Sequential Clip Placement
```swift
@Test func firstClipAtZero() async throws {
    var timeline = Timeline(format: .hd1080p24)
    let storage = try await createMockStorage(duration: 10.0)

    let placement = try timeline.append(storage)

    #expect(placement.offset == .zero)
    #expect(placement.duration.seconds == 10.0)
    #expect(timeline.endTime.seconds == 10.0)
}

@Test func secondClipAfterFirst() async throws {
    var timeline = Timeline(format: .hd1080p24)
    let storage1 = try await createMockStorage(duration: 10.0)
    let storage2 = try await createMockStorage(duration: 5.0)

    _ = try timeline.append(storage1)
    let placement2 = try timeline.append(storage2)

    #expect(placement2.offset.seconds == 10.0)
    #expect(timeline.endTime.seconds == 15.0)
}

@Test func multipleClipsSequential() async throws {
    var timeline = Timeline(format: .hd1080p24)

    var expectedOffset = 0.0
    for i in 1...5 {
        let duration = Double(i) * 2.0
        let storage = try await createMockStorage(duration: duration)
        let placement = try timeline.append(storage)

        #expect(placement.offset.seconds == expectedOffset)
        expectedOffset += duration
    }

    #expect(timeline.clips.count == 5)
    #expect(timeline.duration.seconds == 30.0) // 2+4+6+8+10
}
```

#### UT-3.3: Clip Placement Return Value
```swift
@Test func placementReturnsTimelineBounds() async throws {
    var timeline = Timeline(format: .hd1080p24)
    let storage = try await createMockStorage(duration: 10.0)

    let placement = try timeline.append(storage)

    #expect(placement.timelineStart == .zero)
    #expect(placement.timelineEnd.seconds == 10.0)
}
```

---

### UT-4: Asset Creation

#### UT-4.1: From Audio TypedDataStorage
```swift
@Test func assetFromAudioStorage() async throws {
    let storage = try await createMockAudioStorage(
        duration: 30.0,
        sampleRate: 48000,
        channels: 2,
        mimeType: "audio/mpeg"
    )

    let asset = try Asset(from: storage, id: "r1")

    #expect(asset.id == "r1")
    #expect(asset.hasAudio == true)
    #expect(asset.hasVideo == false)
    #expect(asset.duration?.seconds == 30.0)
    #expect(asset.audioRate == 48000)
    #expect(asset.audioChannels == 2)
}
```

#### UT-4.2: From Video TypedDataStorage
```swift
@Test func assetFromVideoStorage() async throws {
    let storage = try await createMockVideoStorage(
        duration: 60.0,
        mimeType: "video/mp4"
    )

    let asset = try Asset(from: storage, id: "r2")

    #expect(asset.hasVideo == true)
    #expect(asset.hasAudio == true)
    #expect(asset.duration?.seconds == 60.0)
}
```

#### UT-4.3: From Image TypedDataStorage
```swift
@Test func assetFromImageStorage() async throws {
    let storage = try await createMockImageStorage(
        width: 1920,
        height: 1080,
        mimeType: "image/png"
    )

    let asset = try Asset(from: storage, id: "r3")

    #expect(asset.hasVideo == true)
    #expect(asset.hasAudio == false)
    // Images have no inherent duration - should use default or require explicit
}
```

---

### UT-5: FCPXML Generation

#### UT-5.1: Document Structure
```swift
@Test func documentHasCorrectVersion() throws {
    let doc = FCPXMLDocument(version: "1.11")
    let xml = try doc.xmlString()

    #expect(xml.contains("version=\"1.11\""))
}

@Test func documentHasResources() throws {
    var doc = FCPXMLDocument()
    doc.resources.formats.append(.hd1080p24Format(id: "r1"))

    let xml = try doc.xmlString()

    #expect(xml.contains("<resources>"))
    #expect(xml.contains("<format"))
    #expect(xml.contains("id=\"r1\""))
}
```

#### UT-5.2: Asset Element
```swift
@Test func assetElementAttributes() throws {
    let asset = Asset(
        id: "r2",
        name: "TestClip",
        src: URL(string: "file:///Media/test.mp3")!,
        duration: Timecode(seconds: 30),
        hasVideo: false,
        hasAudio: true,
        audioChannels: 2,
        audioRate: 48000
    )

    let element = asset.xmlElement()

    #expect(element.name == "asset")
    #expect(element.attribute(forName: "id")?.stringValue == "r2")
    #expect(element.attribute(forName: "hasAudio")?.stringValue == "1")
    #expect(element.attribute(forName: "audioChannels")?.stringValue == "2")
}
```

#### UT-5.3: Asset-Clip Element
```swift
@Test func assetClipElementAttributes() throws {
    let clip = AssetClip(
        ref: "r2",
        offset: Timecode(seconds: 10),
        duration: Timecode(seconds: 30)
    )

    let element = clip.xmlElement()

    #expect(element.name == "asset-clip")
    #expect(element.attribute(forName: "ref")?.stringValue == "r2")
    #expect(element.attribute(forName: "offset")?.stringValue == "10s")
    #expect(element.attribute(forName: "duration")?.stringValue == "30s")
}
```

#### UT-5.4: Sequence and Spine
```swift
@Test func sequenceContainsSpine() throws {
    let sequence = Sequence(formatRef: "r1")
    let element = sequence.xmlElement()

    let spine = element.elements(forName: "spine").first
    #expect(spine != nil)
}

@Test func spineContainsClips() throws {
    var sequence = Sequence(formatRef: "r1")
    sequence.spine.append(AssetClip(ref: "r2", duration: Timecode(seconds: 10)))
    sequence.spine.append(AssetClip(ref: "r3", duration: Timecode(seconds: 20)))

    let element = sequence.xmlElement()
    let spine = element.elements(forName: "spine").first!
    let clips = spine.elements(forName: "asset-clip")

    #expect(clips.count == 2)
}
```

---

## Integration Tests

### IT-1: SwiftCompartido Integration

#### IT-1.1: TypedDataStorage to Timeline
```swift
@Test func typedDataStorageToTimeline() async throws {
    // Create real TypedDataStorage with audio data
    let context = ModelContext(/* test container */)
    let storage = TypedDataStorage(/* audio params */)
    storage.binaryValue = try loadTestAudioData()
    storage.durationSeconds = 30.0
    storage.sampleRate = 48000
    storage.channels = 2
    context.insert(storage)

    var timeline = Timeline(format: .hd1080p24)
    let placement = try timeline.append(storage)

    #expect(placement.duration.seconds == 30.0)
    #expect(timeline.clips.count == 1)
}
```

#### IT-1.2: Multiple TypedDataStorage Records
```swift
@Test func multipleStorageRecordsToTimeline() async throws {
    let records = try await createTestStorageRecords(count: 10)

    var timeline = Timeline(format: .hd1080p24)
    for record in records {
        _ = try timeline.append(record)
    }

    #expect(timeline.clips.count == 10)
}
```

---

### IT-2: Bundle Export

#### IT-2.1: Complete Bundle Structure
```swift
@Test func bundleContainsRequiredFiles() async throws {
    var timeline = Timeline(format: .hd1080p24)
    let storage = try await createMockStorage(duration: 10.0)
    _ = try timeline.append(storage)

    let bundleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Test.fcpbundle")

    let exporter = FCPBundleExporter(timeline: timeline)
    try await exporter.export(to: bundleURL, projectName: "Test")

    // Verify structure
    #expect(FileManager.default.fileExists(atPath: bundleURL.path))
    #expect(FileManager.default.fileExists(
        atPath: bundleURL.appendingPathComponent("Info.plist").path
    ))
    #expect(FileManager.default.fileExists(
        atPath: bundleURL.appendingPathComponent("Test.fcpxml").path
    ))
    #expect(FileManager.default.fileExists(
        atPath: bundleURL.appendingPathComponent("Media").path
    ))
}
```

#### IT-2.2: Media Files Copied
```swift
@Test func mediaFilesCopiedToBundle() async throws {
    var timeline = Timeline(format: .hd1080p24)
    let storage = try await createMockAudioStorage(duration: 10.0)
    _ = try timeline.append(storage)

    let bundleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Test.fcpbundle")

    let exporter = FCPBundleExporter(timeline: timeline)
    try await exporter.export(to: bundleURL, projectName: "Test")

    // Verify media copied
    let mediaDir = bundleURL.appendingPathComponent("Media")
    let mediaFiles = try FileManager.default.contentsOfDirectory(atPath: mediaDir.path)
    #expect(mediaFiles.count == 1)
}
```

#### IT-2.3: FCPXML References Media
```swift
@Test func fcpxmlReferencesMediaFiles() async throws {
    var timeline = Timeline(format: .hd1080p24)
    let storage = try await createMockAudioStorage(duration: 10.0)
    _ = try timeline.append(storage)

    let bundleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Test.fcpbundle")

    let exporter = FCPBundleExporter(timeline: timeline)
    try await exporter.export(to: bundleURL, projectName: "Test")

    // Read FCPXML and verify media references
    let fcpxmlURL = bundleURL.appendingPathComponent("Test.fcpxml")
    let xmlString = try String(contentsOf: fcpxmlURL)

    #expect(xmlString.contains("Media/"))
}
```

---

### IT-3: Large Timeline Performance

#### IT-3.1: 100 Clips Performance
```swift
@Test func hundredClipsPerformance() async throws {
    var timeline = Timeline(format: .hd1080p24)

    let startTime = Date()
    for _ in 0..<100 {
        let storage = try await createMockStorage(duration: 1.0)
        _ = try timeline.append(storage)
    }
    let buildTime = Date().timeIntervalSince(startTime)

    #expect(buildTime < 1.0) // Should complete in < 1 second
    #expect(timeline.clips.count == 100)
}
```

#### IT-3.2: Export Performance
```swift
@Test func exportPerformance() async throws {
    var timeline = Timeline(format: .hd1080p24)
    for _ in 0..<100 {
        let storage = try await createMockStorage(duration: 1.0)
        _ = try timeline.append(storage)
    }

    let bundleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PerfTest.fcpbundle")

    let exporter = FCPBundleExporter(timeline: timeline)

    let startTime = Date()
    try await exporter.export(to: bundleURL, projectName: "PerfTest")
    let exportTime = Date().timeIntervalSince(startTime)

    #expect(exportTime < 30.0) // Should complete in < 30 seconds
}
```

---

## Validation Tests

### VT-1: DTD Validation

#### VT-1.1: Valid Against FCPXML DTD
```swift
@Test func generatedXMLValidAgainstDTD() async throws {
    var timeline = Timeline(format: .hd1080p24)
    let storage = try await createMockStorage(duration: 10.0)
    _ = try timeline.append(storage)

    let document = try timeline.fcpxmlDocument()
    let xmlString = try document.xmlString()

    // Write to temp file
    let xmlURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test.fcpxml")
    try xmlString.write(to: xmlURL, atomically: true, encoding: .utf8)

    // Validate with xmllint
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xmllint")
    process.arguments = [
        "--dtdvalid", dtdPath,
        xmlURL.path
    ]

    let pipe = Pipe()
    process.standardError = pipe
    try process.run()
    process.waitUntilExit()

    #expect(process.terminationStatus == 0)
}
```

---

## Test Fixtures

### Mock TypedDataStorage Factory
```swift
@MainActor
func createMockStorage(duration: Double) async throws -> TypedDataStorage {
    let storage = TypedDataStorage()
    storage.id = UUID()
    storage.mimeType = "audio/mpeg"
    storage.durationSeconds = duration
    storage.sampleRate = 48000
    storage.channels = 2
    storage.binaryValue = Data(repeating: 0, count: 1024) // Minimal test data
    return storage
}

@MainActor
func createMockAudioStorage(
    duration: Double,
    sampleRate: Int = 48000,
    channels: Int = 2,
    mimeType: String = "audio/mpeg"
) async throws -> TypedDataStorage {
    let storage = TypedDataStorage()
    storage.id = UUID()
    storage.mimeType = mimeType
    storage.durationSeconds = duration
    storage.sampleRate = sampleRate
    storage.channels = channels
    storage.binaryValue = try loadTestAudioFile()
    return storage
}
```

### Test Audio File
```swift
func loadTestAudioFile() throws -> Data {
    // Load a small valid MP3 file for testing
    let url = Bundle.module.url(forResource: "test-audio", withExtension: "mp3")!
    return try Data(contentsOf: url)
}
```

---

## Manual Test Checklist

### MT-1: Final Cut Pro Import

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
- [ ] Verify: Timeline duration matches expected total

### MT-2: Various Media Types

- [ ] Test with MP3 audio
- [ ] Test with WAV audio
- [ ] Test with M4A audio
- [ ] Test with MP4 video
- [ ] Test with MOV video
- [ ] Test with PNG images
- [ ] Test with JPEG images

### MT-3: Edge Cases

- [ ] Empty timeline (should produce valid but empty project)
- [ ] Single clip
- [ ] Very long clip (> 1 hour)
- [ ] Many short clips (100+)
- [ ] Mixed media types on same timeline

---

## CI Integration

### Workflow Configuration

```yaml
# In .github/workflows/tests.yml
jobs:
  unit-tests:
    name: Unit Tests
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4
      - name: Run unit tests
        run: |
          swift test --filter "SwiftSecuenciaTests.UT"

  integration-tests:
    name: Integration Tests
    runs-on: macos-26
    needs: [unit-tests]
    steps:
      - uses: actions/checkout@v4
      - name: Run integration tests
        run: |
          swift test --filter "SwiftSecuenciaTests.IT"

  validation-tests:
    name: Validation Tests
    runs-on: macos-26
    needs: [integration-tests]
    steps:
      - uses: actions/checkout@v4
      - name: Run validation tests
        run: |
          swift test --filter "SwiftSecuenciaTests.VT"
```

---

## Test Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| Timecode | 95% |
| VideoFormat | 90% |
| Timeline | 90% |
| Asset | 85% |
| FCPXML Generation | 85% |
| Bundle Export | 80% |
| Overall | 85% |
