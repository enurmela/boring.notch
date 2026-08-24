#!/bin/zsh
# Build a Release copy of the fork and install it to /Applications as a
# standalone app you launch like any other — no Xcode, no rebuilding each
# time. Re-run after pulling changes to update the installed app.
#
# Installs as "boringNotch (T3).app" so it sits beside the stock
# /Applications/boringNotch.app rather than overwriting it. They share a
# bundle id (so they share settings and must not run at once), but the file
# stays separate so you can always fall back to the stock build.
set -e
cd "$(dirname "$0")/.."

APP_NAME="boringNotch (T3)"
DEST="/Applications/$APP_NAME.app"
DERIVED="build/Release"
BUILT="$DERIVED/Build/Products/Release/boringNotch.app"

echo "› Building Release…"
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch \
  -configuration Release -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" build \
  | grep -E "error:|BUILD" || true

if [ ! -d "$BUILT" ]; then
  echo "✗ Build product not found at $BUILT"; exit 1
fi

echo "› Installing to $DEST…"
# Quit the installed fork if it's running from this path.
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$BUILT" "$DEST"

# Ad-hoc re-sign in place so the (sandbox-free) entitlements apply, and clear
# the quarantine flag so Gatekeeper doesn't block the local build.
codesign --force --deep --sign - \
  --entitlements boringNotch/boringNotch.entitlements "$DEST" 2>/dev/null || \
  codesign --force --deep --sign - "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "✓ Installed $DEST"
echo "  Launch it from Spotlight/Dock as \"$APP_NAME\"."
echo "  (Don't run it at the same time as the stock boringNotch — they share the notch.)"
