import ArgumentParser
import Foundation

struct Build: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Generate FCPXML from a JSON timeline definition."
    )

    @Argument(help: "Path to the JSON timeline definition file")
    var inputFile: String

    @Option(name: .long, help: "Output path for the FCPXML file or bundle")
    var output: String?

    @Flag(name: .long, help: "Produce a .fcpxmld bundle with embedded media")
    var bundle: Bool = false

    @Option(name: .long, help: "FCPXML version to generate")
    var formatVersion: String = "1.11"

    mutating func run() async throws {
        // Step 1: Parse JSON
        let inputURL = URL(fileURLWithPath: inputFile)
        let parser = JSONTimelineParser()
        var definition = try parser.parse(fileAt: inputURL)

        // Step 2: Resolve file paths
        let baseURL = inputURL.deletingLastPathComponent()
        let resolver = FileResolver()
        definition = try resolver.resolve(definition: definition, relativeTo: baseURL)

        // Step 3: Deduplicate assets
        let assetMap = resolver.deduplicateAssets(in: definition)

        // Step 4: Probe missing durations
        let probe = MediaProbe()
        definition = try await probe.probeMissingDurations(in: definition)

        // Print timeline summary
        printSummary(definition: definition, assetMap: assetMap)

        // TODO: FCPXML export will be implemented in later sprints
    }

    private func printSummary(definition: TimelineDefinition, assetMap: [String: UUID]) {
        print("Timeline: \(definition.timeline.name)")
        print("Format: \(definition.timeline.format.width)x\(definition.timeline.format.height) @ \(definition.timeline.format.frameRate) fps")
        print("Audio: \(definition.timeline.audio.layout) \(definition.timeline.audio.rate)")
        print("Clips: \(definition.clips.count)")
        print("Unique assets: \(assetMap.count)")

        // Calculate total duration
        var totalDuration: Double = 0
        for clip in definition.clips {
            if let durationStr = clip.duration {
                // Parse simple "Xs" format for now
                if let value = Double(durationStr.dropLast()) {
                    totalDuration += value
                }
            }
        }
        print("Total duration: \(String(format: "%.2f", totalDuration))s")

        // Determine lane range
        let lanes = definition.clips.compactMap { $0.lane }.sorted()
        if let minLane = lanes.first, let maxLane = lanes.last {
            print("Lanes: \(minLane)...\(maxLane)")
        }
    }
}
