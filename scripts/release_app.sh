#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Vladimir Babic (DY4JMWWW5S)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-macverce-notary}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-Vibe Check}"
APP_DIR="$ROOT_DIR/.build/$APP_BUNDLE_NAME.app"
ASSET_DIR="$ROOT_DIR/.build/release-assets"
ASSET_BASENAME="${ASSET_BASENAME:-VibeCheck}"

SIGN_IDENTITY="$SIGN_IDENTITY" scripts/build_app.sh >/dev/null

codesign --verify --strict --deep --verbose=2 "$APP_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
ZIP_PATH="$ASSET_DIR/$ASSET_BASENAME-v$VERSION.zip"

mkdir -p "$ASSET_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

spctl -a -vvv -t execute "$APP_DIR"
shasum -a 256 "$ZIP_PATH"
printf '%s\n' "$ZIP_PATH"
