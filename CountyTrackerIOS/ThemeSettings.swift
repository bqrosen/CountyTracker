import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case nord

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .nord:
            return "Nord"
        }
    }
}

@MainActor
final class ThemeSettings: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: storageKey)
        }
    }

    private let storageKey = "county_tracker_theme_mode_v1"

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: storageKey),
           let persistedTheme = AppTheme(rawValue: rawValue) {
            selectedTheme = persistedTheme
        } else {
            selectedTheme = .system
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch selectedTheme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark, .nord:
            return .dark
        }
    }

    var isNord: Bool {
        selectedTheme == .nord
    }

    var nordBackground: Color {
        Color(.sRGB, red: 0.18, green: 0.20, blue: 0.25, opacity: 1)
    }

    var nordSecondaryBackground: Color {
        Color(.sRGB, red: 0.23, green: 0.26, blue: 0.32, opacity: 1)
    }

    var nordCardBackground: Color {
        Color(.sRGB, red: 0.27, green: 0.30, blue: 0.37, opacity: 1)
    }

    var nordPrimaryText: Color {
        Color(.sRGB, red: 0.90, green: 0.91, blue: 0.94, opacity: 1)
    }

    var nordSecondaryText: Color {
        Color(.sRGB, red: 0.84, green: 0.85, blue: 0.88, opacity: 1)
    }

    var nordAccent: Color {
        Color(.sRGB, red: 0.53, green: 0.75, blue: 0.82, opacity: 1)
    }
}
