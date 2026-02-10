import Foundation
import Universal

/// Parser for timeline definition JSON files.
struct JSONTimelineParser: Sendable {

    /// Parse a timeline definition from a JSON file.
    ///
    /// - Parameter url: The URL to the JSON file.
    /// - Returns: A validated `TimelineDefinition`.
    /// - Throws: `ParserError` if parsing or validation fails.
    func parse(fileAt url: URL) throws -> TimelineDefinition {
        // Read data from file
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ParserError.fileNotFound(url)
        }

        // Parse using Universal
        let json: JSON
        do {
            json = try JSON.parse(data)
        } catch {
            throw ParserError.invalidJSON(url, underlying: error)
        }

        // Decode TimelineDefinition
        let definition: TimelineDefinition
        do {
            definition = try TimelineDefinition(json: json)
        } catch {
            throw ParserError.decodingFailed(url, underlying: error)
        }

        // Validate required fields
        try validate(definition)

        return definition
    }

    /// Validate a parsed timeline definition.
    private func validate(_ definition: TimelineDefinition) throws {
        // Validate timeline.name is present (non-empty)
        guard !definition.timeline.name.isEmpty else {
            throw ParserError.validationFailed("timeline.name is required and cannot be empty")
        }

        // Validate clips
        for (index, clip) in definition.clips.enumerated() {
            switch clip.type {
            case .marker:
                // Marker clips require markerType
                guard clip.markerType != nil else {
                    throw ParserError.validationFailed(
                        "Clip \(index) (type: marker) must have 'markerType' field"
                    )
                }
            case .video, .audio, .image:
                // Non-marker clips require file
                guard clip.file != nil else {
                    throw ParserError.validationFailed(
                        "Clip \(index) (name: \(clip.name), type: \(clip.type.rawValue)) must have 'file' field"
                    )
                }
            }
        }
    }
}

/// Errors that can occur during parsing.
enum ParserError: Error, LocalizedError {
    case fileNotFound(URL)
    case invalidJSON(URL, underlying: Error)
    case decodingFailed(URL, underlying: Error)
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .invalidJSON(let url, let error):
            return "Invalid JSON in \(url.lastPathComponent): \(error.localizedDescription)"
        case .decodingFailed(let url, let error):
            return "Failed to decode timeline definition from \(url.lastPathComponent): \(error.localizedDescription)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        }
    }
}
