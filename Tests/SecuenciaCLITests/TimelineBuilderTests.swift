import Foundation
import SwiftCompartido
import SwiftData
import SwiftSecuencia
import Testing

@testable import SecuenciaCLICore

@Suite("TimelineBuilder Tests")
struct TimelineBuilderTests {

  // MARK: - Test Fixtures

  private func createTestDefinition() -> TimelineDefinition {
    TimelineDefinition(
      timeline: TimelineConfig(
        name: "Test Timeline",
        format: FormatConfig(
          width: 1920,
          height: 1080,
          frameRate: "24",
          colorSpace: "rec709"
        ),
        audio: AudioConfig(
          layout: "stereo",
          rate: "48000"
        )
      ),
      clips: [
        ClipDefinition(
          name: "Clip 1",
          file: "/tmp/clip1.mov",
          offset: "0s",
          duration: "10s",
          lane: 0,
          type: .video,
          markerType: nil,
          volume: nil,
          opacity: 1.0
        ),
        ClipDefinition(
          name: "Clip 2",
          file: "/tmp/clip2.mov",
          offset: "10s",
          duration: "5s",
          lane: 1,
          type: .video,
          markerType: nil,
          volume: -6.0,
          opacity: 0.8
        ),
      ]
    )
  }

  private func createTestAssetMap() -> [String: UUID] {
    [
      "/tmp/clip1.mov": UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      "/tmp/clip2.mov": UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
    ]
  }

  // MARK: - Timeline Creation Tests

