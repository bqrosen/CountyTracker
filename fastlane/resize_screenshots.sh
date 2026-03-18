#!/bin/bash
set -euo pipefail

# Resize screenshots in fastlane/metadata/en-US/screenshots/* to App Store expected sizes
# Uses sips (built-in) to resize images to target pixel dimensions per device class.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
META_DIR="$ROOT_DIR/fastlane/metadata/en-US/screenshots"

declare -A SIZE_MAP
# mapping: folder name -> "widthxheight"
SIZE_MAP["iPhone 14 Pro Max"]="1284x2778"
SIZE_MAP["iPhone 12 Pro Max"]="1284x2778"
SIZE_MAP["iPhone 14 Plus"]="1284x2778"
SIZE_MAP["iPhone 14"]="1170x2532"
SIZE_MAP["iPhone 13"]="1170x2532"
SIZE_MAP["iPhone 12"]="1170x2532"
SIZE_MAP["iPhone 11"]="828x1792"
SIZE_MAP["iPhone 8 Plus"]="1242x2208"
SIZE_MAP["iPhone 8"]="750x1334"
SIZE_MAP["iPhone SE (2nd generation)"]="750x1334"
SIZE_MAP["iPhone 5s"]="640x1136"

if [ ! -d "$META_DIR" ]; then
  echo "No metadata screenshots directory found at $META_DIR"
  exit 1
fi

echo "Resizing screenshots under $META_DIR"

for deviceDir in "$META_DIR"/*; do
  [ -d "$deviceDir" ] || continue
  deviceName=$(basename "$deviceDir")
  target=${SIZE_MAP["$deviceName"]:-}
  if [ -z "$target" ]; then
    echo "No target size for device '$deviceName' — skipping resizing (will copy unchanged)."
    continue
  fi
  width=$(echo "$target" | cut -dx -f1)
  height=$(echo "$target" | cut -dx -f2)

  echo "Resizing images for $deviceName -> ${width}x${height}"
  for img in "$deviceDir"/*; do
    [ -f "$img" ] || continue
    # Ensure PNG
    ext="${img##*.}"
    tmp="${img%.*}-resized.png"
    sips -z $height $width "$img" --out "$tmp" >/dev/null
    mv "$tmp" "$img"
  done
done

echo "Resizing complete."
