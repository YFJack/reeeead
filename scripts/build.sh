#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
if [[ "$CONFIG" != "release" && "$CONFIG" != "debug" ]]; then
  echo 'Usage: scripts/build.sh [release|debug]' >&2
  exit 1
fi
swift build -c "$CONFIG" -j 1
BIN="$(swift build -c "$CONFIG" --show-bin-path)"
APP="$PWD/dist/Reeeead.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Reeeead" "$APP/Contents/MacOS/Reeeead"
cp packaging/Info.plist "$APP/Contents/Info.plist"
if [[ -f packaging/Reeeead.icns ]]; then cp packaging/Reeeead.icns "$APP/Contents/Resources/"; fi
codesign --force --sign "${LUMA_SIGN_IDENTITY:--}" --identifier app.luma.reader "$APP"
echo "Built: $APP"
