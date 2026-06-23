import Foundation
import FirebaseCore
import FirebaseAnalytics
import os

/// A wrapper around Firebase Analytics to avoid tying the entire codebase to Firebase APIs directly.
/// This allows safe execution even if `GoogleService-Info.plist` is missing during development.
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private var isConfigured = false
    
    private init() {}
    
    /// Safely configures Firebase. Should be called at app launch.
    func configure() {
        // Prevent multiple configurations
        guard !isConfigured else { return }
        
        // Safely check if GoogleService-Info.plist exists in the bundle before configuring
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            isConfigured = true
            Logger.general.info("AnalyticsManager: Firebase successfully configured")
        } else {
            Logger.general.warning("AnalyticsManager: GoogleService-Info.plist not found. Firebase Analytics will be disabled")
        }
    }
    
    /// Logs a custom event to Analytics if configured.
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        guard isConfigured else { return }
        Analytics.logEvent(name, parameters: parameters)
    }
    
    /// Sets a user property in Analytics if configured.
    func setUserProperty(_ value: String?, forName name: String) {
        guard isConfigured else { return }
        Analytics.setUserProperty(value, forName: name)
    }
    
    /// Logs the currently active screen.
    func logScreenView(screenClass: String, screenName: String) {
        logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenClass: screenClass,
            AnalyticsParameterScreenName: screenName
        ])
    }
}