  @Test("Create Timeline with correct name")
  @MainActor
  func testCreateTimeline() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.name == "Test Timeline")
  }

  @Test("Timeline has correct video format")
  @MainActor
  func testTimelineVideoFormat() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    guard let format = timeline.videoFormat else {
      Issue.record("Video format not set")
      return
    }

    #expect(format.width == 1920)
    #expect(format.height == 1080)
    #expect(format.frameRate == .fps24)
    #expect(format.colorSpace == .rec709)
  }

  @Test("Timeline has correct audio configuration")
  @MainActor
  func testTimelineAudioConfig() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.audioLayout == .stereo)
    #expect(timeline.audioRate == .rate48kHz)
  }

  // MARK: - Format Mapping Tests

  @Test("Parse frame rate 23.98")
  @MainActor
  func testFrameRate23_98() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = TimelineDefinition(
      timeline: TimelineConfig(
        name: "Test Timeline",
        format: FormatConfig(
          width: 1920,
          height: 1080,
          frameRate: "23.98",
          colorSpace: "rec709"
        ),
        audio: createTestDefinition().timeline.audio
      ),
      clips: createTestDefinition().clips
    )

    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.videoFormat?.frameRate == .fps23_98)
  }

  @Test("Parse frame rate 29.97")
  @MainActor
  func testFrameRate29_97() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = TimelineDefinition(
      timeline: TimelineConfig(
        name: "Test Timeline",
        format: FormatConfig(
          width: 1920,
          height: 1080,
          frameRate: "29.97",
          colorSpace: "rec709"
        ),
        audio: createTestDefinition().timeline.audio
      ),
      clips: createTestDefinition().clips
    )

    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.videoFormat?.frameRate == .fps29_97)
  }

  @Test("Parse audio layout mono")
  @MainActor
  func testAudioLayoutMono() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = TimelineDefinition(
      timeline: TimelineConfig(
        name: "Test Timeline",
        format: createTestDefinition().timeline.format,
        audio: AudioConfig(
          layout: "mono",
          rate: "48000"
        )
      ),
      clips: createTestDefinition().clips
    )

    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.audioLayout == .mono)
  }

  @Test("Parse audio rate 44.1kHz")
  @MainActor
  func testAudioRate44_1kHz() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = TimelineDefinition(
      timeline: TimelineConfig(
        name: "Test Timeline",
        format: createTestDefinition().timeline.format,
        audio: AudioConfig(
          layout: "stereo",
          rate: "44100"
        )
      ),
      clips: createTestDefinition().clips
    )

    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.audioRate == .rate44_1kHz)
  }

  // MARK: - FileAssetProvider Tests

  @Test("FileAssetProvider has one entry per unique file")
  @MainActor
  func testFileAssetProviderUniqueEntries() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (_, provider) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(provider.assetIDs.count == 2)
  }

  @Test("FileAssetProvider entries have correct UUIDs")
  @MainActor
  func testFileAssetProviderUUIDs() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (_, provider) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    let uuid1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let uuid2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    #expect(provider.assetIDs.contains(uuid1))
    #expect(provider.assetIDs.contains(uuid2))
  }

  // MARK: - Clip Processing Tests

  @Test("Timeline has correct number of clips")
  @MainActor
  func testTimelineClipCount() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.clips.count == 2)
  }

  @Test("Clips have correct offset and duration")
  @MainActor
  func testClipOffsetAndDuration() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    let clip1 = timeline.clips[0]
    #expect(clip1.offset == .zero)
    #expect(clip1.duration.seconds == 10.0)

    let clip2 = timeline.clips[1]
    #expect(clip2.offset.seconds == 10.0)
    #expect(clip2.duration.seconds == 5.0)
  }

  @Test("Clips have correct lane assignment")
  @MainActor
  func testClipLanes() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.clips[0].lane == 0)
    #expect(timeline.clips[1].lane == 1)
  }

  @Test("Clips have correct optional properties")
  @MainActor
  func testClipOptionalProperties() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    let clip1 = timeline.clips[0]
    #expect(clip1.volumeDb == nil)
    #expect(clip1.opacity == 1.0)

    let clip2 = timeline.clips[1]
    #expect(clip2.volumeDb == -6.0)
    #expect(clip2.opacity == 0.8)
  }

  // MARK: - Marker Processing Tests

  @Test("Process standard marker")
  @MainActor
  func testProcessStandardMarker() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    var clips = createTestDefinition().clips
    clips.append(
      ClipDefinition(
        name: "Review Point",
        file: nil,
        offset: "5s",
        duration: nil,
        lane: nil,
        type: .marker,
        markerType: "standard",
        volume: nil,
        opacity: nil
      )
    )

    let definition = TimelineDefinition(
      timeline: createTestDefinition().timeline,
      clips: clips
    )

    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.markers.count == 1)
    #expect(timeline.markers[0].value == "Review Point")
    #expect(timeline.markers[0].start.seconds == 5.0)
  }

  @Test("Process chapter marker")
  @MainActor
  func testProcessChapterMarker() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    var clips = createTestDefinition().clips
    clips.append(
      ClipDefinition(
        name: "Chapter 1",
        file: nil,
        offset: "0s",
        duration: nil,
        lane: nil,
        type: .marker,
        markerType: "chapter",
        volume: nil,
        opacity: nil
      )
    )

    let definition = TimelineDefinition(
      timeline: createTestDefinition().timeline,
      clips: clips
    )

    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.chapterMarkers.count == 1)
    #expect(timeline.chapterMarkers[0].value == "Chapter 1")
    #expect(timeline.chapterMarkers[0].start == .zero)
  }

  @Test("Process TODO marker")
  @MainActor
  func testProcessTodoMarker() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    var clips = createTestDefinition().clips
    clips.append(
      ClipDefinition(
        name: "Fix audio",
        file: nil,
        offset: "15s",
        duration: nil,
        lane: nil,
        type: .marker,
        markerType: "todo",
        volume: nil,
        opacity: nil
      )
    )

    let definition = TimelineDefinition(
      timeline: createTestDefinition().timeline,
      clips: clips
    )

    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, _) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    #expect(timeline.markers.count == 1)
    #expect(timeline.markers[0].value == "Fix audio")
    #expect(timeline.markers[0].start.seconds == 15.0)
    #expect(timeline.markers[0].completed == false)
  }

  // MARK: - Integration Tests

  @Test("Full build integration")
  @MainActor
  func testFullBuildIntegration() async throws {
    let container = try SwiftDataBootstrap.createInMemoryContainer()
    let context = SwiftDataBootstrap.createContext(from: container)

    let definition = createTestDefinition()
    let assetMap = createTestAssetMap()

    let builder = TimelineBuilder()
    let (timeline, provider) = try await builder.build(
      from: definition,
      assetMap: assetMap,
      in: context
    )

    // Verify timeline
    #expect(timeline.name == "Test Timeline")
    #expect(timeline.clips.count == 2)
    #expect(timeline.videoFormat?.width == 1920)
    #expect(timeline.audioLayout == .stereo)

    // Verify provider
    #expect(provider.assetIDs.count == 2)

    // Verify persistence
    try context.save()

    let descriptor = FetchDescriptor<Timeline>()
    let timelines = try context.fetch(descriptor)
    #expect(timelines.count == 1)
    #expect(timelines[0].name == "Test Timeline")
  }
}
