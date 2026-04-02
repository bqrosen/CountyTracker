# CountyTracker
Making maps of the counties you've been in is fun. I got into it when I real;ized I just needed three of four more to complete all of Califonia. Now there's an app for that. CountyTracker is a lightweight, privacy-focused iOS app that overlays county boundaries on Apple Maps, automatically keeps track of counties you've visited, and fills them in to build a personalized map of your visits over time.

## Features
- Running counter of your total number and percentage of US counties visited.
- Long press on unexplored counties to get driving directions to them in Apple Maps.
- Export map snapshots directly to your Photos library for sharing.
- Import and export mapchart.net-compatible county file lists (aka configuration .txt files). I have no affiliation with [mapchart.net](https://www.mapchart.net/), but I'm a big fan.
- Background tracking: If enabled, CountyTracker uses Apple's low-power location services (Significant-Change Location Service and the system `CLVisit` APIs), which rely primarily on cell‑tower and Wi‑Fi-based location rather than continuous GPS. This provides system-delivered, infrequent visit/location updates with minimal battery impact while remaining accurate enough for county-level tracking. It requires the `Always` location permission; you can disable background tracking in the app or revoke the permission in Settings.
- Includes US county-equivalent subdivisions for US territories like Puerto Rico, Guam, and the USVI (toggleable).
- View in eight colorful themes: Light, Dark, Nord, Snow, Sepia, Outrun, Cyber, Jungle

### Privacy
CountyTracker is fully open source and runs entirely on your device. All location and visit data are stored locally; nothing is collected, transmitted, or shared with the developer or third parties.

### Monetization
This app is free to download with all features enabled and no ads. There is an in-app tip jar if you're feeling appreciative; making any in-app purchase removes the tip jar button.

### Location Permissions
The app requests two types of location permissions:
- **While Using**: For manual county tracking during active app use
- **Always**: For background county tracking (optional)

### Prerequisites 
- iPhone 12 and later 
- iPad Air 5th generation and later
- iPad Pro 11-inch (3rd generation) and later
- iOS 16.0 or later 

## Support & Feedback
For bug reports, feature requests, or general feedback:
- Shoot me an email at dev at bqrosen.com
- Or open an issue on GitHub

## Planned Features
- Manually adding counties in-app (currently possible only by importing a file from [mapchart.net](https://www.mapchart.net/) or by editing a configuration file).

## Author

**Burke Rosen**  
GitHub: [@bqrosen](https://github.com/bqrosen)

## Acknowledgments

- US county and national boundary data sourced from the US census bureau's [TIGERweb](https://tigerweb.geo.census.gov/tigerwebmain/TIGERweb_main.html).
- SwiftUI framework and Core Location services provided by Apple.

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

---

**Current Version:** 1.1  
**Deployment Target:** iOS 16.0+  
**Platform:** iPhone & iPad
**Last Updated:** March 18, 2026  

