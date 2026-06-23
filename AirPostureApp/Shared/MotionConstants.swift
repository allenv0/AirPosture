import Foundation

enum MotionConstants {
    static let calibrationDuration: TimeInterval = 5.0
    static let maxDataPoints = 50
    static let motionUpdateInterval: TimeInterval = 1.0
    static let gracePeriodDuration: TimeInterval = 30.0
    static let maxRetryAttempts = 5
    static let maxMotionManagerRestarts = 3
    static let motionManagerRestartCooldown: TimeInterval = 30.0
    static let healthCheckInterval: TimeInterval = 2.0
    static let maxSilenceDuration: TimeInterval = 10.0
    static let hapticInterval: TimeInterval = 0.2
    static let poorPosturePercentageThreshold = 41
    static let badPostureNoticeThreshold: TimeInterval = 10.0
    static let hapticFeedbackDelay: TimeInterval = 5.0
    static let recoveryDurationThreshold: TimeInterval = 5.0
    static let defaultRealtimeNotificationDelay: TimeInterval = 5.0
    static let uiUpdateFrequencyHz = 15.0

    static let poorPostureThreshold: Double = -22.0
    static let normalAirPodsAngle: Double = 0.0
    static let warningThreshold: Double = 20.0
    static let lowPassFilterFactor: Double = 0.4
    static let connectionTimeoutInterval: TimeInterval = 5.0

    static let powerSavingUpdateInterval: TimeInterval = 10.0
    static let deepSleepUpdateInterval: TimeInterval = 30.0
    static let powerSavingThreshold: TimeInterval = 300.0
    static let deepSleepThreshold: TimeInterval = 600.0

    static let backgroundUpdateInterval: TimeInterval = 1.0
    static let maxBackgroundUpdates = 300
}
