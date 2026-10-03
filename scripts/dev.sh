#!/bin/zsh
# Dev loop for the fork while the stable boringNotch from /Applications is the
# daily driver: quit stable, build + launch the dev build, and when the dev
# build exits (Ctrl-C here or quit from its menu), bring stable back.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV_APP="build/DerivedData/Build/Products/Debug/Boring Notch.app"
STABLE_APP="/Applications/Boring Notch.app"
[ -d "$STABLE_APP" ] || STABLE_APP="/Applications/boringNotch.app"

echo "› Quitting stable boringNotch…"
osascript -e "tell application \"$STABLE_APP\" to quit" 2>/dev/null || true

echo "› Building…"
# Ad-hoc signing so the (sandbox-free) entitlements actually apply.
mkdir -p build/DerivedData
if ! xcodebuild -project boringNotch.xcodeproj -scheme boringNotch \
  -configuration Debug -derivedDataPath build/DerivedData \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" build > build/DerivedData/dev.log 2>&1; then
  tail -n 60 build/DerivedData/dev.log
  [ ! -d "$STABLE_APP" ] || open "$STABLE_APP"
  exit 1
fi

restore_stable() {
  echo "› Restoring stable boringNotch…"
  pkill -f "$DEV_APP/Contents/MacOS/Boring Notch" 2>/dev/null || true
  [ -d "$STABLE_APP" ] && open "$STABLE_APP"
}
trap restore_stable EXIT

echo "› Launching dev build (Ctrl-C to stop and restore stable)…"
"$DEV_APP/Contents/MacOS/Boring Notch"
