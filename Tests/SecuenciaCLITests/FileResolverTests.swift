import Testing
import Foundation
@testable import SecuenciaCLI

@Suite("FileResolver Path Resolution Tests")
struct FileResolverPathResolutionTests {

    /// Test that relative paths resolve to absolute paths against the base URL.
    @Test func relativePathResolvesToAbsolute() throws {
        let resolver = FileResolver()

        // Load resolution-test.json fixture
        let fixturesURL = try fixtureURL()
        let jsonURL = fixturesURL.appendingPathComponent("resolution-test.json")
        let parser = JSONTimelineParser()
        let definition = try parser.parse(fileAt: jsonURL)

        // Resolve paths relative to the fixtures directory
        let resolved = try resolver.resolve(definition: definition, relativeTo: fixturesURL)

        // Verify the file path is now absolute
        let clip = try #require(resolved.clips.first)
        let filePath = try #require(clip.file)

        #expect(filePath.hasPrefix("/"))
        #expect(filePath.hasSuffix("media/exists.txt"))
        #expect(FileManager.default.fileExists(atPath: filePath))
    }

    /// Test that absolute paths pass through unchanged.
    @Test func absolutePathPassesThrough() throws {
        let resolver = FileResolver()

        // Create a clip with an absolute path
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "test".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let clip = ClipDefinition(
            name: "Test",
            file: tempFile.path,
            offset: "0s",
            duration: "1s",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
        )

        let definition = TimelineDefinition(
            timeline: TimelineConfig(
                name: "Test",
                format: FormatConfig(width: 1920, height: 1080, frameRate: "24", colorSpace: "rec709"),
                audio: AudioConfig(layout: "stereo", rate: "48kHz")
            ),
            clips: [clip]
        )

        let resolved = try resolver.resolve(definition: definition, relativeTo: URL(fileURLWithPath: "/"))

        // Verify path is unchanged
        let resolvedClip = try #require(resolved.clips.first)
        #expect(resolvedClip.file == tempFile.path)
    }

    /// Test that missing files throw an error with the full resolved path.
    @Test func missingFileThrowsWithResolvedPath() throws {
        let resolver = FileResolver()

        // Load missing-file.json fixture
        let fixturesURL = try fixtureURL()
        let jsonURL = fixturesURL.appendingPathComponent("missing-file.json")
        let parser = JSONTimelineParser()
        let definition = try parser.parse(fileAt: jsonURL)

        // Attempt to resolve - should throw
        #expect(throws: FileResolver.FileResolverError.self) {
            _ = try resolver.resolve(definition: definition, relativeTo: fixturesURL)
        }

        // Verify the error message contains the resolved path
        do {
            _ = try resolver.resolve(definition: definition, relativeTo: fixturesURL)
            Issue.record("Expected fileNotFound error")
        } catch let error as FileResolver.FileResolverError {
            if case .fileNotFound(let path) = error {
                #expect(path.hasPrefix("/"))
                #expect(path.contains("media/nope.mov"))
            } else {
                Issue.record("Wrong error case")
            }
        }
    }

    // MARK: - Helpers

    private func fixtureURL() throws -> URL {
        let bundle = Bundle.module
        guard let url = bundle.resourceURL?.appendingPathComponent("Fixtures") else {
            throw FileResolverTestError.fixturesNotFound
        }
        return url
    }

    enum FileResolverTestError: Error {
        case fixturesNotFound
    }
}

@Suite("FileResolver Asset Deduplication Tests")
struct FileResolverDeduplicationTests {

    /// Test that clips referencing the same file get the same UUID.
    @Test func sameFilePathProducesSameUUID() throws {
        let resolver = FileResolver()

        // Create two clips with the same file path
        let filePath = "/path/to/audio.m4a"
        let clip1 = ClipDefinition(
            name: "Clip 1",
            file: filePath,
            offset: "0s",
            duration: "5s",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
        )
        let clip2 = ClipDefinition(
            name: "Clip 2",
            file: filePath,
            offset: "5s",
            duration: "5s",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
        )

        let definition = TimelineDefinition(
            timeline: TimelineConfig(
                name: "Test",
                format: FormatConfig(width: 1920, height: 1080, frameRate: "24", colorSpace: "rec709"),
                audio: AudioConfig(layout: "stereo", rate: "48kHz")
            ),
            clips: [clip1, clip2]
        )

        let assetMap = resolver.deduplicateAssets(in: definition)

        // Should have exactly one entry
        #expect(assetMap.count == 1)

        // Both clips should map to the same UUID
        let uuid = try #require(assetMap[filePath])
        #expect(uuid == assetMap[filePath])
    }

    /// Test that different file paths produce different UUIDs.
    @Test func differentPathsProduceDifferentUUIDs() throws {
        let resolver = FileResolver()

        let clip1 = ClipDefinition(
            name: "Clip 1",
            file: "/path/to/audio1.m4a",
            offset: "0s",
            duration: "5s",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
        )
        let clip2 = ClipDefinition(
            name: "Clip 2",
            file: "/path/to/audio2.m4a",
            offset: "5s",
            duration: "5s",
            lane: 0,
            type: .audio,
            markerType: nil,
            volume: nil,
            opacity: nil
        )

        let definition = TimelineDefinition(
            timeline: TimelineConfig(
                name: "Test",
                format: FormatConfig(width: 1920, height: 1080, frameRate: "24", colorSpace: "rec709"),
                audio: AudioConfig(layout: "stereo", rate: "48kHz")
            ),
            clips: [clip1, clip2]
        )

        let assetMap = resolver.deduplicateAssets(in: definition)

        // Should have two distinct entries
        #expect(assetMap.count == 2)

        let uuid1 = try #require(assetMap["/path/to/audio1.m4a"])
        let uuid2 = try #require(assetMap["/path/to/audio2.m4a"])

        #expect(uuid1 != uuid2)
    }

    /// Test that deterministicUUID produces the same UUID for the same path.
    @Test func deterministicUUIDIsDeterministic() throws {
        let path = "/Users/test/media/audio.m4a"
        let uuid1 = FileResolver.deterministicUUID(for: path)
        let uuid2 = FileResolver.deterministicUUID(for: path)

        #expect(uuid1 == uuid2)
    }

    /// Test that deterministicUUID produces different UUIDs for different paths.
    @Test func deterministicUUIDDiffersByPath() throws {
        let uuid1 = FileResolver.deterministicUUID(for: "/path/a.mov")
        let uuid2 = FileResolver.deterministicUUID(for: "/path/b.mov")

        #expect(uuid1 != uuid2)
    }
}
