# SwiftSecuencia CLI — Execution Plan

> Add a command-line interface that reads a JSON timeline definition and produces FCPXML output for Final Cut Pro.

---

## Work Units

| Name | Directory | Sprints | Dependencies |
|------|-----------|---------|-------------|
| CLI Scaffold | Sources/SecuenciaCLI/ | 1 | none |
| JSON Parsing | Sources/SecuenciaCLI/ | 2 | CLI Scaffold |
| Asset Resolution | Sources/SwiftSecuencia/ | 2 | CLI Scaffold |
| CLI Pipeline | Sources/SecuenciaCLI/ | 3 | JSON Parsing, Asset Resolution |
| Validation | Tests/, Sources/SecuenciaCLI/ | 2 | CLI Pipeline |

**Dependency structure**: Graph (not strictly layered). See diagram below.

### Dependency Graph

```
Sprint 1 (CLI Scaffold)
   ├───────────────────────────┐
   ▼                           ▼
Sprint 2 (JSON parsing)    Sprint 4 (AssetProvider protocol)
   ▼                           ▼
Sprint 3 (file resolution) Sprint 5 (refactor exporters)
   │                           │
   └───────────┬───────────────┘
               ▼
         Sprint 6 (SwiftData bootstrap + TimelineBuilder)
               ▼
         Sprint 7 (build command integration)
               ▼
         Sprint 8 (end-to-end tests)
               ▼
         Sprint 9 (DTD validation)
               ▼
         Sprint 10 (validate + schema + docs)
```

**Parallel execution**: After Sprint 1 completes, Sprints 2-3 (JSON Parsing) and Sprints 4-5 (Asset Resolution) MUST run simultaneously as independent work units to maximize throughput. Sprint 6 waits for both branches to complete.

**⚠️ CRITICAL**: Sprint 5 (19 tasks, ~10h) is the bottleneck. Within Sprint 5, FCPXMLExporter track (5.1-5.7) and FCPXMLBundleExporter track (5.8-5.15) can run in parallel as independent sub-tracks.

---

## JSON Input Schema

The CLI accepts a JSON file describing a timeline. This schema is the contract between SwiftSecuencia and any tool that generates timeline definitions (Fountain parsers, automation scripts, other skills).

```json
{
  "timeline": {
    "name": "Tutorial Video",
    "format": {
      "width": 1920,
      "height": 1080,
      "frameRate": "23.98",
      "colorSpace": "rec709"
    },
    "audio": {
      "layout": "stereo",
      "rate": "48kHz"
    }
  },
  "clips": [
    {
      "name": "Title Card",
      "file": "media/title-card.png",
      "offset": "0s",
      "duration": "3s",
      "lane": 0,
      "type": "image"
    },
    {
      "name": "Act 1 Screen Recording",
      "file": "media/act1-screen.mov",
      "offset": "3s",
      "duration": "42s",
      "lane": 0,
      "type": "video"
    },
    {
      "name": "Act 1 Narration",
      "file": "media/act1-narration.m4a",
      "offset": "3s",
      "lane": -1,
      "type": "audio"
    },
    {
      "name": "Chapter 1",
      "offset": "0s",
      "type": "marker",
      "markerType": "chapter"
    }
  ]
}
```

### Schema Rules

- `file`: Relative to the JSON file's directory, or absolute path. After resolution, stored as absolute path string. Resolved at parse time.
- `offset`: Time string in FCPXML format — `"0s"`, `"3s"`, `"1001/24000s"` (rational), or `"10.5s"` (decimal seconds).
- `duration`: Same format as offset. Optional for audio/video — if omitted, the CLI probes the file to determine duration.
- `lane`: Integer. 0 = primary storyline. Positive = above (B-roll/titles). Negative = below (audio/music). Default: 0.
- `type`: One of `"video"`, `"audio"`, `"image"`, `"marker"`. Determines export behavior and MIME derivation.
- `markerType`: Only for `type: "marker"`. One of `"standard"`, `"chapter"`, `"todo"`.
- Clips without `duration` and `type: "audio"` or `type: "video"` require the file to exist so duration can be probed.
- Multiple clips referencing the same file share a single asset in the FCPXML output.

### MIME Type Derivation

The `type` field combined with the file extension determines MIME type and asset flags:

| type | hasVideo | hasAudio | MIME (by extension) |
|------|----------|----------|-------------------|
| `video` | true | true | `.mov` → `video/quicktime`, `.mp4` → `video/mp4` |
| `audio` | false | true | `.m4a` → `audio/mp4`, `.mp3` → `audio/mpeg`, `.wav` → `audio/wav`, `.aiff` → `audio/aiff` |
| `image` | true | false | `.png` → `image/png`, `.jpg`/`.jpeg` → `image/jpeg`, `.tiff` → `image/tiff` |
| `marker` | — | — | N/A (no file) |

---

## Work Unit: JSON Schema

### Sprint 1: Executable target and JSON model types

**Entry criteria**: None — first sprint.

**Tasks**:

1. **Package.swift setup**
   - Add to `Package.swift`:
     - Executable target `SecuenciaCLI` in `Sources/SecuenciaCLI/`
     - Dependency on `swift-argument-parser` (from `apple/swift-argument-parser`, version 1.3.0+)
     - Dependency on `SwiftSecuencia` library target
     - Dependency on `Pipeline` library target (macOS only — the CLI is macOS only)
     - Add `resources: [.process("Resources/")]` to the SecuenciaCLI target (needed later for schema.json)
   - Commit: "Add SecuenciaCLI executable target to Package.swift"

2. **Secuencia.swift entry point**
   - Create `Sources/SecuenciaCLI/Secuencia.swift` (**not** `main.swift`):
     - Import ArgumentParser
     - Define `Secuencia` as `@main` struct conforming to `ParsableCommand`
     - Subcommands: `Build` (generates FCPXML from JSON)
     - Version flag: `--version`
   - Commit: "Add Secuencia main entry point"

3. **BuildCommand stub**
   - Create `Sources/SecuenciaCLI/Commands/BuildCommand.swift`:
     - `struct Build: AsyncParsableCommand` with `commandName: "build"`
     - Arguments: `inputFile: String` (path to JSON file, positional)
     - Options: `--output <path>`, `--bundle`, `--format-version <version>`
     - Stub `run()` method that prints "Not yet implemented"
   - Commit: "Add BuildCommand stub"

4. **TimelineDefinition + ClipType enum**
   - Create `Sources/SecuenciaCLI/Models/TimelineDefinition.swift`:
     - `struct TimelineDefinition: Codable, Sendable`:
       - `timeline: TimelineConfig`
       - `clips: [ClipDefinition]`
     - `enum ClipType: String, Codable, Sendable`: `video`, `audio`, `image`, `marker`
   - Commit: "Add TimelineDefinition root struct and ClipType enum"

5. **Config structs (Timeline, Format, Audio)**
   - Extend `TimelineDefinition.swift`:
     - `struct TimelineConfig: Codable, Sendable`:
       - `name: String`, `format: FormatConfig`, `audio: AudioConfig`
     - `struct FormatConfig: Codable, Sendable`:
       - `width: Int`, `height: Int`, `frameRate: String`, `colorSpace: String?`
     - `struct AudioConfig: Codable, Sendable`:
       - `layout: String`, `rate: String`
   - Commit: "Add timeline configuration structs"

6. **ClipDefinition struct**
   - Extend `TimelineDefinition.swift`:
     - `struct ClipDefinition: Codable, Sendable`:
       - `name: String`, `file: String?`, `offset: String`, `duration: String?`
       - `lane: Int?`, `type: ClipType`, `markerType: String?`
       - `volume: Double?`, `opacity: Double?`
   - Commit: "Add ClipDefinition struct"

7. **TimelineDefinition tests - Decode/encode**
   - Create `Tests/SecuenciaCLITests/TimelineDefinitionTests.swift`:
     - Test: decode the example JSON from schema section
     - Test: encode and re-decode roundtrip preserves all fields
   - Commit: "Add TimelineDefinition decode/encode tests"

