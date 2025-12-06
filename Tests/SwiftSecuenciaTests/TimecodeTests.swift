import Testing
import Foundation
@testable import SwiftSecuencia

// MARK: - Initialization Tests

@Test func timecodeInitWithRationalValue() async throws {
    let tc = Timecode(value: 1001, timescale: 30000)
    #expect(tc.value == 1001)
    #expect(tc.timescale == 30000)
}

@Test func timecodeInitWithSeconds() async throws {
    let tc = Timecode(seconds: 5.0)
    #expect(tc.seconds == 5.0)
}

@Test func timecodeInitWithSecondsCustomTimescale() async throws {
    let tc = Timecode(seconds: 2.5, preferredTimescale: 1000)
    #expect(tc.value == 2500)
    #expect(tc.timescale == 1000)
}

@Test func timecodeInitWithFrames24fps() async throws {
    let tc = Timecode(frames: 24, frameRate: .fps24)
    // 24 frames at 24fps = 1 second
    #expect(abs(tc.seconds - 1.0) < 0.0001)
}

@Test func timecodeInitWithFrames2997fps() async throws {
    let tc = Timecode(frames: 30, frameRate: .fps29_97)
    // 30 frames at 29.97fps ≈ 1.001 seconds
    let expectedSeconds = 30.0 * (1001.0 / 30000.0)
    #expect(abs(tc.seconds - expectedSeconds) < 0.0001)
}

@Test func timecodeZero() async throws {
    let tc = Timecode.zero
    #expect(tc.value == 0)
    #expect(tc.seconds == 0.0)
}

// MARK: - FCPXML String Tests

@Test func timecodeFCPXMLStringZero() async throws {
    let tc = Timecode.zero
    #expect(tc.fcpxmlString == "0s")
}

@Test func timecodeFCPXMLStringWholeSeconds() async throws {
    let tc = Timecode(seconds: 5.0, preferredTimescale: 1)
    #expect(tc.fcpxmlString == "5s")
}

@Test func timecodeFCPXMLStringFractional() async throws {
    let tc = Timecode(value: 1001, timescale: 30000)
    #expect(tc.fcpxmlString == "1001/30000s")
}

@Test func timecodeFCPXMLStringSimplifies() async throws {
    // 2/4 should simplify to 1/2
    let tc = Timecode(value: 2, timescale: 4)
    #expect(tc.fcpxmlString == "1/2s")
}

// MARK: - Parsing Tests

@Test func timecodeParseWholeSeconds() async throws {
    let tc = Timecode(fcpxmlString: "5s")
    #expect(tc != nil)
    #expect(tc?.value == 5)
    #expect(tc?.timescale == 1)
}

@Test func timecodeParseFractional() async throws {
    let tc = Timecode(fcpxmlString: "1001/30000s")
    #expect(tc != nil)
    #expect(tc?.value == 1001)
    #expect(tc?.timescale == 30000)
}

@Test func timecodeParseZero() async throws {
    let tc = Timecode(fcpxmlString: "0s")
    #expect(tc != nil)
    #expect(tc?.value == 0)
}

@Test func timecodeParseInvalidNoSuffix() async throws {
    let tc = Timecode(fcpxmlString: "5")
    #expect(tc == nil)
}

@Test func timecodeParseInvalidFormat() async throws {
    let tc = Timecode(fcpxmlString: "invalid")
    #expect(tc == nil)
}

// MARK: - Arithmetic Tests

@Test func timecodeAddition() async throws {
    let tc1 = Timecode(seconds: 2.0, preferredTimescale: 600)
    let tc2 = Timecode(seconds: 3.0, preferredTimescale: 600)
    let sum = tc1 + tc2
    #expect(abs(sum.seconds - 5.0) < 0.0001)
}

@Test func timecodeAdditionDifferentTimescales() async throws {
    let tc1 = Timecode(value: 1, timescale: 2)   // 0.5 seconds
    let tc2 = Timecode(value: 1, timescale: 4)   // 0.25 seconds
    let sum = tc1 + tc2
    #expect(abs(sum.seconds - 0.75) < 0.0001)
}

@Test func timecodeSubtraction() async throws {
    let tc1 = Timecode(seconds: 5.0, preferredTimescale: 600)
    let tc2 = Timecode(seconds: 2.0, preferredTimescale: 600)
    let diff = tc1 - tc2
    #expect(abs(diff.seconds - 3.0) < 0.0001)
}

@Test func timecodeMultiplication() async throws {
    let tc = Timecode(seconds: 2.0, preferredTimescale: 600)
    let result = tc * 3
    #expect(abs(result.seconds - 6.0) < 0.0001)
}

@Test func timecodeMultiplicationReversed() async throws {
    let tc = Timecode(seconds: 2.0, preferredTimescale: 600)
    let result = 3 * tc
    #expect(abs(result.seconds - 6.0) < 0.0001)
}

// MARK: - Comparison Tests

@Test func timecodeCompareLessThan() async throws {
    let tc1 = Timecode(seconds: 2.0, preferredTimescale: 600)
    let tc2 = Timecode(seconds: 3.0, preferredTimescale: 600)
    #expect(tc1 < tc2)
}

@Test func timecodeCompareGreaterThan() async throws {
    let tc1 = Timecode(seconds: 3.0, preferredTimescale: 600)
    let tc2 = Timecode(seconds: 2.0, preferredTimescale: 600)
    #expect(tc1 > tc2)
}

@Test func timecodeCompareEqual() async throws {
    let tc1 = Timecode(value: 1, timescale: 2)
    let tc2 = Timecode(value: 2, timescale: 4)
    // Both represent 0.5 seconds, but are they equal?
    // Our comparison uses cross-multiplication, so they should compare as equal
    #expect(!(tc1 < tc2))
    #expect(!(tc1 > tc2))
}

@Test func timecodeCompareDifferentTimescales() async throws {
    let tc1 = Timecode(value: 1, timescale: 2)   // 0.5 seconds
    let tc2 = Timecode(value: 1, timescale: 4)   // 0.25 seconds
    #expect(tc1 > tc2)
}

// MARK: - Equality Tests

@Test func timecodeEquality() async throws {
    let tc1 = Timecode(value: 1001, timescale: 30000)
    let tc2 = Timecode(value: 1001, timescale: 30000)
    #expect(tc1 == tc2)
}

@Test func timecodeInequalityValue() async throws {
    let tc1 = Timecode(value: 1001, timescale: 30000)
    let tc2 = Timecode(value: 1002, timescale: 30000)
    #expect(tc1 != tc2)
}

@Test func timecodeInequalityTimescale() async throws {
    let tc1 = Timecode(value: 1001, timescale: 30000)
    let tc2 = Timecode(value: 1001, timescale: 24000)
    #expect(tc1 != tc2)
}

// MARK: - Codable Tests

@Test func timecodeCodable() async throws {
    let original = Timecode(value: 1001, timescale: 30000)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Timecode.self, from: data)
    #expect(decoded == original)
}

// MARK: - Description Tests

@Test func timecodeDescription() async throws {
    let tc = Timecode(value: 1001, timescale: 30000)
    #expect(tc.description == "1001/30000s")
}
