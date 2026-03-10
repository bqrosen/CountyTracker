# CountyTracker iOS App (SwiftUI)

This folder contains a SwiftUI iOS app implementation that:
- uses GPS via Core Location,
- reverse-geocodes coordinates using Apple geocoding data,
- tracks unique US counties visited,
- stores results locally in `UserDefaults`.

## What you get
- `CountyTrackerApp.swift`: app entry point
- `ContentView.swift`: map + controls + visited counties list
- `LocationService.swift`: permission + location updates
- `CountyTrackerViewModel.swift`: throttled reverse geocode logic
- `CountyTrackerStore.swift`: county normalization + persistence
- `CountyVisit.swift`: county data model

## Xcode setup
Project generation has already been done in this repository:

1. Open `CountyTracker.xcodeproj` in Xcode.
2. Select the `CountyTracker` scheme and an iPhone simulator or device.
3. Build and run.

`NSLocationWhenInUseUsageDescription` is already set in `CountyTrackerIOS/Info.plist`.

## Notes
- County detection uses `CLPlacemark.subAdministrativeArea`.
- Only US locations (`isoCountryCode == "US"`) are recorded.
- Updates are throttled by time and distance to reduce geocoding calls.
- App supports both While Using and Always location permission prompts.
