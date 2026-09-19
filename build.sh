#!/bin/bash
set -e
cd "$(dirname "$0")"
APP=Blink4.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Blink4</string>
  <key>CFBundleDisplayName</key><string>Blink4</string>
  <key>CFBundleExecutable</key><string>Blink4</string>
  <key>CFBundleIdentifier</key><string>com.imhkr.blink4</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

swiftc -O -target arm64-apple-macos12 -o "$APP/Contents/MacOS/Blink4.arm64" Sources/main.swift
swiftc -O -target x86_64-apple-macos12 -o "$APP/Contents/MacOS/Blink4.x86_64" Sources/main.swift
lipo -create -output "$APP/Contents/MacOS/Blink4" "$APP/Contents/MacOS/Blink4.arm64" "$APP/Contents/MacOS/Blink4.x86_64"
rm "$APP/Contents/MacOS/Blink4.arm64" "$APP/Contents/MacOS/Blink4.x86_64"
codesign --force --deep -s - "$APP"
echo "BUILD OK -> $(pwd)/$APP"
