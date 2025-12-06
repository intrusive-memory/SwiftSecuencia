# FCPXML DTD Validation

SwiftSecuencia includes comprehensive DTD (Document Type Definition) validation to ensure that all generated FCPXML documents conform to Apple's official FCPXML specification.

## Overview

The validation system uses `xmllint` (built into macOS) to validate generated FCPXML documents against official DTD files from Apple/CommandPost. This ensures that Final Cut Pro can successfully import the generated files.

## Components

### 1. FCPXMLDTDValidator

Located at: `Sources/SwiftSecuencia/Validation/FCPXMLDTDValidator.swift`

A Swift utility that wraps `xmllint` to provide DTD validation:

```swift
let validator = FCPXMLDTDValidator()
let result = try validator.validate(
    xmlContent: fcpxmlString,
    version: "1.11"
)

if result.isValid {
    print("✓ Valid FCPXML")
} else {
    print("✗ Validation failed:")
    for error in result.errors {
        print("  - \(error)")
    }
}
```

**Features:**
- Validates FCPXML content against DTD files
- Supports versions 1.8 through 1.13
- Provides detailed error messages from xmllint
- Automatically resolves DTD file paths

### 2. DTD Files

Located at: `Tests/SwiftSecuenciaTests/Resources/DTD/`

Official DTD files from [CommandPost](https://github.com/CommandPost/CommandPost):
- FCPXMLv1_8.dtd
- FCPXMLv1_9.dtd
- FCPXMLv1_10.dtd
- FCPXMLv1_11.dtd
- FCPXMLv1_12.dtd
- FCPXMLv1_13.dtd

### 3. Validation Tests

Located at: `Tests/SwiftSecuenciaTests/FCPXMLDTDValidationTests.swift`

Comprehensive test suite with 9 tests:
- `emptyTimelinePassesDTDValidation` - Validates minimal timeline structure
- `singleClipTimelinePassesDTDValidation` - Validates single clip export
- `multiClipTimelinePassesDTDValidation` - Validates multiple clips
- `multiLaneTimelinePassesDTDValidation` - Validates multi-lane timelines
- `timelineWithSourceStartPassesDTDValidation` - Validates source start attribute
- `timelineWithNamedClipsPassesDTDValidation` - Validates clip names
- `differentVideoFormatsPassDTDValidation` - Tests multiple video formats
- `validateAgainstMultipleDTDVersions` - Tests versions 1.9-1.13
- `dtdValidationProvidesUsefulErrors` - Tests error reporting

## CI Integration

DTD validation runs automatically on every CI test cycle in GitHub Actions:

```yaml
- name: Run FCPXML DTD validation tests
  run: |
    echo "🔍 Running FCPXML DTD validation tests..."
    swift test --filter FCPXMLDTDValidation
```

This ensures that:
- No regressions are introduced to FCPXML generation
- All generated FCPXML conforms to the specification
- Changes are validated before merging

## Supported FCPXML Versions

The validator supports versions **1.9 through 1.13**.

**Note:** Version 1.8 has different DTD requirements (e.g., doesn't support `media-rep` element) and is not currently supported by the exporter.

## Validation Results

The `DTDValidationResult` contains:
- `isValid: Bool` - Whether validation passed
- `errors: [String]` - Array of validation errors (empty if valid)
- `rawOutput: String` - Full stderr output from xmllint

## Running Validation Locally

### Validate Specific Tests

```bash
swift test --filter FCPXMLDTDValidation
```

### Validate All Tests

```bash
swift test
```

### Manual Validation

You can also validate FCPXML files manually using xmllint:

```bash
xmllint --noout --dtdvalid Tests/SwiftSecuenciaTests/Resources/DTD/FCPXMLv1_11.dtd your-file.fcpxml
```

## Common Validation Errors

### Missing Required Attributes

```
Element format does not carry attribute name
Element format does not carry attribute frameDuration
```

**Fix:** Ensure all required attributes are present in the XML.

### Invalid Element Nesting

```
Element asset content does not follow the DTD
```

**Fix:** Check that child elements appear in the correct order per the DTD.

### Unknown Elements

```
No declaration for element media-rep
```

**Fix:** Verify the element is supported in the target FCPXML version.

## Best Practices

1. **Always validate exports** - Run DTD validation on all exported FCPXML
2. **Test across versions** - If supporting multiple FCPXML versions, test each
3. **Check error messages** - DTD errors provide specific line numbers and fixes
4. **Use CI validation** - Let CI catch validation issues before merging
5. **Keep DTDs updated** - Monitor CommandPost repo for DTD updates

## Technical Details

### DTD Resolution

The validator searches for DTD files in the following locations:

1. Test bundle resources (SPM `Bundle.module`)
2. `Tests/SwiftSecuenciaTests/Resources/DTD/` (relative to working directory)
3. Project root + `Tests/SwiftSecuenciaTests/Resources/DTD/` (relative to source file)

### xmllint Command

The validator runs:

```bash
xmllint --noout --dtdvalid <dtd-path> <xml-path>
```

Where:
- `--noout` suppresses normal output
- `--dtdvalid` specifies the DTD file to validate against
- Errors are captured from stderr

### Exit Codes

- **0** - Validation passed
- **Non-zero** - Validation failed (errors in stderr)

## Resources

- [Apple FCPXML Reference](https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference)
- [FCP Cafe Developer Resources](https://fcp.cafe/developers/fcpxml/)
- [CommandPost DTD Repository](https://github.com/CommandPost/CommandPost/tree/develop/src/extensions/cp/apple/fcpxml/dtd)
- [xmllint Documentation](http://xmlsoft.org/xmllint.html)

## Future Enhancements

Potential improvements to the validation system:

1. **Schema validation** - Add XSD (XML Schema Definition) validation
2. **Custom validation rules** - Add semantic validation beyond DTD structure
3. **Performance testing** - Validate large timelines (1000+ clips)
4. **FCP import testing** - Automated import into Final Cut Pro for end-to-end validation
5. **Version-specific exports** - Customize export based on target FCPXML version
