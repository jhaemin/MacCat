#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)
APP="build/MacCat.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacCat" "$APP/Contents/MacOS/MacCat"
cp Scripts/Info.plist "$APP/Contents/Info.plist"
RESOURCE_BUNDLE="$BIN_DIR/MacCat_MacCat.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    echo "Missing resource bundle: $RESOURCE_BUNDLE" >&2
    exit 1
fi
rm -rf "$APP/Contents/Resources/MacCat_MacCat.bundle"
ditto "$RESOURCE_BUNDLE" "$APP/Contents/Resources/MacCat_MacCat.bundle"
"$BIN_DIR/MacCat" --render-previews build/previews
iconutil -c icns build/previews/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
echo "Built $APP"
if [[ "${1:-}" == "--open" ]]; then
    open "$APP"
fi
