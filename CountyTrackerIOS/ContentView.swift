import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @EnvironmentObject private var viewModel: CountyTrackerViewModel
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var store: CountyTrackerStore
    @EnvironmentObject private var themeSettings: ThemeSettings

    @AppStorage("hasSeenLocationOnboarding") private var hasSeenOnboarding = false

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

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Counties")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                                let total = 3244
                                let visited = store.totalUniqueCounties
                                let pct = total > 0 ? Int((Double(visited) / Double(total) * 100).rounded()) : 0
                                Text("\(visited)/\(total.formatted())  \(pct)%")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            Button {
                                viewModel.resetMapRegion()
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .font(.title2)
                            }
                            .buttonStyle(.bordered)
                        }

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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { if !$0 { hasSeenOnboarding = true } }
            )) {
                LocationOnboardingView(
                    onAllow: {
                        hasSeenOnboarding = true
                        locationService.requestAlwaysPermission()
                    },
                    onDismiss: {
                        hasSeenOnboarding = true
                    }
                )
            }
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

// MARK: - Location onboarding sheet

private struct LocationOnboardingView: View {
    let onAllow: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "location.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Background County Tracking")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("""
CountyTracker can automatically record counties as you travel — even when the app is closed.

It uses **Significant Location Change** monitoring, which relies on cell towers and Wi-Fi rather than GPS. This means your battery is barely affected between location updates.

Your location data never leaves your device.
""")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)

            Spacer()

            Button(action: onAllow) {
                Text("Enable Background Tracking")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)

            Button("Not Now") {
                onDismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
        }
        .interactiveDismissDisabled(true)
    }
}
