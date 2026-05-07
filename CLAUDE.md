# Claude-Specific Development Instructions

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation.

**Last Updated**: 2026-05-06
**Version**: 3.2.4

---

## Overview

This file contains instructions specific to **Claude Code** agents working on SwiftSecuencia.

For universal project information (architecture, testing, CLI, etc.), see [AGENTS.md](AGENTS.md).

---

## Global Claude Settings

Your global Claude instructions are in: `~/.claude/CLAUDE.md`

Key patterns from global settings:
- **Communication Style**: Complete candor - flag risks and architectural concerns up front
- **Security**: NEVER echo secrets, environment variables, or credentials
- **Build Preference**: ALWAYS use `xcodebuild` (or XcodeBuildMCP), NEVER `swift build/test`
- **Makefile Projects**: SwiftSecuencia has a Makefile - use `make` targets instead of raw commands
- **GitHub Actions**: ALWAYS use `macos-26` or later for CI/CD

---

## Makefile-First Project

SwiftSecuencia has a **Makefile** that encodes the correct build commands, schemes, and dependencies.

**CRITICAL**: ALWAYS use `make` targets instead of raw `xcodebuild` commands.

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

## MCP Server Configuration

Claude Code has access to specialized MCP servers for iOS/macOS development and App Store operations.

### 1. XcodeBuildMCP

**CRITICAL**: Use XcodeBuildMCP tools for ALL Xcode operations instead of direct `xcodebuild` commands.

#### Available Operations

**Building**:
- `build_macos` - Build for macOS
- `build_sim` - Build for iOS Simulator
- `build_device` - Build for iOS Device
- `build_run_macos` - Build and run on macOS
- `build_run_sim` - Build and run on iOS Simulator

**Testing**:
- `test_macos` - Run tests on macOS
- `test_sim` - Run tests on iOS Simulator
- `test_device` - Run tests on iOS Device

**Swift Packages**:
- `swift_package_build` - Build Swift package
- `swift_package_test` - Test Swift package
- `swift_package_run` - Run Swift package executable
- `swift_package_clean` - Clean Swift package

**Project Info**:
- `discover_projs` - Discover Xcode projects/workspaces
- `list_schemes` - List available schemes
- `show_build_settings` - Show build settings

**Utilities**:
- `clean` - Clean build artifacts

#### Usage Pattern

```swift
// ❌ DON'T use direct xcodebuild
xcodebuild test -scheme SwiftSecuencia-Package -destination 'platform=macOS'

// ✅ DO use XcodeBuildMCP (or make test)
// Use test_macos or swift_package_test
// Or simply: make test
```

#### Benefits

- Structured output instead of parsing xcodebuild text
- Built-in error handling and retry logic
- Faster incremental builds with experimental build system
- Automatic scheme discovery
- Better CI/CD integration

### 2. App Store Connect MCP

**Available for App Store metrics, TestFlight, and Xcode Cloud CI/CD monitoring.**

#### Available Operations

**Apps**:
- `list_apps` - List all apps in App Store Connect
- `get_app` - Get app metadata and details

**Financial**:
- `get_sales_report` - Download sales reports
- `get_revenue_metrics` - Revenue and subscription analytics
- `get_subscription_metrics` - Subscription analytics

**Xcode Cloud** (CI/CD Monitoring):
- `get_xcode_cloud_summary` - CI/CD workflow summary with statistics
- `list_xcode_cloud_products` - List all CI/CD products
- `get_xcode_cloud_workflows` - Get workflows for a product
- `get_xcode_cloud_builds` - Get build history with commit info
- `get_xcode_cloud_build_details` - Inspect specific build run details

**TestFlight**:
- `get_testflight_metrics` - Beta testing data
- `get_beta_testers` - Beta tester information

**Reviews**:
- `get_customer_reviews` - Customer feedback
- `get_review_metrics` - Review analytics

