#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")"
APP="$PWD/ClipX.app"

pkill -x ClipX 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc ClipX.swift \
  -o "$APP/Contents/MacOS/ClipX" \
  -framework Cocoa \
  -framework Security

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ClipX</string>
  <key>CFBundleDisplayName</key><string>ClipX</string>
  <key>CFBundleIdentifier</key><string>online.novec.clipx</string>
  <key>CFBundleExecutable</key><string>ClipX</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>CFBundleShortVersionString</key><string>0.4.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

chmod +x "$APP/Contents/MacOS/ClipX"

echo "Built: $APP"
open "$APP"
