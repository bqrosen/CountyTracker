import SwiftUI

@main
struct CountyTrackerApp: App {
    @StateObject private var locationService: LocationService
    @StateObject private var store: CountyTrackerStore
    @StateObject private var viewModel: CountyTrackerViewModel
    @StateObject private var themeSettings = ThemeSettings()

    init() {
        let locationService = LocationService()
        let store = CountyTrackerStore()
        _locationService = StateObject(wrappedValue: locationService)
        _store = StateObject(wrappedValue: store)
        _viewModel = StateObject(wrappedValue: CountyTrackerViewModel(locationService: locationService, store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeSettings.preferredColorScheme)
                .environmentObject(viewModel)
                .environmentObject(locationService)
                .environmentObject(store)
                .environmentObject(themeSettings)
        }
    }
}
