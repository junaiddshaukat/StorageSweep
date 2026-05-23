#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$ROOT_DIR/.build/StorageSweep.app"
ZIP_PATH="$ROOT_DIR/.build/StorageSweep.zip"
DMG_PATH="$ROOT_DIR/.build/StorageSweep.dmg"

"$ROOT_DIR/build-app.sh" >/dev/null
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
"$ROOT_DIR/package-dmg.sh" --no-build >/dev/null

echo "$ZIP_PATH"
echo "$DMG_PATH"
