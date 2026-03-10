import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @EnvironmentObject private var viewModel: CountyTrackerViewModel
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var store: CountyTrackerStore
    @EnvironmentObject private var themeSettings: ThemeSettings

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                CountyBoundaryMapView(region: $viewModel.mapRegion)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 12) {
                    statCard("Counties", value: "\(store.totalUniqueCounties)")
                    statCard("States", value: "\(store.totalStatesVisited)")
                    statCard("Visits", value: "\(store.totalVisits)")
                }

                NavigationLink {
                    VisitedCountiesView()
                } label: {
                    Label("Visited Counties Map", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current County")
                        .font(.headline)
                    Text(viewModel.currentCountyLabel)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if let errorMessage = locationService.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Text("Permission: \(permissionText(locationService.authorizationStatus))")
                        .font(.footnote)
                        .foregroundStyle(secondaryTextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Button("Allow While Using") {
                        viewModel.requestPermission()
                    }
                    .buttonStyle(.bordered)

                    Button("Allow Always") {
                        viewModel.requestAlwaysPermission()
                    }
                    .buttonStyle(.bordered)

                    Button(locationService.isTracking ? "Tracking" : "Start") {
                        viewModel.startTracking()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(locationService.isTracking)

                    Button("Stop") {
                        viewModel.stopTracking()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!locationService.isTracking)
                }

                List(store.visits) { visit in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(visit.displayName)
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                        Text("Visits: \(visit.visitCount)")
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                        Text("First seen: \(dateFormatter.string(from: visit.firstVisitedAt))")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                        Text("Last seen: \(dateFormatter.string(from: visit.lastVisitedAt))")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }
                    .listRowBackground(listRowBackgroundColor)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(listBackgroundColor)
            }
            .padding()
            .foregroundStyle(primaryTextColor)
            .background(screenBackgroundColor.ignoresSafeArea())
            .navigationTitle("County Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Theme") {
                        ForEach(AppTheme.allCases) { theme in
                            Button(themeLabel(theme)) {
                                themeSettings.selectedTheme = theme
                            }
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        viewModel.clearData()
                    }
                    .disabled(store.visits.isEmpty)
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
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var screenBackgroundColor: Color {
        themeSettings.isNord ? themeSettings.nordBackground : Color(.systemBackground)
    }

    private var listBackgroundColor: Color {
        themeSettings.isNord ? themeSettings.nordSecondaryBackground : Color(.systemBackground)
    }

    private var listRowBackgroundColor: Color {
        themeSettings.isNord ? themeSettings.nordCardBackground : Color(.secondarySystemBackground)
    }

    private var cardBackground: Color {
        themeSettings.isNord ? themeSettings.nordCardBackground : Color(.secondarySystemBackground)
    }

    private var primaryTextColor: Color {
        themeSettings.isNord ? themeSettings.nordPrimaryText : .primary
    }

    private var secondaryTextColor: Color {
        themeSettings.isNord ? themeSettings.nordSecondaryText : .secondary
    }

    private func themeLabel(_ theme: AppTheme) -> String {
        themeSettings.selectedTheme == theme ? "✓ \(theme.displayName)" : theme.displayName
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
