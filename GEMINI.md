# Gemini-Specific Development Instructions

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation.

**Last Updated**: 2026-03-27
**Version**: 3.2.1

---

## Overview

This file contains instructions specific to **Google Gemini** agents working on SwiftSecuencia.

For universal project information (architecture, testing, CLI, etc.), see [AGENTS.md](AGENTS.md).

---

## Gemini Configuration

Gemini agents working on SwiftSecuencia use **standard CLI tools** and **Xcode workflows**.

Unlike Claude Code (which has MCP servers like XcodeBuildMCP), Gemini relies on:
- Standard `xcodebuild` commands
- `make` targets (preferred)
- Direct Swift Package Manager commands (when necessary)
- Standard macOS/iOS development tools

---

## Makefile-First Project

SwiftSecuencia has a **Makefile** that encodes the correct build commands, schemes, and dependencies.

**CRITICAL**: ALWAYS use `make` targets instead of raw `xcodebuild` or `swift` commands.

### Available Make Targets

```bash
make help           # Show all available targets
make build          # Build the package (xcodebuild)
make test           # Run tests (xcodebuild)
make clean          # Clean build artifacts
make resolve        # Resolve Swift package dependencies
make lint           # Run SwiftLint with strict mode
make release        # Build for release
make install        # Install secuencia CLI to /usr/local/bin
```

### Why Use Make?

- Correct schemes, destinations, and flags pre-configured
- Dependency resolution order handled automatically
- Consistent build commands across development and CI
- Enforces Apple Silicon architecture requirements

---

## Build System

### Preferred: Use Makefile Targets

```bash
# Build the package
make build

# Run tests
make test

# Clean build artifacts
make clean

# Resolve dependencies
make resolve

# Run linter
make lint
```

### Alternative: Direct xcodebuild Commands

If you need more control than Makefile provides, use `xcodebuild` directly:

```bash
# Build
xcodebuild build \
    -scheme SwiftSecuencia-Package \
    -destination 'platform=macOS,arch=arm64'

# Test
xcodebuild test \
    -scheme SwiftSecuencia-Package \
    -destination 'platform=macOS,arch=arm64'

# Clean
xcodebuild clean \
    -scheme SwiftSecuencia-Package
```

### NEVER Use swift build/test

**CRITICAL**: SwiftSecuencia requires `xcodebuild` for proper platform-specific builds and dependency resolution.

```bash
# ❌ NEVER
swift build
swift test

# ✅ ALWAYS
make build
make test
```

**Why**: The `swift` command doesn't handle:
- Platform-specific code (`#if os(macOS)`)
- Xcode project settings
- Resource bundles (SecuenciaCLICore/Resources/)
- DTD validation tests (require Xcode build system)

---

## Testing Strategy

### Run All Tests

```bash
make test
```

### Run Specific Test Suite

```bash
# SwiftSecuencia core tests only
xcodebuild test \
    -scheme SwiftSecuencia-Package \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:SwiftSecuenciaTests

# CLI tests only
xcodebuild test \
    -scheme SwiftSecuencia-Package \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:SecuenciaCLITests
```

### Run Specific Test

```bash
xcodebuild test \
    -scheme SwiftSecuencia-Package \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:SwiftSecuenciaTests/TimelineTests/testCreateTimeline
```

---

## Dependency Management

### Resolve Dependencies

```bash
# Preferred
make resolve

# Alternative
xcodebuild -resolvePackageDependencies -scheme SwiftSecuencia-Package
```

### Update Dependencies

Edit `Package.swift`, then:

```bash
make resolve
make build
make test
```

### Check Package Graph

```bash
swift package show-dependencies
```

---

## Code Quality

### SwiftLint

```bash
# Run linter (strict mode)
make lint

# Auto-fix issues (use with caution)
swiftlint --fix

# Show linter configuration
cat .swiftlint.yml
```

### Swift Format

SwiftSecuencia uses **SwiftLint** for linting, not `swift-format`.

---

## CLI Tool Development

### Build CLI

```bash
make build
```

### Run CLI (Development)

