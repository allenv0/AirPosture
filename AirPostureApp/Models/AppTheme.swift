import SwiftUI

enum AppTheme: String, CaseIterable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
    
    var icon: String {
        switch self {
        case .dark: return "moon"
        case .light: return "sun"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()
    
    var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: UserDefaultsKeys.selectedTheme)
        }
    }
    
    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedTheme) ?? AppTheme.dark.rawValue
        self.selectedTheme = AppTheme(rawValue: savedTheme) ?? .dark
    }
}
