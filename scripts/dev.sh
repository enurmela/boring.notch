#!/bin/zsh
# Dev loop for the fork while the stable boringNotch from /Applications is the
# daily driver: quit stable, build + launch the dev build, and when the dev
# build exits (Ctrl-C here or quit from its menu), bring stable back.
set -e
cd "$(dirname "$0")/.."

DEV_APP="build/DerivedData/Build/Products/Debug/boringNotch.app"
STABLE_APP="/Applications/boringNotch.app"

echo "› Quitting stable boringNotch…"
osascript -e 'tell application "boringNotch" to quit' 2>/dev/null || true

echo "› Building…"
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch \
  -configuration Debug -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build | grep -E "error|BUILD" || true

restore_stable() {
  echo "› Restoring stable boringNotch…"
  pkill -f "$DEV_APP/Contents/MacOS/boringNotch" 2>/dev/null || true
  [ -d "$STABLE_APP" ] && open "$STABLE_APP"
}
trap restore_stable EXIT

echo "› Launching dev build (Ctrl-C to stop and restore stable)…"
"$DEV_APP/Contents/MacOS/boringNotch"
