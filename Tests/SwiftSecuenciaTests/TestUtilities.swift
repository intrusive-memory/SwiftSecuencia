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

    // Wait with timeout to prevent hangs in CI
    let deadline = Date().addingTimeInterval(30)
    while process.isRunning && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.1)
    }
    if process.isRunning {
      process.terminate()
      throw TestUtilitiesError.audioGenerationTimedOut
    }

    guard process.terminationStatus == 0 else {
      throw TestUtilitiesError.audioGenerationFailed
    }

    // Read the generated audio file
    let data = try Data(contentsOf: tempFile)

    // Clean up
    try? FileManager.default.removeItem(at: tempFile)

    return data
  }

  /// Generates real audio data using macOS `say` command with ALAC encoding.
  ///
  /// This variant generates M4A audio with enough words to approximate the
  /// requested duration (approximately 2 words per second).
  ///
  /// - Parameters:
  ///   - duration: Approximate duration in seconds (default: 1.0).
  /// - Returns: Audio file data in ALAC/M4A format.
  static func generateAudioData(duration: Double = 1.0) throws -> Data {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".m4a")

    // Generate enough words to fill the duration (approx 2 words per second)
    let wordCount = max(Int(duration * 2), 1)
    let text = Array(repeating: "test", count: wordCount).joined(separator: " ")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = ["-o", tempURL.path, "--data-format=alac", text]

    try process.run()

    // Wait with timeout to prevent hangs in CI
    let deadline = Date().addingTimeInterval(30)
    while process.isRunning && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.1)
    }
    if process.isRunning {
      process.terminate()
      throw TestUtilitiesError.audioGenerationTimedOut
    }

    guard process.terminationStatus == 0 else {
      throw TestUtilitiesError.audioGenerationFailed
    }

    let data = try Data(contentsOf: tempURL)
    try? FileManager.default.removeItem(at: tempURL)

    return data
  }

  enum TestUtilitiesError: Error {
    case audioGenerationFailed
    case audioGenerationTimedOut
  }
}
