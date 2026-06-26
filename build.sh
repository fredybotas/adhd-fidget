#!/bin/bash
set -e

APP="FidgetBall"
BUNDLE="$APP.app/Contents"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"

if   [ "$ARCH" = "arm64"  ]; then TARGET="arm64-apple-macos14.0"
elif [ "$ARCH" = "x86_64" ]; then TARGET="x86_64-apple-macos14.0"
else echo "Unknown arch: $ARCH" && exit 1; fi

echo "Building $APP for $TARGET..."

rm -rf "$APP.app"
mkdir -p "$BUNDLE/MacOS" "$BUNDLE/Resources"

# Build app icon from design PNG
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
PNG="design/adhd-fidget-app-icon.svg.png"
for size in 16 32 64 128 256 512; do
  sips -z $size $size "$PNG" --out "$ICONSET/icon_${size}x${size}.png" 2>/dev/null
  double=$((size * 2))
  sips -z $double $double "$PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" 2>/dev/null
done
iconutil -c icns "$ICONSET" -o "$BUNDLE/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

swiftc \
    -target "$TARGET" \
    -sdk "$SDK" \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/BallSettings.swift \
    Sources/HotkeyManager.swift \
    Sources/SettingsWindowController.swift \
    Sources/BallView.swift \
    -framework Carbon \
    -o "$BUNDLE/MacOS/$APP"

cp Info.plist "$BUNDLE/Info.plist"

# Ad-hoc sign so Gatekeeper allows local launch
codesign --sign - --force "$APP.app" 2>/dev/null || true

echo "Done. Launch with:  open $APP.app"
