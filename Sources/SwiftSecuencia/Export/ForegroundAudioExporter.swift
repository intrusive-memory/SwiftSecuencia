//
//  ForegroundAudioExporter.swift
//  SwiftSecuencia
//
//  Foreground audio export that takes over the main thread for maximum performance.
//  Use this when speed matters more than UI responsiveness.
//

import AVFoundation
import Foundation
import SwiftCompartido
import SwiftData

/// Foreground audio exporter that runs on the main thread with maximum priority.
///
/// This exporter sacrifices UI responsiveness for maximum export speed by:
/// - Running all operations on the main thread (no actor context switching)
/// - Using direct ModelContext access (no cross-actor communication)
/// - Parallel file writes with high priority
/// - No progress update overhead
///
/// **When to use:**
/// - Export speed is critical
/// - UI blocking is acceptable
/// - User is actively waiting for export to complete
/// - Small to medium timelines (< 100 clips)
///
/// **When NOT to use:**
/// - User needs to interact with UI during export
/// - Very large timelines (high memory usage)
/// - Background processing is preferred
///
/// ## Usage
///
/// ```swift
/// @MainActor
/// func exportForeground() async {
///     let exporter = ForegroundAudioExporter()
///     let outputURL = try await exporter.exportAudio(
///         timeline: timeline,
///         modelContext: modelContext,
///         to: destinationURL,
///         progress: progress
///     )
/// }
/// ```
@MainActor
public struct ForegroundAudioExporter {

  public let telemetry: SecuenciaTelemetryReporter?

  /// Directory the per-clip temp WAVs are staged in while building the
  /// `AVMutableComposition`. When `nil`, falls back to the system temp dir
  /// (`FileManager.default.temporaryDirectory`) — the historical behaviour.
  ///
  /// Callers running under a caller-owned cache/temp tree (e.g. a CLI's
  /// `--cache-dir`, or a hermetic CI sandbox) pass that directory here so the
  /// exporter never spills audio into the shared system temp dir. The directory
  /// is created if absent and its writability is checked eagerly, so a bad path
  /// or a permissions problem throws `AudioExportError.workDirectoryNotWritable`
  /// up front rather than failing deep inside the parallel write phase.
  public let workDirectory: URL?

  public init(
    telemetry: SecuenciaTelemetryReporter? = nil,
    workDirectory: URL? = nil
  ) {
    self.telemetry = telemetry
    self.workDirectory = workDirectory
  }

  /// Resolve the directory temp clips are staged in, creating it if needed and
  /// verifying it is writable. Throws `AudioExportError.workDirectoryNotWritable`
  /// when an explicit `workDirectory` cannot be created or written to.
  ///
  /// When `workDirectory` is `nil` the system temp dir is returned unchecked —
  /// it is assumed writable, matching the pre-`workDirectory` behaviour.
  private func resolvedWorkDirectory() throws -> URL {
    guard let dir = workDirectory else {
      return FileManager.default.temporaryDirectory
    }
    let fm = FileManager.default
    var isDir: ObjCBool = false
    if fm.fileExists(atPath: dir.path, isDirectory: &isDir) {
      guard isDir.boolValue, fm.isWritableFile(atPath: dir.path) else {
        throw AudioExportError.workDirectoryNotWritable(path: dir.path)
      }
      return dir
    }
    do {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      throw AudioExportError.workDirectoryNotWritable(path: dir.path)
    }
    guard fm.isWritableFile(atPath: dir.path) else {
      throw AudioExportError.workDirectoryNotWritable(path: dir.path)
    }
    return dir
  }

