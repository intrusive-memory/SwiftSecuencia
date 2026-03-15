# SwiftSecuencia Makefile
# Requires Apple Silicon (arm64) architecture

.PHONY: help check-arch build test clean resolve install lint lint-fix format release dist

# Default target
help:
	@echo "SwiftSecuencia Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make build     - Build the package (Apple Silicon only)"
	@echo "  make test      - Run all tests (Apple Silicon only)"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make resolve   - Resolve package dependencies"
	@echo "  make install   - Install secuencia CLI to /usr/local/bin"
	@echo "  make release   - Build release binary"
	@echo "  make dist      - Create distributable tarball for Homebrew"
	@echo "  make lint      - Run SwiftLint with strict mode (matches CI)"
	@echo "  make lint-fix  - Auto-fix SwiftLint violations where possible"
	@echo "  make format    - Format Swift source files with swift-format"
	@echo ""
	@echo "Requirements:"
	@echo "  - Apple Silicon (arm64) architecture"
	@echo "  - Xcode 16.2 or later"
	@echo "  - Swift 6.2 or later"

# Check architecture - fail if not Apple Silicon
check-arch:
	@ARCH=$$(uname -m); \
	if [ "$$ARCH" != "arm64" ]; then \
		echo "❌ Error: This project requires Apple Silicon (arm64)"; \
		echo "   Current architecture: $$ARCH"; \
		exit 1; \
	fi

# Resolve dependencies
resolve: check-arch
	@echo "🔄 Resolving package dependencies..."
	xcodebuild -resolvePackageDependencies -scheme SwiftSecuencia-Package

# Build the package
build: check-arch
	@echo "🔨 Building SwiftSecuencia..."
	xcodebuild build \
		-scheme SwiftSecuencia-Package \
		-destination 'platform=macOS,arch=arm64'

# Run all tests
test: check-arch
	@echo "🧪 Running SwiftSecuencia tests..."
	@echo ""
	xcodebuild test \
		-scheme SwiftSecuencia-Package \
		-destination 'platform=macOS,arch=arm64' \
		-enableCodeCoverage YES

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	xcodebuild clean -scheme SwiftSecuencia-Package -destination 'platform=macOS,arch=arm64' 2>/dev/null || true
	rm -rf .build
	rm -rf bin
	rm -rf dist

# Install CLI to /usr/local/bin
install: check-arch
	@echo "📦 Building secuencia CLI for release..."
	xcodebuild build \
		-scheme secuencia \
		-destination 'platform=macOS,arch=arm64' \
		-configuration Release
	@echo "📦 Installing secuencia to /usr/local/bin..."
	@PRODUCT_PATH=$$(xcodebuild build \
		-scheme secuencia \
		-destination 'platform=macOS,arch=arm64' \
		-configuration Release \
		-showBuildSettings 2>/dev/null | \
		grep -m 1 "BUILT_PRODUCTS_DIR" | \
		sed 's/.*= //'); \
	if [ -f "$$PRODUCT_PATH/secuencia" ]; then \
		cp "$$PRODUCT_PATH/secuencia" /usr/local/bin/secuencia; \
		chmod +x /usr/local/bin/secuencia; \
		echo "✅ Installed secuencia to /usr/local/bin/secuencia"; \
	else \
		echo "❌ Error: Could not find built secuencia executable"; \
		exit 1; \
	fi

# Build release binary
release: check-arch
	@echo "🔨 Building secuencia CLI for release..."
	xcodebuild build \
		-scheme secuencia \
		-destination 'platform=macOS,arch=arm64' \
		-configuration Release

# Create distributable tarball
dist: release
	@echo "📦 Creating distribution tarball..."
	@mkdir -p dist bin
	@VERSION=$$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0"); \
	DERIVED_DATA="$${HOME}/Library/Developer/Xcode/DerivedData"; \
	PRODUCT_DIR=$$(find "$$DERIVED_DATA"/SwiftSecuencia-*/Build/Products/Release -name secuencia -type f 2>/dev/null | head -1 | xargs dirname); \
	if [ -z "$$PRODUCT_DIR" ] || [ ! -f "$$PRODUCT_DIR/secuencia" ]; then \
		echo "❌ Error: Could not find built secuencia executable"; \
		exit 1; \
	fi; \
	cp "$$PRODUCT_DIR/secuencia" bin/; \
	tar -C bin -czvf dist/secuencia-$$VERSION-arm64-macos.tar.gz secuencia; \
	SHA256=$$(shasum -a 256 dist/secuencia-$$VERSION-arm64-macos.tar.gz | cut -d' ' -f1); \
	echo ""; \
	echo "=== Distribution Package ==="; \
	echo "Tarball: dist/secuencia-$$VERSION-arm64-macos.tar.gz"; \
	echo "SHA256:  $$SHA256"; \
	ls -lh dist/secuencia-$$VERSION-arm64-macos.tar.gz

# Run SwiftLint with strict mode (matches CI)
lint:
	@echo "🔍 Running SwiftLint with strict mode..."
	swiftlint lint --strict

# Auto-fix SwiftLint violations where possible
lint-fix:
	@echo "🔧 Auto-fixing SwiftLint violations..."
	swiftlint --fix

# Format Swift source files with swift-format
format:
	@echo "✨ Formatting Swift source files..."
	swift format -i -r .
