import Testing
import Foundation
@testable import SwiftSecuencia

// MARK: - Initialization Tests

@Test func videoFormatInit() async throws {
    let format = VideoFormat(
        width: 1920,
        height: 1080,
        frameRate: .fps24,
        colorSpace: .rec709
    )
    #expect(format.width == 1920)
    #expect(format.height == 1080)
    #expect(format.frameRate == .fps24)
    #expect(format.colorSpace == .rec709)
    #expect(format.interlaced == false)
}

@Test func videoFormatInterlaced() async throws {
    let format = VideoFormat(
        width: 1920,
        height: 1080,
        frameRate: .fps29_97,
        colorSpace: .rec709,
        interlaced: true
    )
    #expect(format.interlaced == true)
}

// MARK: - Static Constructors Tests

@Test func videoFormatHD1080p() async throws {
    let format = VideoFormat.hd1080p(frameRate: .fps24)
    #expect(format.width == 1920)
    #expect(format.height == 1080)
    #expect(format.frameRate == .fps24)
    #expect(format.colorSpace == .rec709)
}

@Test func videoFormatHD720p() async throws {
    let format = VideoFormat.hd720p(frameRate: .fps30)
    #expect(format.width == 1280)
    #expect(format.height == 720)
    #expect(format.frameRate == .fps30)
}

@Test func videoFormatUHD4K() async throws {
    let format = VideoFormat.uhd4K(frameRate: .fps24)
    #expect(format.width == 3840)
    #expect(format.height == 2160)
    #expect(format.colorSpace == .rec2020)  // Default for UHD
}

@Test func videoFormatDCI4K() async throws {
    let format = VideoFormat.dci4K(frameRate: .fps24)
    #expect(format.width == 4096)
    #expect(format.height == 2160)
    #expect(format.colorSpace == .rec2020)
}

// MARK: - Computed Properties Tests

@Test func videoFormatAspectRatio16x9() async throws {
    let format = VideoFormat.hd1080p(frameRate: .fps24)
    let aspect = format.aspectRatio
    #expect(abs(aspect - (16.0 / 9.0)) < 0.01)
}

@Test func videoFormatFrameDuration() async throws {
    let format = VideoFormat.hd1080p(frameRate: .fps24)
    let duration = format.frameDuration
    #expect(duration == FrameRate.fps24.frameDuration)
}

@Test func videoFormatIsHD() async throws {
    #expect(VideoFormat.hd1080p(frameRate: .fps24).isHD == true)
    #expect(VideoFormat.hd720p(frameRate: .fps24).isHD == true)
    #expect(VideoFormat.uhd4K(frameRate: .fps24).isHD == false)
}

@Test func videoFormatIsUHD() async throws {
    #expect(VideoFormat.uhd4K(frameRate: .fps24).isUHD == true)
    #expect(VideoFormat.dci4K(frameRate: .fps24).isUHD == true)
    #expect(VideoFormat.hd1080p(frameRate: .fps24).isUHD == false)
}

// MARK: - FCPXML Format Name Tests

@Test func videoFormatFCPXMLName1080p24() async throws {
    let format = VideoFormat.hd1080p(frameRate: .fps24)
    #expect(format.fcpxmlFormatName == "FFVideoFormat1080p24")
}

@Test func videoFormatFCPXMLName1080p2398() async throws {
    let format = VideoFormat.hd1080p(frameRate: .fps23_98)
    #expect(format.fcpxmlFormatName == "FFVideoFormat1080p2398")
}

@Test func videoFormatFCPXMLName720p30() async throws {
    let format = VideoFormat.hd720p(frameRate: .fps30)
    #expect(format.fcpxmlFormatName == "FFVideoFormat720p30")
}

@Test func videoFormatFCPXMLName4K() async throws {
    let format = VideoFormat.uhd4K(frameRate: .fps24)
    #expect(format.fcpxmlFormatName == "FFVideoFormat2160p24")
}

@Test func videoFormatFCPXMLNameDCI4K() async throws {
    let format = VideoFormat.dci4K(frameRate: .fps24)
    #expect(format.fcpxmlFormatName == "FFVideoFormat4096x2160p24")
}

