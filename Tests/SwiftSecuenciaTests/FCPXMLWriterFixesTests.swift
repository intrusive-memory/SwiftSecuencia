//
//  FCPXMLWriterFixesTests.swift
//  SwiftSecuenciaTests
//
//  4.0.0 writer fixes: deterministic resource IDs, lossless pass-through audio,
//  opt-in silence trimming that keeps audio in place, no placeholder spine
//  elements, adjust-volume / mute output, DTD-valid child order, round-up asset
//  durations, and percent-encoded absolute src URLs.
//

#if os(macOS)

  import Foundation
  import SwiftCompartido
  import SwiftData
  import Testing
  @testable import SwiftSecuencia

  @Suite("FCPXML writer fixes (4.0.0)")
  struct FCPXMLWriterFixesTests {

    // MARK: - Helpers

    private static func makeContainer() throws -> ModelContainer {
      let schema = Schema([Timeline.self, TimelineClip.self, TypedDataStorage.self])
      let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
      return try ModelContainer(for: schema, configurations: [config])
    }

    private static func tempDir(_ name: String = UUID().uuidString) throws -> URL {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("FCPXMLWriterFixesTests")
        .appendingPathComponent(name)
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
      return url
    }

    /// 16-bit mono PCM WAV. `silence` seconds of zeros, then `tone` seconds of a
    /// 440 Hz sine at half scale.
    private static func wav(silence: Double = 0, tone: Double, sampleRate: Int = 24_000) -> Data {
      let silentSamples = Int(silence * Double(sampleRate))
      let toneSamples = Int(tone * Double(sampleRate))
      var pcm = Data(capacity: (silentSamples + toneSamples) * 2)
      for _ in 0..<silentSamples { pcm.append(contentsOf: [0, 0]) }
      for i in 0..<toneSamples {
        let v = Int16(16_000 * sin(2 * Double.pi * 440 * Double(i) / Double(sampleRate)))
        withUnsafeBytes(of: v.littleEndian) { pcm.append(contentsOf: $0) }
      }
      var d = Data()
      func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
      func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
      d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + pcm.count))
      d.append(contentsOf: Array("WAVE".utf8))
      d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1)
      u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
      d.append(contentsOf: Array("data".utf8)); u32(UInt32(pcm.count))
      d.append(pcm)
      return d
    }

    /// Writes `data` to `dir/<id>.wav` and returns its provider entry.
    private static func entry(
      _ data: Data, id: UUID, in dir: URL, seconds: Double
    ) throws -> FileAssetEntry {
      let url = dir.appendingPathComponent("\(id.uuidString).wav")
      try data.write(to: url)
      return FileAssetEntry(
        fileURL: url, name: "clip-\(id.uuidString.prefix(4))", mimeType: "audio/wav",
        durationSeconds: seconds, hasVideo: false, hasAudio: true)
    }

    private static func timeline(_ clips: [TimelineClip], context: ModelContext) throws -> Timeline {
      let t = Timeline(
        name: "Fixes", videoFormat: .hd1080p(frameRate: .fps23_98), audioLayout: .mono,
        audioRate: .rate48kHz)
      t.clips.append(contentsOf: clips)
      context.insert(t)
      try context.save()
      return t
    }

    private static func clip(
      _ id: UUID, at offset: Double, seconds: Double, lane: Int = 0, name: String = "c"
    ) -> TimelineClip {
      TimelineClip(
        name: name, assetStorageId: id, offset: Timecode(seconds: offset),
        duration: Timecode(seconds: seconds), sourceStart: Timecode(seconds: 0), lane: lane)
    }

    @MainActor
    private static func exportBundle(
      _ timeline: Timeline, provider: AssetProvider, to dir: URL,
      mode: FCPXMLBundleExporter.AudioMediaMode = .passThrough, trims: Bool = false
    ) async throws -> (url: URL, xml: String) {
      var exporter = FCPXMLBundleExporter(
        version: .v1_14, includeMedia: true, audioMediaMode: mode, trimsSilence: trims)
      let url = try await exporter.exportBundle(
        timeline: timeline, assetProvider: provider, to: dir, bundleName: "out")
      let xml = try String(
        contentsOf: url.appendingPathComponent("Info.fcpxml"), encoding: .utf8)
      return (url, xml)
    }

    private static func dtdURL() throws -> URL {
      try #require(
        Bundle.module.url(
          forResource: "FCPXMLv1_14", withExtension: "dtd", subdirectory: "Fixtures"))
    }

    /// Frames (at 23.976) encoded in an FCPXML time attribute `name="…"` of the
    /// first element matching `elementPrefix`.
    private static func attr(_ name: String, of elementPrefix: String, in xml: String) -> String? {
      guard let start = xml.range(of: elementPrefix) else { return nil }
      let rest = xml[start.lowerBound...]
      let tagEnd = rest.firstIndex(of: ">") ?? rest.endIndex
      let tag = rest[..<tagEnd]
      guard let a = tag.range(of: " \(name)=\"") else { return nil }
      let v = tag[a.upperBound...]
      return String(v[..<(v.firstIndex(of: "\"") ?? v.endIndex)])
    }

    private static func frames(_ fcpxmlTime: String?) -> Int? {
      guard let t = fcpxmlTime else { return nil }
      if t == "0s" { return 0 }
      let parts = t.dropLast().split(separator: "/")
      guard parts.count == 2, let n = Int(parts[0]), let d = Int(parts[1]) else { return nil }
      // 1 frame = 1001/24000 s
      let num = n * 24_000
      let den = d * 1001
      return num % den == 0 ? num / den : nil
    }

    // MARK: - Tests

    @Test("Exporting the same timeline twice gives byte-identical FCPXML")
    @MainActor
    func deterministicOutput() async throws {
      let container = try Self.makeContainer()
      let dir = try Self.tempDir()
      let ids = (0..<4).map { _ in UUID() }
      var registry: [UUID: FileAssetEntry] = [:]
      for id in ids {
        registry[id] = try Self.entry(Self.wav(tone: 1), id: id, in: dir, seconds: 1)
      }
      let t = try Self.timeline(
        ids.enumerated().map { Self.clip($1, at: Double($0), seconds: 1) },
        context: container.mainContext)
      let provider = FileAssetProvider(registry: registry)

      let a = try await Self.exportBundle(t, provider: provider, to: try Self.tempDir())
      let b = try await Self.exportBundle(t, provider: provider, to: try Self.tempDir())
      #expect(a.xml == b.xml)
    }

    @Test("Pass-through writes the WAV bytes unchanged, no M4A")
    @MainActor
    func passThroughKeepsWAV() async throws {
      let container = try Self.makeContainer()
      let dir = try Self.tempDir()
      let id = UUID()
      let data = Self.wav(tone: 1.5)
      let provider = FileAssetProvider(registry: [
        id: try Self.entry(data, id: id, in: dir, seconds: 1.5)
      ])
      let t = try Self.timeline([Self.clip(id, at: 0, seconds: 1.5)], context: container.mainContext)

      let out = try await Self.exportBundle(t, provider: provider, to: try Self.tempDir())
      let media = out.url.appendingPathComponent("Media/\(id.uuidString).wav")
      #expect(try Data(contentsOf: media) == data)
      #expect(out.xml.contains("Media/\(id.uuidString).wav"))
      #expect(!out.xml.contains(".m4a"))
    }

    @Test("A fully silent clip stays a clip; no <comment> in the spine")
    @MainActor
    func silentClipIsKept() async throws {
      let container = try Self.makeContainer()
      let dir = try Self.tempDir()
      let id = UUID()
      let provider = FileAssetProvider(registry: [
        id: try Self.entry(Self.wav(silence: 1, tone: 0), id: id, in: dir, seconds: 1)
      ])
      let t = try Self.timeline([Self.clip(id, at: 0, seconds: 1)], context: container.mainContext)

      // Default transcode mode, default (off) trimming.
      let out = try await Self.exportBundle(
        t, provider: provider, to: try Self.tempDir(), mode: .transcodeToM4A)
      #expect(out.xml.contains("<asset-clip"))
      #expect(!out.xml.contains("<comment"))
    }

    @Test("Silence trimming moves the clip so the audible audio stays in place")
    @MainActor
    func trimKeepsAudioInPlace() async throws {
      let container = try Self.makeContainer()
      let dir = try Self.tempDir()
      let id = UUID()
      let provider = FileAssetProvider(registry: [
        id: try Self.entry(Self.wav(silence: 0.5, tone: 1), id: id, in: dir, seconds: 1.5)
      ])
      let offsetSeconds = 2.0
      let t = try Self.timeline(
        [Self.clip(id, at: offsetSeconds, seconds: 1.5)], context: container.mainContext)

      let out = try await Self.exportBundle(
        t, provider: provider, to: try Self.tempDir(), mode: .transcodeToM4A, trims: true)
      let offset = try #require(Self.frames(Self.attr("offset", of: "<asset-clip", in: out.xml)))
      let start = try #require(Self.frames(Self.attr("start", of: "<asset-clip", in: out.xml)))
      // Source time 0 sits at (offset - start); that must still be the clip's
      // timeline position (2.0 s = 47.95 frames → 48), within one frame of rounding.
      #expect(start > 0, "leading silence should be trimmed")
      #expect(abs((offset - start) - 48) <= 1)
    }

    @Test("Gain becomes adjust-volume; mute becomes enabled=0; 0 dB is omitted")
    @MainActor
    func gainAndMute() async throws {
      let container = try Self.makeContainer()
      let dir = try Self.tempDir()
      let loud = UUID(), quiet = UUID(), muted = UUID()
      var registry: [UUID: FileAssetEntry] = [:]
      for id in [loud, quiet, muted] {
        registry[id] = try Self.entry(Self.wav(tone: 1), id: id, in: dir, seconds: 1)
      }
      let a = Self.clip(loud, at: 0, seconds: 1, name: "unity")
      a.volumeDb = 0
      let b = Self.clip(quiet, at: 1, seconds: 1, name: "quiet")
      b.volumeDb = -6
      let c = Self.clip(muted, at: 2, seconds: 1, name: "muted")
      c.isMuted = true
      let t = try Self.timeline([a, b, c], context: container.mainContext)

      let out = try await Self.exportBundle(
        t, provider: FileAssetProvider(registry: registry), to: try Self.tempDir())
      // Exactly one adjust-volume: -6 dB on "quiet"; 0 dB on "unity" is omitted.
      #expect(out.xml.components(separatedBy: "<adjust-volume").count == 2)
      #expect(out.xml.contains(#"<adjust-volume amount="-6.00dB"/>"#))
      let unityTag = try #require(Self.clipTag(named: "unity", in: out.xml))
      let quietTag = try #require(Self.clipTag(named: "quiet", in: out.xml))
      let mutedTag = try #require(Self.clipTag(named: "muted", in: out.xml))
      #expect(!unityTag.contains("enabled="))
      #expect(!quietTag.contains("enabled="))
      #expect(mutedTag.contains(#"enabled="0""#))
    }

    /// The opening `<asset-clip …>` tag whose `name` attribute is `name`.
    private static func clipTag(named name: String, in xml: String) -> String? {
      guard let n = xml.range(of: "name=\"\(name)\"") else { return nil }
      guard let open = xml[..<n.lowerBound].range(of: "<asset-clip", options: .backwards)
      else { return nil }
      guard let close = xml[n.upperBound...].firstIndex(of: ">") else { return nil }
      return String(xml[open.lowerBound...close])
    }

    @Test("Bundle FCPXML with metadata, markers and gain passes the 1.14 DTD")
    @MainActor
    func dtdValidWithAnnotations() async throws {
      let container = try Self.makeContainer()
      let dir = try Self.tempDir()
      let id = UUID()
      let provider = FileAssetProvider(registry: [
        id: try Self.entry(Self.wav(tone: 2), id: id, in: dir, seconds: 2)
      ])
      let c = Self.clip(id, at: 0, seconds: 2)
      c.volumeDb = -3
      c.markers = [Marker(start: Timecode(seconds: 0.5), value: "beat")]
      c.metadata = Metadata(entries: ["com.apple.proapps.studio.scene": "1"])
      let t = try Self.timeline([c], context: container.mainContext)
      t.metadata = Metadata(entries: ["com.apple.proapps.studio.reel": "A"])

      let out = try await Self.exportBundle(t, provider: provider, to: try Self.tempDir())
      let result = try FCPXMLDTDValidator().validate(
        xmlContent: out.xml, version: .v1_14, dtdURL: try Self.dtdURL())
      #expect(result.isValid, "\(result.errors)")
      #expect(out.xml.contains(#"audioRate="48k""#))
      #expect(out.xml.contains(#"audioLayout="mono""#))
    }

    @Test("Asset duration rounds up to whole frames, never truncating")
    func assetDurationRoundsUp() {
      // 1.02 s = 24.455 frames at 23.976: nearest would be 24 (cuts 11 ms), up is 25.
      let up = Timecode.frameAlignedUp(seconds: 1.02, frameRate: .fps23_98)
      #expect(up.fcpxmlString == "25025/24000s")
      // An exact frame count is not bumped by floating-point noise.
      let exact = Timecode.frameAlignedUp(seconds: 24.0 * 1001.0 / 24_000.0, frameRate: .fps23_98)
      #expect(exact.fcpxmlString == "24024/24000s")
    }

    @Test("Absolute src is a percent-encoded file URL (path with a space)")
    @MainActor
    func absoluteSrcIsEncoded() throws {
      let container = try Self.makeContainer()
      let dir = try Self.tempDir("with space \(UUID().uuidString)")
      let id = UUID()
      let provider = FileAssetProvider(registry: [
        id: try Self.entry(Self.wav(tone: 1), id: id, in: dir, seconds: 1)
      ])
      let t = try Self.timeline([Self.clip(id, at: 0, seconds: 1)], context: container.mainContext)

      var exporter = FCPXMLExporter(version: .v1_14)
      let xml = try exporter.export(timeline: t, assetProvider: provider)
      let src = try #require(Self.attr("src", of: "<media-rep", in: xml))
      #expect(src.hasPrefix("file:///"))
      #expect(src.contains("with%20space"))
      #expect(!src.contains(" "))
      #expect(URL(string: src)?.path == dir.appendingPathComponent("\(id.uuidString).wav").path)
    }
  }

#endif