8. **TimelineDefinition tests - Validation**
   - Extend `TimelineDefinitionTests.swift`:
     - Test: missing optional fields decode to nil
     - Test: invalid `type` value produces `DecodingError`
   - Commit: "Add TimelineDefinition validation tests"

**Exit criteria** (all 8 tasks complete):
- [ ] `xcodebuild build -scheme SecuenciaCLI -destination 'platform=macOS'` succeeds
- [ ] `xcodebuild test -scheme SecuenciaCLI -destination 'platform=macOS'` — all tests pass
- [ ] Package.swift has SecuenciaCLI target with dependencies (Task 1)
- [ ] Secuencia @main entry point exists (Task 2)
- [ ] BuildCommand stub compiles (Task 3)
- [ ] TimelineDefinition + ClipType defined (Task 4)
- [ ] All config structs defined (Tasks 5-6)
- [ ] Decode/encode tests pass (Task 7)
- [ ] Validation tests pass (Task 8)
- [ ] Running `secuencia build --help` prints argument descriptions
- [ ] TimelineDefinition decodes the example JSON successfully

---

### Sprint 2: JSON parsing and time string parsing

**Entry criteria**: Sprint 1 exit criteria satisfied.

**Parallelization**:
- Phase 1: Task 0 (add Universal dependency) must complete first
- Phase 2: Tasks 1, 2, 3 can run in parallel (3 parser implementations)
- Phase 3: Tasks 4, 5, 6 can run in parallel (3 test files)

**Tasks**:
0. **Add Universal dependency to Package.swift**:
   - Add `.package(url: "https://github.com/marcprux/universal.git", from: "5.3.0")` to dependencies
   - Add `.product(name: "Universal", package: "universal")` to SecuenciaCLI target dependencies
   - Commit: "Add Universal package for multi-format parsing"

1. Create `Sources/SecuenciaCLI/Parsing/JSONTimelineParser.swift`:
   - `struct JSONTimelineParser`
   - Method `parse(fileAt url: URL) throws -> TimelineDefinition`:
     - Read data from file
     - Parse using Universal: `let json = try JSON.parse(data)`
     - Decode TimelineDefinition: `try TimelineDefinition(json: json)`
     - Validate required fields: `timeline.name`, `timeline.format`, `timeline.audio` must be present
     - For non-marker clips: `file` must be non-nil
     - For marker clips: `markerType` must be non-nil
   - This method does NOT resolve file paths or probe durations — that is Sprint 3
2. Create `Sources/SecuenciaCLI/Parsing/TimeStringParser.swift` (no changes from original plan):
   - `struct TimeStringParser`
   - Method `parse(_ string: String) throws -> Timecode`:
     - `"0s"`, `"3s"` → integer seconds
     - `"3.5s"`, `"10.25s"` → decimal seconds
     - `"1001/24000s"` → rational FCPXML format (numerator/denominator)
     - Negative values → throw with descriptive error
     - Empty string → throw with descriptive error
     - No `s` suffix → throw with descriptive error (must be explicit)
   - Return `Timecode` value from SwiftSecuencia
3. Create `Sources/SecuenciaCLI/Parsing/FrameRateParser.swift`:
   - `struct FrameRateParser`
   - Method `parse(_ string: String) throws -> FrameRate`:
     - `"23.98"` → `.fps23_98`
     - `"24"` → `.fps24`
     - `"25"` → `.fps25`
     - `"29.97"` → `.fps29_97`
     - `"30"` → `.fps30`
     - `"50"` → `.fps50`
     - `"59.94"` → `.fps59_94`
     - `"60"` → `.fps60`
     - Unrecognized value → throw with error listing valid values
4. Create `Tests/SecuenciaCLITests/TimeStringParserTests.swift`:
   - Test: integer seconds `"0s"`, `"3s"`, `"120s"`
   - Test: decimal seconds `"3.5s"`, `"0.1s"`, `"10.25s"`
   - Test: rational format `"1001/24000s"`, `"0/1s"`
   - Test: negative value `"-3s"` throws
   - Test: empty string throws
   - Test: missing suffix `"3"` throws
   - Test: nonsense `"abc"` throws
5. Create `Tests/SecuenciaCLITests/FrameRateParserTests.swift`:
   - Test: all 8 standard frame rates parse correctly
   - Test: unrecognized value throws with descriptive error
6. Create `Tests/SecuenciaCLITests/JSONTimelineParserTests.swift`:
   - Test: parse valid JSON file with all field types
   - Test: parse JSON with missing optional fields
   - Test: parse JSON with invalid clip type throws
   - Test: parse JSON with marker missing markerType throws
   - Test: parse nonexistent file throws

**Exit criteria**:
- [ ] Build succeeds
- [ ] All tests pass (7 tasks total: 0-6)
- [ ] Universal package dependency added to Package.swift (Task 0)
- [ ] JSONTimelineParser uses Universal's JSON.parse() (Task 1)
- [ ] Time strings `"0s"`, `"3.5s"`, and `"1001/24000s"` all parse to correct Timecode values
- [ ] All 8 standard frame rate strings parse to correct FrameRate values
- [ ] Invalid inputs produce descriptive errors (not crashes)

---

### Sprint 3: File resolution and media probing

**Entry criteria**: Sprint 2 exit criteria satisfied.

