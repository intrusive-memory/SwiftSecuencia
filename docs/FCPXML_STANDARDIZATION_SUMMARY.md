---
type: doc
updated: 2026-07-21
---

# FCPXML Standardization Summary

**Date**: 2026-07-21  
**Version**: SwiftSecuencia 3.5.0-dev  
**Action**: Standardized on `.fcpxmld` bundle format (Option A)

---

## Changes Made

### 1. ✅ Removed Deprecated `.fcpbundle` Support

**Deleted**:
- `Sources/SwiftSecuencia/Export/SwiftSecuenciaBundleExporter.swift`

**Reason**: `.fcpbundle` is NOT documented in Apple's official FCPXML specifications. Apple's official bundle format (since DTD 1.10) is `.fcpxmld`.

### 2. ✅ Updated CLI to Use `.fcpxmld`

**Modified**:
- `Sources/SecuenciaCLICore/Commands/BuildCommand.swift`
  - Changed from `SwiftSecuenciaBundleExporter` → `FCPXMLBundleExporter`
  - Changed bundle extension from `.fcpbundle` → `.fcpxmld`
  - Updated method signatures to match `FCPXMLBundleExporter` API

**CLI Command** (unchanged):
```bash
secuencia build input.json --bundle  # Creates .fcpxmld bundle
```

### 3. ✅ Added DTD Files for All Versions

**Added**:
- `Tests/SecuenciaCLITests/Fixtures/FCPXMLv1_14.dtd` (copied from SwiftSecuenciaTests)

**Complete DTD Coverage** (v1.8 - v1.14):
- ✅ FCPXMLv1_8.dtd
- ✅ FCPXMLv1_9.dtd
- ✅ FCPXMLv1_10.dtd (bundle support introduced)
- ✅ FCPXMLv1_11.dtd
- ✅ FCPXMLv1_12.dtd
- ✅ FCPXMLv1_13.dtd
- ✅ FCPXMLv1_14.dtd (current default)

### 4. ✅ Updated Documentation

**Added to AGENTS.md**:
- New "FCPXML Export Formats" section explaining:
  - Standalone `.fcpxml` vs. Bundle `.fcpxmld`
  - Official Apple format history (DTD 1.10+)
  - Bundle structure diagram
  - Supported FCPXML versions table (1.8-1.14)
  - PipelineNeo dependency explanation
  - Export API examples

**Key Clarifications**:
- `.fcpxmld` is Apple's **official** bundle format (documented)
- `.fcpbundle` was never documented by Apple
- Bundle support requires **DTD 1.10 or later**
- Current default version: **1.14** (FCP 12.0+)

### 5. ✅ Added Comprehensive Tests

#### New Test Files Created:

**`Tests/SwiftSecuenciaTests/FCPXMLBundleExporterTests.swift`** (13 tests):
- ✅ Bundle directory structure validation
- ✅ Info.plist format and metadata
- ✅ Media file copying to `Media/` directory
- ✅ Info.fcpxml XML validity
- ✅ Progress tracking accuracy
- ✅ Cancellation handling
- ✅ Version compatibility (1.10-1.14)
- ✅ Missing asset error handling

**`Tests/SwiftSecuenciaTests/FCPXMLVersionTests.swift`** (14 tests):
- ✅ Version string representation (1.8-1.14)
- ✅ Default version validation (1.14)
- ✅ Exported XML version attributes
- ✅ DTD file availability for all versions
- ✅ Bundle support availability (1.10+)
- ✅ Version sequence ordering
- ✅ XML structure validation
- ✅ Version switching between exports
- ✅ Version string parsing
- ✅ Invalid version string handling
- ✅ All versions export without errors

#### Test Coverage Summary:

| Area | Tests | Status |
|------|-------|--------|
| Bundle Structure | 5 tests | ✅ New |
| Bundle Progress/Cancel | 2 tests | ✅ New |
| Version Compatibility | 14 tests | ✅ New |
| Format/Asset/Sequence | Existing | ✅ Already covered |
| Audio Export | Existing | ✅ Already covered |
| AssetProvider | Existing | ✅ Already covered |
| DTD Validation | Existing | ✅ Already covered |

