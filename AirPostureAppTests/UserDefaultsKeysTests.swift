import Testing
@testable import AirPosture

@Suite("UserDefaultsKeys")
struct UserDefaultsKeysTests {
    @Test("All keys are non-empty")
    func testKeysNonEmpty() {
        #expect(!UserDefaultsKeys.selectedTheme.isEmpty)
        #expect(!UserDefaultsKeys.selectedAvatar.isEmpty)
        #expect(!UserDefaultsKeys.sessions.isEmpty)
        #expect(!UserDefaultsKeys.poorPostureThreshold.isEmpty)
        #expect(!UserDefaultsKeys.normalAirPodsAngle.isEmpty)
        #expect(!UserDefaultsKeys.isHapticFeedbackEnabled.isEmpty)
        #expect(!UserDefaultsKeys.notificationMode.isEmpty)
        #expect(!UserDefaultsKeys.realtimeNotificationDelay.isEmpty)
        #expect(!UserDefaultsKeys.audioCueStyle.isEmpty)
        #expect(!UserDefaultsKeys.hasCompletedOnboarding.isEmpty)
    }
    
    @Test("All keys are unique")
    func testKeysUnique() {
        let allKeys = [
            UserDefaultsKeys.selectedTheme,
            UserDefaultsKeys.selectedAvatar,
            UserDefaultsKeys.sessions,
            UserDefaultsKeys.hasShownDemoSessions,
            UserDefaultsKeys.poorPostureThreshold,
            UserDefaultsKeys.normalAirPodsAngle,
            UserDefaultsKeys.isHapticFeedbackEnabled,
            UserDefaultsKeys.isBadPostureHapticEnabled,
            UserDefaultsKeys.isWarningCountdownEnabled,
            UserDefaultsKeys.isRecoveryCountdownEnabled,
            UserDefaultsKeys.notificationMode,
            UserDefaultsKeys.realtimeNotificationDelay,
            UserDefaultsKeys.audioCueStyle,
            UserDefaultsKeys.hasCompletedOnboarding,
            UserDefaultsKeys.backgroundSessionState,
        ]
        let uniqueKeys = Set(allKeys)
        #expect(allKeys.count == uniqueKeys.count)
    }
}
