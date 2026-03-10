import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @EnvironmentObject private var viewModel: CountyTrackerViewModel

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Map(coordinateRegion: $viewModel.mapRegion, showsUserLocation: true)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 12) {
                    statCard("Counties", value: "\(viewModel.store.totalUniqueCounties)")
                    statCard("States", value: "\(viewModel.store.totalStatesVisited)")
                    statCard("Visits", value: "\(viewModel.store.totalVisits)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current County")
                        .font(.headline)
                    Text(viewModel.currentCountyLabel)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if let errorMessage = viewModel.locationService.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Text("Permission: \(permissionText(viewModel.locationService.authorizationStatus))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Button("Allow Location") {
                        viewModel.requestPermission()
                    }
                    .buttonStyle(.bordered)

                    Button(viewModel.locationService.isTracking ? "Tracking" : "Start") {
                        viewModel.startTracking()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.locationService.isTracking)

                    Button("Stop") {
                        viewModel.stopTracking()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.locationService.isTracking)
                }

                List(viewModel.store.visits) { visit in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(visit.displayName)
                            .font(.headline)
                        Text("Visits: \(visit.visitCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("First seen: \(dateFormatter.string(from: visit.firstVisitedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Last seen: \(dateFormatter.string(from: visit.lastVisitedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("County Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        viewModel.clearData()
                    }
                    .disabled(viewModel.store.visits.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func statCard(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func permissionText(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }
}
