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
Because this environment does not have full Xcode tooling enabled, create the Xcode project locally:

1. Open Xcode and create a new **iOS App** project named **CountyTracker** (SwiftUI lifecycle).
2. Replace the generated Swift files with the files from this folder.
3. In your app target settings, add these Info.plist keys:
   - `NSLocationWhenInUseUsageDescription` = `CountyTracker uses your location to record counties you've visited.`
4. Build and run on a real iPhone (recommended for GPS).

## Notes
- County detection uses `CLPlacemark.subAdministrativeArea`.
- Only US locations (`isoCountryCode == "US"`) are recorded.
- Updates are throttled by time and distance to reduce geocoding calls.