---

## Format Clarification

### Official Apple Formats

| Extension | Status | Introduced | Structure |
|-----------|--------|------------|-----------|
| `.fcpxml` | ✅ Official | DTD 1.8+ | Single XML file |
| `.fcpxmld` | ✅ Official | DTD 1.10+ | Bundle (Info.plist + Info.fcpxml + Media/) |
| `.fcpbundle` | ❌ Undocumented | ??? | Not in Apple docs |

### Apple Documentation References

1. **FCPXML Bundle Reference**  
   https://developer.apple.com/documentation/professional-video-applications/fcpxml-bundle-reference
   
   > "FCPXML Bundles have a `.fcpxmld` extension."

2. **Document Type Definition (DTD)**  
   https://developer.apple.com/documentation/professional-video-applications/document-type-definition
   
   > "The following DTD applies to Final Cut Pro XML (FCPXML) Interchange Format 1.10."
   > "FCPXML bundle support is available for Document Type Definition (DTD) 1.10 and later."

### Bundle Structure (`.fcpxmld`)

```
MyProject.fcpxmld/
├── Info.plist              # CFBundleName, CFBundleIdentifier
├── Info.fcpxml             # Main FCPXML document
└── Media/                  # Embedded media files
    ├── r1_audio.wav
    ├── r2_video.mov
    └── ...
```

**Key Points**:
- macOS treats `.fcpxmld` as a single file (bundle/package)
- Final Cut Pro imports `.fcpxmld` natively
- Self-contained (no external file dependencies)
- Works across different systems without broken paths

---

## API Usage

### Standalone FCPXML Export

```swift
#if os(macOS)
let exporter = FCPXMLExporter(version: .v1_14)
let xmlString = try await exporter.export(
    timeline: timeline,
    assetProvider: assetProvider,
    libraryName: "My Library",
    eventName: "My Event"
)
try xmlString.write(to: outputURL, atomically: true, encoding: .utf8)
#endif
```

### Bundle Export (Recommended)

```swift
#if os(macOS)
var exporter = FCPXMLBundleExporter(
    version: .v1_14,
    includeMedia: true
)

let bundleURL = try await exporter.exportBundle(
    timeline: timeline,
    assetProvider: assetProvider,
    to: outputDirectory,
    bundleName: "MyProject",  // Creates MyProject.fcpxmld
    libraryName: "My Library",
    eventName: "My Event",
    projectName: "My Project",
    progress: progress  // Optional: Foundation.Progress
)
#endif
```

### CLI Usage

```bash
# Standalone .fcpxml
secuencia build timeline.json --output output.fcpxml

# Bundle .fcpxmld (recommended)
secuencia build timeline.json --bundle --output MyProject

# Specify version
secuencia build timeline.json --bundle --format-version 1.13
```

---

## Breaking Changes

### For Existing Users

**No Breaking Changes** for most users:
- ✅ `FCPXMLExporter` API unchanged (standalone `.fcpxml`)
- ✅ `FCPXMLBundleExporter` API unchanged (`.fcpxmld` bundles)
- ✅ CLI `--bundle` flag still works (now creates `.fcpxmld`)

**Breaking Changes** (minimal):
- ❌ `SwiftSecuenciaBundleExporter` removed (was creating non-standard `.fcpbundle`)
  - **Migration**: Use `FCPXMLBundleExporter` instead
  - **Old**: `SwiftSecuenciaBundleExporter(version: .v1_14)`
  - **New**: `FCPXMLBundleExporter(version: .v1_14, includeMedia: true)`

### Migration Guide

If you were using `SwiftSecuenciaBundleExporter`:

```swift
// OLD (removed)
let exporter = SwiftSecuenciaBundleExporter(version: .v1_14)
try await exporter.exportBundle(
    timeline: timeline,
    projectName: "Project",
    eventName: "Event",
    bundleURL: URL(fileURLWithPath: "/path/to/output.fcpbundle"),
    assetProvider: provider
)

// NEW (recommended)
var exporter = FCPXMLBundleExporter(version: .v1_14, includeMedia: true)
let bundleURL = try await exporter.exportBundle(
    timeline: timeline,
    assetProvider: provider,
    to: URL(fileURLWithPath: "/path/to/"),
    bundleName: "output",  // Creates output.fcpxmld
    libraryName: "My Library",
    eventName: "Event",
    projectName: "Project"
)
```

