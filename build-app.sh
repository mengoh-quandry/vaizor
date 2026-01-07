#!/bin/bash

set -e

echo "🔨 Building Vaizor..."

# Build release version
swift build -c release

echo "📦 Creating app bundle..."

# Create app bundle structure
mkdir -p Vaizor.app/Contents/MacOS
mkdir -p Vaizor.app/Contents/Resources

# Copy executable
cp .build/release/vaizor Vaizor.app/Contents/MacOS/Vaizor

# Copy app icon
cp Resources/Icons/Vaizor.png Vaizor.app/Contents/Resources/Vaizor.png

# Generate .icns from PNG for proper Finder icon
ICONSET_DIR="$(mktemp -d)/Vaizor.iconset"
mkdir -p "$ICONSET_DIR"
for size in 16 32 64 128 256 512; do
  /usr/bin/sips -z "$size" "$size" Resources/Icons/Vaizor.png --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  /usr/bin/sips -z $((size * 2)) $((size * 2)) Resources/Icons/Vaizor.png --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o Vaizor.app/Contents/Resources/Vaizor.icns
rm -rf "$ICONSET_DIR"

# Create Info.plist
cat > Vaizor.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Vaizor</string>
    <key>CFBundleIdentifier</key>
    <string>com.vaizor.app</string>
    <key>CFBundleName</key>
    <string>Vaizor</string>
    <key>CFBundleIconFile</key>
    <string>Vaizor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ Build complete!"
echo ""
echo "To run Vaizor:"
echo "  open Vaizor.app"
echo ""
echo "Or double-click Vaizor.app in Finder"
