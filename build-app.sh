#!/bin/bash
#
# Vaizor macOS App Build Script
# =============================
# This script builds, signs, notarizes, and packages Vaizor for distribution.
#
# Usage:
#   ./build-app.sh              # Development build (no signing)
#   ./build-app.sh --release    # Release build with signing and notarization
#   ./build-app.sh --dmg        # Create DMG only (assumes app is already built and signed)
#   ./build-app.sh --help       # Show help
#
# Prerequisites for release builds:
#   1. Apple Developer Program membership
#   2. Developer ID Application certificate installed in Keychain
#   3. Developer ID Installer certificate (for pkg distribution)
#   4. App-specific password for notarization
#
# Configuration:
#   Set the following environment variables or edit the values below:
#   - DEVELOPER_ID_APPLICATION: Your Developer ID Application certificate name
#   - DEVELOPER_ID_INSTALLER: Your Developer ID Installer certificate name
#   - APPLE_ID: Your Apple ID email for notarization
#   - APPLE_TEAM_ID: Your Apple Developer Team ID
#   - NOTARIZATION_PASSWORD: App-specific password (store in Keychain recommended)
#
# ============================================================================

set -e

# ==============================================================================
# CONFIGURATION - Edit these values for your Developer ID
# ==============================================================================

# Code Signing Identity (find yours with: security find-identity -v -p codesigning)
# Format: "Developer ID Application: Your Name (TEAM_ID)"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-}"

# Installer Signing Identity (for .pkg files)
# Format: "Developer ID Installer: Your Name (TEAM_ID)"
DEVELOPER_ID_INSTALLER="${DEVELOPER_ID_INSTALLER:-}"

# Apple ID for notarization (your Apple Developer account email)
APPLE_ID="${APPLE_ID:-}"

# Team ID (10-character alphanumeric, find at developer.apple.com/account)
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"

# Notarization password - Use Keychain reference for security:
#   xcrun notarytool store-credentials "VAIZOR_NOTARIZATION" \
#     --apple-id "your@email.com" \
#     --team-id "YOURTEAMID" \
#     --password "xxxx-xxxx-xxxx-xxxx"
# Then set: NOTARIZATION_KEYCHAIN_PROFILE="VAIZOR_NOTARIZATION"
NOTARIZATION_KEYCHAIN_PROFILE="${NOTARIZATION_KEYCHAIN_PROFILE:-}"
NOTARIZATION_PASSWORD="${NOTARIZATION_PASSWORD:-}"

# ==============================================================================
# VERSION CONFIGURATION
# ==============================================================================

# Version numbers - Update these for each release
VERSION_MAJOR=1
VERSION_MINOR=0
VERSION_PATCH=0
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

VERSION_STRING="${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}"
FULL_VERSION="${VERSION_STRING}.${BUILD_NUMBER}"

# ==============================================================================
# BUILD CONFIGURATION
# ==============================================================================

APP_NAME="Vaizor"
BUNDLE_ID="com.vaizor.app"
MIN_MACOS_VERSION="14.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION_STRING}"
ENTITLEMENTS_FILE="${SCRIPT_DIR}/Vaizor.entitlements"

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

