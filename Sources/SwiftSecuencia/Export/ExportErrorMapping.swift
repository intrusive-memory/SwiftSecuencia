//
//  ExportErrorMapping.swift
//  SwiftSecuencia
//
//  Maps PipelineNeo error types to SwiftSecuencia error types to prevent
//  PipelineNeo errors from leaking to callers of SwiftSecuenciaExporter.
//
//  ## Error Taxonomy
//
//  SwiftSecuencia export errors are organized into three tiers:
//
//  1. **`FCPXMLExportError`** -- errors during FCPXML document generation.
//     Maps from `PipelineNeo.FCPXMLExportError`.
//
//  2. **`FCPXMLBundleExportError`** -- errors during `.fcpxmld` bundle creation.
//     Maps from `PipelineNeo.FCPXMLBundleExportError`.
//
//  3. **`FCPXMLValidationError`** -- errors during FCPXML structure validation.
//     Maps from `PipelineNeo.FCPXMLError` and `PipelineNeo.ValidationError`.
//
//  ## Usage
//
//  The primary entry point is `remappingExportErrors(_:)`, which wraps any
//  throwing closure and translates PipelineNeo errors at the boundary:
//
//  ```swift
//  let xml = try remappingExportErrors {
//      try pipelineNeoExporter.export(timeline: t, assets: a)
//  }
//  ```
//
//  Callers of `SwiftSecuenciaExporter` never need to import PipelineNeo
//  and never see PipelineNeo error types.
//

#if os(macOS)

import Foundation
import PipelineNeo

// MARK: - FCPXMLExportError Mapping

extension FCPXMLExportError {

    /// Creates a `FCPXMLExportError` by mapping a `PipelineNeo.FCPXMLExportError`.
    ///
    /// | PipelineNeo case                     | SwiftSecuencia case                  |
    /// |--------------------------------------|--------------------------------------|
    /// | `.missingFormat`                     | `.missingFormat`                     |
    /// | `.missingAsset(assetId: String)`     | `.missingAssetRef(assetRef: String)` |
    /// | `.invalidTimeline(reason: String)`   | `.invalidTimeline(reason: String)`   |
    /// | `.cancelled`                         | `.cancelled`                         |
    ///
    /// - Parameter pipelineNeoError: The PipelineNeo error to map.
    public init(mappingFrom pipelineNeoError: PipelineNeo.FCPXMLExportError) {
        switch pipelineNeoError {
        case .missingFormat:
            self = .missingFormat
        case .missingAsset(let assetId):
            self = .missingAssetRef(assetRef: assetId)
        case .invalidTimeline(let reason):
            self = .invalidTimeline(reason: reason)
        case .cancelled:
            self = .cancelled
        }
    }

    /// Maps a `PipelineNeo.FCPXMLExportError` to a `FCPXMLExportError`.
    ///
    /// - Parameter pipelineNeoError: The PipelineNeo error to map.
    /// - Returns: The mapped `FCPXMLExportError`.
    public static func mapped(from pipelineNeoError: PipelineNeo.FCPXMLExportError) -> FCPXMLExportError {
        FCPXMLExportError(mappingFrom: pipelineNeoError)
    }
}

// MARK: - FCPXMLBundleExportError

/// Errors that can occur during FCPXML bundle (.fcpxmld) creation.
///
/// Maps from `PipelineNeo.FCPXMLBundleExportError` to provide user-friendly
/// error messages suitable for UI or CLI display.
public enum FCPXMLBundleExportError: Error, LocalizedError {

    /// The bundle directory could not be created.
    case bundleCreationFailed(reason: String)

    /// A media file could not be copied into the bundle's Media/ folder.
    case mediaCopyFailed(assetRef: String, underlying: Error?)

    /// The Info.fcpxml file could not be written to the bundle.
    case writeFailed(reason: String)

    /// The requested FCPXML version does not support the bundle format.
    /// Bundle exports require FCPXML version 1.10 or higher.
    case unsupportedBundleVersion(currentVersion: String, minimumVersion: String)

    // MARK: LocalizedError

