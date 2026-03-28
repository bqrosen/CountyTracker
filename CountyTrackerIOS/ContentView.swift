import SwiftUI
import MapKit
import CoreLocation
import UniformTypeIdentifiers
import Photos
import StoreKit

// MARK: - Timing Constants
private enum TimingConstants {
    static let tutorialInitialDelay: UInt64 = 500_000_000           // 0.5s: allow onboarding animations to finish
    static let tutorialPollInterval: UInt64 = 50_000_000            // 50ms: check for user input frequently
    static let importCompletionDisplayDuration: UInt64 = 180_000_000 // 0.18s: show import completion message briefly
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: CountyTrackerViewModel
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var store: CountyTrackerStore
    @EnvironmentObject private var themeSettings: ThemeSettings

    @AppStorage("hasSeenLocationOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasSeenQuickTutorial") private var hasSeenQuickTutorial = false
    @AppStorage("hasCompletedSupportPurchase") private var hasCompletedSupportPurchase = false
    @AppStorage("showTerritories") private var showTerritories = true

    @State private var isImporting = false
    @State private var isImportInProgress = false
    @State private var importProgress: Double = 0
    @State private var importStatusMessage = ""
    @State private var isExporting = false
    @State private var exportDocument = MapChartTextDocument(text: "")
    @State private var alertMessage: String?
    @State private var resetMapZoom = false
    @State private var confirmClearData = false
    @State private var mapCoordinator: VisitedCountyMapView.Coordinator?
    @State private var mapSnapshot: UIImage?
    @State private var isShareSheetPresented = false
    @State private var isTipJarPresented = false
    @State private var tutorialStepIndex: Int?
    @State private var isTutorialRunning = false
    @State private var shouldAdvanceTutorial = false
    @State private var cachedPalette: GlassPalette?
    @State private var lastPaletteTheme: AppTheme?
    @State private var cachedMapKeys: Set<String>?
    @State private var lastShowTerritoriesForKeys: Bool?
    @StateObject private var tipJarStore = TipJarStore()

    private let quickTutorialSteps = [
        "Long-press anywhere on the map for driving directions in Apple Maps.",
        "Use the share menu to import/export your map data or save a map snapshot to Photos.",
        "Tap Start to track counties automatically as you travel."
    ]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var palette: GlassPalette {
        // Memoize palette creation - only create if theme changed
        if lastPaletteTheme != themeSettings.selectedTheme {
            cachedPalette = GlassPalette(theme: themeSettings)
            lastPaletteTheme = themeSettings.selectedTheme
        }
        return cachedPalette ?? GlassPalette(theme: themeSettings)
    }

    private var territoryStateCodes: Set<String> {
        ["AS", "GU", "MP", "PR", "VI"]
    }

    private var displayedVisitedCounties: Int {
        if showTerritories { return store.totalUniqueCounties }
        return store.visits.filter { !territoryStateCodes.contains($0.stateCode.uppercased()) }.count
    }

    private var displayedTotalCounties: Int {
        showTerritories ? 3233 : 3144
    }

