#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$ROOT_DIR/.build/StorageSweep.app"
DMG_ROOT="$ROOT_DIR/.build/dmg-root"
DMG_PATH="$ROOT_DIR/.build/StorageSweep.dmg"

if [[ "${1:-}" != "--no-build" ]]; then
  "$ROOT_DIR/build-app.sh" >/dev/null
fi

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
cp -R "$APP_PATH" "$DMG_ROOT/StorageSweep.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "Storage Sweep" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
