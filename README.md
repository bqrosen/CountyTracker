# CountyTracker

A SwiftUI-based iOS app that automatically tracks US counties you've visited using GPS location services.

## Overview

CountyTracker is an elegant, privacy-focused mobile application designed for geography enthusiasts and road trip planners. The app uses your device's GPS to automatically record every US county you visit, building a personalized map of your county visits over time.

**Current Version:** 1.1  
**Deployment Target:** iOS 16.0+  
**Platform:** iPhone & iPad

## Technical Details

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- An iPhone/iPad running iOS 16.0 or later (for deployment)
- An Apple Developer Account (optional, for device deployment)

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

### Geographic Data Sources

The app uses the following geospatial databases:

- **counties.json**: GeoJSON FeatureCollection containing boundary polygons for approximately 3,200 US counties, parishes, and county-equivalents. Includes properties: NAME, STUSAB (state abbreviation), and GEOID. Used for rendering county boundaries on the map and intersection detection.

- **county_centroids.json**: Geographic centroid coordinates (latitude/longitude) for each US county. Used for map display optimization and feature annotations.

- **us_border.geojson**: US national boundary polygon in GeoJSON format. Provides the outer boundary reference for map rendering.

These datasets are bundled with the app and do not require external API calls, ensuring offline functionality and privacy.

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
