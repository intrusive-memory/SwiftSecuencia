# Makefile for SwiftSecuencia
#
# Common targets for building, testing, and managing the Swift package.
# Uses xcodebuild for all operations per CLAUDE.md guidelines.

.PHONY: help build test clean resolve install release lint

# Default target
help:
	@echo "SwiftSecuencia Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make build      - Build all targets"
	@echo "  make test       - Run all tests"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make resolve    - Resolve package dependencies"
	@echo "  make lint       - Format Swift source files"
	@echo "  make help       - Show this help message"
	@echo ""
	@echo "macOS-specific targets:"
	@echo "  make test-macos - Run tests on macOS"
	@echo "  make build-macos - Build for macOS"
	@echo ""
	@echo "Note: SwiftSecuencia is a Swift package with macOS and iOS support."
	@echo "      FCPXML export requires macOS; iOS only supports audio export."

# Build all targets
build:
	swift build

# Build for macOS specifically
build-macos:
	xcodebuild build \
		-scheme SwiftSecuencia \
		-destination 'platform=macOS'

# Run all tests
test:
	swift test

# Run tests on macOS
test-macos:
	xcodebuild test \
		-scheme SwiftSecuencia \
		-destination 'platform=macOS'

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Resolve package dependencies
resolve:
	swift package resolve

# Update dependencies
update:
	swift package update

# Format Swift source files
lint:
	swift format -i -r .

# Build release configuration
release:
	swift build -c release

# Install CLI tool (secuencia) to /usr/local/bin
install: release
	@echo "Installing secuencia CLI to /usr/local/bin..."
	install -d /usr/local/bin
	install .build/release/secuencia /usr/local/bin/secuencia
	@echo "✓ Installed secuencia to /usr/local/bin/secuencia"