@Test func videoFormatFCPXMLNameInterlaced() async throws {
    let format = VideoFormat(
        width: 1920,
        height: 1080,
        frameRate: .fps29_97,
        interlaced: true
    )
    #expect(format.fcpxmlFormatName == "FFVideoFormat1080i2997")
}

// MARK: - Codable Tests

@Test func videoFormatCodable() async throws {
    let original = VideoFormat.hd1080p(frameRate: .fps24, colorSpace: .rec709)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(VideoFormat.self, from: data)
    #expect(decoded == original)
}

// MARK: - Description Tests

@Test func videoFormatDescription() async throws {
    let format = VideoFormat.hd1080p(frameRate: .fps24)
    #expect(format.description == "1920×1080p @ 24 fps")
}

@Test func videoFormatDescriptionInterlaced() async throws {
    let format = VideoFormat(
        width: 1920,
        height: 1080,
        frameRate: .fps29_97,
        interlaced: true
    )
    #expect(format.description == "1920×1080i @ 29.97 fps")
}

// MARK: - ColorSpace Tests

@Test func colorSpaceFCPXMLValue() async throws {
    #expect(ColorSpace.rec709.fcpxmlValue == "1-1-1 (Rec. 709)")
    #expect(ColorSpace.rec2020.fcpxmlValue == "9-18-9 (Rec. 2020)")
    #expect(ColorSpace.rec2020HLG.fcpxmlValue == "9-18-9 (Rec. 2020 HLG)")
    #expect(ColorSpace.rec2020PQ.fcpxmlValue == "9-18-9 (Rec. 2020 PQ)")
    #expect(ColorSpace.sRGB.fcpxmlValue == "sRGB IEC61966-2.1")
}

@Test func colorSpaceIsHDR() async throws {
    #expect(ColorSpace.rec709.isHDR == false)
    #expect(ColorSpace.rec2020.isHDR == false)
    #expect(ColorSpace.rec2020HLG.isHDR == true)
    #expect(ColorSpace.rec2020PQ.isHDR == true)
    #expect(ColorSpace.sRGB.isHDR == false)
}

@Test func colorSpaceIsWideGamut() async throws {
    #expect(ColorSpace.rec709.isWideGamut == false)
    #expect(ColorSpace.rec2020.isWideGamut == true)
    #expect(ColorSpace.rec2020HLG.isWideGamut == true)
    #expect(ColorSpace.rec2020PQ.isWideGamut == true)
    #expect(ColorSpace.sRGB.isWideGamut == false)
}

// MARK: - AudioLayout Tests

@Test func audioLayoutChannelCount() async throws {
    #expect(AudioLayout.mono.channelCount == 1)
    #expect(AudioLayout.stereo.channelCount == 2)
    #expect(AudioLayout.surround.channelCount == 6)
    #expect(AudioLayout.surround7_1.channelCount == 8)
}

@Test func audioLayoutFCPXMLValue() async throws {
    #expect(AudioLayout.mono.fcpxmlValue == "mono")
    #expect(AudioLayout.stereo.fcpxmlValue == "stereo")
    #expect(AudioLayout.surround.fcpxmlValue == "surround")
    #expect(AudioLayout.surround7_1.fcpxmlValue == "7.1 surround")
}

// MARK: - AudioRate Tests

@Test func audioRateSampleRate() async throws {
    #expect(AudioRate.rate44_1kHz.sampleRate == 44100)
    #expect(AudioRate.rate48kHz.sampleRate == 48000)
    #expect(AudioRate.rate88_2kHz.sampleRate == 88200)
    #expect(AudioRate.rate96kHz.sampleRate == 96000)
}

@Test func audioRateFormattedString() async throws {
    #expect(AudioRate.rate48kHz.formattedString == "48 kHz")
    #expect(AudioRate.rate44_1kHz.formattedString == "44.1 kHz")
}

@Test func audioRateFromSampleRate() async throws {
    #expect(AudioRate(sampleRate: 48000) == .rate48kHz)
    #expect(AudioRate(sampleRate: 12345) == nil)
}

@Test func audioRateFromApproximateSampleRate() async throws {
    #expect(AudioRate.from(approximateSampleRate: 48000) == .rate48kHz)
    #expect(AudioRate.from(approximateSampleRate: 48100) == .rate48kHz)  // Within 1%
    #expect(AudioRate.from(approximateSampleRate: 12345) == nil)
}
