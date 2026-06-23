import Foundation
import os

#if canImport(UIKit)
import UIKit
#endif

@MainActor
protocol HapticControllerDependencies: AnyObject {
    var isHapticFeedbackEnabled: Bool { get }
    var isBadPostureHapticEnabled: Bool { get }
    var isWarningCountdownEnabled: Bool { get }
    var isRecoveryCountdownEnabled: Bool { get }
    var hasActiveSession: Bool { get }
    var isPaused: Bool { get }
    func sendPostureWarningNotification()
    func sendHapticStartNotification()
}

@Observable
@MainActor
final class HapticFeedbackController {
    private(set) var isInWarningCountdown: Bool = false
    private(set) var warningCountdownSeconds: Int = 0
    private(set) var isInRecoveryCountdown: Bool = false
    private(set) var recoveryCountdownSeconds: Int = 0

    private var isHapticActive: Bool = false
    private var redCircleStartTime: Date?
    private var hapticTimer: Timer?
    private var countdownSource: DispatchSourceTimer?
    private var warningEndAt: Date?
    private var recoveryEndAt: Date?
    private var lastCircleColor: CircleColor = .green
    private var hasSentWarningNotification: Bool = false
    private var hasSentHapticStartNotification: Bool = false

    private let hapticInterval: TimeInterval = MotionConstants.hapticInterval
    var badPostureNoticeThreshold: TimeInterval = MotionConstants.badPostureNoticeThreshold
    private let hapticFeedbackDelay: TimeInterval = MotionConstants.hapticFeedbackDelay
    private let recoveryDurationThreshold: TimeInterval = MotionConstants.recoveryDurationThreshold

    private weak var dependencies: HapticControllerDependencies?

    private enum CircleColor {
        case red
        case green
    }

    func configure(dependencies: HapticControllerDependencies) {
        self.dependencies = dependencies
    }

    func handleCircleColorTransition(
        fromPoorPosture: Bool, toPoorPosture: Bool, at currentTime: Date
    ) {
        let previousColor: CircleColor = fromPoorPosture ? .red : .green
        let currentColor: CircleColor = toPoorPosture ? .red : .green

        guard let deps = dependencies, deps.hasActiveSession else {
            if isInWarningCountdown || isInRecoveryCountdown {
                stopWarningCountdown()
                stopRecoveryCountdown()
            }
            return
        }

        switch (previousColor, currentColor) {
        case (.green, .red):
            redCircleStartTime = currentTime
            hasSentWarningNotification = false
            hasSentHapticStartNotification = false
            Logger.haptics.info("Head visualizer turned RED - Starting bad posture tracking")

        case (.red, .green):
            if isHapticActive && !isInRecoveryCountdown {
                startRecoveryCountdown()
                Logger.haptics.info("Head visualizer turned GREEN - Starting recovery countdown")
            } else {
                Logger.haptics.info("Head visualizer turned GREEN")
            }
            redCircleStartTime = nil
            stopWarningCountdown()

        case (.red, .red):
            if let startTime = redCircleStartTime {
                let redDuration = currentTime.timeIntervalSince(startTime)

                if redDuration >= badPostureNoticeThreshold && !hasSentWarningNotification {
                    hasSentWarningNotification = true
                    startWarningCountdown()
                    deps.sendPostureWarningNotification()
                    Logger.haptics.info("Bad posture sustained - Showing warning notice")
                }

                if redDuration >= (badPostureNoticeThreshold + hapticFeedbackDelay)
                    && !hasSentHapticStartNotification
                {
                    hasSentHapticStartNotification = true
                    startHapticFeedback()
                    stopWarningCountdown()
                    deps.sendHapticStartNotification()
                    Logger.haptics.info("Bad posture sustained - Starting haptic feedback")
                }
            }

        case (.green, .green):
            break
        }
    }

    func updateHapticFeedback() {
        guard let deps = dependencies, !deps.isPaused && deps.hasActiveSession else {
            teardownCountdownSchedulerIfIdle()
            return
        }

        if isInRecoveryCountdown && lastCircleColor == .red {
            stopRecoveryCountdown()
            Logger.haptics.info("Recovery interrupted - Head visualizer turned red again")
        }

        tickConsolidatedCountdowns(updateOnly: true)
    }

    func stopAllFeedback() {
        stopHapticFeedback()
        stopWarningCountdown()
        stopRecoveryCountdown()
        teardownCountdownSchedulerIfIdle()
    }

    func resetState() {
        stopHapticFeedback()
        stopWarningCountdown()
        stopRecoveryCountdown()

        isHapticActive = false
        redCircleStartTime = nil
        lastCircleColor = .green
        hasSentWarningNotification = false
        hasSentHapticStartNotification = false
    }

    func updateLastCircleColor(isPoorPosture: Bool) {
        let newColor: CircleColor = isPoorPosture ? .red : .green
        lastCircleColor = newColor
    }

    func lastCircleIsRed() -> Bool {
        lastCircleColor == .red
    }

    func cancelCountdownScheduler() {
        cancelTimerSourceSafely(&countdownSource)
    }

