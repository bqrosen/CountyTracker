#!/bin/bash
set -euo pipefail

# Boots required simulators and runs Fastlane snapshot
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SNAP_OUTPUT_DIR="$HOME/Downloads/CountyTrackerScreenshots"

DEVICES=(
  "iPhone 14 Pro Max"
  "iPhone 12 Pro Max"
  "iPhone 14 Plus"
  "iPhone 14"
  "iPhone 8 Plus"
  "iPhone 8"
  "iPhone SE (2nd generation)"
  "iPhone 5s"
)

echo "Booting simulators used by snapshot..."
for name in "${DEVICES[@]}"; do
  UDID=$(xcrun simctl list devices | grep "${name} (" | grep -v unavailable | awk -F '[()]' '{print $2}' | head -n1 || true
  if [ -z "$UDID" ]; then
    echo "Simulator $name not found; skipping."
    continue
  fi
  state=$(xcrun simctl list devices | grep "$UDID" | sed -n '1p' | sed -E 's/.*(Booted|Shutdown).*/\1/') || true
  if [ "$state" != "Booted" ]; then
    echo "Booting $name ($UDID)"
    xcrun simctl boot "$UDID" || true
  else
    echo "$name already booted"
  fi
done

echo "Running fastlane snapshot (output: $SNAP_OUTPUT_DIR)"
cd "$ROOT_DIR/fastlane"
./run_snapshot.sh

echo "Shutting down simulators booted by script..."
for name in "${DEVICES[@]}"; do
  UDID=$(xcrun simctl list devices | grep "${name} (" | grep -v unavailable | awk -F '[()]' '{print $2}' | head -n1 || true
  if [ -n "$UDID" ]; then
    xcrun simctl shutdown "$UDID" || true
  fi
done

echo "Done. Screenshots are in $SNAP_OUTPUT_DIR"
