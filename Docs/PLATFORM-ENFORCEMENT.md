# Platform Version Enforcement Guide

This document describes the multi-layered approach to enforcing minimum platform versions (macOS/iOS 26.0+) across all SwiftSecuencia libraries.

## Overview

SwiftSecuencia and related libraries require **macOS 26.0+** (released September 2025) as the minimum deployment target. This guide shows how to prevent code using older platform versions from being committed.

## Enforcement Layers

### 1. SwiftLint (Compile-Time + CI)

**File**: `.swiftlint.yml`

SwiftLint catches old `@available`, `#available`, and `#unavailable` statements using custom regex rules.

```yaml
custom_rules:
  # Prevent @available with macOS versions < 26
  no_old_macos_availability_attribute:
    regex: '@available\s*\([^)]*macOS\s*(?:,\s*introduced:\s*)?([0-9]|1[0-9]|2[0-5])(?:\.[0-9]+)?'
    match_kinds:
      - attribute.builtin
    message: "Use @available(macOS 26.0, *) or higher. macOS versions < 26 are not supported."
    severity: error

  # Prevent #available with macOS versions < 26
  no_old_macos_availability_check:
    regex: '#available\s*\([^)]*macOS\s*(?:,\s*introduced:\s*)?([0-9]|1[0-9]|2[0-5])(?:\.[0-9]+)?'
    message: "Use #available(macOS 26, *) or higher. macOS versions < 26 are not supported."
    severity: error

  # Prevent iOS references (if macOS-only library)
  no_ios_availability:
    regex: '(@available|#available|#unavailable)\s*\([^)]*iOS'
    message: "This library is macOS 26.0+ only. Do not use iOS availability checks."
    severity: error

**Run locally**:
```bash
swiftlint lint --strict
```

### 2. Package.swift (Build-Time)

**File**: `Package.swift`

Explicitly declare platform support to prevent accidental compilation for older platforms.

```swift
let package = Package(
    name: "SwiftSecuencia",
    platforms: [
        .macOS(.v26)  // Minimum deployment target
    ],
    // ... rest of configuration
)
```

The Swift compiler will reject any API usage that requires newer platforms than declared.

### 3. GitHub Actions (CI Enforcement)

**File**: `.github/workflows/tests.yml`

Automated checks in CI prevent merging code with old platform references.

```yaml
- name: Install SwiftLint
  run: brew install swiftlint

- name: Run SwiftLint
  run: |
    echo "🔍 Running SwiftLint with strict mode..."
    swiftlint lint --strict
    echo "✅ SwiftLint passed" >> $GITHUB_STEP_SUMMARY

- name: Verify Platform Configuration
  run: |
    echo "🔍 Verifying Package.swift platform configuration..."
    if grep -E "platforms.*\.(macOS|iOS)\(\.v([0-9]|1[0-9]|2[0-5])\)" Package.swift; then
      echo "❌ Package.swift contains platform version < 26"
      exit 1
    fi
    echo "✅ Platform configuration verified (macOS 26+)" >> $GITHUB_STEP_SUMMARY
```

## Installation Steps

### For SwiftSecuencia (Already Implemented)

SwiftSecuencia already has all enforcement layers configured:
1. ✅ `.swiftlint.yml` with custom rules
2. ✅ `Package.swift` with `platforms: [.macOS(.v26)]`
3. ✅ GitHub Actions workflow with SwiftLint and platform verification

### For Other Libraries

To apply this same enforcement to other libraries:

#### Step 1: Copy SwiftLint Configuration

```bash
# From your library root directory
cp /path/to/SwiftSecuencia/.swiftlint.yml .
```

**Customize for iOS support** (if needed):
```yaml
# For libraries that support BOTH macOS and iOS 26+
custom_rules:
  no_old_availability:
    regex: '@available\s*\(\s*(macOS|iOS)\s+([0-9]|1[0-9]|2[0-5])(\.[0-9]+)?\s*,'
    message: "Use @available(macOS 26.0, *) or @available(iOS 26.0, *). Versions < 26 are not supported."
    severity: error
```

#### Step 2: Update Package.swift

```swift
let package = Package(
    name: "YourLibrary",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)  // Only if you support iOS
    ],
    // ... rest of configuration
)
```

#### Step 3: Add CI Workflow Steps

Add to your `.github/workflows/*.yml`:

```yaml
- name: Install SwiftLint
  run: brew install swiftlint

- name: Run SwiftLint
  run: swiftlint lint --strict

- name: Verify Platform Configuration
  run: |
    if grep -E "platforms.*\.(macOS|iOS)\(\.v([0-9]|1[0-9]|2[0-5])\)" Package.swift; then
      echo "❌ Package.swift contains platform version < 26"
      exit 1
    fi
```

#### Step 4: Install Pre-commit Hook (Optional)

```bash
# Install SwiftLint (if not already installed)
brew install swiftlint

# Copy pre-commit hook
cp /path/to/SwiftSecuencia/.git/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Verification

### Test the Setup

Create a test file with old platform code:

```swift
// This should be caught by SwiftLint
@available(macOS 10.15, *)
func oldPlatformFunction() {
    print("This should fail linting")
}

// This should also be caught
if #available(macOS 12, *) {
    print("Old platform check")
}
```

Run SwiftLint:
```bash
swiftlint lint --strict
```

Expected output:
```
error: Use @available(macOS 26.0, *) or higher. macOS versions < 26 are not supported. (no_old_macos_availability_attribute)
error: Use #available(macOS 26, *) or higher. macOS versions < 26 are not supported. (no_old_macos_availability_check)
```

## Common Issues

### SwiftLint Not Detecting Violations

1. Verify `.swiftlint.yml` is in the project root
2. Check that the file isn't in the `excluded` list
3. Run with `--strict` flag for errors (not just warnings)

### Regex Not Matching

The regex patterns match platform versions 0-25:
- `([0-9]|1[0-9]|2[0-5])` matches: 0, 1, 2, ..., 19, 20, ..., 25
- Versions 26+ will NOT match (which is correct)

Test regex at: https://regex101.com/

### CI Passing Despite Violations

Ensure you're using `swiftlint lint --strict` in CI, which treats warnings as errors.

## Shared Configuration (Advanced)

For managing multiple libraries, create a shared configuration repository:

```
MyLibraries-Config/
├── .swiftlint.yml           # Shared SwiftLint config
├── hooks/
│   └── pre-commit           # Shared pre-commit hook
└── workflows/
    └── platform-check.yml   # Reusable workflow
```

Then symlink in each library:
```bash
ln -s ../MyLibraries-Config/.swiftlint.yml .swiftlint.yml
```

Or use Git submodules:
```bash
git submodule add https://github.com/you/MyLibraries-Config.git config
ln -s config/.swiftlint.yml .swiftlint.yml
```

## Resources

- [SwiftLint Documentation](https://realm.github.io/SwiftLint/)
- [Swift Package Manager - Platform Deployment](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html)
- [GitHub Actions - macOS Runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners)
- [Swift Evolution - Package Manager Platform Settings](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0236-package-manager-platform-deployment-settings.md)

## Version History

- **2025-12-06**: Initial implementation for SwiftSecuencia
  - macOS 26.0+ enforcement
  - SwiftLint custom rules for `@available`, `#available`, `#unavailable`
  - GitHub Actions integration
  - Documentation