    private func startHapticFeedback() {
        guard let deps = dependencies else { return }
        guard !isHapticActive && deps.isHapticFeedbackEnabled && deps.isBadPostureHapticEnabled else {
            if !deps.isHapticFeedbackEnabled {
                Logger.haptics.info("Haptic feedback disabled by user - not starting")
            } else if !deps.isBadPostureHapticEnabled {
                Logger.haptics.info("Bad posture haptic feedback disabled by user - not starting")
            }
            return
        }

        isHapticActive = true

        #if os(iOS)
        hapticTimer = Timer.scheduledTimer(withTimeInterval: hapticInterval, repeats: true) {
            [weak self] _ in
                self?.triggerHeavyHaptic()
        }
        #endif

        Logger.haptics.info("Haptic feedback started")
    }

    private func stopHapticFeedback() {
        guard isHapticActive else { return }

        isHapticActive = false
        hapticTimer?.invalidate()
        hapticTimer = nil

        Logger.haptics.info("Haptic feedback stopped")
    }

    private func triggerHeavyHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    private func startWarningCountdown() {
        guard let deps = dependencies else { return }
        guard !isInWarningCountdown && deps.isWarningCountdownEnabled else {
            if !deps.isWarningCountdownEnabled {
                Logger.haptics.info("Warning countdown disabled - skipping countdown timer")
            }
            return
        }

        isInWarningCountdown = true
        warningCountdownSeconds = Int(hapticFeedbackDelay)
        warningEndAt = Date().addingTimeInterval(hapticFeedbackDelay)
        ensureCountdownScheduler()

        Logger.haptics.info("Warning countdown started - \(self.warningCountdownSeconds) seconds remaining")
    }

    func stopWarningCountdown() {
        guard isInWarningCountdown else { return }

        isInWarningCountdown = false
        warningCountdownSeconds = 0
        warningEndAt = nil
        teardownCountdownSchedulerIfIdle()

        Logger.haptics.info("Warning countdown stopped")
    }

    private func startRecoveryCountdown() {
        guard let deps = dependencies else { return }
        guard !isInRecoveryCountdown && deps.isRecoveryCountdownEnabled else {
            if !deps.isRecoveryCountdownEnabled {
                Logger.haptics.info("Recovery countdown disabled - skipping countdown timer")
                stopHapticFeedback()
            }
            return
        }

        isInRecoveryCountdown = true
        recoveryCountdownSeconds = Int(recoveryDurationThreshold)
        recoveryEndAt = Date().addingTimeInterval(recoveryDurationThreshold)
        ensureCountdownScheduler()

        Logger.haptics.info("Recovery countdown started - \(self.recoveryCountdownSeconds) seconds remaining")
    }

    func stopRecoveryCountdown() {
        guard isInRecoveryCountdown else { return }

        isInRecoveryCountdown = false
        recoveryCountdownSeconds = 0
        recoveryEndAt = nil
        teardownCountdownSchedulerIfIdle()

        Logger.haptics.info("Recovery countdown stopped")
    }

    private func ensureCountdownScheduler() {
        guard countdownSource == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        source.schedule(deadline: .now(), repeating: 1.0)
        source.setEventHandler { [weak self] in
            self?.tickConsolidatedCountdowns(updateOnly: false)
        }
        countdownSource = source
        source.resume()
    }

    private func teardownCountdownSchedulerIfIdle() {
        if warningEndAt == nil && recoveryEndAt == nil {
            countdownSource?.cancel()
            countdownSource = nil
        }
    }

    private func tickConsolidatedCountdowns(updateOnly: Bool) {
        guard let deps = dependencies, deps.hasActiveSession else {
            teardownCountdownSchedulerIfIdle()
            return
        }

        let now = Date()

        if let end = warningEndAt {
            let remaining = max(0, Int(end.timeIntervalSince(now).rounded(.down)))
            if remaining != warningCountdownSeconds {
                // no-op marker for observation
            }
            if remaining > 0 {
                Self.safeMainActor {
                    self.warningCountdownSeconds = remaining
                }
            } else if !updateOnly {
                Self.safeMainActor {
                    self.stopWarningCountdown()
                    self.startHapticFeedback()
                    if !self.hasSentHapticStartNotification {
                        self.hasSentHapticStartNotification = true
                        deps.sendHapticStartNotification()
                    }
                }
            }
        }

        if let end = recoveryEndAt {
            let remaining = max(0, Int(end.timeIntervalSince(now).rounded(.down)))
            if remaining != recoveryCountdownSeconds {
                // no-op marker for observation
            }
            if remaining > 0 {
                Self.safeMainActor {
                    self.recoveryCountdownSeconds = remaining
                }
            } else if !updateOnly {
                Self.safeMainActor {
                    self.stopHapticFeedback()
                    self.stopRecoveryCountdown()
                    Logger.haptics.info("Recovery countdown completed - Haptic feedback stopped")
                }
            }
        }

        if warningEndAt == nil && recoveryEndAt == nil {
            teardownCountdownSchedulerIfIdle()
        }
    }

    private func cancelTimerSourceSafely(_ source: inout DispatchSourceTimer?) {
        SystemUtilities.cancelTimerSourceSafely(&source)
    }

    private static func safeMainActor(operation: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            operation()
        } else {
            Task { @MainActor in
                operation()
            }
        }
    }
}
