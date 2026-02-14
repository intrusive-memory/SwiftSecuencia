import Foundation
import SwiftSecuencia

/// Parser for frame rate strings.
struct FrameRateParser: Sendable {

    /// Parse a frame rate string to a FrameRate value.
    ///
    /// Supported frame rates:
    /// - "23.98" → .fps23_98
    /// - "24" → .fps24
    /// - "25" → .fps25
    /// - "29.97" → .fps29_97
    /// - "30" → .fps30
    /// - "50" → .fps50
    /// - "59.94" → .fps59_94
    /// - "60" → .fps60
    ///
    /// - Parameter string: The frame rate string to parse.
    /// - Returns: A `FrameRate` value.
    /// - Throws: `FrameRateParserError` if the value is unrecognized.
    func parse(_ string: String) throws -> FrameRate {
        switch string {
        case "23.98":
            return .fps23_98
        case "24":
            return .fps24
        case "25":
            return .fps25
        case "29.97":
            return .fps29_97
        case "30":
            return .fps30
        case "50":
            return .fps50
        case "59.94":
            return .fps59_94
        case "60":
            return .fps60
        default:
            throw FrameRateParserError.unrecognizedValue(
                string,
                validValues: ["23.98", "24", "25", "29.97", "30", "50", "59.94", "60"]
            )
        }
    }
}

/// Errors that can occur during frame rate parsing.
enum FrameRateParserError: Error, LocalizedError {
    case unrecognizedValue(String, validValues: [String])

    var errorDescription: String? {
        switch self {
        case .unrecognizedValue(let value, let validValues):
            let validList = validValues.joined(separator: ", ")
            return "Unrecognized frame rate: \(value). Valid values: \(validList)"
        }
    }
}
