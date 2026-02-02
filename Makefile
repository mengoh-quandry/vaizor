#
# Vaizor Build Makefile
# =====================
# Convenient shortcuts for building and packaging Vaizor.
#
# Usage:
#   make build      - Development build
#   make release    - Release build with signing and notarization
#   make dmg        - Create DMG only
#   make clean      - Clean all build artifacts
#   make help       - Show all available targets
#

.PHONY: build release dmg clean help test run install setup-signing

# Default target
all: build

# Development build (no signing, no DMG)
build:
	@./build-app.sh

# Release build with full signing and notarization
# Requires credentials to be configured (see build-config.sh.template)
release:
	@if [ -f build-config.sh ]; then \
		source build-config.sh && ./build-app.sh --release; \
	else \
		./build-app.sh --release; \
	fi

# Release build with signing but skip notarization (faster for testing)
release-local:
	@if [ -f build-config.sh ]; then \
		source build-config.sh && ./build-app.sh --release --skip-notarize; \
	else \
		./build-app.sh --release --skip-notarize; \
	fi

# Release build without signing (for testing build process)
release-unsigned:
	@./build-app.sh --release --skip-sign

# Create DMG from existing app bundle
dmg:
	@./build-app.sh --dmg

# Run the app
run: build
	@open build/Vaizor.app

# Run existing app without rebuilding
open:
	@if [ -d "build/Vaizor.app" ]; then \
		open build/Vaizor.app; \
	elif [ -d "Vaizor.app" ]; then \
		open Vaizor.app; \
	else \
		echo "No app bundle found. Run 'make build' first."; \
		exit 1; \
	fi

# Clean build artifacts
clean:
	@./build-app.sh --clean
	@rm -rf build/
	@rm -rf Vaizor.app
	@rm -f *.dmg
	@echo "Clean complete"

# Deep clean including Swift package cache
clean-all: clean
	@rm -rf .build/
	@swift package clean 2>/dev/null || true
	@echo "Deep clean complete"

# Run tests (if available)
test:
	@swift test

# Install to /Applications (requires sudo for system-wide, or user Applications)
install: build
	@if [ -d "build/Vaizor.app" ]; then \
		cp -R build/Vaizor.app ~/Applications/ 2>/dev/null || \
		sudo cp -R build/Vaizor.app /Applications/; \
		echo "Installed to Applications folder"; \
	else \
		echo "Build the app first with 'make build'"; \
		exit 1; \
	fi

# Show available signing identities
list-identities:
	@echo "Available code signing identities:"
	@security find-identity -v -p codesigning

# Verify the built app's signature
verify:
	@if [ -d "build/Vaizor.app" ]; then \
		echo "Verifying signature..."; \
		codesign --verify --deep --strict --verbose=2 build/Vaizor.app; \
		echo ""; \
		echo "Checking Gatekeeper assessment..."; \
		spctl --assess --type execute --verbose build/Vaizor.app || true; \
	else \
		echo "No app bundle found at build/Vaizor.app"; \
		exit 1; \
	fi

# Setup helper: create build-config.sh from template
setup-signing:
	@if [ -f build-config.sh ]; then \
		echo "build-config.sh already exists. Edit it to update credentials."; \
	else \
		cp build-config.sh.template build-config.sh; \
		echo "Created build-config.sh from template."; \
		echo "Edit build-config.sh to add your credentials."; \
	fi

# Show build info
info:
	@echo "Vaizor Build System"
	@echo "==================="
	@echo ""
	@echo "Version: 1.0.0"
	@echo "Bundle ID: com.vaizor.app"
	@echo "Min macOS: 14.0"
	@echo ""
	@echo "Build directory: build/"
	@echo "App bundle: build/Vaizor.app"
	@echo ""
	@if [ -f build-config.sh ]; then \
		echo "Signing config: build-config.sh (configured)"; \
	else \
		echo "Signing config: Not configured (run 'make setup-signing')"; \
	fi

# Help
help:
	@echo "Vaizor Build System"
	@echo "==================="
	@echo ""
	@echo "Development:"
	@echo "  make build         - Build development version"
	@echo "  make run           - Build and run the app"
	@echo "  make open          - Open existing app bundle"
	@echo "  make test          - Run tests"
	@echo ""
	@echo "Release:"
	@echo "  make release       - Full release with signing and notarization"
	@echo "  make release-local - Release with signing, skip notarization"
	@echo "  make release-unsigned - Release build without signing"
	@echo "  make dmg           - Create DMG from existing app"
	@echo ""
	@echo "Distribution:"
	@echo "  make install       - Install to Applications folder"
	@echo "  make verify        - Verify app signature"
	@echo ""
	@echo "Setup:"
	@echo "  make setup-signing - Create build-config.sh from template"
	@echo "  make list-identities - Show available signing identities"
	@echo "  make info          - Show build configuration info"
	@echo ""
	@echo "Cleaning:"
	@echo "  make clean         - Remove build artifacts"
	@echo "  make clean-all     - Deep clean including package cache"
	@echo ""
	@echo "For full options, run: ./build-app.sh --help"
