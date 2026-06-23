import Foundation
import SwiftUI

struct PostureHomeState: Equatable {
    var pitch: Double
    var roll: Double
    var yaw: Double
    var postureState: PostureState
    var pitchHistory: [Double]
    var postureScorePercent: Int
    var poorPostureDuration: TimeInterval
    var totalSessionTime: TimeInterval
    var runningWalkingDuration: TimeInterval
    var isDeviceConnected: Bool
    var isPaused: Bool
    var connectionStatus: String
    var isInBackground: Bool
    var isInWarningCountdown: Bool
    var isInRecoveryCountdown: Bool
    var warningCountdownSeconds: Int
    var recoveryCountdownSeconds: Int
    var poorPostureThreshold: Double
    var normalAirPodsAngle: Double
    var isHapticFeedbackEnabled: Bool

    var hasActiveSession: Bool {
        totalSessionTime > 0
    }

    var formattedSessionTime: String {
        let minutes = Int(totalSessionTime) / 60
        let seconds = Int(totalSessionTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static let idle = PostureHomeState(
        pitch: 0,
        roll: 0,
        yaw: 0,
        postureState: .good(postureDuration: 0),
        pitchHistory: [],
        postureScorePercent: 0,
        poorPostureDuration: 0,
        totalSessionTime: 0,
        runningWalkingDuration: 0,
        isDeviceConnected: false,
        isPaused: false,
        connectionStatus: "Not started",
        isInBackground: false,
        isInWarningCountdown: false,
        isInRecoveryCountdown: false,
        warningCountdownSeconds: 0,
        recoveryCountdownSeconds: 0,
        poorPostureThreshold: MotionConstants.poorPostureThreshold,
        normalAirPodsAngle: MotionConstants.normalAirPodsAngle,
        isHapticFeedbackEnabled: true
    )
}
