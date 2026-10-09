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

# `--bundle-only [dir]` assembles the .app without touching /Applications.
# Used by CI to produce an uploadable artifact.
BUNDLE_ONLY=0
if [ "${1:-}" = "--bundle-only" ]; then
    BUNDLE_ONLY=1
    DEST="${2:-./dist}/${APP_NAME}.app"
fi

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

# App icon: the upstream icon.png, verbatim (see Assets/vscode-pets/).
# Upscaled into an iconset since the source is 128px; sips pads cleanly.
if [ -f Assets/vscode-pets/icon.upstream.png ]; then
    rm -rf /tmp/macos-pets.iconset
    mkdir -p /tmp/macos-pets.iconset
    for s in 16 32 128 256 512; do
        sips -z $s $s Assets/vscode-pets/icon.upstream.png \
            --out /tmp/macos-pets.iconset/icon_${s}x${s}.png >/dev/null 2>&1
        sips -z $s $s Assets/vscode-pets/icon.upstream.png \
            --out /tmp/macos-pets.iconset/icon_$((s/2))x$((s/2))@2x.png >/dev/null 2>&1
    done
    iconutil -c icns /tmp/macos-pets.iconset \
        -o "$DEST/Contents/Resources/AppIcon.icns" 2>/dev/null || true
    rm -rf /tmp/macos-pets.iconset
fi
# Fallback so the bundle is never icon-less if conversion failed.
if [ ! -f "$DEST/Contents/Resources/AppIcon.icns" ]; then
    cat > /tmp/macos-pets-icon.swift <<'SWIFT'
import AppKit
let size = 512
let image = NSImage(size: NSSize(width: size, height: size))
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
    if swiftc -O -o /tmp/macos-pets-icon /tmp/macos-pets-icon.swift 2>/dev/null \
        && /tmp/macos-pets-icon "$DEST/Contents/Resources/icon.png" 2>/dev/null \
        && iconutil -c icns "$DEST/Contents/Resources/icon.png" \
            -o "$DEST/Contents/Resources/AppIcon.icns" 2>/dev/null; then
        rm -f "$DEST/Contents/Resources/icon.png"
    else
        rm -f "$DEST/Contents/Resources/icon.png"
        echo "  (icon generation skipped)"
    fi
fi

# Ad-hoc signature so Gatekeeper lets a locally built app run.
codesign --force --deep --sign - "$DEST" 2>/dev/null || echo "  (codesign skipped)"

if [ "$BUNDLE_ONLY" = "1" ]; then
    echo "==> Bundle assembled at $DEST (not installed)"
else
    echo "==> Installed to $DEST"
    echo
    echo "Run it with:  open '$DEST'"
fi
echo "Verify with:  ./.build/release/macos-pets --selftest"

# `--raycast-scripts [dir]` writes Raycast Script Commands (one per action)
# that drive the running app through the same `send` channel.
if [ "${1:-}" = "--raycast-scripts" ] || [ "${3:-}" = "--raycast-scripts" ]; then
    SCRIPT_DIR="${2:-$HOME/.config/raycast/scripts}"
    # allow `--bundle-only DIR --raycast-scripts [DIR]` ordering
    if [ "${1:-}" != "--raycast-scripts" ] && [ "${3:-}" = "--raycast-scripts" ]; then
        SCRIPT_DIR="${4:-$HOME/.config/raycast/scripts}"
    fi
    BIN="$DEST/Contents/MacOS/macos-pets"
    mkdir -p "$SCRIPT_DIR"
    write_script() {
        # $1 filename, $2 title, $3 command, $4 mode
        cat > "$SCRIPT_DIR/$1" <<EOF
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title $2
# @raycast.mode $4
# @raycast.packageName macOS Pets
exec "$BIN" send $3
EOF
        chmod +x "$SCRIPT_DIR/$1"
    }
    # Per-species add/remove scripts from the live catalogue.
    "$DEST/Contents/MacOS/macos-pets" --list-species 2>/dev/null | while IFS='|' read -r id name; do
        [ -z "$id" ] && continue
        slug=$(echo "$id" | tr ' ' '-')
        write_script "add-pet-$slug.sh" "Add $name" "add $id" silent
        write_script "remove-pet-$slug.sh" "Remove $name" "remove $id" silent
    done
    write_script "add-random-pet.sh" "Add Random Pet" "add-random" silent
    write_script "remove-last-pet.sh" "Remove Last Pet" "remove-last" silent
    write_script "clear-pets.sh" "Clear All Pets" "clear" silent
    write_script "throw-ball.sh" "Throw Ball" "throw" silent
    write_script "place-ball.sh" "Place Ball at Cursor" "place" silent
    write_script "hide-pets.sh" "Hide Pets" "hide" silent
    write_script "show-pets.sh" "Show Pets" "show" silent
    echo "==> Raycast scripts written to $SCRIPT_DIR"
    echo
    echo "    Raycast cannot register script folders itself — one manual step:"
    echo "    1. This opens Raycast settings at Extensions now."
    echo "    2. Go to Script Commands → Add Directories and pick:"
    echo "         $SCRIPT_DIR"
    echo "    3. Search \"Throw Ball\" to confirm, or run Reload Script Commands."
    open "raycast://extensions" 2>/dev/null || true
fi