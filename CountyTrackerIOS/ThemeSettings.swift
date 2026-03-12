import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case nord
    case sepia
    case outrun
    case cyber
    case jungle
    case snow

    var id: String { rawValue }

    var appIconName: String? {
        switch self {
        case .system, .nord:
            return nil
        case .light:
            return "AppIconLight"
        case .dark:
            return "AppIconDark"
        case .sepia:
            return "AppIconSepia"
        case .outrun:
            return "AppIconOutrun"
        case .cyber:
            return "AppIconCyber"
        case .jungle:
            return "AppIconJungle"
        case .snow:
            return "AppIconSnow"
        }
    }

    var displayName: String {
        switch self {
        case .system:    return "System"
        case .light:     return "Light"
        case .dark:      return "Dark"
        case .nord:      return "Nord"
        case .sepia:     return "Sepia"
        case .outrun:    return "Outrun"
        case .cyber:     return "Cyber"
        case .jungle:    return "Jungle"
        case .snow:      return "Snow"
        }
    }
}

@MainActor
final class ThemeSettings: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: storageKey)
            applyAppIcon(for: selectedTheme)
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

        applyAppIcon(for: selectedTheme)
    }

    private func applyAppIcon(for theme: AppTheme) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let desiredIcon = theme.appIconName
        guard UIApplication.shared.alternateIconName != desiredIcon else { return }

        UIApplication.shared.setAlternateIconName(desiredIcon)
    }

    var preferredColorScheme: ColorScheme? {
        switch selectedTheme {
        case .system:
            return nil
        case .light, .sepia, .snow:
            return .light
        case .dark, .nord, .outrun, .cyber, .jungle:
            return .dark
        }
    }

    var isNord: Bool {
        selectedTheme == .nord
    }

    var isSepia: Bool {
        selectedTheme == .sepia
    }

    var isOutrun: Bool {
        selectedTheme == .outrun
    }

    var isCyber: Bool {
        selectedTheme == .cyber
    }

    var isJungle: Bool {
        selectedTheme == .jungle
    }

    var isSnow: Bool {
        selectedTheme == .snow
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

    // MARK: - Sepia

    var sepiaBackground: Color {
        Color(.sRGB, red: 0.953, green: 0.910, blue: 0.816, opacity: 1)
    }

    var sepiaSecondaryBackground: Color {
        Color(.sRGB, red: 0.910, green: 0.851, blue: 0.710, opacity: 1)
    }

    var sepiaCardBackground: Color {
        Color(.sRGB, red: 0.875, green: 0.800, blue: 0.635, opacity: 1)
    }

    var sepiaPrimaryText: Color {
        Color(.sRGB, red: 0.173, green: 0.102, blue: 0.055, opacity: 1)
    }

    var sepiaSecondaryText: Color {
        Color(.sRGB, red: 0.420, green: 0.298, blue: 0.165, opacity: 1)
    }

    var sepiaAccent: Color {
        Color(.sRGB, red: 0.722, green: 0.361, blue: 0.220, opacity: 1)
    }

    // MARK: - Outrun

    var outrunBackground: Color {
        Color(.sRGB, red: 0.051, green: 0.008, blue: 0.129, opacity: 1)
    }

    var outrunSecondaryBackground: Color {
        Color(.sRGB, red: 0.086, green: 0.031, blue: 0.165, opacity: 1)
    }

    var outrunCardBackground: Color {
        Color(.sRGB, red: 0.122, green: 0.039, blue: 0.220, opacity: 1)
    }

    var outrunPrimaryText: Color {
        Color(.sRGB, red: 0.910, green: 0.957, blue: 0.973, opacity: 1)
    }

    var outrunSecondaryText: Color {
        Color(.sRGB, red: 0.5, green: 0.8, blue: 1.0, opacity: 1)
    }

    var outrunAccent: Color {
        Color(.sRGB, red: 1.0, green: 0.176, blue: 0.471, opacity: 1)
    }

    // MARK: - Cyber

    var cyberBackground: Color {
        Color(.sRGB, red: 0.020, green: 0.039, blue: 0.055, opacity: 1)
    }

    var cyberSecondaryBackground: Color {
        Color(.sRGB, red: 0.039, green: 0.086, blue: 0.157, opacity: 1)
    }

    var cyberCardBackground: Color {
        Color(.sRGB, red: 0.055, green: 0.118, blue: 0.212, opacity: 1)
    }

    var cyberPrimaryText: Color {
        Color(.sRGB, red: 0.941, green: 0.902, blue: 0.078, opacity: 1)
    }

    var cyberSecondaryText: Color {
        Color(.sRGB, red: 0.75, green: 0.3, blue: 1.0, opacity: 1)
    }

    var cyberAccent: Color {
        Color(.sRGB, red: 0.831, green: 1.0, blue: 0.0, opacity: 1)
    }

    // MARK: - Snow

    var snowBackground: Color {
        Color(.sRGB, red: 0.925, green: 0.937, blue: 0.957, opacity: 1)
    }

    var snowSecondaryBackground: Color {
        Color(.sRGB, red: 0.898, green: 0.914, blue: 0.941, opacity: 1)
    }

    var snowCardBackground: Color {
        Color(.sRGB, red: 0.847, green: 0.871, blue: 0.914, opacity: 1)
    }

    var snowPrimaryText: Color {
        Color(.sRGB, red: 0.180, green: 0.204, blue: 0.251, opacity: 1)
    }

    var snowSecondaryText: Color {
        Color(.sRGB, red: 0.298, green: 0.337, blue: 0.416, opacity: 1)
    }

    var snowAccent: Color {
        Color(.sRGB, red: 0.353, green: 0.573, blue: 0.678, opacity: 1)
    }

    // MARK: - Jungle

    var jungleBackground: Color {
        Color(.sRGB, red: 0.047, green: 0.110, blue: 0.059, opacity: 1)
    }

    var jungleSecondaryBackground: Color {
        Color(.sRGB, red: 0.071, green: 0.165, blue: 0.086, opacity: 1)
    }

    var jungleCardBackground: Color {
        Color(.sRGB, red: 0.102, green: 0.220, blue: 0.114, opacity: 1)
    }

    var junglePrimaryText: Color {
        Color(.sRGB, red: 0.843, green: 0.961, blue: 0.769, opacity: 1)
    }

    var jungleSecondaryText: Color {
        Color(.sRGB, red: 0.541, green: 0.816, blue: 0.467, opacity: 1)
    }

    var jungleAccent: Color {
        Color(.sRGB, red: 0.243, green: 0.882, blue: 0.365, opacity: 1)
    }

    // MARK: - Map colors

    var mapStrokeColor: Color {
        switch selectedTheme {
        case .light, .dark, .system, .nord, .snow:
            return Color(.sRGB, red: 191/255, green: 97/255, blue: 106/255, opacity: 1)
        case .sepia:
            return sepiaAccent
        case .outrun:
            return Color(.sRGB, red: 0.0, green: 0.93, blue: 1.0, opacity: 1)
        case .cyber:
            return cyberAccent
        case .jungle:
            return jungleAccent
        }
    }

    var mapFillColor: Color {
        switch selectedTheme {
        case .light, .dark, .system, .nord, .snow:
            return Color(.sRGB, red: 191/255, green: 97/255, blue: 106/255, opacity: 0.35)
        case .sepia:
            return sepiaAccent.opacity(0.30)
        case .outrun:
            return Color(.sRGB, red: 0.0, green: 0.93, blue: 1.0, opacity: 0.35)
        case .cyber:
            return cyberAccent.opacity(0.35)
        case .jungle:
            return jungleAccent.opacity(0.30)
        }
    }
}