  /// Exports audio elements directly to M4A format (fast path - skips Timeline creation).
  ///
  /// This method provides the fastest possible export by skipping Timeline creation
  /// and SwiftData persistence. Use this when you already have audio elements and
  /// just need to export them to M4A as quickly as possible.
  ///
  /// **Performance:** ~15-20% faster than Timeline-based export due to:
  /// - No Timeline object creation
  /// - No SwiftData persistence (skips disk I/O)
  /// - No redundant asset fetches
  /// - Direct path from audio elements to M4A
  ///
  /// - Parameters:
  ///   - audioElements: Array of TypedDataStorage with audio content
  ///   - modelContext: SwiftData ModelContext for asset access
  ///   - outputURL: Destination file URL for the M4A file
  ///   - timingDataFormat: Format for timing data export (default: .none)
  ///   - masterFadeOut: Duration in seconds for a master fade-out applied to the final N seconds of the entire mix (default: 0, no fade)
  ///   - progress: Optional Progress object for tracking
  /// - Returns: URL of the created M4A file
  /// - Throws: AudioExportError if export fails
  public func exportAudioDirect(
    audioElements: [TypedDataStorage],
    modelContext: ModelContext,
    to outputURL: URL,
    timingDataFormat: TimingDataFormat = .none,
    masterFadeOut: TimeInterval = 0,
    progress: Progress? = nil
  ) async throws -> URL {
    // Set up progress tracking
    let exportProgress = progress ?? Progress(totalUnitCount: 100)
    exportProgress.localizedDescription = "Exporting audio (foreground)"

    // Validate we have audio elements
    guard !audioElements.isEmpty else {
      throw AudioExportError.emptyTimeline
    }

    // Filter for audio only (fast - just MIME type check)
    exportProgress.localizedAdditionalDescription = "Validating audio elements"
    let audioFiles = audioElements.filter { $0.mimeType.hasPrefix("audio/") }

    guard !audioFiles.isEmpty else {
      throw AudioExportError.emptyTimeline
    }

    exportProgress.completedUnitCount = 5

    // Check for cancellation
    if exportProgress.isCancelled {
      throw AudioExportError.cancelled
    }

    // Build composition directly from audio elements (no Timeline)
    exportProgress.localizedAdditionalDescription = "Building composition"
    let (composition, tempFiles, audioMix) = try await buildCompositionDirect(
      audioElements: audioFiles,
      masterFadeOut: masterFadeOut,
      progress: exportProgress
    )
    exportProgress.completedUnitCount = 40

    // Check for cancellation
    if exportProgress.isCancelled {
      cleanupTempFiles(tempFiles)
      throw AudioExportError.cancelled
    }

    // Export composition (60%)
    exportProgress.localizedAdditionalDescription = "Exporting audio"
    do {
      try await exportComposition(
        composition,
        to: outputURL,
        audioMix: audioMix,
        progress: exportProgress
      )

      // Clean up temp files after successful export
      cleanupTempFiles(tempFiles)

      exportProgress.completedUnitCount = 90

      // Generate timing data if requested
      if timingDataFormat != .none {
        exportProgress.localizedAdditionalDescription = "Generating timing data"
        do {
          try await generateTimingData(
            audioElements: audioFiles,
            audioFileName: outputURL.lastPathComponent,
            outputDirectory: outputURL.deletingLastPathComponent(),
            format: timingDataFormat,
            modelContext: modelContext
          )
        } catch {
          // Log warning but continue - timing data generation should not fail the export
          print("Warning: Failed to generate timing data: \(error)")
        }
      }

      exportProgress.completedUnitCount = 100
      exportProgress.localizedAdditionalDescription = "Export complete"

      return outputURL
    } catch {
      // Clean up temp files on error
      cleanupTempFiles(tempFiles)
      throw error
    }
  }

