import SwiftUI
import MapKit
import CoreLocation
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: CountyTrackerViewModel
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var store: CountyTrackerStore
    @EnvironmentObject private var themeSettings: ThemeSettings

    @AppStorage("hasSeenLocationOnboarding") private var hasSeenOnboarding = false

    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = MapChartTextDocument(text: "")
    @State private var alertMessage: String?
    @State private var resetMapZoom = false

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
                        VisitedCountyMapView(
                            visitedKeys: Set(store.visits.map { $0.key }),
                            resetMapZoom: $resetMapZoom
                        )
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
                                resetMapZoom = true
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

                        Button {
                            // placeholder — tip jar coming soon
                        } label: {
                            Label("Support CountyTracker  ☕", systemImage: "heart.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.pink)
                        .disabled(true)

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
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.plainText, .json],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    let text = String(decoding: data, as: UTF8.self)
                    let added = try store.importMapChartText(text)
                    alertMessage = "Imported \(added) new counties from MapChart file."
                } catch {
                    alertMessage = "Import failed: \(error.localizedDescription)"
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .plainText,
                defaultFilename: "mapchartSave__usa_counties__-1"
            ) { result in
                switch result {
                case .success:
                    alertMessage = "MapChart export saved."
                case .failure(let error):
                    alertMessage = "Export failed: \(error.localizedDescription)"
                }
            }
            .alert("MapChart Data", isPresented: .constant(alertMessage != nil), actions: {
                Button("OK") { alertMessage = nil }
            }, message: {
                Text(alertMessage ?? "")
            })
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
                    HStack {
                        Menu("Data") {
                            Button("Import MapChart File") {
                                isImporting = true
                            }
                            Button("Export MapChart File") {
                                do {
                                    exportDocument = MapChartTextDocument(text: try store.exportMapChartText())
                                    isExporting = true
                                } catch {
                                    alertMessage = "Export failed: \(error.localizedDescription)"
                                }
                            }
                        }
                        Button("Clear") {
                            viewModel.clearData()
                        }
                        .disabled(store.visits.isEmpty)
                    }
                }
            }
        }
    }

    private func themeLabel(_ theme: AppTheme) -> String {
        themeSettings.selectedTheme == theme ? "✓ \(theme.displayName)" : theme.displayName
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

                Text("iOS will show two permission prompts. Tap **Allow While Using App** on the first, then **Change to Always Allow** on the second.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
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
