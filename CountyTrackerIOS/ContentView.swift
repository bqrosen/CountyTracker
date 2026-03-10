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

    private var palette: GlassPalette {
        GlassPalette(theme: themeSettings)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [palette.backgroundGradientTop, palette.backgroundGradientBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        CountyBoundaryMapView(region: $viewModel.mapRegion)
                            .frame(height: 255)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .glassCard(palette, cornerRadius: 22)

                        HStack(spacing: 10) {
                            statCard("Counties", value: "\(store.totalUniqueCounties)")
                            statCard("States", value: "\(store.totalStatesVisited)")
                            statCard("Visits", value: "\(store.totalVisits)")
                        }

                        NavigationLink {
                            VisitedCountiesView()
                        } label: {
                            Label("Open Visited Counties Map", systemImage: "map.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(palette.accent)

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
                                .foregroundStyle(palette.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassCard(palette)

                        HStack(spacing: 8) {
                            Button(locationService.isTracking ? "Tracking" : "Start") {
                                viewModel.startTracking()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(palette.accent)
                            .disabled(locationService.isTracking)

                            Button("Stop") {
                                viewModel.stopTracking()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!locationService.isTracking)

                            Button("Location Settings") {
                                locationService.openAppSettings()
                            }
                            .buttonStyle(.bordered)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Visit History")
                                .font(.headline)

                            List(store.visits) { visit in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(visit.displayName)
                                        .font(.headline)
                                        .foregroundStyle(palette.primaryText)
                                    Text("Visits: \(visit.visitCount)")
                                        .font(.subheadline)
                                        .foregroundStyle(palette.secondaryText)
                                    Text("First seen: \(dateFormatter.string(from: visit.firstVisitedAt))")
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                    Text("Last seen: \(dateFormatter.string(from: visit.lastVisitedAt))")
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                }
                                .listRowBackground(palette.rowFill)
                            }
                            .frame(minHeight: 260)
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                        }
                        .padding(14)
                        .glassCard(palette)
                    }
                    .padding()
                }
            }
            .foregroundStyle(palette.primaryText)
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
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassCard(palette, cornerRadius: 16)
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
