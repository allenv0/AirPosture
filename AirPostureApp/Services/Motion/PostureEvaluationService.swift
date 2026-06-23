import Foundation
import os

@MainActor
protocol PostureEvaluating: AnyObject {
    var postureState: PostureState { get }
    var poorPostureThreshold: Double { get set }
    var normalAirPodsAngle: Double { get set }

    func evaluatePosture(newPitch: Double, sessionStartTime: Date, hapticController: HapticFeedbackController)
}

@Observable
@MainActor
final class PostureEvaluationService: PostureEvaluating {
    private(set) var postureState: PostureState = .good(postureDuration: 0)
    var poorPostureThreshold: Double {
        didSet {
            UserDefaults.standard.set(poorPostureThreshold, forKey: UserDefaultsKeys.poorPostureThreshold)
        }
    }
    var normalAirPodsAngle: Double {
        didSet {
            UserDefaults.standard.set(normalAirPodsAngle, forKey: UserDefaultsKeys.normalAirPodsAngle)
        }
    }

    init() {
        let savedThreshold = UserDefaults.standard.object(forKey: UserDefaultsKeys.poorPostureThreshold) as? Double
        self.poorPostureThreshold = savedThreshold ?? MotionConstants.poorPostureThreshold

        let savedAngle = UserDefaults.standard.object(forKey: UserDefaultsKeys.normalAirPodsAngle) as? Double
        self.normalAirPodsAngle = savedAngle ?? MotionConstants.normalAirPodsAngle
    }

    var adjustedPitch: Double = 0

    func evaluatePosture(newPitch: Double, sessionStartTime: Date, hapticController: HapticFeedbackController) {
        let currentTime = Date()
        let adjustedPitch = newPitch - normalAirPodsAngle
        self.adjustedPitch = adjustedPitch

        let isPoorPosture = adjustedPitch < poorPostureThreshold
        let wasPoorPosture = hapticController.lastCircleIsRed()

        if newPitch > MotionConstants.warningThreshold {
            let duration = postureState.lastGoodStateTime.distance(to: currentTime)
            postureState = duration > 2.0
                ? .alert(pitch: newPitch, duration: duration)
                : .warning(pitch: newPitch, timeAboveThreshold: duration)
        } else {
            let duration = sessionStartTime != Date.distantPast
                ? currentTime.timeIntervalSince(sessionStartTime) : 0
            postureState = .good(postureDuration: duration)
        }

        hapticController.handleCircleColorTransition(fromPoorPosture: wasPoorPosture, toPoorPosture: isPoorPosture, at: currentTime)
        hapticController.updateLastCircleColor(isPoorPosture: isPoorPosture)
    }

    func isPoorPosture(pitch: Double) -> Bool {
        return (pitch - normalAirPodsAngle) < poorPostureThreshold
    }
}
