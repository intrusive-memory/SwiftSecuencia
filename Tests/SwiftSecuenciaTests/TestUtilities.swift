//
//  TestUtilities.swift
//  SwiftSecuencia
//
//  Shared test utilities for generating fixtures.
//

import Foundation

/// Utilities for generating test fixtures
enum TestUtilities {

    /// Generates real audio data using macOS `say` command.
    ///
    /// This creates actual audio files that can be processed by AVFoundation,
    /// which is necessary for testing audio conversion functionality.
    ///
    /// - Parameters:
    ///   - text: Text to synthesize (default: "Test audio").
    ///   - format: Audio format - "aiff", "wav", or "m4a" (default: "aiff").
    /// - Returns: Audio file data.
    static func generateAudioData(text: String = "Test audio", format: String = "aiff") throws -> Data {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(format)

        // Use macOS `say` command to generate audio
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-o", tempFile.path, text]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TestUtilitiesError.audioGenerationFailed
        }

        // Read the generated audio file
        let data = try Data(contentsOf: tempFile)

        // Clean up
        try? FileManager.default.removeItem(at: tempFile)

        return data
    }

    enum TestUtilitiesError: Error {
        case audioGenerationFailed
    }
}
