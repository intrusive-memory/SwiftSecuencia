//
//  FCPXMLValidator.swift
//  SwiftSecuencia
//
//  Validates FCPXML documents and timelines before export.
//

#if os(macOS)

import Foundation
import SwiftData
import SwiftCompartido

/// Validates FCPXML documents and timelines.
///
/// The validator checks for common issues that would prevent successful
/// import into Final Cut Pro, including missing asset references, invalid
/// time values, and structural issues.
///
/// ## Basic Usage
///
/// ```swift
/// let validator = FCPXMLValidator()
/// let result = await validator.validate(timeline, modelContext: context)
///
/// if result.isValid {
///     print("Timeline is valid!")
/// } else {
///     print("Validation failed:")
///     print(result.detailedDescription)
/// }
/// ```
public struct FCPXMLValidator {

    public init() {}

    /// Validates a timeline before export.
    ///
    /// - Parameters:
    ///   - timeline: The timeline to validate.
    ///   - modelContext: SwiftData model context for accessing assets.
    /// - Returns: Validation result with errors and warnings.
    @MainActor
    public func validate(_ timeline: Timeline, modelContext: ModelContext) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Check 1: Timeline must not be empty
        if timeline.clips.isEmpty {
            errors.append(ValidationError(
                type: .emptyTimeline,
                message: "Timeline has no clips"
            ))
            // Can't continue validation if empty
            return ValidationResult(errors: errors, warnings: warnings)
        }

        // Check 2: Format must be valid
        if let format = timeline.videoFormat {
            if format.width <= 0 || format.height <= 0 {
                errors.append(ValidationError(
                    type: .invalidFormat,
                    message: "Video format has invalid dimensions: \(format.width)x\(format.height)"
                ))
            }
        } else {
            errors.append(ValidationError(
                type: .invalidFormat,
                message: "Timeline has no video format configured"
            ))
        }

        // Get all unique asset IDs referenced by clips
        let referencedAssetIDs = Set(timeline.clips.map { $0.assetStorageId })

        // Fetch all assets from storage to check references
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let allAssets: [TypedDataStorage]
        do {
            allAssets = try modelContext.fetch(descriptor)
        } catch {
            errors.append(ValidationError(
                type: .missingAssetReference,
                message: "Failed to fetch assets from storage: \(error.localizedDescription)"
            ))
            return ValidationResult(errors: errors, warnings: warnings)
        }

        let availableAssetIDs = Set(allAssets.map { $0.id })

        // Check 3: All asset references must resolve
        for assetID in referencedAssetIDs {
            if !availableAssetIDs.contains(assetID) {
                errors.append(ValidationError(
                    type: .missingAssetReference,
                    message: "Clip references missing asset",
                    context: ["assetId": assetID.uuidString]
                ))
            }
        }

        // Check 4: All time values must be non-negative
        for clip in timeline.clips {
            if clip.offset.value < 0 {
                errors.append(ValidationError(
                    type: .invalidTimeValue,
                    message: "Clip has negative offset",
                    context: [
                        "clipId": clip.id.uuidString,
                        "offset": clip.offset.fcpxmlString
                    ]
                ))
            }

            if clip.duration.value <= 0 {
                errors.append(ValidationError(
                    type: .invalidDuration,
                    message: "Clip has zero or negative duration",
                    context: [
                        "clipId": clip.id.uuidString,
                        "duration": clip.duration.fcpxmlString
                    ]
                ))
            }

            // Check for source start (must be non-negative)
            if clip.sourceStart.value < 0 {
                errors.append(ValidationError(
                    type: .invalidTimeValue,
                    message: "Clip has negative source start",
                    context: [
                        "clipId": clip.id.uuidString,
                        "sourceStart": clip.sourceStart.fcpxmlString
                    ]
                ))
            }
        }

        // Check 5: Clip durations should not exceed asset durations (warning only)
        for clip in timeline.clips {
            if let asset = allAssets.first(where: { $0.id == clip.assetStorageId }),
               let assetDuration = asset.durationSeconds {
                let clipDurationSeconds = clip.duration.seconds
                let sourceStartSeconds = clip.sourceStart.seconds

                if sourceStartSeconds + clipDurationSeconds > assetDuration + 0.001 { // Small tolerance for floating point
                    warnings.append(ValidationWarning(
                        type: .missingMetadata,
                        message: "Clip duration exceeds asset duration (may be trimmed)",
                        context: [
                            "clipId": clip.id.uuidString,
                            "assetId": clip.assetStorageId.uuidString,
                            "clipDuration": String(format: "%.3f", clipDurationSeconds),
                            "assetDuration": String(format: "%.3f", assetDuration)
                        ]
                    ))
                }
            }
        }

        // Check 6: Warn about overlapping clips on same lane
        let clipsByLane = Dictionary(grouping: timeline.clips, by: { $0.lane })
        for (lane, clipsOnLane) in clipsByLane {
            let sortedClips = clipsOnLane.sorted { $0.offset < $1.offset }

            for i in 0..<sortedClips.count - 1 {
                let currentClip = sortedClips[i]
                let nextClip = sortedClips[i + 1]

                let currentEnd = currentClip.offset + currentClip.duration
                if nextClip.offset < currentEnd {
                    warnings.append(ValidationWarning(
                        type: .overlappingClipsOnSameLane,
                        message: "Clips overlap on same lane (FCP will handle mixing)",
                        context: [
                            "lane": String(lane),
                            "clip1": currentClip.id.uuidString,
                            "clip2": nextClip.id.uuidString,
                            "overlap": (currentEnd - nextClip.offset).fcpxmlString
                        ]
                    ))
                }
            }
        }

        // Check 7: Warn about large timelines
        if timeline.clips.count > 1000 {
            warnings.append(ValidationWarning(
                type: .largeTimeline,
                message: "Timeline has \(timeline.clips.count) clips (may impact performance)"
            ))
        }

        // Check 8: Warn about unused assets (assets in storage but not on timeline)
        let unusedAssets = availableAssetIDs.subtracting(referencedAssetIDs)
        if !unusedAssets.isEmpty && unusedAssets.count < 50 { // Only warn if reasonable number
            for unusedAssetID in unusedAssets.prefix(10) { // Limit to first 10
                warnings.append(ValidationWarning(
                    type: .unusedAsset,
                    message: "Asset in storage but not used in timeline",
                    context: ["assetId": unusedAssetID.uuidString]
                ))
            }
        }

        return ValidationResult(errors: errors, warnings: warnings)
    }
}

#endif
