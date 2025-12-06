//
//  TimelineError.swift
//  SwiftSecuencia
//
//  Timeline-specific errors.
//

import Foundation

/// Errors that can occur during timeline operations.
public enum TimelineError: Error, Sendable, Equatable {

    /// The specified clip was not found on the timeline.
    case clipNotFound(clipId: UUID)

    /// The specified offset is outside the valid range.
    case invalidOffset(offset: Timecode, reason: String)

    /// The specified lane is invalid.
    case invalidLane(lane: Int, reason: String)

    /// The clip duration is invalid.
    case invalidDuration(duration: Timecode, reason: String)

    /// No available lane was found for the clip.
    case noAvailableLane(at: Timecode, duration: Timecode)

    /// A ripple operation would result in invalid clip positions.
    case rippleConflict(reason: String)

    /// The timeline format configuration is invalid.
    case invalidFormat(reason: String)

    /// The asset storage reference is invalid.
    case invalidAssetReference(storageId: UUID, reason: String)
}

// MARK: - LocalizedError

extension TimelineError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .clipNotFound(let clipId):
            return "Clip not found: \(clipId)"

        case .invalidOffset(let offset, let reason):
            return "Invalid offset \(offset): \(reason)"

        case .invalidLane(let lane, let reason):
            return "Invalid lane \(lane): \(reason)"

        case .invalidDuration(let duration, let reason):
            return "Invalid duration \(duration): \(reason)"

        case .noAvailableLane(let offset, let duration):
            return "No available lane at \(offset) for clip of duration \(duration)"

        case .rippleConflict(let reason):
            return "Ripple conflict: \(reason)"

        case .invalidFormat(let reason):
            return "Invalid format: \(reason)"

        case .invalidAssetReference(let storageId, let reason):
            return "Invalid asset reference \(storageId): \(reason)"
        }
    }
}

// MARK: - CustomStringConvertible

extension TimelineError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "Unknown timeline error"
    }
}