print_header() {
    echo ""
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

print_step() {
    echo ""
    echo ">>> $1"
}

print_success() {
    echo "[SUCCESS] $1"
}

print_warning() {
    echo "[WARNING] $1"
}

print_error() {
    echo "[ERROR] $1" >&2
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is required but not installed."
        exit 1
    fi
}

show_help() {
    cat << EOF
Vaizor Build Script
===================

Usage: ./build-app.sh [OPTIONS]

Options:
  --release     Build for release with code signing and notarization
  --dmg         Create DMG package only (app must already exist)
  --skip-sign   Skip code signing (for testing)
  --skip-notarize Skip notarization (for testing signed builds locally)
  --clean       Clean build artifacts before building
  --verbose     Show detailed build output
  --help        Show this help message

Environment Variables:
  DEVELOPER_ID_APPLICATION    Code signing identity for app
  DEVELOPER_ID_INSTALLER      Code signing identity for installer
  APPLE_ID                    Apple ID for notarization
  APPLE_TEAM_ID               Apple Developer Team ID
  NOTARIZATION_KEYCHAIN_PROFILE  Keychain profile name (preferred)
  NOTARIZATION_PASSWORD       App-specific password (if not using keychain)
  BUILD_NUMBER                Override automatic build number

Examples:
  # Development build
  ./build-app.sh

  # Release build with signing
  DEVELOPER_ID_APPLICATION="Developer ID Application: John Doe (ABC123XYZ)" \\
  ./build-app.sh --release --skip-notarize

  # Full release with notarization
  ./build-app.sh --release

  # Create DMG from existing signed app
  ./build-app.sh --dmg

EOF
}

# ==============================================================================
# PARSE ARGUMENTS
# ==============================================================================

RELEASE_BUILD=false
DMG_ONLY=false
SKIP_SIGN=false
SKIP_NOTARIZE=false
CLEAN_BUILD=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            RELEASE_BUILD=true
            shift
            ;;
        --dmg)
            DMG_ONLY=true
            shift
            ;;
        --skip-sign)
            SKIP_SIGN=true
            shift
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ==============================================================================
# VALIDATION
# ==============================================================================

print_header "Vaizor Build Script v${VERSION_STRING}"

echo "Build Configuration:"
echo "  Version: ${VERSION_STRING} (${BUILD_NUMBER})"
echo "  Release Build: ${RELEASE_BUILD}"
echo "  Skip Signing: ${SKIP_SIGN}"
echo "  Skip Notarization: ${SKIP_NOTARIZE}"

if [[ "$RELEASE_BUILD" == "true" && "$SKIP_SIGN" == "false" ]]; then
    if [[ -z "$DEVELOPER_ID_APPLICATION" ]]; then
        print_error "DEVELOPER_ID_APPLICATION is required for release builds."
        echo ""
        echo "To find your signing identity, run:"
        echo "  security find-identity -v -p codesigning"
        echo ""
        echo "Then set the environment variable:"
        echo "  export DEVELOPER_ID_APPLICATION=\"Developer ID Application: Your Name (TEAMID)\""
        exit 1
    fi
    echo "  Signing Identity: ${DEVELOPER_ID_APPLICATION}"
fi

if [[ "$RELEASE_BUILD" == "true" && "$SKIP_NOTARIZE" == "false" ]]; then
    if [[ -z "$NOTARIZATION_KEYCHAIN_PROFILE" && (-z "$APPLE_ID" || -z "$APPLE_TEAM_ID") ]]; then
        print_error "Notarization credentials are required for release builds."
        echo ""
        echo "Option 1 - Store credentials in Keychain (recommended):"
        echo "  xcrun notarytool store-credentials \"VAIZOR_NOTARIZATION\" \\"
        echo "    --apple-id \"your@email.com\" \\"
        echo "    --team-id \"YOURTEAMID\" \\"
        echo "    --password \"xxxx-xxxx-xxxx-xxxx\""
        echo "  export NOTARIZATION_KEYCHAIN_PROFILE=\"VAIZOR_NOTARIZATION\""
        echo ""
        echo "Option 2 - Set environment variables:"
        echo "  export APPLE_ID=\"your@email.com\""
        echo "  export APPLE_TEAM_ID=\"YOURTEAMID\""
        echo "  export NOTARIZATION_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
        echo ""
        echo "Or use --skip-notarize for local testing."
        exit 1
    fi
fi

# ==============================================================================
# CLEAN
# ==============================================================================

if [[ "$CLEAN_BUILD" == "true" ]]; then
    print_step "Cleaning build artifacts..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${SCRIPT_DIR}/.build"
    swift package clean 2>/dev/null || true
    print_success "Clean complete"
