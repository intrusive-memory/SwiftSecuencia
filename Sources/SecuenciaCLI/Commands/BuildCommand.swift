import ArgumentParser
import Foundation
import SwiftSecuencia
import SwiftData

#if os(macOS)
import Pipeline
#endif

// MARK: - FCPXMLVersion Extension

#if os(macOS)
extension FCPXMLVersion {
    /// Creates a version from a string (e.g., "1.11", "1.13").
    static func from(string: String) -> FCPXMLVersion {
        switch string {
        case "1.8": return .v1_8
        case "1.9": return .v1_9
        case "1.10": return .v1_10
        case "1.11": return .v1_11
        case "1.12": return .v1_12
        case "1.13": return .v1_13
        default: return .default
        }
    }
}
#endif

// MARK: - Build Command

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

    @MainActor
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

        // Step 5: Bootstrap SwiftData and build timeline
        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let builder = TimelineBuilder()
        let (timeline, assetProvider) = try await builder.build(
            from: definition,
            assetMap: assetMap,
            in: context
        )

        // Step 6: Export based on mode
        let outputURL = try await exportTimeline(
            timeline: timeline,
            assetProvider: assetProvider,
            definition: definition,
            assetMap: assetMap
        )

        // Print success summary
        printExportSummary(
            outputURL: outputURL,
            definition: definition,
            assetMap: assetMap
        )
    }

    /// Exports the timeline based on the selected mode.
    @MainActor
    private mutating func exportTimeline(
        timeline: Timeline,
        assetProvider: FileAssetProvider,
        definition: TimelineDefinition,
        assetMap: [String: UUID]
    ) async throws -> URL {
        #if os(macOS)
        if bundle {
            // Bundle export mode
            let outputDir: URL
            if let outputPath = output {
                outputDir = URL(fileURLWithPath: outputPath).deletingLastPathComponent()
            } else {
                outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            }

            let bundleName = output?.replacingOccurrences(of: ".fcpxmld", with: "") ?? definition.timeline.name

            var bundleExporter = FCPXMLBundleExporter(
                version: .from(string: formatVersion),
                includeMedia: true
            )

            return try await bundleExporter.exportBundle(
                timeline: timeline,
                assetProvider: assetProvider,
                to: outputDir,
                bundleName: bundleName,
                libraryName: "SwiftSecuencia Export",
                eventName: definition.timeline.name
            )
        } else {
            // Standalone FCPXML export
            let outputPath: String
            if let output = output {
                outputPath = output
            } else {
                let inputURL = URL(fileURLWithPath: inputFile)
                outputPath = inputURL.deletingPathExtension().appendingPathExtension("fcpxml").path
            }

            var exporter = FCPXMLExporter(version: .from(string: formatVersion))
            let xmlString = try exporter.export(
                timeline: timeline,
                assetProvider: assetProvider,
                libraryName: "SwiftSecuencia Export",
                eventName: definition.timeline.name
            )

            let outputURL = URL(fileURLWithPath: outputPath)
            try xmlString.write(to: outputURL, atomically: true, encoding: .utf8)

            return outputURL
        }
        #else
        throw ValidationError("FCPXML export is only available on macOS")
        #endif
    }

    /// Prints export success summary.
    private func printExportSummary(
        outputURL: URL,
        definition: TimelineDefinition,
        assetMap: [String: UUID]
    ) {
        print("\n✅ Export successful!")
        print("Output: \(outputURL.path)")
        print("Timeline: \(definition.timeline.name)")
        print("Format: \(definition.timeline.format.width)x\(definition.timeline.format.height) @ \(definition.timeline.format.frameRate) fps")
        print("Clips: \(definition.clips.count)")
        print("Unique assets: \(assetMap.count)")

        // Calculate total duration
        var totalDuration: Double = 0
        for clip in definition.clips {
            if let durationStr = clip.duration {
                let parser = TimeStringParser()
                if let timecode = try? parser.parse(durationStr) {
                    totalDuration += timecode.seconds
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
