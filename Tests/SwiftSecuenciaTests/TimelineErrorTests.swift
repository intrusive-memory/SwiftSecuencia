import Testing
import Foundation
@testable import SwiftSecuencia

// MARK: - TimelineError Tests

@Test func timelineErrorClipNotFound() async throws {
    let clipId = UUID()
    let error = TimelineError.clipNotFound(clipId: clipId)

    #expect(error.errorDescription?.contains("not found") == true)
    #expect(error.description.contains("not found"))
}

@Test func timelineErrorInvalidOffset() async throws {
    let error = TimelineError.invalidOffset(offset: Timecode(seconds: -5), reason: "Negative offset")

    #expect(error.errorDescription?.contains("Invalid offset") == true)
    #expect(error.errorDescription?.contains("Negative offset") == true)
}

@Test func timelineErrorInvalidLane() async throws {
    let error = TimelineError.invalidLane(lane: 100, reason: "Lane out of range")

    #expect(error.errorDescription?.contains("Invalid lane") == true)
    #expect(error.errorDescription?.contains("100") == true)
}

@Test func timelineErrorInvalidDuration() async throws {
    let error = TimelineError.invalidDuration(duration: Timecode(seconds: 0), reason: "Zero duration")

    #expect(error.errorDescription?.contains("Invalid duration") == true)
}

@Test func timelineErrorNoAvailableLane() async throws {
    let error = TimelineError.noAvailableLane(at: Timecode(seconds: 5), duration: Timecode(seconds: 10))

    #expect(error.errorDescription?.contains("No available lane") == true)
}

@Test func timelineErrorRippleConflict() async throws {
    let error = TimelineError.rippleConflict(reason: "Would create negative offset")

    #expect(error.errorDescription?.contains("Ripple conflict") == true)
}

@Test func timelineErrorInvalidFormat() async throws {
    let error = TimelineError.invalidFormat(reason: "Missing video format")

    #expect(error.errorDescription?.contains("Invalid format") == true)
}

@Test func timelineErrorInvalidAssetReference() async throws {
    let storageId = UUID()
    let error = TimelineError.invalidAssetReference(storageId: storageId, reason: "Asset not found")

    #expect(error.errorDescription?.contains("Invalid asset reference") == true)
}

@Test func timelineErrorEquatable() async throws {
    let id1 = UUID()
    let id2 = UUID()

    let error1 = TimelineError.clipNotFound(clipId: id1)
    let error2 = TimelineError.clipNotFound(clipId: id1)
    let error3 = TimelineError.clipNotFound(clipId: id2)

    #expect(error1 == error2)
    #expect(error1 != error3)
}