**Key Differences**:
1. Extension changes from `.fcpbundle` → `.fcpxmld`
2. API takes directory + name instead of full bundle URL
3. `includeMedia` parameter explicit (was implicit)
4. `libraryName` parameter added
5. Returns bundle URL instead of void

---

## Testing

### Run All Tests

```bash
make test
```

### Run Specific Test Suites

```bash
# Bundle format tests
xcodebuild test -scheme SwiftSecuencia-Package \
    -destination 'platform=macOS' \
    -only-testing:SwiftSecuenciaTests/FCPXMLBundleExporterTests

# Version compatibility tests
xcodebuild test -scheme SwiftSecuencia-Package \
    -destination 'platform=macOS' \
    -only-testing:SwiftSecuenciaTests/FCPXMLVersionTests
```

### Test Coverage Goals

- ✅ Bundle structure validation
- ✅ Info.plist format
- ✅ Media file handling
- ✅ Progress tracking
- ✅ Cancellation
- ✅ Version compatibility (1.8-1.14)
- ✅ Error handling

---

## Recommendations

### For New Projects

**Always use `.fcpxmld` bundles** unless you have a specific reason for standalone XML:

```swift
var exporter = FCPXMLBundleExporter(version: .v1_14, includeMedia: true)
let bundleURL = try await exporter.exportBundle(...)
```

**Benefits**:
- Self-contained (no broken file paths)
- FCP native format
- Archive-ready
- Cross-system compatible

### For Existing Projects

**No action required** if using:
- `FCPXMLExporter` (standalone `.fcpxml`)
- `FCPXMLBundleExporter` (`.fcpxmld` bundles)
- CLI without custom code

**Migration required** only if using:
- `SwiftSecuenciaBundleExporter` (removed) → Use `FCPXMLBundleExporter`

---

## Future Considerations

### When New FCPXML Versions Are Released

1. **Add DTD file** to `Tests/*/Fixtures/FCPXMLv*.dtd`
2. **Add version case** to `FCPXMLVersion` enum (in PipelineNeo)
3. **Update default version** in `SwiftSecuencia.swift`
4. **Add version test** to `FCPXMLVersionTests.swift`
5. **Update documentation** in AGENTS.md

### Monitoring Apple Documentation

Watch for updates to:
- https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference
- https://support.apple.com/final-cut-pro (DTD downloads)

---

## References

### Apple Documentation

- [FCPXML Reference](https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference)
- [FCPXML Bundle Reference](https://developer.apple.com/documentation/professional-video-applications/fcpxml-bundle-reference)
- [Document Type Definition (DTD)](https://developer.apple.com/documentation/professional-video-applications/document-type-definition)
- [Creating FCPXML Documents](https://developer.apple.com/documentation/professional-video-applications/creating-fcpxml-documents)

### Dependencies

- [PipelineNeo](https://github.com/TheAcharya/pipeline-neo) (MIT License) - FCPXML generation
- [SwiftFijos](https://github.com/intrusive-memory/SwiftFijos) - DTD validation

### Related Files

- `Sources/SwiftSecuencia/Export/FCPXMLExporter.swift` - Standalone export
- `Sources/SwiftSecuencia/Export/FCPXMLBundleExporter.swift` - Bundle export
- `Sources/SecuenciaCLICore/Commands/BuildCommand.swift` - CLI implementation
- `Tests/SwiftSecuenciaTests/FCPXMLBundleExporterTests.swift` - Bundle tests
- `Tests/SwiftSecuenciaTests/FCPXMLVersionTests.swift` - Version tests
- `AGENTS.md` - Updated documentation

---

**End of Summary** - SwiftSecuencia now exclusively uses Apple's official `.fcpxmld` bundle format.
