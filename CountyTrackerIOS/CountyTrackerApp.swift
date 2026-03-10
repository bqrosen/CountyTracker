import SwiftUI

@main
struct CountyTrackerApp: App {
    @StateObject private var viewModel = CountyTrackerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
