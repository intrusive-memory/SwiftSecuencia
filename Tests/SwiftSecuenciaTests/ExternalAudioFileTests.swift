//
//  ExternalAudioFileTests.swift
//  SwiftSecuenciaTests
//
//  Covers:
//   (a) TimelineClip.fromAudioFile(...) — builds a clip from a real audio file
//       with a non-zero duration and a valid, persisted assetStorageId.
//   (b) ForegroundAudioExporter per-clip gain — dB→linear mapping and the
//       AVMutableAudioMix it constructs reflecting volumeDb / isMuted.
//

import AVFoundation
import Foundation
import SwiftCompartido
import SwiftData
import Testing

@testable import SwiftSecuencia

// MARK: - Test Helpers

/// Writes a short mono sine-tone WAV to a temp file and returns its URL.
private func writeToneWav(
  seconds: Double = 0.5,
  sampleRate: Double = 44_100
) throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("wav")

  guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
    throw NSError(domain: "ExternalAudioFileTests", code: 1)
  }
  let file = try AVAudioFile(forWriting: url, settings: format.settings)

  let frameCount = AVAudioFrameCount(seconds * sampleRate)
  guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
    throw NSError(domain: "ExternalAudioFileTests", code: 2)
  }
  buffer.frameLength = frameCount
  if let channel = buffer.floatChannelData {
    for frame in 0..<Int(frameCount) {
      channel[0][frame] = Float(sin(2.0 * Double.pi * 440.0 * Double(frame) / sampleRate)) * 0.2
    }
  }
  try file.write(from: buffer)
  return url
}

// MARK: - (a) Factory Tests

@Test("fromAudioFile builds a clip with non-zero duration and a persisted asset")
@MainActor
func fromAudioFileBuildsClipWithDurationAndAsset() throws {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try ModelContainer(
    for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
  let context = ModelContext(container)

  let wavURL = try writeToneWav(seconds: 0.5)
  defer { try? FileManager.default.removeItem(at: wavURL) }

  let clip = try TimelineClip.fromAudioFile(
    url: wavURL,
    in: context,
    name: "Tone",
    offset: Timecode(seconds: 2.0),
    lane: -1
  )
  try context.save()

  // Duration derived from the file (~0.5s).
  #expect(clip.duration.seconds > 0.4)
  #expect(clip.duration.seconds < 0.6)
  #expect(clip.name == "Tone")
  #expect(clip.lane == -1)
  #expect(clip.offset.seconds == 2.0)

  // assetStorageId references a real, persisted TypedDataStorage record.
  let descriptor = FetchDescriptor<TypedDataStorage>()
  let records = try context.fetch(descriptor)
  #expect(records.count == 1)
  #expect(records.first?.id == clip.assetStorageId)
  #expect(records.first?.mimeType == "audio/wav")
  #expect((records.first?.durationSeconds ?? 0) > 0.4)
  #expect((records.first?.binaryValue?.isEmpty == false))

  // The clip's asset is fetchable and recognized as audio.
  let fetched = clip.fetchAsset(in: context)
  #expect(fetched != nil)
  #expect(clip.isAudioClip(in: context))
}

@Test("fromAudioFile rejects unsupported extensions")
@MainActor
func fromAudioFileRejectsUnsupportedFormat() throws {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try ModelContainer(
    for: Timeline.self, TimelineClip.self, TypedDataStorage.self, configurations: config)
  let context = ModelContext(container)

  let bogus = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("txt")
  try Data("not audio".utf8).write(to: bogus)
  defer { try? FileManager.default.removeItem(at: bogus) }

  #expect(throws: TimelineClip.AudioFileError.self) {
    _ = try TimelineClip.fromAudioFile(url: bogus, in: context)
  }
}

@Test("audioMimeType maps known audio extensions")
func audioMimeTypeMapping() {
  #expect(TimelineClip.audioMimeType(forPathExtension: "mp3") == "audio/mpeg")
  #expect(TimelineClip.audioMimeType(forPathExtension: "m4a") == "audio/mp4")
  #expect(TimelineClip.audioMimeType(forPathExtension: "wav") == "audio/wav")
  #expect(TimelineClip.audioMimeType(forPathExtension: "aiff") == "audio/aiff")
  #expect(TimelineClip.audioMimeType(forPathExtension: "xyz") == nil)
}

// MARK: - (b) Per-Clip Gain Tests

@Test("linearAmplitude maps dB / mute to linear volume")
func linearAmplitudeMapping() {
  // Unity: nil dB or 0 dB → 1.0
  #expect(ForegroundAudioExporter.linearAmplitude(volumeDb: nil, isMuted: false) == 1.0)
  #expect(
    abs(ForegroundAudioExporter.linearAmplitude(volumeDb: 0.0, isMuted: false) - 1.0) < 0.0001)

  // Muted → 0 regardless of dB.
  #expect(ForegroundAudioExporter.linearAmplitude(volumeDb: 0.0, isMuted: true) == 0.0)
  #expect(ForegroundAudioExporter.linearAmplitude(volumeDb: 6.0, isMuted: true) == 0.0)

  // -inf dB → 0 (silence).
  #expect(
    ForegroundAudioExporter.linearAmplitude(
      volumeDb: -Double.infinity, isMuted: false) == 0.0)

  // -6 dB → ~0.501; +6 dB → ~1.995.
  let minus6 = ForegroundAudioExporter.linearAmplitude(volumeDb: -6.0, isMuted: false)
  #expect(abs(minus6 - 0.5012) < 0.01)
  let plus6 = ForegroundAudioExporter.linearAmplitude(volumeDb: 6.0, isMuted: false)
  #expect(abs(plus6 - 1.9953) < 0.01)
}

@Test("makeAudioMix builds input parameters reflecting volumeDb / isMuted")
func makeAudioMixReflectsVolumes() throws {
  // Build a composition with three audio tracks.
  let composition = AVMutableComposition()
  guard
    let trackUnity = composition.addMutableTrack(
      withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
    let trackMuted = composition.addMutableTrack(
      withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
    let trackQuiet = composition.addMutableTrack(
      withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
  else {
    Issue.record("Failed to create composition tracks")
    return
  }

  // Mirror the export path: clip volumeDb / isMuted → linear amplitude.
  let unityVol = ForegroundAudioExporter.linearAmplitude(volumeDb: 0.0, isMuted: false)
  let mutedVol = ForegroundAudioExporter.linearAmplitude(volumeDb: nil, isMuted: true)
  let quietVol = ForegroundAudioExporter.linearAmplitude(volumeDb: -6.0, isMuted: false)

  let mix = ForegroundAudioExporter.makeAudioMix([
    (track: trackUnity, volume: unityVol),
    (track: trackMuted, volume: mutedVol),
    (track: trackQuiet, volume: quietVol),
  ])

  #expect(mix.inputParameters.count == 3)

  func readVolume(_ params: AVAudioMixInputParameters) -> Float {
    var start: Float = -1
    var end: Float = -1
    var range = CMTimeRange.zero
    _ = params.getVolumeRamp(
      for: .zero, startVolume: &start, endVolume: &end, timeRange: &range)
    return start
  }

  let volumes = mix.inputParameters.map(readVolume)
  #expect(abs(volumes[0] - 1.0) < 0.0001)  // unity
  #expect(volumes[1] == 0.0)  // muted
  #expect(abs(volumes[2] - 0.5012) < 0.01)  // -6 dB
}