  /// Exports a timeline's audio to M4A format on the main thread.
  ///
  /// This method blocks the main thread for maximum performance:
  /// 1. Fetches all clips and assets from SwiftData (main thread)
  /// 2. Loads all audio data into memory (main thread)
  /// 3. Writes all files to disk in parallel (high priority tasks)
  /// 4. Builds AVMutableComposition (main thread)
  /// 5. Exports to M4A (Apple encoder)
  ///
  /// **Warning:** This will freeze the UI during export. Use only when
  /// maximum speed is more important than UI responsiveness.
  ///
  /// - Parameters:
  ///   - timeline: The Timeline to export (main thread)
  ///   - modelContext: SwiftData ModelContext (main thread)
  ///   - outputURL: Destination file URL for the M4A file
  ///   - timingDataFormat: Format for timing data export (default: .none)
  ///   - masterFadeOut: Duration in seconds for a master fade-out applied to the final N seconds of the entire mix (default: 0, no fade)
  ///   - progress: Optional Progress object for tracking
  /// - Returns: URL of the created M4A file
  /// - Throws: AudioExportError if export fails
  public func exportAudio(
    timeline: Timeline,
    modelContext: ModelContext,
    to outputURL: URL,
    timingDataFormat: TimingDataFormat = .none,
    masterFadeOut: TimeInterval = 0,
    progress: Progress? = nil
  ) async throws -> URL {
    // Capture export start event
    let modelContextObjectCount = getModelContextObjectCount(modelContext)
    await telemetry?.capture(.exportStart(
      timelineClipCount: timeline.clips.count,
      modelContextObjects: modelContextObjectCount
    ))

    // Set up progress tracking
    let exportProgress = progress ?? Progress(totalUnitCount: 100)
    exportProgress.localizedDescription = "Exporting audio (foreground)"

    // Step 1: Filter audio clips (5%)
    exportProgress.localizedAdditionalDescription = "Loading timeline"
    let audioClips = try filterAudioClips(timeline.clips, modelContext: modelContext)

    guard !audioClips.isEmpty else {
      throw AudioExportError.emptyTimeline
    }

    exportProgress.completedUnitCount = 5

    // Check for cancellation
    if exportProgress.isCancelled {
      throw AudioExportError.cancelled
    }

    // Step 2: Build composition (35%)
    exportProgress.localizedAdditionalDescription = "Building composition"
    let built = try await buildComposition(
      from: timeline,
      audioClips: audioClips,
      modelContext: modelContext,
      masterFadeOut: masterFadeOut,
      progress: exportProgress
    )
    let composition = built.composition
    let tempFiles = built.tempFiles
    let audioMix = built.audioMix
    exportProgress.completedUnitCount = 40

    // Check for cancellation
    if exportProgress.isCancelled {
      cleanupTempFiles(tempFiles)
      throw AudioExportError.cancelled
    }

    // Step 3: Export composition (60%)
    exportProgress.localizedAdditionalDescription = "Exporting audio"
    do {
      try await exportComposition(
        composition,
        to: outputURL,
        audioMix: audioMix,
        progress: exportProgress
      )

      // Clean up temp files after successful export
      cleanupTempFiles(tempFiles)

      exportProgress.completedUnitCount = 90

      // Generate timing data if requested
      if timingDataFormat != .none {
        exportProgress.localizedAdditionalDescription = "Generating timing data"
        do {
          try await generateTimingData(
            timeline: timeline,
            audioFileName: outputURL.lastPathComponent,
            outputDirectory: outputURL.deletingLastPathComponent(),
            format: timingDataFormat,
            modelContext: modelContext
          )
        } catch {
          // Log warning but continue - timing data generation should not fail the export
          print("Warning: Failed to generate timing data: \(error)")
        }
      }

      exportProgress.completedUnitCount = 100
      exportProgress.localizedAdditionalDescription = "Export complete"

      // Capture export complete event
      let outputSizeMB = getFileSize(outputURL)
      let modelContextObjectCount = getModelContextObjectCount(modelContext)
      await telemetry?.capture(.exportComplete(
        outputSizeMB: outputSizeMB,
        modelContextObjects: modelContextObjectCount,
        pendingChanges: modelContext.hasChanges
      ))

      return outputURL
    } catch {
      // Clean up temp files on error
      cleanupTempFiles(tempFiles)
      throw error
    }
  }

  // MARK: - Audio Clip Filtering

  /// Filters timeline clips to include only audio clips.
  private func filterAudioClips(
    _ clips: [TimelineClip],
    modelContext: ModelContext
  ) throws -> [TimelineClip] {
    var audioClips: [TimelineClip] = []

    for clip in clips {
      guard let asset = clip.fetchAsset(in: modelContext) else {
        throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
      }

      if asset.mimeType.hasPrefix("audio/") {
        audioClips.append(clip)
      }
    }

    return audioClips
  }

  // MARK: - Composition Building

  /// Builds an AVMutableComposition directly from audio elements (fast path).
  ///
  /// This is the optimized path for exportAudioDirect() that skips Timeline creation.
  /// Uses optimized I/O with FileHandle and pre-allocation.
  ///
  /// - Parameters:
  ///   - audioElements: Array of TypedDataStorage audio elements
  ///   - masterFadeOut: Duration in seconds for a master fade-out applied to the final N seconds of the entire mix
  ///   - progress: Progress object for tracking
  /// - Returns: Tuple of (composition, tempFiles, audioMix)
  /// - Throws: AudioExportError on failure
  private func buildCompositionDirect(
    audioElements: [TypedDataStorage],
    masterFadeOut: TimeInterval,
    progress: Progress
  ) async throws -> (composition: AVMutableComposition, tempFiles: [URL], audioMix: AVMutableAudioMix?) {
    // Phase 1: Load all audio data into memory (15%)
    progress.localizedAdditionalDescription = "Loading audio files"

    var audioData: [(data: Data, fileExtension: String)] = []
    audioData.reserveCapacity(audioElements.count)

    for (index, element) in audioElements.enumerated() {
      guard let data = element.binaryValue else {
        throw AudioExportError.invalidAudioData(assetId: element.id, reason: "No binary data")
      }

      let ext = fileExtension(for: element.mimeType)
      audioData.append((data: data, fileExtension: ext))

      // Update progress
      let progressUnits = Int64(5 + Int((Double(index + 1) / Double(audioElements.count)) * 15))
      progress.completedUnitCount = progressUnits
      progress.localizedAdditionalDescription =
        "Loaded \(index + 1) of \(audioElements.count) audio files"
    }

    progress.completedUnitCount = 20

    // Check for cancellation
    if progress.isCancelled {
      throw AudioExportError.cancelled
    }

    // Phase 2: Write all files to disk in parallel with optimized I/O (10%)
    progress.localizedAdditionalDescription = "Writing audio files"
    let tempFiles = try await writeAudioFilesToDiskOptimized(
      audioData: audioData,
      progress: progress
    )
    progress.completedUnitCount = 30

    // Check for cancellation
    if progress.isCancelled {
      cleanupTempFiles(tempFiles)
      throw AudioExportError.cancelled
    }

    // Phase 3: Build composition from files (10%)
    progress.localizedAdditionalDescription = "Building audio composition"
    let (composition, audioMix) = try await buildCompositionFromFilesOptimized(
      audioElements: audioElements,
      tempFiles: tempFiles,
      masterFadeOut: masterFadeOut,
      progress: progress
    )

    return (composition, tempFiles, audioMix)
  }

