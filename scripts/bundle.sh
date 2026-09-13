#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/NetTracker.app"
CONTENTS="$APP/Contents"
AGENT="$ROOT/build/agent/NetTrackerAgent"

if [ ! -x "$AGENT" ]; then
  echo "agent binary missing, run scripts/build.sh first" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Library/LoginItems"

if [ -d "$ROOT/macos/NetTracker.xcodeproj" ] && xcodebuild -version >/dev/null 2>&1; then
  xcodebuild -project "$ROOT/macos/NetTracker.xcodeproj" -scheme NetTracker \
    -configuration Release -derivedDataPath "$ROOT/build/DerivedData" \
    CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}" CODE_SIGNING_ALLOWED=YES
  if [ -f "$ROOT/build/DerivedData/Build/Products/Release/NetTracker.app/Contents/MacOS/NetTracker" ]; then
    cp "$ROOT/build/DerivedData/Build/Products/Release/NetTracker.app/Contents/MacOS/NetTracker" "$CONTENTS/MacOS/NetTracker"
  elif [ -f "$ROOT/build/DerivedData/Build/Products/Release/NetTracker" ]; then
    cp "$ROOT/build/DerivedData/Build/Products/Release/NetTracker" "$CONTENTS/MacOS/NetTracker"
  else
    echo "could not find built NetTracker binary in DerivedData" >&2
    exit 1
  fi
else
  SDK="$(xcrun --show-sdk-path --sdk macosx)"
  STRIPDIR="$ROOT/build/swift-strip"
  rm -rf "$STRIPDIR" && mkdir -p "$STRIPDIR"
  for f in $(find "$ROOT/macos/NetTracker" -name '*.swift'); do
    python3 - "$f" "$STRIPDIR/$(basename "$f")" <<'PY'
import sys
src = open(sys.argv[1]).read()
out, i, n = [], 0, len(src)
while i < n:
    m = src.find('#Preview', i)
    if m == -1:
        out.append(src[i:]); break
    out.append(src[i:m])
    j = src.find('{', m)
    depth = 1; j += 1
    while depth > 0 and j < n:
        if src[j] == '{': depth += 1
        elif src[j] == '}': depth -= 1
        j += 1
    i = j
open(sys.argv[2], 'w').write(''.join(out))
PY
  done
  # shellcheck disable=SC2046
  swiftc -O -o "$CONTENTS/MacOS/NetTracker" $(find "$STRIPDIR" -name '*.swift') \
    -target arm64-apple-macosx14.0 -sdk "$SDK"
fi

cp "$ROOT/macos/NetTracker/Info.plist" "$CONTENTS/Info.plist"
cp "$AGENT" "$CONTENTS/Library/LoginItems/NetTrackerAgent"
chmod +x "$CONTENTS/MacOS/NetTracker" "$CONTENTS/Library/LoginItems/NetTrackerAgent"
if [ -f "$ROOT/macos/NetTracker/Resources/AppIcon.icns" ]; then
  cp "$ROOT/macos/NetTracker/Resources/AppIcon.icns" "$CONTENTS/Resources/"
fi
echo "bundled $APP"
