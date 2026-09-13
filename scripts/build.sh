#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/agent/NetTrackerAgent"
mkdir -p "$ROOT/build/agent"
cd "$ROOT/agent"
GOARCH="${GOARCH:-arm64}" GOOS=darwin go build -trimpath -o "$OUT" ./cmd/nettracker-agent
echo "built $OUT"