  /// Result of building an audio composition: the composition itself, the
  /// temporary files backing its tracks, and the audio mix carrying per-clip gain.
  private struct BuiltComposition {
    let composition: AVMutableComposition
    let tempFiles: [URL]
    let audioMix: AVMutableAudioMix
  }

  /// Builds an AVMutableComposition from timeline clips.
  ///
  /// This uses a two-phase approach optimized for main thread:
  /// 1. Load all audio data into memory (main thread - 15% progress)
  /// 2. Write all files to disk in parallel (high priority - 10% progress)
  /// 3. Build composition from files (main thread - 10% progress)
  private func buildComposition(
    from timeline: Timeline,
    audioClips: [TimelineClip],
    modelContext: ModelContext,
    masterFadeOut: TimeInterval,
    progress: Progress
  ) async throws -> BuiltComposition {
    let sortedClips = audioClips.sorted { $0.offset < $1.offset }

    // Phase 1: Load all audio data into memory (15%)
    progress.localizedAdditionalDescription = "Loading audio files"
    let audioData = try loadAllAudioData(
      clips: sortedClips,
      modelContext: modelContext,
      progress: progress
    )
    progress.completedUnitCount = 20

    // Check for cancellation
    if progress.isCancelled {
      throw AudioExportError.cancelled
    }

    // Phase 2: Write all files to disk in parallel (10%)
    progress.localizedAdditionalDescription = "Writing audio files"
    let tempFiles = try await writeAudioFilesToDisk(
      audioData: audioData,
      progress: progress
    )
    progress.completedUnitCount = 30

    // Check for cancellation
    if progress.isCancelled {
      cleanupTempFiles(tempFiles)
      throw AudioExportError.cancelled
    }

    // Phase 3: Build composition (10%)
    progress.localizedAdditionalDescription = "Building audio composition"
    let (composition, audioMix) = try await buildCompositionFromFiles(
      clips: sortedClips,
      tempFiles: tempFiles,
      masterFadeOut: masterFadeOut,
      progress: progress
    )

    return BuiltComposition(composition: composition, tempFiles: tempFiles, audioMix: audioMix)
  }

  /// Phase 1: Load all audio data into memory.
  private func loadAllAudioData(
    clips: [TimelineClip],
    modelContext: ModelContext,
    progress: Progress
  ) throws -> [(data: Data, fileExtension: String)] {
    var audioData: [(data: Data, fileExtension: String)] = []
    audioData.reserveCapacity(clips.count)

    for (index, clip) in clips.enumerated() {
      guard let asset = clip.fetchAsset(in: modelContext) else {
        throw AudioExportError.missingAsset(assetId: clip.assetStorageId)
      }

      guard let data = asset.binaryValue else {
        throw AudioExportError.invalidAudioData(assetId: asset.id, reason: "No binary data")
      }

      let ext = fileExtension(for: asset.mimeType)
      audioData.append((data: data, fileExtension: ext))

      // Update progress
      let progressUnits = Int64(5 + Int((Double(index + 1) / Double(clips.count)) * 15))
      progress.completedUnitCount = progressUnits
      progress.localizedAdditionalDescription = "Loaded \(index + 1) of \(clips.count) audio files"
    }

    return audioData
  }

