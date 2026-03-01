import Foundation
import Testing

@testable import SecuenciaCLICore

struct TimeStringParserTests {
  let parser = TimeStringParser()

  // MARK: - Integer Seconds Tests

  @Test func parseIntegerSeconds_zero() throws {
    let result = try parser.parse("0s")
    #expect(result.seconds == 0.0)
  }

  @Test func parseIntegerSeconds_three() throws {
    let result = try parser.parse("3s")
    #expect(result.seconds == 3.0)
  }

  @Test func parseIntegerSeconds_large() throws {
    let result = try parser.parse("120s")
    #expect(result.seconds == 120.0)
  }

  // MARK: - Decimal Seconds Tests

  @Test func parseDecimalSeconds_threePointFive() throws {
    let result = try parser.parse("3.5s")
    #expect(result.seconds == 3.5)
  }

  @Test func parseDecimalSeconds_pointOne() throws {
    let result = try parser.parse("0.1s")
    #expect(result.seconds == 0.1)
  }

  @Test func parseDecimalSeconds_tenPointTwoFive() throws {
    let result = try parser.parse("10.25s")
    #expect(result.seconds == 10.25)
  }

  // MARK: - Rational Format Tests

  @Test func parseRationalFormat_ntsc() throws {
    let result = try parser.parse("1001/24000s")
    #expect(result.value == 1001)
    #expect(result.timescale == 24000)
  }

  @Test func parseRationalFormat_zero() throws {
    let result = try parser.parse("0/1s")
    #expect(result.value == 0)
    #expect(result.timescale == 1)
  }

  // MARK: - Error Cases

  @Test func parseThrowsOnNegativeValue() {
    #expect(throws: TimeStringParserError.self) {
      _ = try parser.parse("-3s")
    }
  }

  @Test func parseThrowsOnEmptyString() {
    #expect(throws: TimeStringParserError.self) {
      _ = try parser.parse("")
    }
  }

  @Test func parseThrowsOnMissingSuffix() {
    #expect(throws: TimeStringParserError.self) {
      _ = try parser.parse("3")
    }
  }

  @Test func parseThrowsOnNonsense() {
    #expect(throws: TimeStringParserError.self) {
      _ = try parser.parse("abc")
    }
  }
}
