import Testing
import Foundation
@testable import SecuenciaCLICore

@Suite("MediaProbe MIME Type Tests")
struct MediaProbeMIMETypeTests {

    let probe = MediaProbe()

    // MARK: - Video MIME Types

    @Test func mimeTypeForMOV() {
        let url = URL(fileURLWithPath: "/path/to/video.mov")
        #expect(probe.mimeType(of: url) == "video/quicktime")
    }

    @Test func mimeTypeForMP4() {
        let url = URL(fileURLWithPath: "/path/to/video.mp4")
        #expect(probe.mimeType(of: url) == "video/mp4")
    }

    @Test func mimeTypeForM4V() {
        let url = URL(fileURLWithPath: "/path/to/video.m4v")
        #expect(probe.mimeType(of: url) == "video/x-m4v")
    }

    // MARK: - Audio MIME Types

    @Test func mimeTypeForM4A() {
        let url = URL(fileURLWithPath: "/path/to/audio.m4a")
        #expect(probe.mimeType(of: url) == "audio/mp4")
    }

    @Test func mimeTypeForMP3() {
        let url = URL(fileURLWithPath: "/path/to/audio.mp3")
        #expect(probe.mimeType(of: url) == "audio/mpeg")
    }

    @Test func mimeTypeForWAV() {
        let url = URL(fileURLWithPath: "/path/to/audio.wav")
        #expect(probe.mimeType(of: url) == "audio/wav")
    }

    @Test func mimeTypeForAIFF() {
        let url = URL(fileURLWithPath: "/path/to/audio.aiff")
        #expect(probe.mimeType(of: url) == "audio/aiff")
    }

    @Test func mimeTypeForAIF() {
        let url = URL(fileURLWithPath: "/path/to/audio.aif")
        #expect(probe.mimeType(of: url) == "audio/aiff")
    }

    // MARK: - Image MIME Types

    @Test func mimeTypeForPNG() {
        let url = URL(fileURLWithPath: "/path/to/image.png")
        #expect(probe.mimeType(of: url) == "image/png")
    }

    @Test func mimeTypeForJPG() {
        let url = URL(fileURLWithPath: "/path/to/image.jpg")
        #expect(probe.mimeType(of: url) == "image/jpeg")
    }

    @Test func mimeTypeForJPEG() {
        let url = URL(fileURLWithPath: "/path/to/image.jpeg")
        #expect(probe.mimeType(of: url) == "image/jpeg")
    }

    @Test func mimeTypeForTIFF() {
        let url = URL(fileURLWithPath: "/path/to/image.tiff")
        #expect(probe.mimeType(of: url) == "image/tiff")
    }

    @Test func mimeTypeForTIF() {
        let url = URL(fileURLWithPath: "/path/to/image.tif")
        #expect(probe.mimeType(of: url) == "image/tiff")
    }

    // MARK: - Unknown Extensions

    @Test func mimeTypeForUnknownExtension() {
        let url = URL(fileURLWithPath: "/path/to/file.xyz")
        #expect(probe.mimeType(of: url) == "application/octet-stream")
    }

    @Test func mimeTypeForNoExtension() {
        let url = URL(fileURLWithPath: "/path/to/file")
        #expect(probe.mimeType(of: url) == "application/octet-stream")
    }

    // MARK: - Case Insensitivity

    @Test func mimeTypeIsCaseInsensitive() {
        let urlUpper = URL(fileURLWithPath: "/path/to/video.MOV")
        let urlLower = URL(fileURLWithPath: "/path/to/video.mov")

        #expect(probe.mimeType(of: urlUpper) == "video/quicktime")
        #expect(probe.mimeType(of: urlLower) == "video/quicktime")
    }
}

// Note: Duration probing tests (Parts B & C) will be added in Sprint 8
// when real media fixtures are available. For now, we verify the API exists.
@Suite("MediaProbe Duration API Tests")
struct MediaProbeDurationAPITests {

    let probe = MediaProbe()

    @Test func durationMethodExists() async throws {
        // This test verifies the duration(of:) method compiles and exists.
        // Full integration testing with real media files happens in Sprint 8.

        // Create a minimal test file (not a real media file, will fail to probe)
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
        try "test".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Expect this to throw because it's not a valid media file
        // We're just verifying the method signature is correct
        do {
            _ = try await probe.duration(of: tempFile)
            Issue.record("Expected duration probing to fail on non-media file")
        } catch {
            // Expected - not a real media file
        }
    }

    @Test func probeMissingDurationsMethodExists() async throws {
        // This test verifies the probeMissingDurations(in:) method compiles.
        // Full testing with real media files happens in Sprint 8.

        let definition = TimelineDefinition(
            timeline: TimelineConfig(
                name: "Test",
                format: FormatConfig(width: 1920, height: 1080, frameRate: "24", colorSpace: "rec709"),
                audio: AudioConfig(layout: "stereo", rate: "48kHz")
            ),
            clips: []
        )

        // Should handle empty clips array without error
        let result = try await probe.probeMissingDurations(in: definition)
        #expect(result.clips.isEmpty)
    }
}
