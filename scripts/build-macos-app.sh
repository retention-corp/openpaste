#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION"

BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)"
APP_DIR="$ROOT_DIR/dist/OpenPaste.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BIN_PATH/OpenPaste" "$MACOS_DIR/OpenPaste"
codesign --force --deep --sign - --identifier io.local.openpaste "$APP_DIR"

echo "Built app bundle at: $APP_DIR"
