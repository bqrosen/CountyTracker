import Foundation
import CoreLocation
import MapKit

@MainActor
final class CountyTrackerViewModel: ObservableObject {
    @Published private(set) var currentCountyLabel: String = "No county yet"
    @Published private(set) var isResolvingCounty = false

    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
        span: MKCoordinateSpan(latitudeDelta: 1.45, longitudeDelta: 1.45)
    )

    @Published var mapRegion = CountyTrackerViewModel.defaultRegion

    let locationService: LocationService
    let store: CountyTrackerStore

    private let geocoder = CLGeocoder()
    private var lastResolvedLocation: CLLocation?
    private var lastResolvedAt: Date?
    private var hasCenteredOnUser = false

    init(locationService: LocationService, store: CountyTrackerStore) {
        self.locationService = locationService
        self.store = store

        locationService.onLocationUpdate = { [weak self] location in
            guard let self else { return }
            Task {
                await self.handleLocationUpdate(location)
            }
        }
    }

    func requestPermission() {
        locationService.requestAlwaysPermission()
    }

    func requestAlwaysPermission() {
        locationService.requestAlwaysPermission()
    }

    func startTracking() {
        hasCenteredOnUser = false
        locationService.startTracking()
    }

    func stopTracking() {
        locationService.stopTracking()
    }

    func clearData() {
        store.clearAll()
    }

    func resetMapRegion() {
        if let location = locationService.lastLocation {
            mapRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.45, longitudeDelta: 1.45)
            )
        } else {
            mapRegion = Self.defaultRegion
        }
        hasCenteredOnUser = true
    }

    private func handleLocationUpdate(_ location: CLLocation) async {
        if !hasCenteredOnUser {
            mapRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
            )
            hasCenteredOnUser = true
        }

        guard shouldResolveCounty(for: location) else {
            return
        }

        await resolveCounty(for: location)
    }

    private func shouldResolveCounty(for location: CLLocation) -> Bool {
        if isResolvingCounty {
            return false
        }

        if let lastLocation = lastResolvedLocation {
            let meters = location.distance(from: lastLocation)
            if meters < 1200 {
                return false
            }
        }

        if let lastTime = lastResolvedAt {
            let seconds = Date().timeIntervalSince(lastTime)
            if seconds < 90 {
                return false
            }
        }

        return true
    }

    private func resolveCounty(for location: CLLocation) async {
        isResolvingCounty = true

        defer {
            isResolvingCounty = false
            lastResolvedLocation = location
            lastResolvedAt = Date()
        }

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                return
            }

            guard let countryCode = placemark.isoCountryCode?.uppercased(), countryCode == "US" else {
                currentCountyLabel = "Outside US"
                return
            }

            let county = placemark.subAdministrativeArea ?? "Unknown County"
            let state = placemark.administrativeArea ?? "?"
            currentCountyLabel = "\(county), \(state)"
            store.recordVisit(from: placemark, at: Date())
        } catch {
            currentCountyLabel = "Unable to resolve county"
        }
    }
}
