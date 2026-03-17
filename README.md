# CountyTracker

A SwiftUI-based iOS app that automatically tracks US counties you've visited using GPS location services.

## Overview

CountyTracker is an elegant, privacy-focused mobile application designed for geography enthusiasts and road trip planners. The app uses your device's GPS to automatically record every US county you visit, building a personalized map of your county visits over time.

**Current Version:** 1.1  
**Deployment Target:** iOS 16.0+  
**Platform:** iPhone & iPad

## Getting Started

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- An iPhone/iPad running iOS 16.0 or later (for deployment)
- An Apple Developer Account (optional, for device deployment)

### Installation & Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/bqrosen/CountyTracker.git
   cd CountyTracker
   ```

2. **Open in Xcode**
   ```bash
   open CountyTracker.xcodeproj
   ```

3. **Select Target**
   - In Xcode, select the `CountyTracker` scheme
   - Choose an iPhone/iPad simulator or connected device

### Building & Running

**Via Xcode:**
1. Press `Cmd + R` to build and run
2. Grant location permissions when prompted
3. The app will begin tracking counties as you move

**Via Command Line:**
```bash
xcodebuild -project CountyTracker.xcodeproj -scheme CountyTracker -configuration Release -destination 'generic/platform=iOS' archive -archivePath /path/to/archive.xcarchive
```

## Technical Details

### Location Permissions

The app requests two types of location permissions:

- **While Using**: For manual county tracking during active app use
- **Always**: For background county tracking (optional)

Both are configured in `Info.plist`:
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`

### Data Storage

County visit records are stored locally in `UserDefaults` under the key structure:
```
com.example.countytracker.visits.[county_name] = [date_visited]
```

### Supported Devices

- iPhone 12 and later (tested on iPhone 14+)
- iPad Air 5th generation and later
- iPad Pro 11-inch (3rd generation) and later

### Compatibility

- **iOS Minimum**: 16.0
- **Swift**: 5.0+
- **Xcode**: 15.0+

## Current Status

The app has been updated to **version 1.1** with the following improvements:

- ✅ Resolved App Store submission issues (ITMS-90032 invalid image paths)
- ✅ Complete iPhone and iPad icon set (all required sizes)
- ✅ Normalized app icon build settings
- ✅ Verified app metadata and version information

### Build & Release

The project includes proper build configurations for both Debug and Release builds:

- **Debug**: Full debugging symbols, unoptimized for faster compilation
- **Release**: Optimized for performance, stripped of debug info, ready for App Store

## Development

### Code Style

The project follows Apple's SwiftUI and Swift best practices:
- Declarative UI with SwiftUI
- MVVM architecture pattern
- Reactive state management with @State and @StateObject

### File Modifications

Key files modified in version 1.1:
- `CountyTrackerIOS/Info.plist`: Updated to version 1.1, fixed bundle identifier
- `CountyTracker.xcodeproj/project.pbxproj`: Normalized build settings, fixed icon configuration
- Icon asset catalog: Added complete iPhone and iPad icon set

## Deployment

### App Store Submission

To submit to the App Store:

1. Ensure all build settings are correct (verified in version 1.1)
2. Update version number in `Info.plist` (`CFBundleShortVersionString`)
3. Create a Release archive:
   ```bash
   xcodebuild -project CountyTracker.xcodeproj -scheme CountyTracker -configuration Release -destination 'generic/platform=iOS' archive -archivePath CountyTracker.xcarchive
   ```
4. Open the archive in Xcode Organizer
5. Validate and submit to App Store Connect

### Version Management

- **CFBundleShortVersionString**: User-facing version (e.g., "1.1")
- **CFBundleVersion**: Build number (e.g., "1")

## License

This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** license.

You are free to:
- Share and adapt the code
- Use for non-commercial purposes

With the following conditions:
- Provide attribution to the original author
- Do not use for commercial purposes without permission
- Indicate if changes were made

See the [LICENSE](LICENSE) file for the full license text.

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -am 'Add your feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

Please ensure:
- Code follows the existing style conventions
- Changes are tested on multiple device sizes
- Commit messages are clear and descriptive

## Support & Feedback

For bug reports, feature requests, or general feedback:
- Open an issue on GitHub
- Check existing issues to avoid duplicates

## Author

**Burke Rosen**  
GitHub: [@bqrosen](https://github.com/bqrosen)

## Acknowledgments

- US county boundary data sourced from open geospatial datasets
- County centroid coordinates provided by official geographic databases
- SwiftUI framework and Core Location services provided by Apple

---

**Last Updated:** March 17, 2026  
**Status:** Active Development