fi

# ==============================================================================
# DMG ONLY MODE
# ==============================================================================

if [[ "$DMG_ONLY" == "true" ]]; then
    if [[ ! -d "$APP_BUNDLE" ]]; then
        print_error "App bundle not found at ${APP_BUNDLE}"
        echo "Run ./build-app.sh first to create the app."
        exit 1
    fi
    # Skip to DMG creation
    print_header "Creating DMG Package"
else
    # ==============================================================================
    # BUILD
    # ==============================================================================

    print_header "Building Vaizor"

    print_step "Compiling Swift Package (Release)..."

    # Swift build flags for release
    SWIFT_FLAGS="-c release"

    if [[ "$RELEASE_BUILD" == "true" ]]; then
        # Additional optimizations for release
        SWIFT_FLAGS="$SWIFT_FLAGS -Xswiftc -O -Xswiftc -whole-module-optimization"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        swift build $SWIFT_FLAGS
    else
        swift build $SWIFT_FLAGS 2>&1 | grep -E "(Build|Compiling|Linking|error:|warning:)" || true
    fi

    print_success "Compilation complete"

    # ==============================================================================
    # CREATE APP BUNDLE
    # ==============================================================================

    print_step "Creating app bundle structure..."

    # Create directories
    mkdir -p "${APP_BUNDLE}/Contents/MacOS"
    mkdir -p "${APP_BUNDLE}/Contents/Resources"
    mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

    # Copy executable
    cp "${SCRIPT_DIR}/.build/release/vaizor" "${APP_BUNDLE}/Contents/MacOS/Vaizor"

    # Strip debug symbols for release builds
    if [[ "$RELEASE_BUILD" == "true" ]]; then
        print_step "Stripping debug symbols..."
        strip -x "${APP_BUNDLE}/Contents/MacOS/Vaizor" 2>/dev/null || true
        print_success "Debug symbols stripped"
    fi

    # ==============================================================================
    # GENERATE ICONS
    # ==============================================================================

    print_step "Generating app icons..."

    ICONSET_DIR="$(mktemp -d)/Vaizor.iconset"
    mkdir -p "$ICONSET_DIR"

    if [[ -f "${SCRIPT_DIR}/Resources/Icons/Vaizor.png" ]]; then
        # Generate all required icon sizes from source PNG
        for size in 16 32 64 128 256 512; do
            /usr/bin/sips -z "$size" "$size" "${SCRIPT_DIR}/Resources/Icons/Vaizor.png" \
                --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null 2>&1 || true
            /usr/bin/sips -z $((size * 2)) $((size * 2)) "${SCRIPT_DIR}/Resources/Icons/Vaizor.png" \
                --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null 2>&1 || true
        done

        # Create .icns file
        /usr/bin/iconutil -c icns "$ICONSET_DIR" -o "${APP_BUNDLE}/Contents/Resources/Vaizor.icns" 2>/dev/null || {
            print_warning "Failed to create .icns file, using PNG fallback"
        }

        # Copy PNG as backup
        cp "${SCRIPT_DIR}/Resources/Icons/Vaizor.png" "${APP_BUNDLE}/Contents/Resources/Vaizor.png"
        print_success "Icons generated"
    else
        print_warning "Resources/Icons/Vaizor.png not found, using system default icon"
    fi

    rm -rf "$(dirname "$ICONSET_DIR")"

    # ==============================================================================
    # COPY RESOURCES
    # ==============================================================================

    print_step "Copying resources..."

    # Copy bundled JavaScript libraries for artifact rendering
    if [[ -d "${SCRIPT_DIR}/Resources/js" ]]; then
        mkdir -p "${APP_BUNDLE}/Contents/Resources/js"
        cp "${SCRIPT_DIR}/Resources/js/"*.js "${APP_BUNDLE}/Contents/Resources/js/" 2>/dev/null || true
        JS_COUNT=$(ls -1 "${SCRIPT_DIR}/Resources/js/"*.js 2>/dev/null | wc -l | tr -d ' ')
        echo "  Copied $JS_COUNT JavaScript libraries"
    fi

    # Copy whiteboard resources
    if [[ -d "${SCRIPT_DIR}/Resources/whiteboard" ]]; then
        mkdir -p "${APP_BUNDLE}/Contents/Resources/whiteboard"
        cp -R "${SCRIPT_DIR}/Resources/whiteboard/"* "${APP_BUNDLE}/Contents/Resources/whiteboard/" 2>/dev/null || true
        echo "  Copied whiteboard resources"
    fi

    # Copy other icon resources (provider logos, etc.)
    if [[ -d "${SCRIPT_DIR}/Resources/Icons" ]]; then
        mkdir -p "${APP_BUNDLE}/Contents/Resources/Icons"
        cp "${SCRIPT_DIR}/Resources/Icons/"*.png "${APP_BUNDLE}/Contents/Resources/Icons/" 2>/dev/null || true
        cp "${SCRIPT_DIR}/Resources/Icons/"*.jpeg "${APP_BUNDLE}/Contents/Resources/Icons/" 2>/dev/null || true
        echo "  Copied icon resources"
    fi

    print_success "Resources copied"

    # ==============================================================================
    # CREATE INFO.PLIST
    # ==============================================================================

    print_step "Creating Info.plist..."

    cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Vaizor</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>Vaizor.icns</string>
    <key>CFBundleIconName</key>
    <string>Vaizor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION_STRING}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS_VERSION}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>© $(date +%Y) Quandry Labs. All rights reserved.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
        <key>NSAllowsArbitraryLoadsInWebContent</key>
        <true/>
    </dict>
    <key>NSCameraUsageDescription</key>
    <string>Vaizor may use the camera for image capture if enabled.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Vaizor may use the microphone for voice input if enabled.</string>
