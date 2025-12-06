//
//  FCPXMLVersion.swift
//  Pipeline
//
//  Created for SwiftSecuencia
//  Copyright © 2025 SwiftSecuencia. All rights reserved.
//
//  MIT License - See PIPELINE-LICENSE.md file for original Pipeline license
//
import Foundation

/// Defines the supported FCPXML versions.
///
/// This enum provides type-safe version handling for FCPXML documents.
/// Each version corresponds to a DTD file in the Fixtures directory.
///
/// ## Version History
///
/// - **v1_8** (2017): Base version with captions support
/// - **v1_9** (2020): Media representations (proxy/original), 360° video support
/// - **v1_10** (2021): Locator resources, auxiliary video flags
/// - **v1_11** (2023): No structural changes from v1.10
/// - **v1_12** (2024): No structural changes from v1.11
/// - **v1_13** (2024): Stereo 3D support, hidden markers
///
/// ## Usage
///
/// ```swift
/// // Use the default (latest) version
/// let doc = XMLDocument(resources: [], events: [], fcpxmlVersion: .default)
///
/// // Use a specific version
/// let doc = XMLDocument(resources: [], events: [], fcpxmlVersion: .v1_11)
///
/// // Validate against a specific version
/// try doc.validateFCPXMLAgainst(version: .v1_13)
/// ```
public enum FCPXMLVersion: String, CaseIterable, Sendable {
	/// FCPXML version 1.8 (2017) - Caption support
	case v1_8 = "1.8"

	/// FCPXML version 1.9 (2020) - Media representations, 360° video
	case v1_9 = "1.9"

	/// FCPXML version 1.10 (2021) - Locator resources
	case v1_10 = "1.10"

	/// FCPXML version 1.11 (2023)
	case v1_11 = "1.11"

	/// FCPXML version 1.12 (2024)
	case v1_12 = "1.12"

	/// FCPXML version 1.13 (2024) - Stereo 3D support
	case v1_13 = "1.13"

	/// The default FCPXML version to use (always the latest).
	public static let `default`: FCPXMLVersion = .v1_13

	/// The version string suitable for FCPXML documents (e.g., "1.13").
	public var stringValue: String {
		return rawValue
	}

	/// The DTD filename without extension (e.g., "FCPXMLv1_13").
	public var dtdFilename: String {
		let versionUnderscored = rawValue.replacingOccurrences(of: ".", with: "_")
		return "FCPXMLv\(versionUnderscored)"
	}

	/// The DTD filename with extension (e.g., "FCPXMLv1_13.dtd").
	public var dtdFilenameWithExtension: String {
		return "\(dtdFilename).dtd"
	}

	/// Creates an FCPXMLVersion from a version string.
	///
	/// - Parameter string: The version string (e.g., "1.13" or "1_13").
	/// - Returns: The matching FCPXMLVersion, or nil if not found.
	public init?(string: String) {
		// Handle both "1.13" and "1_13" formats
		let normalized = string.replacingOccurrences(of: "_", with: ".")
		self.init(rawValue: normalized)
	}

	/// Creates an FCPXMLVersion from a DTD filename.
	///
	/// - Parameter filename: The DTD filename (e.g., "FCPXMLv1_13.dtd" or "FCPXMLv1_13").
	/// - Returns: The matching FCPXMLVersion, or nil if not found.
	public init?(dtdFilename filename: String) {
		// Remove extension if present
		let nameWithoutExtension = filename.replacingOccurrences(of: ".dtd", with: "")

		// Extract version from "FCPXMLv1_13" format
		guard nameWithoutExtension.hasPrefix("FCPXMLv") else {
			return nil
		}

		let versionPart = String(nameWithoutExtension.suffix(from: nameWithoutExtension.index(nameWithoutExtension.startIndex, offsetBy: 7)))

		// Convert underscores to dots
		let versionString = versionPart.replacingOccurrences(of: "_", with: ".")

		self.init(rawValue: versionString)
	}

	/// Compares this version with another version.
	///
	/// - Parameter other: The version to compare with.
	/// - Returns: True if this version is greater than or equal to the other version.
	public func isAtLeast(_ other: FCPXMLVersion) -> Bool {
		let allVersions = FCPXMLVersion.allCases
		guard let selfIndex = allVersions.firstIndex(of: self),
		      let otherIndex = allVersions.firstIndex(of: other) else {
			return false
		}
		return selfIndex >= otherIndex
	}

	/// Converts the version string to an array of three Int values.
	///
	/// - Returns: An array of [major, minor, patch] integers.
	public var versionArray: [Int] {
		var substringArray = rawValue.split(separator: ".")
		if substringArray.count == 1 {
			substringArray.append(contentsOf: ["0", "0"])
		} else if substringArray.count == 2 {
			substringArray.append("0")
		}
		return substringArray.map { Int($0) ?? 0 }
	}
}