    public var errorDescription: String? {
        switch self {
        case .bundleCreationFailed(let reason):
            return "Could not create the FCPXML bundle: \(reason). Check that the output directory exists and you have write permission."
        case .mediaCopyFailed(let assetRef, let underlying):
            let detail = underlying.map { ": \($0.localizedDescription)" } ?? "."
            return "Failed to copy media for asset '\(assetRef)' into the bundle\(detail) Verify that the source file exists and is readable."
        case .writeFailed(let reason):
            return "Failed to write bundle content: \(reason). Ensure the output directory is writable and the disk is not full."
        case .unsupportedBundleVersion(let current, let minimum):
            return "FCPXML bundle format requires version \(minimum) or higher, but the document version is \(current)."
        }
    }

    // MARK: Mapping from PipelineNeo

    /// Creates a `FCPXMLBundleExportError` by mapping a `PipelineNeo.FCPXMLBundleExportError`.
    public init(mappingFrom pipelineNeoError: PipelineNeo.FCPXMLBundleExportError) {
        switch pipelineNeoError {
        case .bundleCreationFailed(let reason):
            self = .bundleCreationFailed(reason: reason)
        case .mediaCopyFailed(let assetId, let underlying):
            self = .mediaCopyFailed(assetRef: assetId, underlying: underlying)
        case .writeFailed(let reason):
            self = .writeFailed(reason: reason)
        case .bundleRequiresVersion1_10OrHigher(let currentVersion):
            self = .unsupportedBundleVersion(currentVersion: currentVersion, minimumVersion: "1.10")
        }
    }

    /// Maps a `PipelineNeo.FCPXMLBundleExportError` to a `FCPXMLBundleExportError`.
    public static func mapped(from pipelineNeoError: PipelineNeo.FCPXMLBundleExportError) -> FCPXMLBundleExportError {
        FCPXMLBundleExportError(mappingFrom: pipelineNeoError)
    }
}

// MARK: - FCPXMLValidationError

/// Errors that can occur during FCPXML structure validation.
///
/// Maps from `PipelineNeo.FCPXMLError` and `PipelineNeo.ValidationError` to
/// provide user-friendly error messages.
public enum FCPXMLValidationError: Error, LocalizedError {

    /// The FCPXML document could not be parsed (malformed XML).
    case parsingFailed(details: String)

    /// The document does not conform to the FCPXML structure.
    case invalidFormat

    /// The FCPXML version attribute is absent or not supported.
    case unsupportedVersion

    /// The FCPXML document failed structural validation against its DTD.
    case structureValidationFailed(details: String)

    /// A timecode value could not be converted to a valid time.
    case timecodeConversionFailed(details: String)

    /// An internal document operation failed.
    case documentOperationFailed(details: String)

    /// One or more timeline clips or assets failed semantic validation.
    case timelineValidationFailed(errors: [PipelineNeo.ValidationError])

    // MARK: LocalizedError

    public var errorDescription: String? {
        switch self {
        case .parsingFailed(let details):
            return "The FCPXML document could not be parsed: \(details)."
        case .invalidFormat:
            return "The document does not have a valid FCPXML structure."
        case .unsupportedVersion:
            return "The FCPXML version is not supported. Supported versions are 1.5 through 1.14."
        case .structureValidationFailed(let details):
            return "FCPXML DTD validation failed: \(details)."
        case .timecodeConversionFailed(let details):
            return "A timecode value could not be converted: \(details)."
        case .documentOperationFailed(let details):
            return "An internal document operation failed: \(details)."
        case .timelineValidationFailed(let errors):
            let summary = errors.map { $0.message }.joined(separator: "; ")
            return "Timeline validation failed with \(errors.count) error(s): \(summary)."
        }
    }

    // MARK: Mapping from PipelineNeo.FCPXMLError

    /// Creates a `FCPXMLValidationError` by mapping a `PipelineNeo.FCPXMLError`.
    public init(mappingFrom pipelineNeoError: PipelineNeo.FCPXMLError) {
        switch pipelineNeoError {
        case .parsingFailed(let underlying):
            self = .parsingFailed(details: underlying.localizedDescription)
        case .invalidFormat:
            self = .invalidFormat
        case .unsupportedVersion:
            self = .unsupportedVersion
        case .validationFailed(let message):
            self = .structureValidationFailed(details: message)
        case .timecodeConversionFailed(let message):
            self = .timecodeConversionFailed(details: message)
        case .documentOperationFailed(let message):
            self = .documentOperationFailed(details: message)
        }
    }

