import CoreLocation
import Foundation
import UIKit

final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var isTracking = false
    @Published private(set) var errorMessage: String?

    var onLocationUpdate: ((CLLocation) -> Void)?

    private let manager = CLLocationManager()
    private static let trackingKey = "locationService.isTracking"
    /// Set when we want to upgrade to Always as soon as When In Use is granted.
    private var pendingAlwaysUpgrade = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 150
        manager.pausesLocationUpdatesAutomatically = true
        // Required for significant-change wakeup and background delivery
        manager.allowsBackgroundLocationUpdates = true
        authorizationStatus = manager.authorizationStatus

        // If tracking was active before the app was killed or relaunched by iOS,
        // resume without re-prompting the user.
        if UserDefaults.standard.bool(forKey: Self.trackingKey) {
            resumeTracking()
        }
    }

    func requestAlwaysPermission() {
        switch authorizationStatus {
        case .notDetermined:
            // iOS won't show Always directly from notDetermined.
            // Request When In Use first; the delegate will upgrade to Always.
            pendingAlwaysUpgrade = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Already have When In Use — mark upgrade intent and let delegate handle it
            // (don't call requestAlwaysAuthorization directly as it can block UI)
            pendingAlwaysUpgrade = true
        default:
            break
        }
    }

    func startTracking() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location services are disabled in system settings."
            return
        }

        // Check current status and request appropriate permission.
        // The delegate callback (locationManagerDidChangeAuthorization) will
        // handle transitioning from When In Use to Always if needed.
        switch authorizationStatus {
        case .notDetermined:
            // Ask for full Always permission via the upgrade flow
            requestAlwaysPermission()
            return
        case .authorizedWhenInUse, .authorizedAlways:
            // If we only have When In Use, mark that we want Always and the
            // delegate will upgrade on the next authorization change
            if authorizationStatus == .authorizedWhenInUse && !pendingAlwaysUpgrade {
                pendingAlwaysUpgrade = true
            }
        default:
            errorMessage = "Location permission denied. Enable it in Settings > Privacy & Security > Location Services."
            return
        }

        errorMessage = nil
        isTracking = true
        UserDefaults.standard.set(true, forKey: Self.trackingKey)
        startLocationUpdates()
    }

    func stopTracking() {
        isTracking = false
        UserDefaults.standard.set(false, forKey: Self.trackingKey)
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }

    // MARK: - Private

    /// Restarts location updates after an iOS-initiated relaunch (no permission prompts).
    private func resumeTracking() {
        guard authorizationStatus == .authorizedAlways ||
              authorizationStatus == .authorizedWhenInUse else { return }
        isTracking = true
        startLocationUpdates()
    }

    /// Starts both modes:
    /// - Significant location changes: cell/WiFi based, ~500 m, near-zero battery,
    ///   works while app is suspended or killed (iOS relaunches the app).
    ///   Requires "Always" permission for post-kill relaunch.
    /// - Standard updates: GPS, 100 m accuracy, used while app is in the foreground.
    private func startLocationUpdates() {
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        }
        manager.startUpdatingLocation()
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedWhenInUse:
            errorMessage = nil
            // Upgrade to Always if the onboarding requested it
            // Dispatch asynchronously to avoid blocking on the main thread
            if pendingAlwaysUpgrade {
                pendingAlwaysUpgrade = false
                DispatchQueue.main.async {
                    manager.requestAlwaysAuthorization()
                }
                return
            }
            if isTracking {
                startLocationUpdates()
            } else if UserDefaults.standard.bool(forKey: Self.trackingKey) {
                isTracking = true
                startLocationUpdates()
            }
        case .authorizedAlways:
            errorMessage = nil
            pendingAlwaysUpgrade = false
            if isTracking {
                startLocationUpdates()
            } else if UserDefaults.standard.bool(forKey: Self.trackingKey) {
                isTracking = true
                startLocationUpdates()
            }
        case .denied, .restricted:
            errorMessage = "Location permission denied. Enable it in Settings > Privacy & Security > Location Services."
            isTracking = false
            UserDefaults.standard.set(false, forKey: Self.trackingKey)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else {
            return
        }

        lastLocation = latest
        onLocationUpdate?(latest)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let locationError = error as? CLError else {
            errorMessage = error.localizedDescription
            return
        }

        switch locationError.code {
        case .locationUnknown:
            return
        case .denied:
            errorMessage = "Location permission denied. Enable it in Settings > Privacy & Security > Location Services."
            isTracking = false
        default:
            errorMessage = locationError.localizedDescription
        }
    }
}
