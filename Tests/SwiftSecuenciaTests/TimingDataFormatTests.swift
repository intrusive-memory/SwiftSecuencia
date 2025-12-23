import Testing
@testable import SwiftSecuencia

/// Unit tests for TimingDataFormat enum
@Suite("TimingDataFormat Enum")
struct TimingDataFormatTests {

    @Test("TimingDataFormat has all expected cases")
    func allCasesExist() {
        // Verify all four cases exist
        let none: TimingDataFormat = .none
        let webvtt: TimingDataFormat = .webvtt
        let json: TimingDataFormat = .json
        let both: TimingDataFormat = .both

        // Just verifying compilation
        #expect(none == .none)
        #expect(webvtt == .webvtt)
        #expect(json == .json)
        #expect(both == .both)
    }

    @Test("TimingDataFormat is Sendable")
    func isSendable() {
        // Verify Sendable conformance compiles
        let format: TimingDataFormat = .webvtt
        Task {
            let _ = format  // Can be captured in Task
        }
    }

    @Test("TimingDataFormat default should be none")
    func defaultBehavior() {
        // In practice, .none is used as default in function signatures
        func testFunction(format: TimingDataFormat = .none) -> TimingDataFormat {
            format
        }

        #expect(testFunction() == .none)
    }

    @Test("TimingDataFormat cases are distinct")
    func casesAreDistinct() {
        let formats: [TimingDataFormat] = [.none, .webvtt, .json, .both]

        // All cases should be different
        for i in 0..<formats.count {
            for j in (i+1)..<formats.count {
                #expect(formats[i] != formats[j])
            }
        }
    }

    @Test("TimingDataFormat Equatable conformance")
    func equatableConformance() {
        #expect(TimingDataFormat.none == .none)
        #expect(TimingDataFormat.webvtt == .webvtt)
        #expect(TimingDataFormat.json == .json)
        #expect(TimingDataFormat.both == .both)

        #expect(TimingDataFormat.none != .webvtt)
        #expect(TimingDataFormat.webvtt != .json)
        #expect(TimingDataFormat.json != .both)
    }

    @Test("TimingDataFormat can be used in switch statements")
    func switchStatement() {
        let format: TimingDataFormat = .webvtt

        var result = ""
        switch format {
        case .none:
            result = "none"
        case .webvtt:
            result = "webvtt"
        case .json:
            result = "json"
        case .both:
            result = "both"
        }

        #expect(result == "webvtt")
    }

    @Test("TimingDataFormat can be stored in collections")
    func canBeStoredInCollections() {
        let formats: [TimingDataFormat] = [.none, .webvtt, .json, .both]
        #expect(formats.count == 4)
        #expect(formats[0] == .none)
        #expect(formats[1] == .webvtt)

        let set: Set<TimingDataFormat> = [.webvtt, .json, .webvtt]  // Duplicate .webvtt
        #expect(set.count == 2)  // Should have only 2 unique values
    }

    @Test("TimingDataFormat documentation scenarios")
    func documentationScenarios() {
        // Scenario 1: No timing data needed
        let format1: TimingDataFormat = .none
        #expect(format1 == .none)

        // Scenario 2: Web player with native TextTrack API
        let format2: TimingDataFormat = .webvtt
        #expect(format2 == .webvtt)

        // Scenario 3: Custom parser or programmatic access
        let format3: TimingDataFormat = .json
        #expect(format3 == .json)

        // Scenario 4: Need both for web player + custom processing
        let format4: TimingDataFormat = .both
        #expect(format4 == .both)
    }
}