</dict>
</plist>
EOF

    print_success "Info.plist created"

    # ==============================================================================
    # CREATE PKGINFO
    # ==============================================================================

    echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

fi  # End of build section (not DMG_ONLY)

# ==============================================================================
# CODE SIGNING
# ==============================================================================

if [[ "$RELEASE_BUILD" == "true" && "$SKIP_SIGN" == "false" ]]; then
    print_header "Code Signing"

    print_step "Signing app bundle..."

    # Sign frameworks first (if any)
    if [[ -d "${APP_BUNDLE}/Contents/Frameworks" ]]; then
        for framework in "${APP_BUNDLE}/Contents/Frameworks/"*.framework; do
            if [[ -d "$framework" ]]; then
                echo "  Signing framework: $(basename "$framework")"
                codesign --force --options runtime \
                    --entitlements "$ENTITLEMENTS_FILE" \
                    --sign "$DEVELOPER_ID_APPLICATION" \
                    --timestamp \
                    "$framework"
            fi
        done
    fi

    # Sign helper tools (if any)
    if [[ -d "${APP_BUNDLE}/Contents/MacOS" ]]; then
        for helper in "${APP_BUNDLE}/Contents/MacOS/"*; do
            if [[ -x "$helper" && "$(basename "$helper")" != "Vaizor" ]]; then
                echo "  Signing helper: $(basename "$helper")"
                codesign --force --options runtime \
                    --entitlements "$ENTITLEMENTS_FILE" \
                    --sign "$DEVELOPER_ID_APPLICATION" \
                    --timestamp \
                    "$helper"
            fi
        done
    fi

    # Sign the main app bundle
    echo "  Signing main app bundle..."
    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS_FILE" \
        --sign "$DEVELOPER_ID_APPLICATION" \
        --timestamp \
        --deep \
        "$APP_BUNDLE"

    print_success "Code signing complete"

    # Verify signature
    print_step "Verifying code signature..."
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" 2>&1 | head -5

    # Check Gatekeeper assessment
    print_step "Checking Gatekeeper assessment..."
    spctl --assess --type execute --verbose "$APP_BUNDLE" 2>&1 || {
        print_warning "Gatekeeper assessment may fail until app is notarized"
    }

    print_success "Signature verification complete"
