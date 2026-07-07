#!/usr/bin/env bash
#
# build-dmg.sh — Build Latch.app and package it into a distributable DMG.
#
# Usage:
#   ./Distribution/build-dmg.sh            # Debug build
#   ./Distribution/build-dmg.sh --release  # Release build
#
# Requirements:
#   - Xcode command-line tools
#   - xcodegen (brew install xcodegen)
#   - Optional: create-dmg (brew install create-dmg) for a nicer DMG window

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CONFIGURATION="Debug"
if [[ "${1:-}" == "--release" ]]; then
  CONFIGURATION="Release"
fi

APP_NAME="Latch"
BUNDLE_ID="com.latch.app"
BUILD_DIR="$REPO_ROOT/.build/Build/Products/$CONFIGURATION"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="$REPO_ROOT/Distribution/dmg-staging"
DMG_NAME="${APP_NAME}.dmg"
FINAL_DMG="$REPO_ROOT/Distribution/$DMG_NAME"

echo "▶ Regenerating Xcode project..."
xcodegen generate

echo "▶ Building ($CONFIGURATION)..."
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath .build \
  build \
  2>&1 | grep -E "error:|Build (succeeded|FAILED)" || true

if [[ ! -d "$APP_PATH" ]]; then
  echo "✗ Build failed — $APP_PATH not found"
  exit 1
fi

echo "▶ Staging..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "$APP_PATH" "$DIST_DIR/$APP_NAME.app"

echo "▶ Creating DMG..."
rm -f "$FINAL_DMG"

if command -v create-dmg &>/dev/null; then
  create-dmg \
    --volname "$APP_NAME" \
    --volicon "$DIST_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 500 300 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 125 150 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 375 150 \
    "$FINAL_DMG" \
    "$DIST_DIR"
else
  # Fallback: plain hdiutil DMG
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DIST_DIR" \
    -ov \
    -format UDZO \
    "$FINAL_DMG"
fi

SHA=$(shasum -a 256 "$FINAL_DMG" | awk '{print $1}')
echo "✔ DMG: $FINAL_DMG"
echo "  SHA256: $SHA"
echo "$SHA  $DMG_NAME" > "$FINAL_DMG.sha256"

rm -rf "$DIST_DIR"
