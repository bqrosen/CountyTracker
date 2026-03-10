import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var isTracking = false
    @Published private(set) var errorMessage: String?

    var onLocationUpdate: ((CLLocation) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 150
        manager.pausesLocationUpdatesAutomatically = true
        authorizationStatus = manager.authorizationStatus
    }

    func requestWhenInUsePermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            return
        }
        manager.requestAlwaysAuthorization()
    }

    func startTracking() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location services are disabled in system settings."
            return
        }

        if authorizationStatus == .notDetermined {
            requestWhenInUsePermission()
            return
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission denied. Enable it in Settings > Privacy & Security > Location Services."
            return
        }

        errorMessage = nil
        isTracking = true
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            errorMessage = nil
            if isTracking {
                manager.startUpdatingLocation()
            }
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
        errorMessage = error.localizedDescription
    }
}