**Tasks**:
1. Create `Sources/SecuenciaCLI/Parsing/FileResolver.swift` - **Part A: Path resolution**
   - `struct FileResolver`
   - Method `resolve(definition: TimelineDefinition, relativeTo baseURL: URL) throws -> TimelineDefinition`:
     - For each clip with a non-nil `file` path:
       - If path starts with `/`: treat as absolute, verify file exists with `FileManager.fileExists(atPath:)`
       - Otherwise: resolve relative to `baseURL` (the JSON file's parent directory), verify exists
       - If file doesn't exist: throw error with the resolved absolute path
       - Store the resolved absolute path string back in `clip.file`
     - Return a new definition with all paths resolved to absolute path strings
2. Extend `FileResolver` - **Part B: Asset deduplication**
   - Add static method `deterministicUUID(for path: String) -> UUID` (see **Appendix B** for CryptoKit implementation)
   - Add method `deduplicateAssets(in definition: TimelineDefinition) -> [String: UUID]`:
     - Group clips by resolved file path
     - Assign one stable UUID per unique file path using `FileResolver.deterministicUUID(for:)`
     - Return mapping: absolute file path → UUID
3. Create `Sources/SecuenciaCLI/Parsing/MediaProbe.swift` - **Part A: MIME type detection**
   - `struct MediaProbe`
   - Method `mimeType(of fileURL: URL) -> String`:
     - Infer from file extension using the MIME Type Derivation table in the schema section
     - Unknown extension → `"application/octet-stream"` with a logged warning
4. Extend `MediaProbe` - **Part B: Single file duration probing**
   - Add method `duration(of fileURL: URL) async throws -> Double`:
     - Use `AVAsset(url:)` and `asset.load(.duration)` (modern async AVAsset API)
     - Return `CMTimeGetSeconds(duration)`
5. Extend `MediaProbe` - **Part C: Batch duration probing**
   - Add method `probeMissingDurations(in definition: TimelineDefinition) async throws -> TimelineDefinition`:
     - For each clip where `duration` is nil and `file` is non-nil:
       - Probe the file to get duration via `duration(of:)`
       - Set `clip.duration` to the probed value formatted as `"<seconds>s"`
     - Return updated definition
6. Create test fixture files (minimal — no ffmpeg needed):
   - `Tests/SecuenciaCLITests/Fixtures/resolution-test.json`: references `media/exists.txt`
   - `Tests/SecuenciaCLITests/Fixtures/media/exists.txt`: a 1-byte placeholder file (just for path resolution)
   - `Tests/SecuenciaCLITests/Fixtures/missing-file.json`: references `media/nope.mov`
7. Create `Tests/SecuenciaCLITests/FileResolverTests.swift` - **Part A: Path resolution tests**
   - Test: relative path resolves to absolute against base URL
   - Test: absolute path passes through unchanged
   - Test: missing file throws with the full resolved path in the error message
8. Extend `FileResolverTests` - **Part B: Asset deduplication tests**
   - Test: deduplicateAssets assigns same UUID for same file path
   - Test: deduplicateAssets assigns different UUIDs for different file paths
   - Test: same input always produces same UUIDs (determinism via deterministicUUID)
9. Create `Tests/SecuenciaCLITests/MediaProbeTests.swift` - **Parts A, B, C**
   - **Part A tests**: mimeType for `.mov`, `.mp4`, `.m4a`, `.mp3`, `.wav`, `.png`, `.jpg`, `.jpeg`
   - **Part A tests**: mimeType for unknown extension returns `"application/octet-stream"`
   - **Parts B & C tests**: duration probing deferred to end-to-end tests (requires real media fixture from Sprint 8)
10. Update `BuildCommand.run()`:
   - After parsing JSON: call resolve(), deduplicateAssets(), probeMissingDurations()
   - Print parsed timeline summary (clip count, unique assets, total duration, lanes used)
   - Still stub the FCPXML export step

**Exit criteria**:
- [ ] Build succeeds (all 10 tasks)
- [ ] All tests pass (FileResolverTests parts A & B, MediaProbeTests parts A, B, C)
- [ ] Running `secuencia build timeline.json` (with a valid JSON file containing existing files) prints a parsed timeline summary
- [ ] Relative file paths resolve correctly against the JSON file's directory (Task 1)
- [ ] Missing file path produces an error message including the resolved absolute path (Task 1)
- [ ] Two clips referencing the same file produce one shared UUID (Task 2)
- [ ] Same JSON input always produces the same UUIDs via deterministicUUID() (Task 2, Appendix B)
- [ ] MIME type detection works for all standard extensions (Task 3)
- [ ] Duration probing implementation complete (Tasks 4-5, full testing in Sprint 8)

---

## Work Unit: Asset Resolution

### Sprint 4: File-URL asset provider protocol

**Entry criteria**: Sprint 1 (CLI Scaffold) is COMPLETED. (Does NOT depend on Sprints 2-3 — can run in parallel with JSON Parsing work unit.)

**Tasks**:

1. **AssetMetadata struct**
   - Create `Sources/SwiftSecuencia/Export/AssetProvider.swift`
   - Define `struct AssetMetadata: Sendable, Codable`:
     - `id: UUID`, `name: String`, `mimeType: String`
     - `durationSeconds: Double?`
     - `hasVideo: Bool`, `hasAudio: Bool`
     - `width: Int?`, `height: Int?`
   - Commit: "Add AssetMetadata struct"

2. **AssetProvider protocol + error enum**
   - Extend `AssetProvider.swift`
   - Define `AssetProvider` protocol (NOT `Sendable`):
     ```swift
     public protocol AssetProvider {
         func assetMetadata(for id: UUID) throws -> AssetMetadata
         func assetFileURL(for id: UUID) throws -> URL
         func assetData(for id: UUID) throws -> Data
     }
     ```
   - Extension with default `assetData(for:)` implementation throws `AssetProviderError.dataNotSupported`
   - `enum AssetProviderError: LocalizedError`: `assetNotFound(UUID)`, `dataNotSupported`, `fileNotFound(UUID, URL)`
   - Commit: "Add AssetProvider protocol and error types"

3. **SwiftDataAssetProvider implementation**
   - Create `Sources/SwiftSecuencia/Export/SwiftDataAssetProvider.swift`
   - `@MainActor struct SwiftDataAssetProvider: AssetProvider`
   - Initialized with `ModelContext`
   - Implement all 3 protocol methods:
     - `assetMetadata(for:)`: Fetch TypedDataStorage, derive hasVideo/hasAudio from MIME prefix
     - `assetFileURL(for:)`: Return fileReference, throw if nil
     - `assetData(for:)`: Return binaryValue, throw if nil
   - Commit: "Add SwiftDataAssetProvider implementation"

4. **FileAssetProvider struct + initialization**
   - Create `Sources/SwiftSecuencia/Export/FileAssetProvider.swift`
   - `struct FileAssetProvider: AssetProvider, Sendable`
   - `struct FileAssetEntry: Sendable` with all fields
   - Initialization with dictionary: `[UUID: FileAssetEntry]`
   - Methods: `register(_ entry:for:)`, `var assetIDs: [UUID]`
   - Commit: "Add FileAssetProvider struct and initialization"

5. **FileAssetProvider protocol methods**
   - Extend `FileAssetProvider.swift`
   - Implement protocol methods:
     - `assetMetadata(for:)`: Look up entry, return AssetMetadata
     - `assetFileURL(for:)`: Return fileURL, verify exists
     - `assetData(for:)`: Read from disk via Data(contentsOf:)
   - Commit: "Add FileAssetProvider protocol implementation"

6. **FileAssetProvider tests**
   - Create `Tests/SwiftSecuenciaTests/AssetProviderTests.swift`
   - FileAssetProvider tests:
     - Test: returns correct metadata for registered asset
     - Test: returns correct file URL
     - Test: unregistered ID throws `assetNotFound`
     - Test: nonexistent file throws `fileNotFound`
     - Test: hasVideo/hasAudio flags match registration
   - Commit: "Add FileAssetProvider tests"

7. **SwiftDataAssetProvider tests**
   - Extend `AssetProviderTests.swift`
   - SwiftDataAssetProvider tests:
     - Test: default `assetData` implementation throws `dataNotSupported`
     - Test: derives hasVideo=true,hasAudio=true for `video/quicktime`
     - Test: derives hasVideo=false,hasAudio=true for `audio/mp4`
     - Test: derives hasVideo=true,hasAudio=false for `image/png`
   - Commit: "Add SwiftDataAssetProvider tests"

**Exit criteria**:
- [ ] `xcodebuild build -scheme SwiftSecuencia -destination 'platform=macOS'` succeeds
- [ ] `xcodebuild build -scheme SecuenciaCLI -destination 'platform=macOS'` succeeds
- [ ] `xcodebuild test -scheme SwiftSecuencia -destination 'platform=macOS'` — all tests pass (existing + new)
- [ ] `AssetProvider` protocol is public
- [ ] `FileAssetProvider` can be initialized with file paths and returns correct metadata with correct hasVideo/hasAudio flags
- [ ] `SwiftDataAssetProvider` correctly derives hasVideo/hasAudio from MIME type prefixes

---

### Sprint 5: Refactor exporters to use AssetProvider

**Entry criteria**: Sprint 4 exit criteria satisfied.

**CONTEXT WINDOW STRATEGY**: This sprint is split into 19 atomic tasks to avoid context exhaustion. Tasks build incrementally with tests at each step.

**⚠️ CRITICAL PARALLELIZATION**: This is the BOTTLENECK sprint (19 tasks, ~10h).

**Two Independent Tracks** (can run in parallel):
- **Track 1**: FCPXMLExporter refactoring (5.1-5.7) + tests (5.16)
- **Track 2**: FCPXMLBundleExporter refactoring (5.8-5.15) + tests (5.17)
- **Sync Point**: Task 5.18 (regression test) waits for both tracks

**Parallelization Strategy**:
- Launch Track 1 and Track 2 simultaneously
- Track 1 is faster (~4h), Track 2 is slower (~6h)
- Both must complete before Task 5.18

**Tasks**:

### FCPXMLExporter Track (5.1-5.7)

**5.1 - Add AssetProvider method signature** (~40 lines)
- Add export(timeline:assetProvider:...) method signature to FCPXMLExporter
- Stub implementation: throw notImplemented
- Test: verify method exists and throws
- Commit: "Add AssetProvider export method signature to FCPXMLExporter"

**5.2 - Collect unique asset IDs** (~40 lines)
- Collect unique assetStorageId values from timeline.clips
- Return Set<UUID> of asset IDs
- Test: verify correct count of unique assets
- Commit: "FCPXMLExporter: Collect unique asset IDs"

**5.3 - Fetch metadata + generate format** (~60 lines)
- Call assetProvider.assetMetadata(for:) for each ID
- Generate format element (reuse existing logic)
- Test: verify format element generated correctly
- Commit: "FCPXMLExporter: Fetch metadata and generate format"

**5.4 - Replace placeholder URLs** (~80 lines)
- Use assetProvider.assetFileURL(for:) for src attribute
- Generate file:// URLs
- Test: verify file:/// URLs (not placeholders)
- Commit: "FCPXMLExporter: Replace placeholder URLs with file URLs"

**5.5 - Add hasVideo/hasAudio attributes** (~70 lines)
- Use metadata.hasVideo and metadata.hasAudio
- Add to <asset> elements
- Test: verify correct hasVideo/hasAudio flags
- Commit: "FCPXMLExporter: Add hasVideo/hasAudio attributes"

**5.6 - Complete document structure** (~80 lines)
- Complete spine, sequence, project structure
- Finalize XML generation
- Test: verify complete FCPXML structure
- Commit: "FCPXMLExporter: Complete document structure"

**5.7 - Backward compat wrapper** (~40 lines)
- Keep existing export(timeline:modelContext:...)
- Create SwiftDataAssetProvider internally
- Call new method
- Test: verify backward compatibility
- Commit: "FCPXMLExporter: Add backward compatibility wrapper"

### FCPXMLBundleExporter Track (5.8-5.15)

**5.8 - Audio conversion helper** (~120 lines)
- Add convertAudioToM4A(from:to:) method
- AVAssetExportSession implementation (Appendix D)
- Test: convert WAV fixture to M4A
- Commit: "FCPXMLBundleExporter: Add audio conversion helper"

**5.9 - Add AssetProvider method signature** (~40 lines)
- Add exportBundle(timeline:assetProvider:...) method signature
- Stub implementation
- Test: verify method exists and throws
- Commit: "FCPXMLBundleExporter: Add AssetProvider exportBundle signature"

**5.10 - Bundle structure creation** (~100 lines)
- Create .fcpxmld directory
- Create Media/ subdirectory
- Test: verify directory structure
- Commit: "FCPXMLBundleExporter: Create bundle structure"

**5.11 - Direct media copy** (~80 lines)
- Copy M4A files directly
- Copy video/image files directly
- File existence verification
- Test: verify files copied, sizes match
- Commit: "FCPXMLBundleExporter: Implement direct media copy"

**5.12 - Audio conversion integration** (~90 lines)
- Detect non-M4A audio files
- Call convertAudioToM4A(from:to:)
- Progress reporting
- Test: verify WAV/MP3 converted to M4A
- Commit: "FCPXMLBundleExporter: Integrate audio conversion"

**5.13 - Generate Info.fcpxml** (~80 lines)
- Use FCPXMLExporter with relative Media/ paths
- Write to bundle
- Test: verify Info.fcpxml has relative paths
- Commit: "FCPXMLBundleExporter: Generate Info.fcpxml"

**5.14 - Generate Info.plist** (~40 lines)
- Create CFBundle* metadata
- Write plist to bundle
- Test: verify Info.plist structure
- Commit: "FCPXMLBundleExporter: Generate Info.plist"

**5.15 - Backward compat wrapper** (~40 lines)
- Keep existing exportBundle(timeline:modelContext:...)
- Create SwiftDataAssetProvider internally
- Maintain @MainActor isolation
- Test: verify backward compatibility
- Commit: "FCPXMLBundleExporter: Add backward compatibility wrapper"

### Testing (5.16-5.18)

**5.16 - Update FCPXMLExportTests** (~100 lines)
- Test: file:/// URLs (not placeholders)
- Test: hasVideo/hasAudio attributes
- Test: backward compatibility
- All new tests must pass
- Commit: "Add FCPXMLExporter AssetProvider tests"

**5.17 - Update FCPXMLBundleExportTests** (~100 lines)
- Test: bundle structure
- Test: media copying
- Test: audio conversion
- Test: backward compatibility
- All new tests must pass
- Commit: "Add FCPXMLBundleExporter AssetProvider tests"

**5.18 - Full regression suite** (~20 lines)
- Run all existing tests
- Verify zero regressions
- Fix any failures
- Commit: "Verify no regressions from AssetProvider refactor"

**Exit criteria** (all 19 tasks complete):
- [ ] `xcodebuild build -scheme SwiftSecuencia -destination 'platform=macOS'` succeeds
- [ ] `xcodebuild test -scheme SwiftSecuencia -destination 'platform=macOS'` — ALL tests pass
- [ ] FCPXMLExporter refactoring (Tasks 5.1-5.7):
  - [ ] New `export(timeline:assetProvider:)` method exists and works
  - [ ] FileAssetProvider produces FCPXML with actual `file:///` URLs (not placeholders)
  - [ ] hasVideo/hasAudio attributes correct in asset elements
  - [ ] Backward compat: old `export(timeline:modelContext:)` still works
- [ ] FCPXMLBundleExporter refactoring (Tasks 5.8-5.15):
  - [ ] Audio conversion helper method works (`convertAudioToM4A`)
  - [ ] New `exportBundle(timeline:assetProvider:)` method exists and works
  - [ ] Bundle structure creation works
  - [ ] Media files copied to bundle Media/ directory
  - [ ] M4A files copied directly, not transcoded (file size verification)
  - [ ] Non-M4A audio converted to M4A
  - [ ] Backward compat: old `exportBundle(timeline:modelContext:)` still works
- [ ] All new tests pass (Tasks 5.16-5.17)
- [ ] FULL existing test suite passes with zero regressions (Task 5.18)

---

## Work Unit: CLI Pipeline

### Sprint 6: SwiftData Bootstrap & Timeline Builder

**Entry criteria**: JSON Parsing (Sprints 2-3) AND Asset Resolution (Sprints 4-5) are both COMPLETED.

**CONTEXT WINDOW STRATEGY**: This sprint is split into 15 atomic tasks to avoid context exhaustion.

**Tasks**:

**6.1 - SwiftDataBootstrap** (~60 lines)
- createInMemoryContainer() (Appendix A)
- createContext(from:)
- Test: container creation, isStoredInMemoryOnly
- Commit: "Add SwiftDataBootstrap for in-memory container"

**6.2 - Create Timeline** (~30 lines)
- Create Timeline with name from definition.timeline.name
- Stub format properties
- Test: Timeline created with correct name
- Commit: "TimelineBuilder: Create Timeline"

**6.3 - Map FormatConfig → VideoFormat** (~40 lines)
- Parse frameRate via FrameRateParser
- Map colorSpace string to ColorSpace enum
- Set timeline.videoFormat
- Test: correct format mapping
- Commit: "TimelineBuilder: Map FormatConfig to VideoFormat"

**6.4 - Map AudioConfig → AudioLayout/Rate** (~40 lines)
- Map layout string to AudioLayout enum
- Map rate string to AudioRate enum
- Set timeline.audioLayout and audioRate
- Test: correct audio mapping
- Commit: "TimelineBuilder: Map AudioConfig to AudioLayout/Rate"

**6.5 - Derive file metadata** (~70 lines)
- For each unique file in assetMap
- Find first clip referencing file
- Create FileAssetEntry with metadata (name, mimeType, duration, hasVideo, hasAudio)
- Test: metadata derived correctly
- Commit: "TimelineBuilder: Derive file metadata"

**6.6 - Register entries in FileAssetProvider** (~60 lines)
- Create FileAssetProvider
- Register each FileAssetEntry with UUID from assetMap
- Return provider
- Test: one entry per unique file
- Commit: "TimelineBuilder: Register entries in FileAssetProvider"

**6.7 - Parse clip offset and duration** (~60 lines)
- For each non-marker clip
- Parse offset via TimeStringParser
- Parse duration via TimeStringParser
- Look up asset UUID from assetMap
- Test: correct parsing
- Commit: "TimelineBuilder: Parse clip offset and duration"

**6.8 - Create TimelineClip and append** (~80 lines)
- Create TimelineClip with all properties
- Set: assetStorageId, offset, duration, lane, volume, opacity
- Append to timeline
- Test: clips appended at correct offsets, lanes
- Commit: "TimelineBuilder: Create TimelineClip and append"

**6.9 - Marker processing** (~80 lines)
- For each marker clip
- Parse offset via TimeStringParser
- Create Marker or ChapterMarker (Appendix C)
- Append to timeline arrays
- Test: markers at correct offsets
- Commit: "TimelineBuilder: Add marker processing"

**6.10 - Complete build() return** (~40 lines)
- Finalize build() method
- Return (Timeline, FileAssetProvider) tuple
- Test: full integration
- Commit: "TimelineBuilder: Complete build() method"

**6.11 - Format mapping tests** (~60 lines)
- Test: Timeline creation
- Test: FormatConfig → VideoFormat
- Test: AudioConfig → AudioLayout/Rate
- Commit: "Add TimelineBuilder format mapping tests"

**6.12 - Provider and clip tests** (~60 lines)
- Test: FileAssetProvider population
- Test: One entry per unique file
- Test: Clip creation and appending
- Commit: "Add TimelineBuilder provider and clip tests"

**6.13 - Marker and integration tests** (~40 lines)
- Test: Marker processing
- Test: Full build() integration
- Commit: "Add TimelineBuilder marker and integration tests"

**6.14 - SwiftDataBootstrapTests** (~80 lines)
- Test: container creation
- Test: isStoredInMemoryOnly
- Test: schema contains 3 models
- Commit: "Add SwiftDataBootstrap tests"

**Exit criteria** (all 15 tasks complete):
- [ ] Build succeeds
- [ ] All tests pass (Tasks 6.11-6.14)
- [ ] SwiftDataBootstrap (Task 6.1):
  - [ ] In-memory ModelContainer created with 3 models (Timeline, TimelineClip, TypedDataStorage)
  - [ ] Container is in-memory only (no disk writes)
- [ ] TimelineBuilder (Tasks 6.2-6.10):
  - [ ] Timeline creation with correct format mapping
  - [ ] FileAssetProvider populated with one entry per unique file
  - [ ] Non-marker clips processed with correct offsets, durations, lanes
  - [ ] Marker clips added to timeline arrays (not as TimelineClip)
  - [ ] Full integration: `build(from:assetMap:in:)` returns complete Timeline + FileAssetProvider
- [ ] Format string mappings work: "23.98" → fps23_98, "stereo" → .stereo, etc.
- [ ] Invalid format strings produce descriptive errors

---

### Sprint 7: Build Command Integration

**Entry criteria**: Sprint 6 exit criteria satisfied.

**CONTEXT WINDOW STRATEGY**: This sprint is split into 5 atomic tasks to avoid context exhaustion.

**Tasks**:

**7.1 - Parse JSON + resolve paths** (~40 lines)
- Call JSONTimelineParser.parse(fileAt:)
- Call FileResolver.resolve(definition:relativeTo:)
- Error handling for this phase
- Test: parsing valid JSON succeeds
- Commit: "BuildCommand: Parse JSON and resolve paths"

**7.2 - Deduplicate assets + probe durations** (~40 lines)
- Call FileResolver.deduplicateAssets(in:)
- Call MediaProbe.probeMissingDurations(in:)
- Error handling for this phase
- Test: deduplication works correctly
- Commit: "BuildCommand: Deduplicate assets and probe durations"

**7.3 - Bootstrap SwiftData + build timeline** (~40 lines)
- Call SwiftDataBootstrap.createInMemoryContainer()
- Call TimelineBuilder.build(from:assetMap:in:)
- Error handling for this phase
- Test: timeline built successfully
- Commit: "BuildCommand: Bootstrap SwiftData and build timeline"

**7.4 - Choose export mode + generate output** (~40 lines)
- Check --bundle flag
- Call FCPXMLExporter or FCPXMLBundleExporter
- Write output file/bundle
- Print summary
- Test: both export modes work
- Commit: "BuildCommand: Choose export mode and generate output"

**7.5 - BuildCommand tests** (~80 lines)
- Test: full pipeline with valid JSON
- Test: error cases
- Test: output file is well-formed XML
- Commit: "Add BuildCommand tests"

**Exit criteria** (all 5 tasks complete):
- [ ] Build succeeds
- [ ] All tests pass (Task 7.5)
- [ ] `secuencia build timeline.json` with explicit durations and existing placeholder files produces a `.fcpxml` file
- [ ] `secuencia build --bundle timeline.json` with explicit durations produces a `.fcpxmld` directory
- [ ] Output FCPXML is well-formed XML (parseable by `XMLDocument`, verified by test)
- [ ] Error messages include the pipeline stage and relevant file path

---

### Sprint 8: End-to-End Tests

**Entry criteria**: Sprint 7 exit criteria satisfied.

**CONTEXT WINDOW STRATEGY**: This sprint is split into 16 atomic tasks to avoid context exhaustion.

**⭐ VERY HIGH PARALLELIZATION** (5 parallel phases):

**Phase 1** (parallel): Tasks 8.1-8.4 (media fixtures) - all 4 can run simultaneously
**Phase 2** (parallel): Tasks 8.5-8.8 (JSON fixtures) - all 4 can run simultaneously
**Phase 3** (parallel): Tasks 8.9, 8.10, 8.11, 8.13, 8.14 (5 test scenarios) - can run simultaneously
**Phase 4** (sequential): Task 8.12 (bundle test - heavier, run alone)
**Phase 5** (sequential): Task 8.15 (final verification - waits for all)

**Tasks**:

### Media Fixtures (8.1-8.4)

**8.1 - Create test-video.mov** (~10 lines)
- ffmpeg command: 1s 1920x1080 black video with stereo audio
- Verify file created
- Commit: "Add test-video.mov fixture"

**8.2 - Create test-audio.m4a** (~10 lines)
- ffmpeg command: 2s silent stereo audio
- Verify file created
- Commit: "Add test-audio.m4a fixture"

**8.3 - Create test-image.png** (~10 lines)
- ffmpeg command: 1920x1080 black image
- Verify file created
- Commit: "Add test-image.png fixture"

**8.4 - Create test-audio.wav** (~10 lines)
- ffmpeg command: 1s WAV for conversion test
- Verify file created
- Commit: "Add test-audio.wav fixture"

### JSON Fixtures (8.5-8.8)

**8.5 - Create simple-timeline.json** (~15 lines)
- Image 3s lane 0, video 1s lane 0 offset 3s, audio 2s lane -1
- Commit: "Add simple-timeline.json fixture"

**8.6 - Create markers-timeline.json** (~15 lines)
- Same as simple-timeline + chapter markers at 0s and 3s
- Commit: "Add markers-timeline.json fixture"

**8.7 - Create multi-lane-timeline.json** (~15 lines)
- Video lane 0, audio lane -1, image lane 1 (B-roll)
- Commit: "Add multi-lane-timeline.json fixture"

**8.8 - Create auto-duration.json** (~15 lines)
- Clips WITHOUT explicit duration (force probing)
- Commit: "Add auto-duration.json fixture"

### Test Scenarios (8.9-8.15)

**8.9 - Test: Simple timeline export** (~80 lines)
- Verify: <fcpxml version="1.11">
- Verify: 3 <asset> elements
- Verify: correct offsets
- Verify: <format> matches 1080p
- Commit: "Add simple timeline export test"

**8.10 - Test: Multi-lane audio** (~60 lines)
- Verify: lane -1 in spine structure
- Commit: "Add multi-lane audio export test"

**8.11 - Test: Marker export** (~60 lines)
- Verify: <chapter-marker> elements at correct offsets
- Commit: "Add marker export test"

**8.12 - Test: Bundle export** (~120 lines)
- Verify: .fcpxmld directory created
- Verify: Info.fcpxml file
- Verify: Media/ subdirectory with files
- Verify: M4A not transcoded (size matches)
- Verify: WAV converted to M4A
- Commit: "Add bundle export test"

**8.13 - Test: Auto-duration probing** (~80 lines)
- Verify: video duration 1.0s ± 0.1s
- Verify: audio duration 2.0s ± 0.1s
- Commit: "Add auto-duration probing test"

**8.14 - Test: Error handling** (~100 lines)
- Test: missing JSON file → error with path
- Test: malformed JSON → parse error
- Test: nonexistent media → error with resolved path
- Test: clip no duration no file → error with clip name
- Test: invalid time string → error with invalid value
- Commit: "Add error handling tests"

**8.15 - Verify all tests pass** (~10 lines)
- Run full E2E test suite
- All scenarios must pass
- Commit: "Verify all end-to-end tests pass"

**Exit criteria** (all 16 tasks complete):
- [ ] Build succeeds
- [ ] All tests pass (Tasks 8.9-8.15)
- [ ] Media fixtures created (Tasks 8.1-8.4):
  - [ ] test-video.mov (1s, 1080p24, ProRes, stereo audio)
  - [ ] test-audio.m4a (2s, AAC, 48kHz stereo)
  - [ ] test-image.png (1920x1080)
  - [ ] test-audio.wav (1s, for conversion test)
- [ ] JSON fixtures created (Tasks 8.5-8.8):
  - [ ] simple-timeline.json, markers-timeline.json, multi-lane-timeline.json, auto-duration.json
- [ ] EndToEndTests (Tasks 8.9-8.14):
  - [ ] Simple timeline export produces valid FCPXML
  - [ ] Multi-lane audio on lane -1 works
  - [ ] Chapter markers appear in FCPXML
  - [ ] Bundle export creates .fcpxmld with Info.fcpxml and Media/ directory
  - [ ] M4A files copied without transcoding (size matches source)
  - [ ] WAV files converted to M4A
  - [ ] Auto-duration probing within ±0.1s tolerance
- [ ] ErrorHandlingTests (Task 8.14):
  - [ ] Missing file, malformed JSON, nonexistent media, no duration, invalid time string
  - [ ] All error messages descriptive with relevant context
- [ ] Full test suite passes (Task 8.15)

---

## Work Unit: Validation

### Sprint 9: FCPXML DTD validation of output

**Entry criteria**: CLI Pipeline is COMPLETED.

**Tasks**:
1. Add DTD validation step to `BuildCommand.run()`:
   - After generating FCPXML string, validate against the DTD for the `--format-version` version
   - Use existing `FCPXMLDTDValidator` from SwiftSecuencia (in Validation/ directory)
   - If validation fails and `--strict` is NOT set: print warnings to stderr, still write the output file
   - If validation fails and `--strict` IS set: print errors to stderr, do NOT write output, exit with non-zero code
   - Add `--strict` flag to `BuildCommand`
   - If the specified `--format-version` does not have a matching DTD file in the Fixtures bundle (e.g., version `1.7`), skip DTD validation and print a warning: "DTD validation skipped: no DTD available for FCPXML version 1.7"
2. Create `Tests/SecuenciaCLITests/DTDValidationTests.swift`:
   - Test: FCPXML from `simple-timeline.json` passes DTD validation for v1.11
   - Test: FCPXML from `multi-lane-timeline.json` passes DTD validation
   - Test: FCPXML from `markers-timeline.json` passes DTD validation
   - Test: `--strict` with valid FCPXML exits successfully (exit code 0)
   - Test: `--strict` with intentionally invalid FCPXML exits with non-zero code (create a test that produces invalid XML by, e.g., referencing a nonexistent format ID)
   - Test: unsupported DTD version prints warning and skips validation (does not crash)
   - Test: validation warnings are printed to stderr (capture stderr in test)
3. Document the manual FCP import verification as a comment in the test file:
   ```swift
   // MANUAL VERIFICATION: Import the .fcpxmld bundle from
   // simple-timeline.json into Final Cut Pro and verify:
   // - Timeline appears with correct name
   // - Clips are on correct lanes
   // - Chapter markers appear in the timeline index
   ```

**Exit criteria**:
- [ ] Build succeeds
- [ ] All tests pass
- [ ] FCPXML from all three fixture JSONs passes DTD validation for version 1.11
- [ ] `--strict` flag causes non-zero exit when validation fails
- [ ] Default (non-strict) mode prints warnings to stderr but still writes the output file
- [ ] Unsupported DTD version prints warning and skips validation gracefully (no crash)

---

### Sprint 10: Validate command, schema file, and documentation

**Entry criteria**: Sprint 9 exit criteria satisfied.

**Tasks**:

1. **Create ValidateCommand**
   - Create `Sources/SecuenciaCLI/Commands/ValidateCommand.swift`
   - `struct Validate: AsyncParsableCommand` with `commandName: "validate"`
   - Arguments: `inputFile: String`
   - Pipeline (no FCPXML generation):
     1. Parse JSON via JSONTimelineParser
     2. Resolve file paths via FileResolver
     3. Probe missing durations via MediaProbe
     4. Report summary: clip count (by type), unique asset count, total duration, lane range
     5. Report warnings: very short clips (<0.1s), overlapping clips, gaps in primary storyline
   - Exit code 0 on success, non-zero if parsing/resolution fails
   - Commit: "Add ValidateCommand for JSON validation without export"

2. **Create schema.json - Structure and timeline definitions**
   - Create `Sources/SecuenciaCLI/Resources/schema.json`
   - JSON Schema (draft 2020-12)
   - Define top-level structure:
     - `$schema`, `$id`, `title`, `description`
     - Required: `timeline`, `clips`
   - Define `TimelineConfig`, `FormatConfig`, `AudioConfig` in `$defs`
   - Include `description` for all fields
   - Include `examples` for width, height, frameRate
   - Test: example JSON from execution plan validates against this partial schema
   - Commit: "Add JSON Schema - Timeline structure definitions"

3. **Extend schema.json - Clip definitions and enums**
   - Extend `schema.json`
   - Define `ClipDefinition` in `$defs`:
     - All fields: name, file, offset, duration, lane, type, markerType, volume, opacity
     - Required vs optional fields
   - Define all enum values:
     - `type`: video, audio, image, marker
     - `markerType`: standard, chapter, todo
     - `colorSpace`: rec709, rec2020, dciP3
     - `layout`: mono, stereo, surround
     - `rate`: 44.1kHz, 48kHz, 96kHz
     - `frameRate`: 23.98, 24, 25, 29.97, 30, 50, 59.94, 60
   - Add `examples` for time strings: "3s", "1001/24000s", "10.5s"
   - Test: all JSON fixtures from Sprint 8 validate successfully
   - Commit: "Add JSON Schema - Clip definitions and enums"

4. **Create SchemaCommand**
   - Create `Sources/SecuenciaCLI/Commands/SchemaCommand.swift`
   - `struct Schema: ParsableCommand` with `commandName: "schema"`
   - Read `schema.json` from `Bundle.module` resources
   - Print to stdout
   - Error handling: if resource loading fails, print to stderr and exit non-zero
   - Commit: "Add SchemaCommand to output JSON Schema"

5. **Register subcommands**
   - Update `Sources/SecuenciaCLI/Secuencia.swift`
   - Register `Validate` and `Schema` as subcommands in `@main` struct
   - Verify: `secuencia --help` lists build, validate, schema
   - Commit: "Register Validate and Schema subcommands"

6. **Add --help descriptions to BuildCommand**
   - Update `Sources/SecuenciaCLI/Commands/BuildCommand.swift`
   - Add help text to all arguments and options:
     - `inputFile`: "Path to the JSON timeline definition file"
     - `output`: "Output path for the FCPXML file or bundle (default: <input>.fcpxml)"
     - `bundle`: "Produce a .fcpxmld bundle with embedded media instead of standalone FCPXML"
     - `formatVersion`: "FCPXML version to generate (default: 1.11)"
     - `strict`: "Fail if DTD validation finds errors (default: warn only)"
   - Commit: "Add --help descriptions to BuildCommand"

7. **Add --help descriptions to ValidateCommand**
   - Update `ValidateCommand.swift`
   - Add help text to arguments:
     - `inputFile`: "Path to the JSON timeline definition file to validate"
   - Commit: "Add --help descriptions to ValidateCommand"

8. **Add --help descriptions to SchemaCommand**
   - Update `SchemaCommand.swift`
   - Add configuration description for the command itself
   - Commit: "Add --help descriptions to SchemaCommand"

9. **Update README.md**
   - Add `## CLI` section after Quick Start
   - Installation instructions: `swift build -c release`, copy binary, or `swift run SecuenciaCLI`
   - Usage examples for all three subcommands with expected output
   - JSON schema documentation:
     - Field descriptions
     - Time string formats (integer, decimal, rational)
     - MIME type derivation table
     - Link to `secuencia schema` for programmatic access
   - Commit: "Add CLI documentation to README"

10. **Create ValidateCommandTests**
   - Create `Tests/SecuenciaCLITests/ValidateCommandTests.swift`
   - Test: validate `simple-timeline.json` exits 0 and prints summary
   - Test: validate nonexistent file exits non-zero
   - Test: validate malformed JSON exits non-zero with parse error
   - Commit: "Add ValidateCommand tests"

11. **Create SchemaCommandTests**
   - Create `Tests/SecuenciaCLITests/SchemaCommandTests.swift`
   - Test: `secuencia schema` outputs valid JSON (parseable by JSONSerialization)
   - Test: output contains `"$schema"` key
   - Test: example JSON from execution plan conforms to schema
   - Test: Sprint 8 JSON fixtures conform to schema
   - Commit: "Add SchemaCommand tests"

**Exit criteria** (all 11 tasks complete):
- [ ] Build succeeds
- [ ] All tests pass (Tasks 10-11)
- [ ] ValidateCommand (Task 1):
  - [ ] `secuencia validate simple-timeline.json` prints summary and exits 0
  - [ ] Nonexistent/malformed JSON exits non-zero with descriptive error
- [ ] JSON Schema (Tasks 2-3):
  - [ ] schema.json exists with complete structure (timeline + clip definitions)
  - [ ] Contains all enum values (type, markerType, colorSpace, layout, rate, frameRate)
  - [ ] Contains descriptions and examples for all fields
  - [ ] Example JSON from execution plan validates successfully
  - [ ] All Sprint 8 JSON fixtures validate successfully
- [ ] SchemaCommand (Task 4):
  - [ ] `secuencia schema` prints valid JSON Schema to stdout
  - [ ] Output parseable by JSONSerialization
  - [ ] Contains `"$schema"` key
- [ ] Subcommands registered (Task 5):
  - [ ] `secuencia --help` lists build, validate, schema
- [ ] Help text complete (Tasks 6-8):
  - [ ] `secuencia build --help` documents all options
  - [ ] `secuencia validate --help` documents arguments
  - [ ] `secuencia schema --help` shows description
- [ ] README updated (Task 9):
  - [ ] CLI section with installation, usage examples, schema documentation
  - [ ] Time string formats documented
  - [ ] MIME type derivation table included

---

## Dispatch Template

```
You are working on SwiftSecuencia in $PROJECT_ROOT/.

FIRST, read these files in order:
1. $PROJECT_ROOT/EXECUTION_PLAN.md
2. $PROJECT_ROOT/README.md
3. $PROJECT_ROOT/Package.swift

You are executing Sprint <SPRINT_NUMBER>: <SPRINT_NAME>.

<SPRINT_DEFINITION>

ENTRY CRITERIA (verify before starting):
<ENTRY_CRITERIA>

EXIT CRITERIA (verify before declaring done):
<EXIT_CRITERIA>

IMPORTANT:
- Do NOT start the next sprint. Your scope ends after this sprint.
- Do NOT modify EXECUTION_PLAN.md.
- Use xcodebuild (not swift build) for all build and test commands.
- All new types must conform to Sendable where possible (Swift 6 strict concurrency).
- After completing all tasks, run the exit criteria commands and report results.
- Commit your work with a message referencing Sprint <SPRINT_NUMBER>.
```

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 5 |
| Total sprints | 10 |
| Total tasks | 96 (atomically split for maximum context safety, includes Universal integration) |
| Dependency structure | Graph with parallel branches |
| Dispatch mode | dynamic |
| Max parallelism | 3 concurrent work units (Sprints 2 ∥ 3 ∥ 4) |
| Context window safety | All tasks < 100 lines (95%), comprehensive tests < 150 lines (5%) |
| Parallelization speedup | ~35-45% with full task-level parallelization |

### Execution Order

```
Phase 1 — Foundation (sequential):
    Sprint 1: CLI Scaffold (8 tasks, ~3h)

Phase 2 — PARALLEL EXECUTION (launch both branches simultaneously):

    Branch A (16 tasks, ~9h):              Branch B (26 tasks, ~14h) ← CRITICAL PATH
    ├─ Sprint 2: JSON parsing (6 tasks)    ├─ Sprint 4: AssetProvider (7 tasks)
    └─ Sprint 3: File resolution (10)      └─ Sprint 5: Refactor exporters (19) ← BOTTLENECK
                                              ├─ Track 1: FCPXMLExporter (5.1-5.7)
                                              └─ Track 2: FCPXMLBundleExporter (5.8-5.15)

    Note: Branch B takes 5 hours longer than Branch A

Phase 3 — Integration (sequential, waits for BOTH branches):
    Sprint 6: SwiftData bootstrap + TimelineBuilder (15 tasks, ~6h)
    Sprint 7: Build command integration (5 tasks, ~3h)
    Sprint 8: End-to-end tests (16 tasks, ~5h)

Phase 4 — Polish (sequential, optional):
    Sprint 9: DTD validation (3 tasks, ~2.5h)
    Sprint 10: Validate command + docs (11 tasks, ~4.5h)
```

**Supervisor Dispatch Strategy**:
- After Sprint 1: Dispatch Sprints 2 AND 4 simultaneously
- Monitor both branches: Sprint 2→3 and Sprint 4→5
- Sprint 6 blocks until MAX(Branch A completion, Branch B completion)
- Within Sprint 5: Tasks 5.1-5.7 can run parallel to 5.8-5.15
- Within Sprint 8: High task-level parallelization (fixtures, tests)

### Critical Path

**The longest path determines total execution time:**

```
Sprint 1 → Sprint 4 → Sprint 5 → Sprint 6 → Sprint 7 → Sprint 8 → Sprint 9 → Sprint 10
  3h         4h         10h        6h         3h         5h         2.5h       4.5h
```

**Total Critical Path: 38 hours** (sequential execution)

**Parallel Branch** (runs concurrently with critical path):
```
Sprint 1 → Sprint 2 → Sprint 3
  3h         4h         5h
```

**Total Parallel Branch: 12 hours** (finishes 2 hours before Sprint 5 completes)

**Supervisor Behavior**:
- Sprints 2-3 run in parallel with 4-5
- Branch B (Sprints 4-5: 14h) is **LONGER** than Branch A (Sprints 2-3: 9h)
- Branch A finishes first and waits for Branch B
- Sprint 6 blocks until MAX(Branch A, Branch B) completes
- Within Sprint 5: Track 1 (5.1-5.7) and Track 2 (5.8-5.15) can run in parallel
- Within Sprint 8: High task-level parallelization (5 parallel phases)

**Net Result**: With full parallelization, total time reduces from 47h sequential to ~30h parallel (36% speedup).

---

## Appendices

### Appendix A: SwiftData Model Graph

The CLI uses an in-memory SwiftData container. The following models must be registered in the `ModelContainer` schema:

**Required @Model classes**:
- `Timeline` (from SwiftSecuencia) - Primary timeline container
- `TimelineClip` (from SwiftSecuencia) - Individual clips on the timeline
- `TypedDataStorage` (from SwiftCompartido) - Media asset storage

**NOT required** (these are Codable value types stored as JSON Data within the parent models):
- `Marker`, `ChapterMarker`, `Keyword`, `Rating`, `Metadata` - stored as arrays or JSON in Timeline/TimelineClip
- `ScreenplayMetadata` - a Codable struct, not a SwiftData model
- `VideoFormat`, `AudioLayout`, `AudioRate`, `ColorSpace` - enum/struct value types

**Implementation for Sprint 6**:
```swift
import SwiftData
import SwiftCompartido

let schema = Schema([
    Timeline.self,
    TimelineClip.self,
    TypedDataStorage.self  // From SwiftCompartido
])

let configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: true
)

let container = try ModelContainer(
    for: schema,
    configurations: configuration
)
```

**Why this matters**: If you omit `TypedDataStorage` from the schema, SwiftData will fail at runtime when TimelineClip tries to reference an asset by its UUID. All models in the relationship graph must be registered.

---

### Appendix B: Deterministic UUID Generation from File Paths

File paths must map to stable UUIDs so that the same JSON input always produces the same FCPXML resource IDs. Use SHA256 to generate deterministic UUIDs:

**Implementation for Sprint 3**:
```swift
import Foundation
import CryptoKit

extension FileResolver {
    /// Generates a deterministic UUID from a file path using SHA256.
    ///
    /// - Parameter path: The absolute file path.
    /// - Returns: A stable UUID derived from the path.
    static func deterministicUUID(for path: String) -> UUID {
        // Hash the absolute path
        let hash = SHA256.hash(data: Data(path.utf8))

        // Take first 16 bytes (128 bits) for UUID
        let bytes = Array(hash.prefix(16))

        // Construct UUID from bytes
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
```

**Usage in `deduplicateAssets`**:
```swift
method deduplicateAssets(in definition: TimelineDefinition) -> [String: UUID] {
    var assetMap: [String: UUID] = [:]

    for clip in definition.clips where clip.file != nil {
        let path = clip.file!  // Already resolved to absolute path
        if assetMap[path] == nil {
            assetMap[path] = FileResolver.deterministicUUID(for: path)
        }
    }

    return assetMap
}
```

**Verification test** (add to Sprint 3):
```swift
@Test func samePathProducesSameUUID() {
    let path = "/Users/test/media/audio.m4a"
    let uuid1 = FileResolver.deterministicUUID(for: path)
    let uuid2 = FileResolver.deterministicUUID(for: path)
    #expect(uuid1 == uuid2)
}

@Test func differentPathsProduceDifferentUUIDs() {
    let uuid1 = FileResolver.deterministicUUID(for: "/path/a.mov")
    let uuid2 = FileResolver.deterministicUUID(for: "/path/b.mov")
    #expect(uuid1 != uuid2)
}
```

---

### Appendix C: Marker Construction and Placement

Markers from JSON are added to the Timeline's marker arrays, not as TimelineClip instances.

**Marker types** (existing SwiftSecuencia models):
- `Marker` - Standard markers at a timecode
- `ChapterMarker` - Chapter markers for navigation

**Implementation for Sprint 6, Task 2**:

```swift
// In TimelineBuilder.build(from:assetMap:in:)

for clip in definition.clips {
    if clip.type == .marker {
        let offset = try TimeStringParser.parse(clip.offset)

        switch clip.markerType {
        case "chapter":
            let marker = ChapterMarker(
                offset: offset,
                posterOffset: offset,  // Same as offset for now
                name: clip.name ?? "Chapter"
            )
            timeline.chapterMarkers.append(marker)

        case "standard", nil:
            let marker = Marker(
                offset: offset,
                name: clip.name ?? "Marker"
            )
            timeline.markers.append(marker)

        case "todo":
            // TODO markers stored as standard markers with a flag
            var marker = Marker(
                offset: offset,
                name: clip.name ?? "TODO"
            )
            // Set completed = false in marker metadata if Marker supports it
            timeline.markers.append(marker)

        default:
            throw TimelineBuilderError.unsupportedMarkerType(clip.markerType!)
        }
    } else {
        // Process normal clips (video/audio/image)...
    }
}
```

**Marker model reference** (from SwiftSecuencia):
```swift
// These are Codable structs, NOT @Model classes
public struct Marker: Codable, Sendable {
    public let offset: Timecode
    public let name: String
}

public struct ChapterMarker: Codable, Sendable {
    public let offset: Timecode
    public let posterOffset: Timecode
    public let name: String
}
```

---

### Appendix D: Audio Conversion Implementation

Converting non-M4A audio to M4A format for FCPXML bundle export.

**Implementation for Sprint 5, Task 2**:

Add this method to `FCPXMLBundleExporter`:

```swift
#if os(macOS)
import AVFoundation

extension FCPXMLBundleExporter {
    /// Converts audio to M4A format using AVFoundation.
    ///
    /// - Parameters:
    ///   - sourceURL: The source audio file URL.
    ///   - destinationURL: The destination M4A file URL.
    /// - Throws: `FCPXMLBundleExportError.audioConversionFailed` if conversion fails.
    private func convertAudioToM4A(from sourceURL: URL, to destinationURL: URL) async throws {
        let asset = AVURLAsset(url: sourceURL)

        // Verify asset has audio track
        let hasAudio = try await asset.loadTracks(withMediaType: .audio).isEmpty == false
        guard hasAudio else {
            throw FCPXMLBundleExportError.audioConversionFailed(
                sourceURL,
                reason: "No audio track found"
            )
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw FCPXMLBundleExportError.audioConversionFailed(
                sourceURL,
                reason: "Could not create export session"
            )
        }

        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .m4a

        // Export
        await exportSession.export()

        // Check result
        switch exportSession.status {
        case .completed:
            return
        case .failed:
            let error = exportSession.error?.localizedDescription ?? "Unknown error"
            throw FCPXMLBundleExportError.audioConversionFailed(
                sourceURL,
                reason: "Export failed: \(error)"
            )
        case .cancelled:
            throw FCPXMLBundleExportError.audioConversionFailed(
                sourceURL,
                reason: "Export was cancelled"
            )
        default:
            throw FCPXMLBundleExportError.audioConversionFailed(
                sourceURL,
                reason: "Export ended with status: \(exportSession.status.rawValue)"
            )
        }
    }
}

// Add to FCPXMLBundleExportError enum:
extension FCPXMLBundleExportError {
    static func audioConversionFailed(_ url: URL, reason: String = "") -> Self {
        .exportFailed("Audio conversion failed for \(url.lastPathComponent): \(reason)")
    }
}
#endif
```

**Usage in media export loop**:

```swift
// In exportBundle method, media export section:
for (assetId, metadata) in assetMetadata {
    let sourceURL = try assetProvider.assetFileURL(for: assetId)
    let fileExtension = sourceURL.pathExtension.lowercased()

    let fileName: String
    let destinationURL: URL

    if metadata.mimeType.hasPrefix("audio/") {
        // Check if conversion needed
        if fileExtension == "m4a" {
            // Copy directly
            fileName = "\(assetId.uuidString).m4a"
            destinationURL = mediaURL.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } else {
            // Convert to M4A
            fileName = "\(assetId.uuidString).m4a"
            destinationURL = mediaURL.appendingPathComponent(fileName)
            try await convertAudioToM4A(from: sourceURL, to: destinationURL)
        }
    } else {
        // Video/image: copy directly
        fileName = "\(assetId.uuidString).\(fileExtension)"
        destinationURL = mediaURL.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    // Update progress...
}
```
