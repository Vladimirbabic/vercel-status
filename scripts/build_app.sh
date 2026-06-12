#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$ROOT_DIR/.build/MacVerce.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
SIGN_OPTIONS=()

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/MacVerce" "$APP_DIR/Contents/MacOS/MacVerce"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    SIGN_OPTIONS+=(--options runtime --timestamp)
fi

codesign --force --deep "${SIGN_OPTIONS[@]}" --sign "$SIGN_IDENTITY" "$APP_DIR"

printf '%s\n' "$APP_DIR"
