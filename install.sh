#!/bin/bash
# Builds macOS Pets and installs it as a proper .app bundle in /Applications.
#
# A bundle matters here: the overlay windows and the menu-bar item behave
# better as a real app, and macOS needs a bundle to associate the app with
# its icon and activation policy.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="macOS Pets"
DEST="/Applications/${APP_NAME}.app"

echo "==> Building release binary"
swift build -c release

echo "==> Assembling bundle"
rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"

cp .build/release/macos-pets "$DEST/Contents/MacOS/macos-pets"

# Verbatim upstream GIF artwork + attribution (CC BY-ND 4.0, see
# Assets/vscode-pets/ATTRIBUTION.md). Copied unmodified.
echo "==> Bundling artwork"
rm -rf "$DEST/Contents/Resources/vscode-pets"
mkdir -p "$DEST/Contents/Resources/vscode-pets"
cp -R Assets/vscode-pets/media "$DEST/Contents/Resources/vscode-pets/media"
cp Assets/vscode-pets/ATTRIBUTION.md Assets/vscode-pets/LICENSE.upstream Assets/vscode-pets/credits.upstream.md "$DEST/Contents/Resources/vscode-pets/"

cat > "$DEST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>macOS Pets</string>
    <key>CFBundleDisplayName</key>
    <string>macOS Pets</string>
    <key>CFBundleIdentifier</key>
    <string>dev.local.macos-pets</string>
    <key>CFBundleExecutable</key>
    <string>macos-pets</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <!-- Accessory app: no Dock icon, menu bar only. -->
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Generate a pawprint icon so the bundle is not icon-less in the Finder.
cat > /tmp/macos-pets-icon.swift <<'SWIFT'
import AppKit
let size = 512
let image = NSImage(size: NSPoint(width: size, height: size))
image.lockFocus()
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
let cfg = NSImage.SymbolConfiguration(pointSize: 420, weight: .regular)
if let symbol = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    symbol.draw(in: NSRect(x: 46, y: 46, width: size - 92, height: size - 92))
}
image.unlockFocus()
if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
SWIFT
swiftc -O -o /tmp/macos-pets-icon /tmp/macos-pets-icon.swift 2>/dev/null
/tmp/macos-pets-icon "$DEST/Contents/Resources/icon.png" 2>/dev/null || true

cat > "$DEST/Contents/Resources/AppIcon.icns" <<'ICNS'
ICNS
rm -f "$DEST/Contents/Resources/AppIcon.icns"
if [ -f "$DEST/Contents/Resources/icon.png" ]; then
    iconutil -c icns "$DEST/Contents/Resources/icon.png" -o "$DEST/Contents/Resources/AppIcon.icns" 2>/dev/null || true
    rm -f "$DEST/Contents/Resources/icon.png"
fi

# Ad-hoc signature so Gatekeeper lets a locally built app run.
codesign --force --deep --sign - "$DEST" 2>/dev/null || echo "  (codesign skipped)"

echo "==> Installed to $DEST"
echo
echo "Run it with:  open '$DEST'"
echo "Verify with:  ./.build/release/macos-pets --selftest"