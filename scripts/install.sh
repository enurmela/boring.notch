#!/bin/zsh
# Build a Release copy of the fork and install it to /Applications as a
# standalone app you launch like any other — no Xcode, no rebuilding each
# time. Re-run after pulling changes to update the installed app.
#
# Installs as "boringNotch (T3).app" so it sits beside the stock
# /Applications/boringNotch.app rather than overwriting it. They share a
# bundle id (so they share settings and must not run at once), but the file
# stays separate so you can always fall back to the stock build.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="boringNotch (T3)"
DEST="/Applications/$APP_NAME.app"
DERIVED="build/Release"
BUILT="$DERIVED/Build/Products/Release/Boring Notch.app"
BUILD_LOG="$DERIVED/install.log"
mkdir -p "$DERIVED"

echo "› Building Release…"
if ! xcodebuild -project boringNotch.xcodeproj -scheme boringNotch \
  -configuration Release -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" build \
  > "$BUILD_LOG" 2>&1; then
  tail -n 60 "$BUILD_LOG"
  echo "✗ Build failed. The installed app has not been changed."
  exit 1
fi

if [ ! -d "$BUILT" ]; then
  echo "✗ Build product not found at $BUILT"; exit 1
fi

# Prepare and validate the replacement before touching the installed app.
STAGING="$(mktemp -d /Applications/.boringNotch-T3.XXXXXX)"
cleanup() {
  if [ ! -d "$DEST" ] && [ -d "$STAGING/Previous.app" ]; then
    mv "$STAGING/Previous.app" "$DEST"
  fi
  rm -rf "$STAGING"
}
trap cleanup EXIT
ditto "$BUILT" "$STAGING/New.app"
REVISION="$(git rev-parse --short HEAD)"
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  REVISION="$REVISION-dirty"
fi
/usr/libexec/PlistBuddy -c "Add :BNSourceRevision string $REVISION" \
  "$STAGING/New.app/Contents/Info.plist"
codesign --force --deep --sign - \
  --entitlements boringNotch/boringNotch.entitlements "$STAGING/New.app"
codesign --verify --deep --strict "$STAGING/New.app"
xattr -dr com.apple.quarantine "$STAGING/New.app" 2>/dev/null || true

echo "› Installing to $DEST…"
# Quit the installed fork only after the replacement is ready.
if [ -d "$DEST" ]; then
  osascript -e "tell application \"$DEST\" to quit" 2>/dev/null || true
  sleep 1
  mv "$DEST" "$STAGING/Previous.app"
fi
mv "$STAGING/New.app" "$DEST"

echo "✓ Installed $DEST"
echo "  Launch it from Spotlight/Dock as \"$APP_NAME\"."
echo "  (Don't run it at the same time as the stock boringNotch — they share the notch.)"
