import Foundation

@MainActor
protocol ThemeManaging: AnyObject {
    var selectedTheme: AppTheme { get set }
}
