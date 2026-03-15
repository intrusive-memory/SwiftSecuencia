import ArgumentParser
import Foundation
import SecuenciaCLICore

@main
struct Secuencia: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "secuencia",
    abstract: "A command-line tool for generating Final Cut Pro timelines from JSON definitions.",
    version: "3.0.1",
    subcommands: [Build.self, Validate.self, Schema.self]
  )
}