fi

# ==============================================================================
# NOTARIZATION
# ==============================================================================

if [[ "$RELEASE_BUILD" == "true" && "$SKIP_NOTARIZE" == "false" && "$DMG_ONLY" == "false" ]]; then
    print_header "Notarization"

    print_step "Creating ZIP for notarization..."
    NOTARIZATION_ZIP="${BUILD_DIR}/${APP_NAME}-notarization.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARIZATION_ZIP"

    print_step "Submitting to Apple for notarization..."
    echo "This may take several minutes..."

    if [[ -n "$NOTARIZATION_KEYCHAIN_PROFILE" ]]; then
        # Use stored credentials
        xcrun notarytool submit "$NOTARIZATION_ZIP" \
            --keychain-profile "$NOTARIZATION_KEYCHAIN_PROFILE" \
            --wait
    else
        # Use environment variables
        xcrun notarytool submit "$NOTARIZATION_ZIP" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$NOTARIZATION_PASSWORD" \
            --wait
    fi

    print_step "Stapling notarization ticket..."
    xcrun stapler staple "$APP_BUNDLE"

    print_success "Notarization complete"

    # Clean up notarization ZIP
    rm -f "$NOTARIZATION_ZIP"

    # Verify notarization
    print_step "Verifying notarization..."
    spctl --assess --type execute --verbose "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"

    print_success "Notarization verified"
fi

# ==============================================================================
# CREATE DMG
# ==============================================================================

if [[ "$RELEASE_BUILD" == "true" || "$DMG_ONLY" == "true" ]]; then
    print_header "Creating DMG Package"

    DMG_TEMP="${BUILD_DIR}/dmg-temp"
    DMG_PATH="${BUILD_DIR}/${DMG_NAME}.dmg"

    # Clean up any existing DMG work
    rm -rf "$DMG_TEMP"
    rm -f "$DMG_PATH"
    rm -f "${DMG_PATH%.dmg}-temp.dmg"

    print_step "Preparing DMG contents..."
    mkdir -p "$DMG_TEMP"

    # Copy app to DMG staging
    cp -R "$APP_BUNDLE" "$DMG_TEMP/"

    # Create Applications symlink
    ln -s /Applications "$DMG_TEMP/Applications"

    # Create background image directory
    mkdir -p "$DMG_TEMP/.background"

    # Create a simple background image with instructions
    # Using a PNG generated with sips from a colored canvas
    print_step "Creating DMG background..."

    # Create background using Python (available on macOS)
    python3 << 'PYTHON_SCRIPT'
import os
from pathlib import Path

# Create a simple SVG background
svg_content = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="600" height="400" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1a2e;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#16213e;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="100%" height="100%" fill="url(#bg)"/>
  <text x="300" y="350" text-anchor="middle" fill="#666" font-family="SF Pro Display, Helvetica" font-size="14">
    Drag Vaizor to Applications to install
  </text>
