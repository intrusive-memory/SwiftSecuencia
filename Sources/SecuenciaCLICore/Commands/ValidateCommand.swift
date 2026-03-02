import ArgumentParser
import Foundation

public struct Validate: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate a JSON timeline definition without generating FCPXML output."
  )

  @Argument(
    help: "Path to the JSON timeline definition file to validate"
  )
  public var inputFile: String

  public init() {}

  public mutating func run() async throws {
    let inputURL = URL(fileURLWithPath: inputFile)

    // Step 1: Parse JSON
    print("Parsing JSON...")
    let parser = JSONTimelineParser()
    let definition = try parser.parse(fileAt: inputURL)

    // Step 2: Resolve file paths
    print("Resolving file paths...")
    let resolver = FileResolver()
    let baseURL = inputURL.deletingLastPathComponent()
    let resolved = try resolver.resolve(definition: definition, relativeTo: baseURL)

    // Step 3: Probe missing durations
    print("Probing media durations...")
    let probe = MediaProbe()
    let probed = try await probe.probeMissingDurations(in: resolved)

    // Step 4: Generate summary
    print("\n✅ Validation successful!\n")
    print("Timeline Summary:")
    print("  Name: \(probed.timeline.name)")
    print(
      "  Format: \(probed.timeline.format.width)×\(probed.timeline.format.height) @ \(probed.timeline.format.frameRate) fps"
    )
    print("  Color Space: \(probed.timeline.format.colorSpace ?? "not specified")")
    print("  Audio: \(probed.timeline.audio.layout), \(probed.timeline.audio.rate)")

    // Clip count by type
    let clipsByType = Dictionary(grouping: probed.clips, by: { $0.type })
    print("\nClips:")
    print("  Total: \(probed.clips.count)")
    for type in ClipType.allCases.sorted(by: { $0.rawValue < $1.rawValue }) {
      if let clips = clipsByType[type] {
        print("  \(type.rawValue): \(clips.count)")
      }
    }

    // Unique asset count (files only)
    let uniqueFiles = Set(probed.clips.compactMap { $0.file })
    print("\nAssets:")
    print("  Unique files: \(uniqueFiles.count)")

    // Total duration (sum of all clip durations)
    let totalDuration: Double = try probed.clips
      .compactMap { $0.duration }
      .compactMap { try? TimeStringParser().parse($0) }
      .map { $0.seconds }
      .reduce(0, +)
    print("  Total duration: \(String(format: "%.2f", totalDuration))s")

    // Lane range
    let lanes = probed.clips.compactMap { $0.lane }
    if let minLane = lanes.min(), let maxLane = lanes.max() {
      print("  Lane range: \(minLane) to \(maxLane)")
    } else {
      print("  Lane range: none")
    }

    // Step 5: Report warnings
    var warnings: [String] = []

    // Very short clips (<0.1s)
    let timeParser = TimeStringParser()
    for clip in probed.clips where clip.duration != nil {
      if let duration = try? timeParser.parse(clip.duration!), duration.seconds < 0.1 {
        warnings.append(
          "Clip '\(clip.name)' is very short (\(String(format: "%.3f", duration.seconds))s)")
      }
    }

    // Overlapping clips on same lane
    let clipsByLane = Dictionary(
      grouping: probed.clips.filter { $0.type != .marker }, by: { $0.lane ?? 0 })
    for (lane, clips) in clipsByLane {
      let sortedClips = clips.sorted { a, b in
        guard let aParsed = try? timeParser.parse(a.offset),
          let bParsed = try? timeParser.parse(b.offset)
        else { return false }
        return aParsed.seconds < bParsed.seconds
      }

      for i in 0..<sortedClips.count - 1 {
        let currentClip = sortedClips[i]
        let nextClip = sortedClips[i + 1]

        guard let currentDuration = currentClip.duration else { continue }

        guard let currentStart = try? timeParser.parse(currentClip.offset),
          let currentDur = try? timeParser.parse(currentDuration),
          let nextStart = try? timeParser.parse(nextClip.offset)
        else { continue }

        let currentEnd = currentStart.seconds + currentDur.seconds
        if currentEnd > nextStart.seconds {
          warnings.append(
            "Clips '\(currentClip.name)' and '\(nextClip.name)' overlap on lane \(lane)")
        }
      }
    }

    // Gaps in primary storyline (lane 0)
    if let primaryClips = clipsByLane[0]?.filter({ $0.type != .marker }) {
      let sorted = primaryClips.sorted { a, b in
        guard let aParsed = try? timeParser.parse(a.offset),
          let bParsed = try? timeParser.parse(b.offset)
        else { return false }
        return aParsed.seconds < bParsed.seconds
      }

      for i in 0..<sorted.count - 1 {
        let currentClip = sorted[i]
        let nextClip = sorted[i + 1]

        guard let currentDuration = currentClip.duration else { continue }

        guard let currentStart = try? timeParser.parse(currentClip.offset),
          let currentDur = try? timeParser.parse(currentDuration),
          let nextStart = try? timeParser.parse(nextClip.offset)
        else { continue }

        let currentEnd = currentStart.seconds + currentDur.seconds
        let gap = nextStart.seconds - currentEnd
        if gap > 0.01 {  // Allow small floating point errors
          warnings.append(
            "Gap of \(String(format: "%.2f", gap))s in primary storyline between '\(currentClip.name)' and '\(nextClip.name)'"
          )
        }
      }
    }

    // Print warnings
    if !warnings.isEmpty {
      print("\n⚠️  Warnings:")
      for warning in warnings {
        print("  - \(warning)")
      }
    } else {
      print("\n✨ No warnings detected.")
    }
  }
}
