#!/bin/bash
set -euo pipefail

# Collects Fastlane snapshot output and organizes it under fastlane/metadata
# so it's ready for deliver. Does not resize images (snapshot produces device-accurate sizes).

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SNAPSHOT_DIR="$HOME/Downloads/CountyTrackerScreenshots"
META_DIR="$ROOT_DIR/fastlane/metadata/en-US/screenshots"

if [ ! -d "$SNAPSHOT_DIR" ]; then
  echo "Snapshot directory $SNAPSHOT_DIR does not exist. Run snapshot first."
  exit 1
fi

mkdir -p "$META_DIR"

echo "Organizing screenshots from $SNAPSHOT_DIR into $META_DIR"

for file in "$SNAPSHOT_DIR"/*; do
  [ -e "$file" ] || continue
  filename=$(basename "$file")
  # Fastlane snapshot names are like "iPhone 14 Pro Max-01Launch.png" or similar
  # We'll split device name from the rest by the first hyphen.
  if [[ "$filename" == *"-"* ]]; then
    device=${filename%%-*}
    rest=${filename#*-}
  else
    device="unknown"
    rest="$filename"
  fi

  # sanitize device to folder name used by deliver (simple mapping)
  folderName=$(echo "$device" | sed -E 's/[^A-Za-z0-9 _.-]/_/g')
  destDir="$META_DIR/$folderName"
  mkdir -p "$destDir"

  # Copy file into destDir, prefix with an ordering number to preserve sequence
  timestamp=$(date +%s%N)
  cp "$file" "$destDir/${timestamp}_$rest"
  echo "Copied $filename -> $destDir/"
done

echo "Organized screenshots under $META_DIR (one folder per device)."
echo "If you want App Store-specific folders (e.g., 'iPhone 6.5-inch'), rename the device folders accordingly."
