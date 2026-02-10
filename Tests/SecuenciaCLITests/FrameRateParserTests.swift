import Testing
import Foundation
@testable import SecuenciaCLI
@testable import SwiftSecuencia

struct FrameRateParserTests {
    let parser = FrameRateParser()

    // MARK: - Standard Frame Rates

    @Test func parse23_98() throws {
        let result = try parser.parse("23.98")
        #expect(result == .fps23_98)
    }

    @Test func parse24() throws {
        let result = try parser.parse("24")
        #expect(result == .fps24)
    }

    @Test func parse25() throws {
        let result = try parser.parse("25")
        #expect(result == .fps25)
    }

    @Test func parse29_97() throws {
        let result = try parser.parse("29.97")
        #expect(result == .fps29_97)
    }

    @Test func parse30() throws {
        let result = try parser.parse("30")
        #expect(result == .fps30)
    }

    @Test func parse50() throws {
        let result = try parser.parse("50")
        #expect(result == .fps50)
    }

    @Test func parse59_94() throws {
        let result = try parser.parse("59.94")
        #expect(result == .fps59_94)
    }

    @Test func parse60() throws {
        let result = try parser.parse("60")
        #expect(result == .fps60)
    }

    // MARK: - Error Cases

    @Test func parseThrowsOnUnrecognizedValue() {
        #expect(throws: FrameRateParserError.self) {
            _ = try parser.parse("48")
        }
    }

    @Test func parseThrowsWithDescriptiveError() {
        do {
            _ = try parser.parse("100")
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as FrameRateParserError {
            switch error {
            case .unrecognizedValue(let value, let validValues):
                #expect(value == "100")
                #expect(validValues.count == 8)
                #expect(validValues.contains("23.98"))
                #expect(validValues.contains("60"))
            }
        } catch {
            #expect(Bool(false), "Expected FrameRateParserError, got \(error)")
        }
    }
}
