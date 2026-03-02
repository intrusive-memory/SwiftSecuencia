import Foundation
import Testing

@testable import SecuenciaCLICore

@Suite("ValidateCommand Tests")
struct ValidateCommandTests {

  /// Test that validating a valid timeline JSON exits successfully with summary
  @Test func validateValidTimelineSucceeds() async throws {
    let fixtureURL = try getFixtureURL("simple-timeline.json")

    var command = Validate()
    command.inputFile = fixtureURL.path

    // Should not throw
    try await command.run()

    // Expected output includes:
    // - "✅ Validation successful!"
    // - Timeline summary with name, format, clips by type
    // - Asset summary
    // - Lane range
  }

  /// Test that validating a nonexistent file exits with non-zero code
  @Test func validateNonexistentFileThrows() async throws {
    let nonexistentPath = "/tmp/nonexistent-\(UUID().uuidString).json"

    var command = Validate()
    command.inputFile = nonexistentPath

    // Should throw an error
    await #expect(throws: Error.self) {
      try await command.run()
    }
  }

  /// Test that validating malformed JSON exits with parse error
  @Test func validateMalformedJSONThrows() async throws {
    // Create a temporary malformed JSON file
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("malformed-\(UUID().uuidString).json")

    let malformedJSON = """
      {
        "timeline": {
          "name": "Bad JSON",
          "format": {
            "width": 1920,
            "height": 1080,
            "frameRate": "23.98"
          },
          "audio": {
            "layout": "stereo",
            "rate": "48kHz"
          }
        },
        "clips": [
          {
            "name": "Test Clip",
            "offset": "0s",
            "type": "video"
            // Missing closing brace - malformed
      }
      """

    try malformedJSON.write(to: tempURL, atomically: true, encoding: .utf8)
    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }

    var command = Validate()
    command.inputFile = tempURL.path

    // Should throw a parse error
    await #expect(throws: Error.self) {
      try await command.run()
    }
  }

  /// Test that validating JSON with missing required clip file throws
  @Test func validateMissingClipFileThrows() async throws {
    let fixtureURL = try getFixtureURL("missing-file.json")

    var command = Validate()
    command.inputFile = fixtureURL.path

    // Should throw when trying to resolve missing file
    await #expect(throws: Error.self) {
      try await command.run()
    }
  }

  /// Test that validation detects very short clips
  @Test func validateDetectsShortClips() async throws {
    // Create a timeline with a very short clip
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("short-clip-\(UUID().uuidString).json")

    // Create a test media file
    let mediaDir = tempURL.deletingLastPathComponent().appendingPathComponent("media")
    try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
    let testFile = mediaDir.appendingPathComponent("test.txt")
    try "test".write(to: testFile, atomically: true, encoding: .utf8)

    let shortClipJSON = """
      {
        "timeline": {
          "name": "Short Clip Test",
          "format": {
            "width": 1920,
            "height": 1080,
            "frameRate": "23.98"
          },
          "audio": {
            "layout": "stereo",
            "rate": "48kHz"
          }
        },
        "clips": [
          {
            "name": "Very Short",
            "file": "media/test.txt",
            "offset": "0s",
            "duration": "0.05s",
            "type": "image"
          }
        ]
      }
      """

    try shortClipJSON.write(to: tempURL, atomically: true, encoding: .utf8)
    defer {
      try? FileManager.default.removeItem(at: tempURL)
      try? FileManager.default.removeItem(at: mediaDir)
    }

    var command = Validate()
    command.inputFile = tempURL.path

    // Should succeed but print a warning about short clip
    try await command.run()
    // Expected: "⚠️  Warnings: - Clip 'Very Short' is very short (0.050s)"
  }

  // MARK: - Helpers

  private func getFixtureURL(_ name: String) throws -> URL {
    let fixturesDir = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures")

    let fixtureURL = fixturesDir.appendingPathComponent(name)

    guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
      throw TestError.fixtureNotFound(name)
    }

    return fixtureURL
  }

  enum TestError: Error {
    case fixtureNotFound(String)
  }
}
