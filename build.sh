#!/bin/bash

# Build script for SellMore Mac app

set -e

echo "Building SellMore..."

# Clean previous builds
rm -rf dist/
mkdir -p dist/
mkdir -p downloads/

# Create Info.plist
cat > dist/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>SellMore</string>
    <key>CFBundleExecutable</key>
    <string>SellMore</string>
    <key>CFBundleIdentifier</key>
    <string>com.sellmore.SellMore</string>
    <key>CFBundleName</key>
    <string>SellMore</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>SellMore needs access to control other applications to close Zoom windows when timer expires.</string>
</dict>
</plist>
EOF

# Compile for both architectures
echo "Building for x86_64..."
swiftc -target x86_64-apple-macos13.0 -parse-as-library -O main.swift -o dist/SellMore_x86_64

echo "Building for arm64..."
swiftc -target arm64-apple-macos13.0 -parse-as-library -O main.swift -o dist/SellMore_arm64

# Create universal binary
echo "Creating universal binary..."
lipo -create dist/SellMore_x86_64 dist/SellMore_arm64 -output dist/SellMore

# Create app bundle
echo "Creating app bundle..."
mkdir -p dist/SellMore.app/Contents/MacOS/
mkdir -p dist/SellMore.app/Contents/Resources/

cp dist/SellMore dist/SellMore.app/Contents/MacOS/
cp dist/Info.plist dist/SellMore.app/Contents/
chmod +x dist/SellMore.app/Contents/MacOS/SellMore

# Clean up temporary files
rm dist/SellMore_x86_64 dist/SellMore_arm64 dist/SellMore dist/Info.plist

# Compress for distribution
echo "Compressing for distribution..."
cd dist/
zip -r ../downloads/SellMore.zip SellMore.app
cd ..

echo "Build complete!"
echo "App available at: dist/SellMore.app"
echo "Distribution package: downloads/SellMore.zip" 