</svg>'''

build_dir = os.environ.get('BUILD_DIR', 'build')
bg_path = Path(build_dir) / 'dmg-temp' / '.background' / 'background.svg'
bg_path.parent.mkdir(parents=True, exist_ok=True)
bg_path.write_text(svg_content)
print(f"Created background at {bg_path}")
PYTHON_SCRIPT

    # Convert SVG to PNG using built-in tools
    if command -v qlmanage &> /dev/null; then
        qlmanage -t -s 600 -o "$DMG_TEMP/.background" "$DMG_TEMP/.background/background.svg" 2>/dev/null || true
        if [[ -f "$DMG_TEMP/.background/background.svg.png" ]]; then
            mv "$DMG_TEMP/.background/background.svg.png" "$DMG_TEMP/.background/background.png"
        fi
    fi

    print_step "Creating DMG image..."

    # Calculate size (app size + 50MB buffer)
    APP_SIZE=$(du -sm "$APP_BUNDLE" | cut -f1)
    DMG_SIZE=$((APP_SIZE + 50))

    # Create temporary DMG
    hdiutil create -srcfolder "$DMG_TEMP" \
        -volname "$APP_NAME" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        -size "${DMG_SIZE}m" \
        "${DMG_PATH%.dmg}-temp.dmg"

    # Mount the DMG
    print_step "Configuring DMG appearance..."
    MOUNT_POINT=$(hdiutil attach -readwrite -noverify "${DMG_PATH%.dmg}-temp.dmg" | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')

    # Set DMG window appearance using AppleScript
    osascript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 1000, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128

        -- Position icons
        set position of item "Vaizor.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}

        -- Set background if available
        try
            set background picture of viewOptions to file ".background:background.png"
        end try

        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

    # Unmount
    sync
    hdiutil detach "$MOUNT_POINT" -quiet || hdiutil detach "$MOUNT_POINT" -force

    # Convert to compressed DMG
    print_step "Compressing DMG..."
    hdiutil convert "${DMG_PATH%.dmg}-temp.dmg" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$DMG_PATH"

    # Clean up
    rm -f "${DMG_PATH%.dmg}-temp.dmg"
    rm -rf "$DMG_TEMP"

    # Sign the DMG if doing a release build
    if [[ "$RELEASE_BUILD" == "true" && "$SKIP_SIGN" == "false" ]]; then
        print_step "Signing DMG..."
        codesign --force --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$DMG_PATH"
        print_success "DMG signed"
    fi

    # Notarize the DMG
    if [[ "$RELEASE_BUILD" == "true" && "$SKIP_NOTARIZE" == "false" ]]; then
        print_step "Notarizing DMG..."

        if [[ -n "$NOTARIZATION_KEYCHAIN_PROFILE" ]]; then
            xcrun notarytool submit "$DMG_PATH" \
                --keychain-profile "$NOTARIZATION_KEYCHAIN_PROFILE" \
                --wait
        else
            xcrun notarytool submit "$DMG_PATH" \
                --apple-id "$APPLE_ID" \
                --team-id "$APPLE_TEAM_ID" \
                --password "$NOTARIZATION_PASSWORD" \
                --wait
        fi

        xcrun stapler staple "$DMG_PATH"
        print_success "DMG notarized and stapled"
    fi

    DMG_SIZE_FINAL=$(du -h "$DMG_PATH" | cut -f1)
    print_success "DMG created: ${DMG_PATH} (${DMG_SIZE_FINAL})"
fi

# ==============================================================================
# SUMMARY
# ==============================================================================

print_header "Build Complete"

echo ""
echo "App Bundle: ${APP_BUNDLE}"
echo "Version: ${VERSION_STRING} (${BUILD_NUMBER})"

if [[ -f "${BUILD_DIR}/${DMG_NAME}.dmg" ]]; then
    echo "DMG Package: ${BUILD_DIR}/${DMG_NAME}.dmg"
fi

echo ""
echo "To run the app:"
echo "  open ${APP_BUNDLE}"
echo ""

if [[ "$RELEASE_BUILD" == "true" ]]; then
    if [[ "$SKIP_SIGN" == "false" ]]; then
        echo "Code Signing: Complete"
    else
        echo "Code Signing: Skipped"
    fi
    if [[ "$SKIP_NOTARIZE" == "false" ]]; then
        echo "Notarization: Complete"
    else
        echo "Notarization: Skipped"
    fi
    echo ""
    echo "The app is ready for distribution!"
else
    echo "Note: This is a development build."
    echo "For distribution, run: ./build-app.sh --release"
fi

echo ""
