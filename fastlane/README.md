# Fastlane snapshot

This project includes Fastlane snapshot scaffolding to automate screenshots for App Store Connect.

How to run (macOS):

1. Install bundler if you don't have it:

```bash
sudo gem install bundler
```

2. From the project root run:

```bash
cd fastlane
./run_snapshot.sh
```

This will install the `fastlane` gem into `fastlane/vendor` and run `fastlane snapshot`. Screenshots will be saved to `~/Downloads/CountyTrackerScreenshots` per the Snapfile.

Notes:
- The UI tests are minimal and only take a launch screenshot. Edit `CountyTrackerUITests/CountyTrackerUITests.swift` to navigate your app and call `snapshot("name")` at the points you need.
- Keep Fastlane files untracked by Git; they are ignored in `.gitignore`.
