import ArgumentParser
import Foundation

public struct Schema: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "schema",
        abstract: "Output the JSON Schema for SwiftSecuencia timeline definitions."
    )

    public init() {}

    public func run() throws {
        // Load schema.json from Bundle.module resources
        guard let resourceURL = Bundle.module.url(forResource: "schema", withExtension: "json") else {
            fputs("Error: Could not find schema.json resource\n", stderr)
            throw ExitCode.failure
        }

        // Read the schema file
        let schemaData: Data
        do {
            schemaData = try Data(contentsOf: resourceURL)
        } catch {
            fputs("Error: Failed to read schema.json: \(error.localizedDescription)\n", stderr)
            throw ExitCode.failure
        }

        // Validate it's valid JSON (parse and re-serialize for consistency)
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: schemaData)
        } catch {
            fputs("Error: schema.json is not valid JSON: \(error.localizedDescription)\n", stderr)
            throw ExitCode.failure
        }

        // Pretty-print to stdout
        let prettyData: Data
        do {
            prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
        } catch {
            fputs("Error: Failed to serialize schema: \(error.localizedDescription)\n", stderr)
            throw ExitCode.failure
        }

        guard let schemaString = String(data: prettyData, encoding: .utf8) else {
            fputs("Error: Failed to convert schema to UTF-8 string\n", stderr)
            throw ExitCode.failure
        }

        print(schemaString)
    }
}
