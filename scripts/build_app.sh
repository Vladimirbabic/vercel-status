#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$ROOT_DIR/.build/MacVerce.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"
cp "$BIN_DIR/MacVerce" "$APP_DIR/Contents/MacOS/MacVerce"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/MacVerce.icns" "$APP_DIR/Contents/Resources/MacVerce.icns"

if [[ -d "$BIN_DIR/Sparkle.framework" ]]; then
    ditto "$BIN_DIR/Sparkle.framework" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
fi

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    if [[ -d "$APP_DIR/Contents/Frameworks/Sparkle.framework" ]]; then
        codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" \
            "$APP_DIR/Contents/Frameworks/Sparkle.framework"
    fi

    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

printf '%s\n' "$APP_DIR"
