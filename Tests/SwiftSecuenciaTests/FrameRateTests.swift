import Testing
import Foundation
@testable import SwiftSecuencia

// MARK: - Frame Duration Tests

@Test func frameRate23_98Duration() async throws {
    let rate = FrameRate.fps23_98
    let duration = rate.frameDuration
    #expect(duration.value == 1001)
    #expect(duration.timescale == 24000)
}

@Test func frameRate24Duration() async throws {
    let rate = FrameRate.fps24
    let duration = rate.frameDuration
    #expect(duration.value == 100)
    #expect(duration.timescale == 2400)
}

@Test func frameRate25Duration() async throws {
    let rate = FrameRate.fps25
    let duration = rate.frameDuration
    #expect(duration.value == 100)
    #expect(duration.timescale == 2500)
}

@Test func frameRate29_97Duration() async throws {
    let rate = FrameRate.fps29_97
    let duration = rate.frameDuration
    #expect(duration.value == 1001)
    #expect(duration.timescale == 30000)
}

@Test func frameRate30Duration() async throws {
    let rate = FrameRate.fps30
    let duration = rate.frameDuration
    #expect(duration.value == 100)
    #expect(duration.timescale == 3000)
}

@Test func frameRate50Duration() async throws {
    let rate = FrameRate.fps50
    let duration = rate.frameDuration
    #expect(duration.value == 100)
    #expect(duration.timescale == 5000)
}

@Test func frameRate59_94Duration() async throws {
    let rate = FrameRate.fps59_94
    let duration = rate.frameDuration
    #expect(duration.value == 1001)
    #expect(duration.timescale == 60000)
}

@Test func frameRate60Duration() async throws {
    let rate = FrameRate.fps60
    let duration = rate.frameDuration
    #expect(duration.value == 100)
    #expect(duration.timescale == 6000)
}

// MARK: - Frames Per Second Tests

@Test func frameRate24FPS() async throws {
    let rate = FrameRate.fps24
    let fps = rate.framesPerSecond
    #expect(abs(fps - 24.0) < 0.001)
}

@Test func frameRate23_98FPS() async throws {
    let rate = FrameRate.fps23_98
    let fps = rate.framesPerSecond
    #expect(abs(fps - 23.976) < 0.001)
}

@Test func frameRate29_97FPS() async throws {
    let rate = FrameRate.fps29_97
    let fps = rate.framesPerSecond
    #expect(abs(fps - 29.97) < 0.01)
}

// MARK: - Drop Frame Tests

@Test func frameRateIsDropFrame() async throws {
    #expect(FrameRate.fps29_97.isDropFrame == true)
    #expect(FrameRate.fps59_94.isDropFrame == true)
    #expect(FrameRate.fps24.isDropFrame == false)
    #expect(FrameRate.fps30.isDropFrame == false)
    #expect(FrameRate.fps25.isDropFrame == false)
}

// MARK: - FCPXML Suffix Tests

@Test func frameRateFCPXMLSuffix() async throws {
    #expect(FrameRate.fps23_98.fcpxmlSuffix == "2398")
    #expect(FrameRate.fps24.fcpxmlSuffix == "24")
    #expect(FrameRate.fps25.fcpxmlSuffix == "25")
    #expect(FrameRate.fps29_97.fcpxmlSuffix == "2997")
    #expect(FrameRate.fps30.fcpxmlSuffix == "30")
    #expect(FrameRate.fps50.fcpxmlSuffix == "50")
    #expect(FrameRate.fps59_94.fcpxmlSuffix == "5994")
    #expect(FrameRate.fps60.fcpxmlSuffix == "60")
}

// MARK: - Custom Frame Rate Tests

@Test func frameRateCustom() async throws {
    let customDuration = Timecode(value: 1, timescale: 15)  // 15 fps
    let rate = FrameRate.custom(frameDuration: customDuration)
    #expect(rate.frameDuration == customDuration)
    #expect(abs(rate.framesPerSecond - 15.0) < 0.001)
}

// MARK: - From FPS Tests

@Test func frameRateFromFPSExact() async throws {
    let rate = FrameRate.from(fps: 24.0)
    #expect(rate == .fps24)
}

@Test func frameRateFromFPSApproximate() async throws {
    let rate = FrameRate.from(fps: 23.976)
    #expect(rate == .fps23_98)
}

@Test func frameRateFromFPS2997() async throws {
    let rate = FrameRate.from(fps: 29.97)
    #expect(rate == .fps29_97)
}

@Test func frameRateFromFPSCustom() async throws {
    let rate = FrameRate.from(fps: 15.0)
    if case .custom = rate {
        #expect(abs(rate.framesPerSecond - 15.0) < 0.001)
    } else {
        Issue.record("Expected custom frame rate")
    }
}

// MARK: - Description Tests

@Test func frameRateDescription() async throws {
    #expect(FrameRate.fps24.description == "24 fps")
    #expect(FrameRate.fps23_98.description == "23.98 fps")
    #expect(FrameRate.fps29_97.description == "29.97 fps")
}

// MARK: - Codable Tests

@Test func frameRateCodable() async throws {
    let original = FrameRate.fps24
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(FrameRate.self, from: data)
    #expect(decoded == original)
}

@Test func frameRateCustomCodable() async throws {
    let customDuration = Timecode(value: 1, timescale: 15)
    let original = FrameRate.custom(frameDuration: customDuration)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(FrameRate.self, from: data)
    #expect(decoded == original)
}

// MARK: - Equality Tests

@Test func frameRateEquality() async throws {
    #expect(FrameRate.fps24 == FrameRate.fps24)
    #expect(FrameRate.fps24 != FrameRate.fps25)
}
