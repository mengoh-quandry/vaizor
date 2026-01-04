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
