#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/NetTracker.app"
DMG="$ROOT/build/NetTracker.dmg"
VOLNAME="NetTracker"
BACKGROUND="$ROOT/assets/dmg-background.png"
ICON="$ROOT/macos/NetTracker/Resources/AppIcon.icns"

if [ ! -d "$APP" ]; then
  echo "Error: $APP does not exist. Run 'make bundle && make sign' first." >&2
  exit 1
fi

echo "Building NetTracker DMG installer..."
rm -f "$DMG"

# Staging directory
STAGE="$(mktemp -d /tmp/nettracker_dmg_stage.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT INT TERM

cp -R "$APP" "$STAGE/"

if command -v create-dmg >/dev/null 2>&1; then
  echo "Using create-dmg for styled installer..."
  EXTRA_FLAGS=""
  if [ -n "${CI:-}" ] || [ -z "${DISPLAY:-}" -a -z "${TERM_PROGRAM:-}" ]; then
    EXTRA_FLAGS="--skip-jenkins"
  fi
  
  if create-dmg \
    --volname "$VOLNAME" \
    --volicon "$ICON" \
    --background "$BACKGROUND" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 128 \
    --icon "NetTracker.app" 180 230 \
    --hide-extension "NetTracker.app" \
    --app-drop-link 480 230 \
    --format UDZO \
    --overwrite \
    $EXTRA_FLAGS \
    "$DMG" \
    "$STAGE"; then
      echo "Successfully created styled DMG at: $DMG"
      exit 0
  else
    echo "create-dmg failed or ran headless, falling back to hdiutil..." >&2
  fi
fi

# Fallback: standard hdiutil
echo "Creating standard DMG with hdiutil..."
ln -s /Applications "$STAGE/Applications"
if [ -f "$ICON" ]; then
  cp "$ICON" "$STAGE/.VolumeIcon.icns"
  SetFile -a C "$STAGE" 2>/dev/null || true
fi

hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
echo "Successfully created DMG at: $DMG"