**Analytics**:
- `get_app_analytics` - User engagement metrics

**Health**:
- `test_connection` - Test API connection
- `get_api_stats` - API usage and rate limits

#### Usage Pattern

```bash
# ❌ DON'T manually call App Store Connect API
curl -H "Authorization: Bearer ..." https://api.appstoreconnect.apple.com/v1/apps

# ✅ DO use App Store Connect MCP (via Claude)
# "Show me recent Xcode Cloud build status"
# "What's the CI/CD success rate for SwiftSecuencia?"
# "Show me TestFlight metrics"
```

#### Benefits

- Structured financial and CI/CD data with currency handling
- Automatic gzip decompression for reports
- Built-in rate limiting and retry logic
- AI-optimized response formatting
- Real-time build monitoring for Xcode Cloud

---

## Claude-Specific Build Preferences

### 1. Use Makefile Targets

**ALWAYS** use `make` targets for build operations:

```bash
# Build
make build

# Test
make test

# Clean
make clean

# Resolve dependencies
make resolve

# Lint
make lint
```

### 2. XcodeBuildMCP for Direct Operations

When you need direct Xcode operations (not covered by Makefile), use XcodeBuildMCP tools:

- Testing specific destinations: `test_macos`, `test_sim`
- Building for different platforms: `build_macos`, `build_sim`
- Swift package operations: `swift_package_build`, `swift_package_test`

### 3. NEVER Use swift build/test

**CRITICAL**: SwiftSecuencia requires `xcodebuild` for proper dependency resolution and platform-specific builds.

```bash
# ❌ NEVER
swift build
swift test

# ✅ ALWAYS
make build
make test
# OR use XcodeBuildMCP tools
```

---

## Claude-Specific Critical Rules

1. **ALWAYS use Makefile targets** - `make build`, `make test`, `make lint`, etc.
2. **Leverage XcodeBuildMCP** - Use MCP tools for Xcode operations not covered by Makefile
3. **Monitor CI/CD with App Store Connect MCP** - Check Xcode Cloud build status
4. **Follow global CLAUDE.md patterns** - Communication, security, GitHub Actions
5. **NEVER use swift build/test** - Always use `xcodebuild` (via make or MCP)

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
git commit -m "feat: Add new feature

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

### Using XcodeBuildMCP for Advanced Operations

When Makefile targets aren't sufficient, use XcodeBuildMCP:

```bash
# Discover projects
discover_projs

# List schemes
list_schemes

# Show build settings
show_build_settings -scheme SwiftSecuencia-Package

# Test on specific simulator
test_sim -scheme SwiftSecuencia-Package -simulatorName "iPhone 17"
```

---

## Troubleshooting

### "Cannot find MCP tool"

**Issue**: Claude can't find XcodeBuildMCP or App Store Connect MCP tools.

**Fix**: MCP servers are configured in `~/.claude/mcp_servers.json`. Contact user if servers aren't available.

### "Make target fails"

**Issue**: `make test` or `make build` fails with unclear error.

**Fix**:
1. Check Makefile for the actual command being run
2. Use XcodeBuildMCP tools directly for better error messages
3. Verify dependencies are resolved: `make resolve`

### "Xcode Cloud build failed"

**Issue**: CI build fails on GitHub Actions or Xcode Cloud.

**Fix**:
1. Use App Store Connect MCP to check Xcode Cloud build details
2. Verify `macos-26` runner is used in GitHub Actions
3. Check that iOS Simulator destination uses explicit OS version (e.g., `OS=26.1`, NOT `OS=latest`)

---

## Related Documentation

- **Universal Guidelines**: [AGENTS.md](AGENTS.md)
- **Global Claude Settings**: `~/.claude/CLAUDE.md`
- **Gemini-Specific**: [GEMINI.md](GEMINI.md)

---

**End of CLAUDE.md** - This file is specific to Claude Code agents. For universal project documentation, see AGENTS.md.
