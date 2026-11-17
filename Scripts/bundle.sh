#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_ARGS=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}"
BIN_DIR=$(swift build "${BUILD_ARGS[@]}" --show-bin-path)
APP="build/MacCat.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/MacCat" "$APP/Contents/MacOS/MacCat"
cp Scripts/Info.plist "$APP/Contents/Info.plist"
RESOURCE_BUNDLE="$BIN_DIR/MacCat_MacCat.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    echo "Missing resource bundle: $RESOURCE_BUNDLE" >&2
    exit 1
fi
rm -rf "$APP/Contents/Resources/MacCat_MacCat.bundle"
ditto "$RESOURCE_BUNDLE" "$APP/Contents/Resources/MacCat_MacCat.bundle"
SPARKLE=$(find .build/artifacts -type d -name Sparkle.framework -path '*macos*' -print -quit)
[[ -n "$SPARKLE" ]] || { echo "Sparkle.framework not found" >&2; exit 1; }
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
"$BIN_DIR/MacCat" --render-previews build/previews
iconutil -c icns build/previews/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    SIGN=(codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY")
else
    SIGN=(codesign --force --options 0 --sign -)
fi
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
"${SIGN[@]}" --preserve-metadata=entitlements "$FW/XPCServices/Downloader.xpc"
"${SIGN[@]}" "$FW/XPCServices/Installer.xpc"
"${SIGN[@]}" "$FW/Autoupdate"
"${SIGN[@]}" "$FW/Updater.app"
"${SIGN[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
"${SIGN[@]}" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
if [[ "${1:-}" == "--open" ]]; then
    open "$APP"
fi