  /// Phase 2: Write all audio files to disk in parallel (OPTIMIZED with FileHandle).
  private func writeAudioFilesToDiskOptimized(
    audioData: [(data: Data, fileExtension: String)],
    progress: Progress
  ) async throws -> [URL] {
    // Resolve (and validate) the staging directory once, up front: a bad
    // `workDirectory` / permissions problem throws here before we spin up the
    // parallel writers, so the failure is loud and immediate rather than a
    // partial spill. `nil` workDirectory resolves to the system temp dir.
    let stagingDirectory = try resolvedWorkDirectory()

    // Write files in parallel using TaskGroup with high priority + FileHandle optimization
    return try await withThrowingTaskGroup(of: (Int, URL).self) { group in
      var tempURLs: [Int: URL] = [:]

      for (index, audio) in audioData.enumerated() {
        // Each write task runs with high priority
        group.addTask(priority: .high) {
          let tempURL = stagingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(audio.fileExtension)

          // OPTIMIZATION: Use FileHandle for faster, more direct writes
          FileManager.default.createFile(atPath: tempURL.path, contents: nil, attributes: nil)

          let fileHandle = try FileHandle(forWritingTo: tempURL)
          defer {
            try? fileHandle.close()
          }

          // OPTIMIZATION: Pre-allocate file space on macOS (reduces fragmentation, faster writes)
          #if os(macOS)
            let fd = fileHandle.fileDescriptor
            let fileSize = Int64(audio.data.count)
            ftruncate(fd, fileSize)
          #endif

          // Write data in one operation
          try fileHandle.write(contentsOf: audio.data)

          return (index, tempURL)
        }
      }

      // Collect results maintaining order
      for try await (index, url) in group {
        tempURLs[index] = url

        let completedCount = tempURLs.count
        let progressUnits = Int64(20 + Int((Double(completedCount) / Double(audioData.count)) * 10))
        progress.completedUnitCount = progressUnits
        progress.localizedAdditionalDescription =
          "Wrote \(completedCount) of \(audioData.count) files"
      }

      // Return URLs in original order
      return audioData.indices.compactMap { tempURLs[$0] }
    }
  }

  /// Phase 2: Write all audio files to disk in parallel.
  private func writeAudioFilesToDisk(
    audioData: [(data: Data, fileExtension: String)],
    progress: Progress
  ) async throws -> [URL] {
    // Use optimized version
    return try await writeAudioFilesToDiskOptimized(audioData: audioData, progress: progress)
  }

  /// Phase 3: Build AVMutableComposition from audio elements (OPTIMIZED - direct sequencing).
  private func buildCompositionFromFilesOptimized(
    audioElements: [TypedDataStorage],
    tempFiles: [URL],
    masterFadeOut: TimeInterval,
    progress: Progress
  ) async throws -> (composition: AVMutableComposition, audioMix: AVMutableAudioMix?) {
    let composition = AVMutableComposition()
    let clipProgressIncrement = 10.0 / Double(audioElements.count)
    var currentOffset = CMTime.zero

    // Collect tracks for audio mix (unity gain for direct export path)
    var mixEntries: [(track: AVAssetTrack, volume: Float)] = []

    for (index, element) in audioElements.enumerated() {
      // Check for cancellation
      if progress.isCancelled {
        throw AudioExportError.cancelled
      }

      progress.localizedAdditionalDescription = "Adding clip \(index + 1) of \(audioElements.count)"

      // Create a new track for each clip
      guard
        let compositionTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
      else {
        throw AudioExportError.exportFailed(reason: "Failed to create composition track")
      }

      let tempURL = tempFiles[index]

      // Create AVAsset from the temp file
      let avAsset = AVURLAsset(url: tempURL)

      // Get the audio track
      guard let sourceTrack = try await avAsset.loadTracks(withMediaType: .audio).first else {
        throw AudioExportError.invalidAudioData(assetId: element.id, reason: "No audio track found")
      }

      // OPTIMIZATION: Use full audio file duration (no clip trimming needed)
      // Get duration from metadata if available, otherwise use audio track duration
      let duration: CMTime
      if let durationSeconds = element.durationSeconds {
        duration = CMTime(seconds: durationSeconds, preferredTimescale: 600)
      } else {
        duration = try await avAsset.load(.duration)
      }

      let timeRange = CMTimeRange(start: .zero, duration: duration)

      // Insert at current offset and advance
      try compositionTrack.insertTimeRange(timeRange, of: sourceTrack, at: currentOffset)
      currentOffset = CMTimeAdd(currentOffset, duration)

      // Track for audio mix (unity gain = 1.0)
      mixEntries.append((track: compositionTrack, volume: 1.0))

      // Update progress
      let progressUnits = Int64(30 + Int((Double(index + 1) * clipProgressIncrement)))
      progress.completedUnitCount = progressUnits
    }

    // Build audio mix with optional master fade-out
    let audioMix = Self.makeAudioMix(mixEntries, compositionDuration: composition.duration, masterFadeOut: masterFadeOut)
    return (composition, audioMix)
  }

