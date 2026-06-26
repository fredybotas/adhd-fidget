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

swiftc \
    -target "$TARGET" \
    -sdk "$SDK" \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/BallView.swift \
    -o "$BUNDLE/MacOS/$APP"

cp Info.plist "$BUNDLE/Info.plist"

# Ad-hoc sign so Gatekeeper allows local launch
codesign --sign - --force "$APP.app" 2>/dev/null || true

echo "Done. Launch with:  open $APP.app"
