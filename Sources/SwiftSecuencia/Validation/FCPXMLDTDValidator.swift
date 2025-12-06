//
//  FCPXMLDTDValidator.swift
//  SwiftSecuencia
//
//  Validates FCPXML documents against DTD files using xmllint.
//

import Foundation

/// Validates FCPXML documents against DTD specifications using xmllint.
///
/// FCPXMLDTDValidator uses the macOS-provided `xmllint` utility to validate
/// FCPXML documents against their DTD (Document Type Definition) files. This ensures
/// that the generated FCPXML conforms to Apple's FCPXML specification.
///
/// ## Basic Usage
///
/// ```swift
/// let validator = FCPXMLDTDValidator()
/// let result = try validator.validate(
///     xmlContent: fcpxmlString,
///     version: "1.11"
/// )
///
/// if result.isValid {
///     print("✓ Valid FCPXML")
/// } else {
///     print("✗ DTD validation failed:")
///     for error in result.errors {
///         print("  - \(error)")
///     }
/// }
/// ```
public struct FCPXMLDTDValidator {

    /// Result of DTD validation.
    public struct DTDValidationResult: Sendable, Equatable {
        /// Whether the XML passed DTD validation.
        public let isValid: Bool

        /// Validation error messages (empty if valid).
        public let errors: [String]

        /// Full stderr output from xmllint.
        public let rawOutput: String

        /// Creates a DTD validation result.
        public init(isValid: Bool, errors: [String], rawOutput: String) {
            self.isValid = isValid
            self.errors = errors
            self.rawOutput = rawOutput
        }
    }

    /// Creates an FCPXML DTD validator.
    public init() {}

    /// Validates FCPXML content against a DTD file.
    ///
    /// - Parameters:
    ///   - xmlContent: The FCPXML document content as a string.
    ///   - version: The FCPXML version (e.g., "1.11", "1.10").
    ///   - dtdURL: Optional custom DTD file URL. If nil, uses bundled DTD.
    /// - Returns: DTD validation result with errors if invalid.
    /// - Throws: DTDValidationError if DTD not found or xmllint fails.
    public func validate(
        xmlContent: String,
        version: String,
        dtdURL: URL? = nil
    ) throws -> DTDValidationResult {
        // Resolve DTD URL
        let dtdFileURL: URL
        if let customDTD = dtdURL {
            dtdFileURL = customDTD
        } else {
            dtdFileURL = try resolveDTDURL(version: version)
        }

        // Create temporary file for XML content
        let tempXMLURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fcpxml_validate_\(UUID().uuidString).fcpxml")

        defer {
            try? FileManager.default.removeItem(at: tempXMLURL)
        }

        // Write XML to temp file
        try xmlContent.write(to: tempXMLURL, atomically: true, encoding: .utf8)

        // Run xmllint validation
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xmllint")
        process.arguments = [
            "--noout",
            "--dtdvalid",
            dtdFileURL.path,
            tempXMLURL.path
        ]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe() // Suppress stdout

        try process.run()
        process.waitUntilExit()

        // Read stderr output
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrOutput = String(data: stderrData, encoding: .utf8) ?? ""

        // Check exit code
        let exitCode = process.terminationStatus
        let isValid = exitCode == 0

        // Parse errors from stderr
        let errors = parseValidationErrors(from: stderrOutput)

        return DTDValidationResult(
            isValid: isValid,
            errors: errors,
            rawOutput: stderrOutput
        )
    }

    /// Validates FCPXML content from a file URL.
    ///
    /// - Parameters:
    ///   - fileURL: URL to the FCPXML file.
    ///   - version: The FCPXML version (e.g., "1.11", "1.10").
    ///   - dtdURL: Optional custom DTD file URL. If nil, uses bundled DTD.
    /// - Returns: DTD validation result with errors if invalid.
    /// - Throws: DTDValidationError if file cannot be read or DTD not found.
    public func validate(
        fileURL: URL,
        version: String,
        dtdURL: URL? = nil
    ) throws -> DTDValidationResult {
        let xmlContent = try String(contentsOf: fileURL, encoding: .utf8)
        return try validate(xmlContent: xmlContent, version: version, dtdURL: dtdURL)
    }

    // MARK: - Private Helpers

    /// Resolves the DTD file URL for a given FCPXML version.
    private func resolveDTDURL(version: String) throws -> URL {
        // Normalize version string (remove dots)
        let normalizedVersion = version.replacingOccurrences(of: ".", with: "_")
        let dtdFilename = "FCPXMLv\(normalizedVersion).dtd"

        // Try to find DTD in test bundle resources (SPM Bundle.module)
        #if DEBUG
        // In test context, look for test bundle
        if let bundleURL = Bundle.allBundles.first(where: { $0.bundlePath.contains("SwiftSecuenciaTests") })?.resourceURL?.appendingPathComponent("Resources/DTD/\(dtdFilename)"),
           FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }
        #endif

        // Try to find DTD in test resources (relative paths)
        let possiblePaths = [
            // Relative to current working directory
            FileManager.default.currentDirectoryPath + "/Tests/SwiftSecuenciaTests/Resources/DTD/\(dtdFilename)",
            // Relative to project root (for SPM)
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Tests/SwiftSecuenciaTests/Resources/DTD/\(dtdFilename)")
                .path
        ]

        for path in possiblePaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        throw DTDValidationError.dtdNotFound(version: version, searchedPaths: possiblePaths)
    }

    /// Parses validation errors from xmllint stderr output.
    private func parseValidationErrors(from stderrOutput: String) -> [String] {
        guard !stderrOutput.isEmpty else { return [] }

        // Parse xmllint error messages
        // Format: "file.fcpxml:line: element name: validity error : message"
        let lines = stderrOutput.components(separatedBy: .newlines)
        var errors: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip the summary line
            if trimmed.contains("fails to validate") {
                continue
            }

            // Extract error message
            if let range = trimmed.range(of: ": validity error : ") {
                let errorMessage = String(trimmed[range.upperBound...])
                errors.append(errorMessage)
            } else if trimmed.contains("validity error") || trimmed.contains("error") {
                errors.append(trimmed)
            }
        }

        // If no structured errors found but stderr has content, include raw output
        if errors.isEmpty && !stderrOutput.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(stderrOutput)
        }

        return errors
    }
}

// MARK: - Errors

/// Errors that can occur during FCPXML DTD validation.
public enum DTDValidationError: Error, LocalizedError {
    case dtdNotFound(version: String, searchedPaths: [String])
    case xmllintNotFound
    case fileNotReadable(path: String)

    public var errorDescription: String? {
        switch self {
        case .dtdNotFound(let version, let paths):
            return """
            DTD file not found for FCPXML version \(version).
            Searched paths:
            \(paths.map { "  - \($0)" }.joined(separator: "\n"))
            """
        case .xmllintNotFound:
            return "xmllint utility not found at /usr/bin/xmllint"
        case .fileNotReadable(let path):
            return "Cannot read FCPXML file at path: \(path)"
        }
    }
}
