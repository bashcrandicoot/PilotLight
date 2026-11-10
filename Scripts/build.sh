#!/usr/bin/env bash
# Build PilotLight.app into ./build (ad-hoc codesign). Does not install.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/PilotLight.app"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macos${MACOSX_DEPLOYMENT_TARGET}"
# Also build a thin arm64 binary; on Intel this script can be pointed at
# x86_64 by setting SWIFT_TARGET.
if [[ -n "${SWIFT_TARGET:-}" ]]; then
  TARGET="$SWIFT_TARGET"
elif [[ "$(uname -m)" == "x86_64" ]]; then
  TARGET="x86_64-apple-macos${MACOSX_DEPLOYMENT_TARGET}"
fi

echo "Compiling PilotLight for $TARGET"
# shellcheck disable=SC2046
swiftc -O -parse-as-library \
  -module-name PilotLight \
  -target "$TARGET" \
  -sdk "$SDK" \
  -framework AppKit \
  -framework QuartzCore \
  -o "$APP/Contents/MacOS/PilotLight" \
  "$ROOT"/Sources/PilotLight/*.swift

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

# App icon: prefer a ready-made icns, otherwise build one from the iconset.
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
elif [[ -d "$ROOT/Resources/AppIcon.iconset" ]] && command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns -o "$APP/Contents/Resources/AppIcon.icns" "$ROOT/Resources/AppIcon.iconset"
fi

# Menu-bar template images only. Do not copy AppIcon-source.png or the
# Ember SVG, which are design sources, not runtime assets.
for f in MenuIcon.png "MenuIcon@2x.png"; do
  if [[ -f "$ROOT/Resources/$f" ]]; then
    cp "$ROOT/Resources/$f" "$APP/Contents/Resources/$f"
  fi
done

codesign --force --deep --sign - "$APP"
echo "Built $APP"