  /// Phase 3: Build AVMutableComposition from pre-written temp files.
  private func buildCompositionFromFiles(
    clips: [TimelineClip],
    tempFiles: [URL],
    masterFadeOut: TimeInterval,
    progress: Progress
  ) async throws -> (composition: AVMutableComposition, audioMix: AVMutableAudioMix) {
    let composition = AVMutableComposition()
    let clipProgressIncrement = 10.0 / Double(clips.count)

    // Collect one (track, linear-volume) entry per clip so we can build an
    // AVMutableAudioMix that applies each clip's volumeDb / isMuted.
    var mixEntries: [(track: AVAssetTrack, volume: Float)] = []

    for (index, clip) in clips.enumerated() {
      // Check for cancellation
      if progress.isCancelled {
        throw AudioExportError.cancelled
      }

      progress.localizedAdditionalDescription = "Adding clip \(index + 1) of \(clips.count)"

      // Create a new track for each clip
      guard
        let compositionTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
      else {
        throw AudioExportError.exportFailed(reason: "Failed to create composition track")
      }

      let tempURL = tempFiles[index]

      // Create AVAsset from the temp file
      let avAsset = AVURLAsset(url: tempURL)

      // Get the audio track
      guard let sourceTrack = try await avAsset.loadTracks(withMediaType: .audio).first else {
        throw AudioExportError.invalidAudioData(
          assetId: clip.assetStorageId, reason: "No audio track found")
      }

      // Calculate time ranges
      let startTime = CMTime(seconds: clip.sourceStart.seconds, preferredTimescale: 600)
      let duration = CMTime(seconds: clip.duration.seconds, preferredTimescale: 600)
      let timeRange = CMTimeRange(start: startTime, duration: duration)
      let insertTime = CMTime(seconds: clip.offset.seconds, preferredTimescale: 600)

      // Insert into composition
      try compositionTrack.insertTimeRange(timeRange, of: sourceTrack, at: insertTime)

      // Record this clip's per-track gain for the audio mix.
      let volume = Self.linearAmplitude(volumeDb: clip.volumeDb, isMuted: clip.isMuted)
      mixEntries.append((track: compositionTrack, volume: volume))

      // Update progress
      let progressUnits = Int64(30 + Int((Double(index + 1) * clipProgressIncrement)))
      progress.completedUnitCount = progressUnits
    }

    let audioMix = Self.makeAudioMix(mixEntries, compositionDuration: composition.duration, masterFadeOut: masterFadeOut)
    return (composition, audioMix)
  }

  // MARK: - Composition Export

  /// Exports the composition to an M4A file.
  private func exportComposition(
    _ composition: AVMutableComposition,
    to outputURL: URL,
    audioMix: AVAudioMix? = nil,
    progress: Progress
  ) async throws {
    // Capture AVFoundation export start event
    let compositionDuration = composition.duration.seconds
    await telemetry?.capture(.avExportStart(compositionDuration: compositionDuration))

    // Validate composition has audio tracks
    let audioTracks = composition.tracks(withMediaType: .audio)
    guard !audioTracks.isEmpty else {
      throw AudioExportError.exportFailed(reason: "Composition has no audio tracks")
    }

    // Remove existing file if present
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: outputURL.path) {
      try fileManager.removeItem(at: outputURL)
    }

