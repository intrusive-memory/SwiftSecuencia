# SwiftSecuencia Makefile
# Requires Apple Silicon (arm64) architecture

.PHONY: help check-arch build test clean resolve install lint

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
	@echo "  make lint      - Format Swift source files"
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
	xcodebuild clean -scheme SwiftSecuencia-Package
	rm -rf .build

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

# Format Swift source files
lint:
	swift format -i -r .
