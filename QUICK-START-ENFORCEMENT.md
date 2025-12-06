# Quick Start: Platform Enforcement for Your Libraries

Copy this to apply macOS/iOS 26+ enforcement to all your libraries.

## 1. Copy SwiftLint Config (30 seconds)

```bash
# From your new library directory
cp /path/to/SwiftSecuencia/.swiftlint.yml .
```

**For libraries supporting BOTH macOS and iOS**, edit `.swiftlint.yml`:

```yaml
# Change the macOS-only rule to support both platforms
no_old_availability_attribute:
  regex: '@available\s*\(\s*(macOS|iOS)\s+([0-9]|1[0-9]|2[0-5])(\.[0-9]+)?\s*,'
  message: "Use @available(macOS 26.0, *) or @available(iOS 26.0, *). Versions < 26 not supported."
  severity: error

# Remove or comment out the iOS-blocking rule
# no_ios_availability:
#   regex: '(@available|#available|#unavailable)\s*\([^)]*iOS'
#   ...
```

## 2. Update Package.swift (1 minute)

```swift
let package = Package(
    name: "YourLibrary",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)  // Add if you support iOS
    ],
    // ... rest of config
    targets: [
        .target(
            name: "YourLibrary",
            dependencies: [...],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ]
)
```

## 3. Add CI Checks (2 minutes)

Add to your `.github/workflows/*.yml` (in the code quality/linting job):

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
    echo "✅ Platform configuration verified (26+)" >> $GITHUB_STEP_SUMMARY
```

## 4. Test It (30 seconds)

```bash
# Install SwiftLint if not already installed
brew install swiftlint

# Run the linter
swiftlint lint --strict

# Should pass with 0 violations for platform issues
```

## 5. Optional: Pre-commit Hook

```bash
# Create hook file
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
if command -v swiftlint &> /dev/null; then
    swiftlint lint --strict
    if [ $? -ne 0 ]; then
        echo "❌ SwiftLint failed. Fix errors before committing."
        exit 1
    fi
fi
if grep -E "platforms.*\.(macOS|iOS)\(\.v([0-9]|1[0-9]|2[0-5])\)" Package.swift; then
    echo "❌ Package.swift contains platform version < 26"
    exit 1
fi
exit 0
EOF

# Make executable
chmod +x .git/hooks/pre-commit
```

## What This Catches

```swift
// ❌ These will FAIL linting:
@available(macOS 10.15, *)
func oldFunction() {}

if #available(iOS 15, *) {
    // ...
}

#unavailable(macOS 12)

// ✅ These will PASS:
@available(macOS 26.0, *)
func newFunction() {}

if #available(macOS 26, *) {
    // ...
}

#unavailable(macOS 25)  // Unavailable for 25 and below = requires 26+
```

## Full Documentation

See `Docs/PLATFORM-ENFORCEMENT.md` for complete details, troubleshooting, and advanced configurations.

## Verification Checklist

- [ ] `.swiftlint.yml` copied and customized
- [ ] `Package.swift` platforms set to 26+
- [ ] GitHub Actions workflow updated
- [ ] `swiftlint lint --strict` passes locally
- [ ] CI passes on PR
- [ ] (Optional) Pre-commit hook installed

---

**Time to implement:** ~5 minutes per library
**Maintenance:** Zero (automated in CI)