    // Create export session
    guard
      let exportSession = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPresetAppleM4A
      )
    else {
      throw AudioExportError.exportFailed(reason: "Failed to create export session")
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a

    // Apply per-clip gain (volumeDb / isMuted) via the audio mix, when one was
    // built (timeline path). The direct path passes `nil` (unity gain).
    exportSession.audioMix = audioMix

    // OPTIMIZATION: Use fastest audio time pitch algorithm
    exportSession.audioTimePitchAlgorithm = .varispeed

    progress.localizedAdditionalDescription = "Encoding M4A audio"

    // Export (Apple's encoder)
    try await exportSession.export(to: outputURL, as: .m4a)

    // Capture AVFoundation export complete event
    // Note: sessionRetained flag indicates whether the session is still retained in memory
    // In a normal flow, the session should be released after export completes
    let sessionRetained = false  // Export completed successfully, session can be released
    await telemetry?.capture(.avExportComplete(sessionRetained: sessionRetained))

    progress.completedUnitCount = 100
    progress.localizedAdditionalDescription = "Export complete"
  }

  // MARK: - Helpers

  /// Calculates the file size in megabytes.
  private func getFileSize(_ url: URL) -> Double {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
          let fileSize = attributes[.size] as? NSNumber else {
      return 0.0
    }
    // Convert bytes to megabytes
    return Double(fileSize.int64Value) / (1024.0 * 1024.0)
  }

  /// Estimates ModelContext object count by querying registered model types.
  ///
  /// SwiftData's ModelContext doesn't expose registered objects publicly,
  /// so we approximate by querying the main model types and summing their counts.
  private func getModelContextObjectCount(_ modelContext: ModelContext) -> Int {
    // Fetch count of Timeline objects
    let timelineDescriptor = FetchDescriptor<Timeline>()
    let timelineCount = (try? modelContext.fetchCount(timelineDescriptor)) ?? 0

    // Fetch count of TimelineClip objects
    let clipDescriptor = FetchDescriptor<TimelineClip>()
    let clipCount = (try? modelContext.fetchCount(clipDescriptor)) ?? 0

    // Fetch count of TypedDataStorage objects
    let storageDescriptor = FetchDescriptor<TypedDataStorage>()
    let storageCount = (try? modelContext.fetchCount(storageDescriptor)) ?? 0

    return timelineCount + clipCount + storageCount
  }

  /// Cleans up temporary files.
  private func cleanupTempFiles(_ urls: [URL]) {
    for url in urls {
      try? FileManager.default.removeItem(at: url)
    }
  }

  // MARK: - Per-Clip Gain (Audio Mix)

  /// Converts a per-clip decibel gain to a linear amplitude scalar.
  ///
  /// - `isMuted == true` → `0` (silence), regardless of `volumeDb`.
  /// - `volumeDb == nil` → `1.0` (unity gain).
  /// - `volumeDb == 0` → `1.0`.
  /// - `volumeDb == -∞` (or any negative infinity) → `0`.
  /// - otherwise → `pow(10, dB / 20)`.
  ///
  /// - Parameters:
  ///   - volumeDb: The clip's gain in decibels, or `nil` for unity.
  ///   - isMuted: Whether the clip is muted.
  /// - Returns: A linear amplitude in `[0, ∞)` suitable for
  ///   `AVMutableAudioMixInputParameters.setVolume(_:at:)`.
  public nonisolated static func linearAmplitude(volumeDb: Double?, isMuted: Bool) -> Float {
    if isMuted { return 0 }
    guard let db = volumeDb else { return 1.0 }
    if db.isNaN { return 1.0 }
    if db.isInfinite { return db < 0 ? 0 : Float.greatestFiniteMagnitude }
    return Float(pow(10.0, db / 20.0))
  }

  /// Builds an `AVMutableAudioMix` that applies a constant linear volume to each
  /// supplied track, optionally with a master fade-out over the final N seconds.
  ///
  /// - Parameters:
  ///   - entries: Per-track volume settings (from clip volumeDb / isMuted)
  ///   - compositionDuration: Total duration of the composition
  ///   - masterFadeOut: Duration in seconds for a master fade-out applied to the final N seconds of the entire mix (default: 0, no fade)
  /// - Returns: An `AVMutableAudioMix` with per-track volumes and optional master fade-out
  nonisolated static func makeAudioMix(
    _ entries: [(track: AVAssetTrack, volume: Float)],
    compositionDuration: CMTime,
    masterFadeOut: TimeInterval = 0
  ) -> AVMutableAudioMix {
    let mix = AVMutableAudioMix()

    // Compute fade window: [max(0, T − masterFadeOut), T]
    let totalDuration = compositionDuration.seconds
    let fadeStartTime = max(0, totalDuration - masterFadeOut)
    let fadeDuration = totalDuration - fadeStartTime

    mix.inputParameters = entries.map { entry in
      let params = AVMutableAudioMixInputParameters(track: entry.track)

      // Set constant volume from start
      params.setVolume(entry.volume, at: .zero)

      // Apply master fade-out ramp if requested
      if masterFadeOut > 0 && fadeDuration > 0 {
        let fadeStart = CMTime(seconds: fadeStartTime, preferredTimescale: 600)
        let fadeEnd = CMTime(seconds: totalDuration, preferredTimescale: 600)
        let fadeRange = CMTimeRange(start: fadeStart, end: fadeEnd)

        // Ramp from current volume to silence
        params.setVolumeRamp(
          fromStartVolume: entry.volume,
          toEndVolume: 0,
          timeRange: fadeRange
        )
      }

      return params
    }
    return mix
  }

  /// Returns file extension for MIME type.
  private func fileExtension(for mimeType: String) -> String {
    let components = mimeType.split(separator: "/")
    guard components.count == 2 else { return "dat" }

    let subtype = String(components[1])

    switch subtype {
    case "mpeg": return "mp3"
    case "wav", "x-wav", "vnd.wave": return "wav"
    case "aiff", "x-aiff": return "aiff"
    case "mp4": return "m4a"
    case "aac": return "aac"
    default: return subtype
    }
  }

  // MARK: - Timing Data Generation

  /// Generates timing data from Timeline and writes to files.
  @MainActor
  private func generateTimingData(
    timeline: Timeline,
    audioFileName: String,
    outputDirectory: URL,
    format: TimingDataFormat,
    modelContext: ModelContext
  ) async throws {
    switch format {
    case .none:
      return

    case .webvtt:
      try await generateWebVTT(
        timeline: timeline,
        audioFileName: audioFileName,
        outputDirectory: outputDirectory,
        modelContext: modelContext
      )

    case .json:
      try await generateJSON(
        timeline: timeline,
        audioFileName: audioFileName,
        outputDirectory: outputDirectory,
        modelContext: modelContext
      )

    case .both:
      try await generateWebVTT(
        timeline: timeline,
        audioFileName: audioFileName,
        outputDirectory: outputDirectory,
        modelContext: modelContext
      )
      try await generateJSON(
        timeline: timeline,
        audioFileName: audioFileName,
        outputDirectory: outputDirectory,
        modelContext: modelContext
      )
    }
  }

  /// Generates timing data from audio elements and writes to files.
  @MainActor
  private func generateTimingData(
    audioElements: [TypedDataStorage],
    audioFileName: String,
    outputDirectory: URL,
    format: TimingDataFormat,
    modelContext: ModelContext
  ) async throws {
    switch format {
    case .none:
      return

    case .webvtt:
      try await generateWebVTT(
        audioElements: audioElements,
        audioFileName: audioFileName,
        outputDirectory: outputDirectory,
        modelContext: modelContext
      )

    case .json:
      try await generateJSON(
        audioElements: audioElements,
        audioFileName: audioFileName,
        outputDirectory: outputDirectory,
        modelContext: modelContext
      )

    case .both:
      try await generateWebVTT(
        audioElements: audioElements,
        audioFileName: audioFileName,
        outputDirectory: outputDirectory,
        modelContext: modelContext
      )
      try await generateJSON(
        audioElements: audioElements,
        audioFileName: audioFileName,
        outputDirectory: outputDirectory,
        modelContext: modelContext
      )
    }
  }

  /// Generates and writes WebVTT file from Timeline.
  @MainActor
  private func generateWebVTT(
    timeline: Timeline,
    audioFileName: String,
    outputDirectory: URL,
    modelContext: ModelContext
  ) async throws {
    let generator = WebVTTGenerator()
    let webvtt = try await generator.generateWebVTT(from: timeline, modelContext: modelContext)

    // Write to .vtt file
    let vttURL =
      outputDirectory
      .appendingPathComponent(audioFileName)
      .deletingPathExtension()
      .appendingPathExtension("vtt")

    try webvtt.write(to: vttURL, atomically: true, encoding: .utf8)
  }

  /// Generates and writes WebVTT file from audio elements.
  @MainActor
  private func generateWebVTT(
    audioElements: [TypedDataStorage],
    audioFileName: String,
    outputDirectory: URL,
    modelContext: ModelContext
  ) async throws {
    let generator = WebVTTGenerator()
    let webvtt = try await generator.generateWebVTT(from: audioElements, modelContext: modelContext)

    // Write to .vtt file
    let vttURL =
      outputDirectory
      .appendingPathComponent(audioFileName)
      .deletingPathExtension()
      .appendingPathExtension("vtt")

    try webvtt.write(to: vttURL, atomically: true, encoding: .utf8)
  }

  /// Generates and writes JSON file from Timeline.
  @MainActor
  private func generateJSON(
    timeline: Timeline,
    audioFileName: String,
    outputDirectory: URL,
    modelContext: ModelContext
  ) async throws {
    let generator = JSONGenerator()
    let json = try await generator.generateJSON(
      from: timeline,
      audioFileName: audioFileName,
      modelContext: modelContext
    )

    // Write to .timing.json file
    let jsonURL = TimingData.fileURL(for: outputDirectory.appendingPathComponent(audioFileName))

    try json.write(to: jsonURL, atomically: true, encoding: .utf8)
  }

  /// Generates and writes JSON file from audio elements.
  @MainActor
  private func generateJSON(
    audioElements: [TypedDataStorage],
    audioFileName: String,
    outputDirectory: URL,
    modelContext: ModelContext
  ) async throws {
    let generator = JSONGenerator()
    let json = try await generator.generateJSON(
      from: audioElements,
      audioFileName: audioFileName,
      modelContext: modelContext
    )

    // Write to .timing.json file
    let jsonURL = TimingData.fileURL(for: outputDirectory.appendingPathComponent(audioFileName))

    try json.write(to: jsonURL, atomically: true, encoding: .utf8)
  }
}