    /// Maps a `PipelineNeo.FCPXMLError` to a `FCPXMLValidationError`.
    public static func mapped(from pipelineNeoError: PipelineNeo.FCPXMLError) -> FCPXMLValidationError {
        FCPXMLValidationError(mappingFrom: pipelineNeoError)
    }

    /// Creates a `FCPXMLValidationError` from a list of `PipelineNeo.ValidationError` values.
    public init(mappingFrom validationErrors: [PipelineNeo.ValidationError]) {
        self = .timelineValidationFailed(errors: validationErrors)
    }
}

// MARK: - Convenience Error Conversion

extension Error {

    /// Converts this error to `FCPXMLExportError` if it is a PipelineNeo export error.
    public var asFCPXMLExportError: FCPXMLExportError? {
        (self as? PipelineNeo.FCPXMLExportError).map { FCPXMLExportError(mappingFrom: $0) }
    }

    /// Converts this error to `FCPXMLBundleExportError` if it is a PipelineNeo bundle error.
    public var asFCPXMLBundleExportError: FCPXMLBundleExportError? {
        (self as? PipelineNeo.FCPXMLBundleExportError).map { FCPXMLBundleExportError(mappingFrom: $0) }
    }

    /// Converts this error to `FCPXMLValidationError` if it is a PipelineNeo FCPXML error.
    public var asFCPXMLValidationError: FCPXMLValidationError? {
        (self as? PipelineNeo.FCPXMLError).map { FCPXMLValidationError(mappingFrom: $0) }
    }
}

// MARK: - Mapped Error Throwing Helper

/// Executes a throwing closure and remaps any PipelineNeo export errors to their
/// SwiftSecuencia equivalents before rethrowing.
///
/// This is the primary error-translation boundary. By wrapping calls inside
/// `remappingExportErrors`, callers only need to handle SwiftSecuencia error types
/// and never need to import PipelineNeo directly.
///
/// ```swift
/// let xml = try remappingExportErrors {
///     try pipelineNeoExporter.export(timeline: t, assets: a)
/// }
/// ```
///
/// - Parameter body: A throwing closure that may throw PipelineNeo export errors.
/// - Returns: The value returned by `body`.
/// - Throws: The SwiftSecuencia-mapped error if `body` throws a PipelineNeo error;
///           otherwise rethrows `body`'s original error unchanged.
@discardableResult
public func remappingExportErrors<T>(_ body: () throws -> T) throws -> T {
    do {
        return try body()
    } catch let error as PipelineNeo.FCPXMLExportError {
        throw FCPXMLExportError(mappingFrom: error)
    } catch let error as PipelineNeo.FCPXMLBundleExportError {
        throw FCPXMLBundleExportError(mappingFrom: error)
    } catch let error as PipelineNeo.FCPXMLError {
        throw FCPXMLValidationError(mappingFrom: error)
    }
}

/// Async variant of `remappingExportErrors(_:)`.
///
/// - Parameter body: An async throwing closure that may throw PipelineNeo export errors.
/// - Returns: The value returned by `body`.
/// - Throws: The SwiftSecuencia-mapped error if `body` throws a PipelineNeo error;
///           otherwise rethrows `body`'s original error unchanged.
@discardableResult
public func remappingExportErrors<T>(_ body: () async throws -> T) async throws -> T {
    do {
        return try await body()
    } catch let error as PipelineNeo.FCPXMLExportError {
        throw FCPXMLExportError(mappingFrom: error)
    } catch let error as PipelineNeo.FCPXMLBundleExportError {
        throw FCPXMLBundleExportError(mappingFrom: error)
    } catch let error as PipelineNeo.FCPXMLError {
        throw FCPXMLValidationError(mappingFrom: error)
    }
}

#endif // os(macOS)
