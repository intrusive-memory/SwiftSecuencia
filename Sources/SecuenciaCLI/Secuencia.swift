import ArgumentParser
import Foundation

@main
struct Secuencia: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "secuencia",
        abstract: "A command-line tool for generating Final Cut Pro timelines from JSON definitions.",
        version: "1.0.0",
        subcommands: [Build.self, Validate.self, Schema.self]
    )
}