    private var mapVisitedKeys: Set<String> {
        // Memoize map keys calculation - recalculate only if territory filter changed
        if lastShowTerritoriesForKeys != showTerritories {
            if showTerritories {
                cachedMapKeys = Set(store.visits.map { $0.key })
            } else {
                cachedMapKeys = Set(
                    store.visits
                        .filter { !territoryStateCodes.contains($0.stateCode.uppercased()) }
                        .map { $0.key }
                )
            }
            lastShowTerritoriesForKeys = showTerritories
        }
        return cachedMapKeys ?? Set(store.visits.map { $0.key })
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [palette.backgroundGradientTop, palette.backgroundGradientBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if verticalSizeClass == .compact {
                    // Landscape mode: button bar on left side (non-rotated)
                    HStack(spacing: 2) {
                        // Left side: button controls
                        VStack(alignment: .leading, spacing: 8) {
                            Menu {
                                Button("Import mapchart.net style File") {
                                    isImporting = true
                                }
                                .font(.caption)
                                Button("Export mapchart.net style File") {
                                    do {
                                        exportDocument = MapChartTextDocument(text: try store.exportMapChartText())
                                        isExporting = true
                                    } catch {
                                        alertMessage = "Export failed: \(error.localizedDescription)"
                                    }
                                }
                                .font(.caption)
                                Button("Save Map to Photos") {
                                    exportMapToPhotos()
                                }
                                .font(.caption)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                resetMapZoom = true
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(2)
                        
                        // Right side: full map
                        VisitedCountyMapView(
                            visitedKeys: mapVisitedKeys,
                            showTerritories: showTerritories,
                            userLocation: locationService.lastLocation?.coordinate,
                            isTracking: locationService.isTracking,
                            resetMapZoom: $resetMapZoom,
                            theme: themeSettings.selectedTheme,
                            onCoordinatorReady: { coordinator in
                                mapCoordinator = coordinator
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(2)
                    }
                } else {
                    // Portrait mode: original vertical layout
                    ScrollView {
                        VStack(spacing: 14) {
                            VisitedCountyMapView(
                                visitedKeys: mapVisitedKeys,
                                showTerritories: showTerritories,
                                userLocation: locationService.lastLocation?.coordinate,
                                isTracking: locationService.isTracking,
                                resetMapZoom: $resetMapZoom,
                                theme: themeSettings.selectedTheme,
                                onCoordinatorReady: { coordinator in
                                    mapCoordinator = coordinator
                                }
                            )
                                .frame(height: 360)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .glassCard(palette, cornerRadius: 22)

                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Button(showTerritories ? "Hide Territories" : "Show Territories") {
                                        showTerritories.toggle()
                                    }
                                    .buttonStyle(.bordered)
                                    .lineLimit(1)
                                    Menu("Theme") {
                                        ForEach(AppTheme.allCases) { theme in
                                            Button(themeLabel(theme)) {
                                                themeSettings.selectedTheme = theme
                                            }
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .lineLimit(1)
                                    Menu {
                                        Button("Import mapchart.net style File") {
                                            isImporting = true
                                        }
                                        .font(.caption)
                                        Button("Export mapchart.net style File") {
                                            do {
                                                exportDocument = MapChartTextDocument(text: try store.exportMapChartText())
                                                isExporting = true
                                            } catch {
                                                alertMessage = "Export failed: \(error.localizedDescription)"
                                            }
                                        }
                                        .font(.caption)
                                        Button("Save Map to Photos") {
                                            exportMapToPhotos()
                                        }
                                        .font(.caption)
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.title2)
                                    }
                                    .buttonStyle(.bordered)
                                    Button {
                                        resetMapZoom = true
                                    } label: {
                                        Image(systemName: "arrow.uturn.backward.circle")
                                            .font(.title2)
                                    }
                                    .buttonStyle(.bordered)
                                    Spacer()
                                }
                                
                                HStack(alignment: .center, spacing: 8) {
                                    Text("Counties visited:")
                                        .font(.headline)
                                        .foregroundStyle(palette.secondaryText)
                                    let total = displayedTotalCounties
                                    let visited = displayedVisitedCounties
                                    let pct = total > 0 ? Int((Double(visited) / Double(total) * 100).rounded()) : 0
                                    Text("\(visited)/\(total.formatted())  \(pct)%")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                                Button(locationService.isTracking ? "Stop" : "Start") {
                                    if locationService.isTracking {
                                        viewModel.stopTracking()
                                    } else {
                                        viewModel.startTracking()
                                        resetMapZoom = true
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(palette.accent)

                                Button("Location Settings") {
                                    locationService.openAppSettings()
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    confirmClearData = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.title2)
                                }
                                .buttonStyle(.bordered)
                                .disabled(store.visits.isEmpty)
                            }

                            if !hasCompletedSupportPurchase {
                                Button {
                                    isTipJarPresented = true
                                } label: {
                                    Label("Support CountyTracker  ☕", systemImage: "heart.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.bordered)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Visit History")
                                    .font(.headline)
                                List(store.visits.sorted { $0.lastVisitedAt > $1.lastVisitedAt }) { visit in
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
            }
            .foregroundStyle(palette.primaryText)
            .overlay(alignment: .top) {
                if let stepIndex = tutorialStepIndex,
                   quickTutorialSteps.indices.contains(stepIndex) {
                    QuickTutorialBanner(message: quickTutorialSteps[stepIndex]) {
                        shouldAdvanceTutorial = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay {
                if isImportInProgress {
                    ZStack {
                        Color.black.opacity(0.15)
                            .ignoresSafeArea()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Importing MapChart File")
                                .font(.headline)
                            ProgressView(value: importProgress, total: 1.0)
                                .progressViewStyle(.linear)
                            Text(importStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: 320)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .allowsHitTesting(true)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { if !$0 { hasSeenOnboarding = true } }
            )) {
                LocationOnboardingView(onAllow: {
                    hasSeenOnboarding = true
                    locationService.requestAlwaysPermission()
                })
            }
            .sheet(isPresented: $isTipJarPresented) {
                TipJarSheet(tipJarStore: tipJarStore) { message, didCompletePurchase in
                    if didCompletePurchase {
                        hasCompletedSupportPurchase = true
                    }
                    alertMessage = message
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.plainText, .json],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    do {
                        guard let url = try result.get().first else { return }
                        try await importMapChartFile(from: url)
                    } catch {
                        alertMessage = "Import failed: \(error.localizedDescription)"
                        isImportInProgress = false
                    }
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
            .alert("Clear All Data?", isPresented: $confirmClearData) {
                Button("Clear Data", role: .destructive) { viewModel.clearData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all \(store.totalUniqueCounties) visited counties. This cannot be undone.")
            }
            .onAppear {
                startQuickTutorialIfNeeded()
            }
            .onChange(of: hasSeenOnboarding) { _ in
                startQuickTutorialIfNeeded()
            }
        }
    }

    private func themeLabel(_ theme: AppTheme) -> String {
        return themeSettings.selectedTheme == theme ? "✓ \(theme.displayName)" : theme.displayName
    }

    private func exportMapToPhotos() {
        guard let coordinator = mapCoordinator else {
            alertMessage = "Map not ready"
            return
        }
        
        coordinator.requestSnapshot { snapshot in
            guard let image = snapshot else {
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to capture map"
                }
                return
            }
            
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized else {
                    DispatchQueue.main.async {
                        self.alertMessage = "Photos permission is off. In Settings → Privacy & Security → Photos → CountyTracker, choose ‘Add Photos Only’."
                    }
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.alertMessage = "Map saved to Photos"
                        } else {
                            self.alertMessage = "Failed to save map: \(error?.localizedDescription ?? "Unknown error")"
                        }
                    }
                }
            }
        }
    }

    private func importMapChartFile(from url: URL) async throws {
        await MainActor.run {
            isImportInProgress = true
            importProgress = 0.0
            importStatusMessage = "Preparing file..."
        }

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        let data: Data
        if fileSize > 0 {
            data = try readDataWithProgress(from: url, expectedSize: fileSize)
        } else {
            data = try Data(contentsOf: url)
            await MainActor.run {
                importProgress = 0.65
                importStatusMessage = "Processing data..."
            }
        }

        let text = String(decoding: data, as: UTF8.self)

        await MainActor.run {
            importProgress = 0.85
            importStatusMessage = "Importing counties..."
        }

        let added = try await MainActor.run {
            try store.importMapChartText(text)
        }

        await MainActor.run {
            importProgress = 1.0
            importStatusMessage = "Done"
            alertMessage = "Imported \(added) new counties from MapChart file."
        }

        try? await Task.sleep(nanoseconds: 180_000_000)
        await MainActor.run {
            isImportInProgress = false
        }
    }

    private func readDataWithProgress(from url: URL, expectedSize: Int64) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let chunkSize = 64 * 1024
        var collected = Data()
        var bytesRead: Int64 = 0

        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            collected.append(chunk)
            bytesRead += Int64(chunk.count)

            let ratio = min(max(Double(bytesRead) / Double(expectedSize), 0), 1)
            let mappedProgress = 0.05 + (ratio * 0.60)
            Task { @MainActor in
                importProgress = mappedProgress
                importStatusMessage = "Reading file..."
            }
        }

        return collected
    }

    private func startQuickTutorialIfNeeded() {
        guard hasSeenOnboarding, !hasSeenQuickTutorial, !isTutorialRunning else { return }

        hasSeenQuickTutorial = true
        isTutorialRunning = true
        shouldAdvanceTutorial = false

        Task { @MainActor in
            // Initial delay to let onboarding animations settle
            try? await Task.sleep(nanoseconds: TimingConstants.tutorialInitialDelay)
            
            for index in quickTutorialSteps.indices {
                withAnimation(.easeInOut(duration: 0.2)) {
                    tutorialStepIndex = index
                }
                shouldAdvanceTutorial = false
                
                // Wait for tap/swipe to advance
                while !shouldAdvanceTutorial {
                    try? await Task.sleep(nanoseconds: TimingConstants.tutorialPollInterval)
                }
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                tutorialStepIndex = nil
            }
            isTutorialRunning = false
        }
    }


}

private struct QuickTutorialBanner: View {
    let message: String
    var onAdvance: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .opacity(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(radius: 6)
        .onTapGesture(perform: onAdvance)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -30 {  // Swipe left
                        onAdvance()
                    }
                }
        )
    }
}

private struct TipJarSheet: View {
    @ObservedObject var tipJarStore: TipJarStore
    let onResult: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("Support CountyTracker")
                    .font(.title3)
                    .fontWeight(.bold)

                if tipJarStore.isLoadingProducts {
                    ProgressView("Loading tips…")
                } else if let loadError = tipJarStore.loadErrorMessage {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    VStack(spacing: 8) {
                        ForEach(tipJarStore.suggestedProducts, id: \.id) { product in
                            Button {
                                Task { await purchase(product) }
                            } label: {
                                HStack {
                                    Text("Tip \(product.displayPrice)")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(product.displayPrice)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isPurchasing)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Tip Jar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await tipJarStore.loadProducts()
            }
        }
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        let result = await tipJarStore.purchase(product: product)
        isPurchasing = false
        onResult(result.message, result.didCompletePurchase)
        if result.didCompletePurchase {
            dismiss()
        }
    }
}

// MARK: - Location onboarding sheet

private struct LocationOnboardingView: View {
    let onAllow: () -> Void

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
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)

        }
        .interactiveDismissDisabled(true)
    }
}
