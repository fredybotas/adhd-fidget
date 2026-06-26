#!/bin/bash
set -e

APP="FidgetBall"
BUNDLE="$APP.app/Contents"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"

if   [ "$ARCH" = "arm64"  ]; then TARGET="arm64-apple-macos14.0"
elif [ "$ARCH" = "x86_64" ]; then TARGET="x86_64-apple-macos14.0"
else echo "Unknown arch: $ARCH" && exit 1; fi

# Load credentials
if [ -f codesign.env ]; then
    # shellcheck disable=SC1091
    source codesign.env
fi

prompt_if_missing() {
    local var="$1" prompt="$2" secret="$3"
    if [ -z "${!var}" ]; then
        if [ "$secret" = "1" ]; then
            read -r -s -p "$prompt: " value && echo
        else
            read -r -p "$prompt: " value
        fi
        export "$var"="$value"
    fi
}

prompt_if_missing APPLE_SIGN_IDENTITY "Sign identity (e.g. 'Developer ID Application: Name (TEAMID)')"
prompt_if_missing APPLE_ID            "Apple ID email"
prompt_if_missing APPLE_TEAM_ID       "Team ID (10 chars)"
prompt_if_missing APPLE_APP_PASSWORD  "App-specific password" 1

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

echo "Signing with Developer ID..."
codesign --deep --force --options runtime \
    --entitlements FidgetBall.entitlements \
    --sign "$APPLE_SIGN_IDENTITY" \
    "$APP.app"

echo "Verifying signature..."
codesign --verify --deep --strict "$APP.app"
spctl --assess --type exec "$APP.app" || true

echo "Packaging for notarization..."
rm -f "$APP.zip"
ditto -c -k --keepParent "$APP.app" "$APP.zip"

echo "Submitting to Apple notarization (this takes 1–5 min)..."
xcrun notarytool submit "$APP.zip" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP.app"

echo "Verifying notarization..."
spctl --assess --type exec --verbose "$APP.app"

rm -f "$APP.zip"

echo "Creating DMG..."
DMG="$APP.dmg"

if ! command -v create-dmg &>/dev/null; then
    echo "Error: create-dmg not found. Run: brew install create-dmg" && exit 1
fi

rm -f "$DMG"
create-dmg \
    --volname "$APP" \
    --volicon "$(pwd)/$BUNDLE/Resources/AppIcon.icns" \
    --window-pos 400 100 \
    --window-size 500 300 \
    --icon-size 100 \
    --icon "$APP.app" 125 150 \
    --app-drop-link 375 150 \
    "$DMG" \
    "$APP.app"

echo "Signing DMG..."
codesign --sign "$APPLE_SIGN_IDENTITY" "$DMG"

echo "Notarizing DMG (1–5 min)..."
xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

echo "Stapling DMG..."
xcrun stapler staple "$DMG"

echo ""
echo "Done. $DMG is signed, notarized, and ready to distribute."
