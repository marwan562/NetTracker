#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/NetTracker.app"
IDENTITY="${CODE_SIGN_IDENTITY:--}"
ENTITLEMENTS="$ROOT/macos/NetTracker/NetTracker.entitlements"
codesign --force --deep --options runtime --timestamp \
  --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" \
  "$APP/Contents/Library/LoginItems/NetTrackerAgent"
codesign --force --deep --options runtime --timestamp \
  --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --verbose "$APP"
echo "signed $APP with identity $IDENTITY"
