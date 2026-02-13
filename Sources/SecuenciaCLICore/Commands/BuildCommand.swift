import ArgumentParser
import Foundation
import SwiftSecuencia
import SwiftData
import SwiftFijos

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

public struct Build: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Generate FCPXML from a JSON timeline definition."
    )

    @Argument(help: "Path to the JSON timeline definition file")
    public var inputFile: String

    @Option(name: .long, help: "Output path for the FCPXML file or bundle (default: <input>.fcpxml)")
    public var output: String?

    @Flag(name: .long, help: "Produce a .fcpxmld bundle with embedded media instead of standalone FCPXML")
    public var bundle: Bool = false

    @Option(name: .long, help: "FCPXML version to generate (default: 1.11)")
    public var formatVersion: String = "1.11"

    @Flag(name: .long, help: "Fail if DTD validation finds errors (default: warn only)")
    public var strict: Bool = false

    public init() {}

    @MainActor
    public mutating func run() async throws {
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

            // Validate XML against DTD
            let validationPassed = try validateFCPXML(
                xmlString: xmlString,
                version: .from(string: formatVersion)
            )

            // If strict mode and validation failed, don't write output
            if strict && !validationPassed {
                throw ValidationError("DTD validation failed in strict mode. Output not written.")
            }

            let outputURL = URL(fileURLWithPath: outputPath)
            try xmlString.write(to: outputURL, atomically: true, encoding: .utf8)

            return outputURL
        }
        #else
        throw ValidationError("FCPXML export is only available on macOS")
        #endif
    }

    /// Validates FCPXML against the DTD for the specified version.
    /// Returns true if validation passes or is skipped, false if it fails.
    private func validateFCPXML(xmlString: String, version: FCPXMLVersion) throws -> Bool {
        // Check if DTD is available for this version
        guard dtdAvailableFor(version: version) else {
            fputs("⚠️  DTD validation skipped: no DTD available for FCPXML version \(version.stringValue)\n", stderr)
            return true // Skip validation, treat as pass
        }

        let validator = FCPXMLDTDValidator()
        let result = try validator.validate(xmlContent: xmlString, version: version)

        if result.isValid {
            // Validation passed
            return true
        } else {
            // Validation failed - print errors to stderr
            if strict {
                fputs("❌ DTD validation failed:\n", stderr)
            } else {
                fputs("⚠️  DTD validation warnings:\n", stderr)
            }

            for error in result.errors {
                fputs("  - \(error)\n", stderr)
            }

            return false
        }
    }

    /// Checks if a DTD file is available for the given FCPXML version.
    private func dtdAvailableFor(version: FCPXMLVersion) -> Bool {
        let dtdFilename = version.dtdFilenameWithExtension
        do {
            _ = try SwiftFijos.Fijos.getFixture(dtdFilename)
            return true
        } catch {
            return false
        }
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
