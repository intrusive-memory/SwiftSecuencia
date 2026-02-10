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
        print("Not yet implemented")
    }
}
