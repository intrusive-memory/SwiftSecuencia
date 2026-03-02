import Foundation
import SwiftSecuencia

/// Parser for FCPXML time string formats.
struct TimeStringParser: Sendable {

  /// Parse a time string to a Timecode value.
  ///
  /// Supported formats:
  /// - Integer seconds: `"0s"`, `"3s"`, `"120s"`
  /// - Decimal seconds: `"3.5s"`, `"0.1s"`, `"10.25s"`
  /// - Rational format: `"1001/24000s"`, `"0/1s"`
  ///
  /// - Parameter string: The time string to parse.
  /// - Returns: A `Timecode` value.
  /// - Throws: `TimeStringParserError` if parsing fails.
  func parse(_ string: String) throws -> Timecode {
    // Validate non-empty
    guard !string.isEmpty else {
      throw TimeStringParserError.emptyString
    }

    // Validate 's' suffix
    guard string.hasSuffix("s") else {
      throw TimeStringParserError.missingSuffix(string)
    }

    // Remove 's' suffix
    let valueString = String(string.dropLast())

    // Check for rational format (numerator/denominator)
    if valueString.contains("/") {
      return try parseRational(valueString, original: string)
    }

    // Check for decimal format
    if valueString.contains(".") {
      return try parseDecimal(valueString, original: string)
    }

    // Parse as integer seconds
    return try parseInteger(valueString, original: string)
  }

  /// Parse rational format: "1001/24000"
  private func parseRational(_ valueString: String, original: String) throws -> Timecode {
    let components = valueString.split(separator: "/")
    guard components.count == 2 else {
      throw TimeStringParserError.invalidFormat(original)
    }

    guard let numerator = Int64(components[0]),
      let denominator = Int32(components[1])
    else {
      throw TimeStringParserError.invalidFormat(original)
    }

    // Check for negative values
    guard numerator >= 0, denominator > 0 else {
      throw TimeStringParserError.negativeValue(original)
    }

    return Timecode(value: numerator, timescale: denominator)
  }

  /// Parse decimal format: "3.5"
  private func parseDecimal(_ valueString: String, original: String) throws -> Timecode {
    guard let seconds = Double(valueString) else {
      throw TimeStringParserError.invalidFormat(original)
    }

    // Check for negative values
    guard seconds >= 0 else {
      throw TimeStringParserError.negativeValue(original)
    }

    return Timecode(seconds: seconds)
  }

  /// Parse integer format: "3"
  private func parseInteger(_ valueString: String, original: String) throws -> Timecode {
    guard let seconds = Int(valueString) else {
      throw TimeStringParserError.invalidFormat(original)
    }

    // Check for negative values
    guard seconds >= 0 else {
      throw TimeStringParserError.negativeValue(original)
    }

    return Timecode(seconds: Double(seconds))
  }
}

/// Errors that can occur during time string parsing.
enum TimeStringParserError: Error, LocalizedError {
  case emptyString
  case missingSuffix(String)
  case invalidFormat(String)
  case negativeValue(String)

  var errorDescription: String? {
    switch self {
    case .emptyString:
      return "Time string cannot be empty"
    case .missingSuffix(let string):
      return "Time string must end with 's' suffix: \(string)"
    case .invalidFormat(let string):
      return "Invalid time string format: \(string)"
    case .negativeValue(let string):
      return "Time string cannot be negative: \(string)"
    }
  }
}
