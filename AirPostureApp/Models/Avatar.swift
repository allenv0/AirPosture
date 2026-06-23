import SwiftUI

// MARK: - Type Definitions
enum AvatarType: String, CaseIterable {
    case bear = "bear-neck"
    case cat = "cat-neck"
    case dog = "dog-neck"
    case tim = "tim-neck"
    case alice = "alice-neck"
    case bear2 = "bear-neck2"

    var next: AvatarType {
        let allCases = AvatarType.allCases
        let currentIndex = allCases.firstIndex(of: self) ?? 0
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }

    var displayName: String {
        switch self {
        case .bear:
            return "Bear"
        case .cat:
            return "Kitty"
        case .dog:
            return "Samoyed"
        case .tim:
            return "Let Tim Cook"
        case .alice:
            return "Alice"
        case .bear2:
            return "Bear Max"
        }
    }
}

// MARK: - Avatar Manager
@Observable
final class AvatarManager {
    static let shared = AvatarManager()
    
    var selectedAvatar: AvatarType {
        didSet {
            UserDefaults.standard.set(selectedAvatar.rawValue, forKey: UserDefaultsKeys.selectedAvatar)
        }
    }
    
    private init() {
        let savedAvatar = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedAvatar) ?? AvatarType.bear.rawValue
        self.selectedAvatar = AvatarType(rawValue: savedAvatar) ?? .bear
    }
}

// MARK: - Theme Manager
