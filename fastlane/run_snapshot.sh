#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v bundle >/dev/null 2>&1; then
  echo "Please install bundler (gem install bundler) and run this script again."
  exit 1
fi

bundle install --path vendor/bundle

echo "Running snapshot (screenshots will be saved to ~/Downloads/CountyTrackerScreenshots)"
bundle exec fastlane snapshot

echo "Done."
