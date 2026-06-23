import SwiftUI

enum PostureColors {
    static let good = Color(red: 0.0, green: 0.8, blue: 0.4)
    static let warning = Color(red: 1.0, green: 0.76, blue: 0.03)
    static let poor = Color(red: 1.0, green: 0.31, blue: 0.0)
    static let alert = Color(red: 1.0, green: 0.2, blue: 0.2)

    static func forPosturePercentage(_ percentage: Int) -> Color {
        if percentage >= 60 { return good }
        if percentage >= 40 { return warning }
        return poor
    }

    static func forPostureState(_ state: PostureState) -> Color {
        switch state {
        case .good: return good
        case .warning: return warning
        case .alert: return poor
        }
    }
}