```bash
# Build first
make build

# Run from build products
.build/debug/secuencia --help

# Or use swift run (builds automatically)
swift run secuencia --help
```

### Install CLI (Production)

```bash
# Install to /usr/local/bin
make install

# Verify installation
which secuencia
secuencia --version
```

### Test CLI

```bash
# Run CLI tests
xcodebuild test \
    -scheme SwiftSecuencia-Package \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:SecuenciaCLITests

# Or use make
make test
```

---

## GitHub Actions CI/CD

SwiftSecuencia uses GitHub Actions for CI/CD.

### Workflow Files

- `.github/workflows/tests.yml` - Runs on every PR

### Key CI Requirements

**macOS Runner**: ALWAYS use `macos-26` or later

```yaml
runs-on: macos-26  # NEVER use macos-15 or older
```

**iOS Simulator Destination**: Use explicit OS version

```yaml
# ✅ CORRECT
-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1'

# ❌ WRONG (OS=latest doesn't work)
-destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

**Swift Version**: Must be 6.2 or later

```bash
# Verify Swift version in CI
swift --version  # Should show 6.2+
```

---

## Gemini-Specific Critical Rules

1. **ALWAYS use Makefile targets** - `make build`, `make test`, `make lint`, etc.
2. **NEVER use swift build/test** - Always use `xcodebuild` (via make or direct commands)
3. **Use standard CLI tools** - No MCP access; rely on xcodebuild, git, gh CLI
4. **Follow Xcode best practices** - Scheme selection, destination strings, proper flags
5. **Test before committing** - `make test` must pass before pushing

---

## Development Workflow

### Standard Workflow

```bash
# 1. Resolve dependencies
make resolve

# 2. Build
make build

# 3. Run tests
make test

# 4. Lint
make lint

# 5. Commit changes
git add .
git commit -m "feat: Add new feature"
git push origin development
```

### Creating Pull Request

```bash
# Push branch
git push origin feature-branch

# Create PR using GitHub CLI
gh pr create \
    --base development \
    --title "feat: Add new feature" \
    --body "Description of changes"

# Check CI status
gh pr checks
```

---

## Troubleshooting

### "Cannot find module 'SecuenciaCLI'"

**Issue**: Tests can't import `SecuenciaCLI` executable.

**Fix**: Import `SecuenciaCLICore` instead:

```swift
// ❌ WRONG
@testable import SecuenciaCLI

// ✅ CORRECT
@testable import SecuenciaCLICore
```

**Reason**: Executables can't be imported, only libraries.

### "Schema resource not found"

**Issue**: Tests can't find `schema.json` resource.

**Fix**: Use `SchemaResource.schemaURL` instead of `Bundle.module`:

```swift
// ❌ WRONG
let url = Bundle.module.url(forResource: "schema", withExtension: "json")

// ✅ CORRECT
let url = SchemaResource.schemaURL
```

**Reason**: Resource is in SecuenciaCLICore bundle, not test bundle.

### "Build fails on CI but works locally"

**Issue**: Build works on local macOS but fails on GitHub Actions.

**Fix**: Check CI runner version and destination string:

1. Verify `runs-on: macos-26` (not older)
2. Use explicit iOS Simulator OS version (`OS=26.1`, not `OS=latest`)
3. Check Swift version: `swift --version` (should be 6.2+)

### "Tests fail with SwiftData errors"

**Issue**: SwiftData tests fail with actor isolation warnings.

**Fix**: Ensure tests use `@MainActor` when working with SwiftData:

```swift
@Test @MainActor
func testSwiftDataOperation() async throws {
    // SwiftData operations here
}
```

---

## Future Gemini Integrations

This section is a placeholder for future Gemini-specific integrations:

- **Gemini API**: If/when we integrate Gemini API for AI features
- **Gemini Code Assist**: For enhanced code completion and suggestions
- **Gemini-specific automation**: Custom workflows or scripts

---

## Related Documentation

- **Universal Guidelines**: [AGENTS.md](AGENTS.md)
- **Claude-Specific**: [CLAUDE.md](CLAUDE.md)

---

**End of GEMINI.md** - This file is specific to Google Gemini agents. For universal project documentation, see AGENTS.md.
