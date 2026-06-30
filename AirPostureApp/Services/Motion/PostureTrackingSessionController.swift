import Combine
import Foundation
import os

#if os(iOS)
import UIKit
#endif

// MARK: - Delegate Protocol

/// Actions the session controller cannot perform alone because they require
/// access to the parent's motion hardware, haptic controller, or live-activity
/// update path.
@MainActor
protocol SessionControllerDelegate: AnyObject {
    var connectionCoordinator: HeadphoneConnectionCoordinator { get }
    var hapticController: HapticFeedbackController { get }
    var isForegroundTransitioning: Bool { get }
    var isInBackground: Bool { get }
    var lastKnownPoorPostureState: Bool { get set }

    func resumeMotionTracking()
    func pauseMotionTracking()
    func resetMotionDisplay()
    func startActivityDetection()
    func stopActivityDetection()
    func updateLiveActivity(force: Bool)
    func startResumeGracePeriod()
}

// MARK: - Session Controller

/// Owns the tracking-session lifecycle orchestration: starting, pausing,
/// resetting, and saving sessions. Delegates hardware-level actions
/// (motion start/stop, activity detection, haptic control) to the parent
/// through `SessionControllerDelegate`.
///
/// `HeadphoneMotionManager` creates and owns this controller and calls
/// its methods when the user or system triggers session-lifecycle events.
/// Session timing and score math are delegated to `SessionTimingService`.
@Observable
@MainActor
final class PostureTrackingSessionController {

    // MARK: - Delegate

    weak var delegate: (any SessionControllerDelegate)?

    // MARK: - Dependencies

    let sessionTimingService = SessionTimingService(sessionStore: SessionStore.shared)
    let liveActivitySyncService = LiveActivitySyncService()
    let sessionStore = SessionStore.shared
    private let isLiveActivityEnabled = true

    // MARK: - Session State (owned here, mirrored on manager where the UI reads it)

    /// Whether the user has explicitly paused tracking.
    private(set) var isPaused: Bool = false

    /// The time the current session started. `distantPast` means no session.
    var sessionStartTime: Date = .distantPast

    // These are duplicated from SessionTimingService for the backup path
    // (simulator mock, background updates). The primary source of truth for
    // UI-facing values is SessionTimingService, mirrored in processMotionData.
    private var poorPostureStartTime: Date?
    private var accumulatedPoorPostureDuration: TimeInterval = 0
    var lastPoorPostureUpdate: Date = .distantPast
    private var currentActivityStartTime: Date?
    var isUserRunningOrWalking: Bool = false

    // MARK: - Session Lifecycle

    /// Creates a new posture-tracking session in the store, resets timing,
    /// starts activity monitoring, and launches the Live Activity.
    @MainActor
    func startNewSession() {
        Logger.session.info("Start new session called")

        guard let delegate = delegate, delegate.connectionCoordinator.isDeviceConnected else {
            Logger.session.warning("Cannot start new session - AirPods not connected")
            return
        }

        Logger.session.info("Starting new session")
        _ = sessionStore.startNewSession()
        sessionTimingService.startNewSession()
        sessionStartTime = Date()
        lastPoorPostureUpdate = Date()

        isUserRunningOrWalking = false
        currentActivityStartTime = nil
        delegate.startActivityDetection()

        if let session = sessionStore.currentSession {
            Logger.session.info("Session created")
            #if canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                if isLiveActivityEnabled {
                    liveActivitySyncService.startActivity(
                        sessionId: session.id,
                        avatarAssetName: session.avatarType,
                        sessionStartTime: session.startTime
                    )
                }
            }
            #endif
        }

        if isLiveActivityEnabled {
            liveActivitySyncService.startUpdateTimer { [weak self] in
                guard let self, let del = self.delegate else { return }
                del.updateLiveActivity(force: false)
            }
            delegate.updateLiveActivity(force: true)
        }
    }

    /// Resets all session state and optionally starts a fresh session.
    /// The caller should ensure motion state (pitch/roll/yaw/pipeline) is
    /// also reset via `delegate.resetMotionDisplay()`.
    @MainActor
    func resetSession(shouldStartNew: Bool = true) {
        if sessionStore.currentSession != nil {
            saveCurrentSessionIfNeeded()
        }

        sessionTimingService.resetSession()
        sessionStartTime = .distantPast
        poorPostureStartTime = nil
        accumulatedPoorPostureDuration = 0
        lastPoorPostureUpdate = .distantPast

        delegate?.hapticController.stopAllFeedback()
        delegate?.stopActivityDetection()

        isUserRunningOrWalking = false
        currentActivityStartTime = nil

        if shouldStartNew {
            if delegate?.connectionCoordinator.isDeviceConnected ?? false {
                startNewSession()
            } else {
                Logger.session.warning("Cannot start new session - AirPods not connected")
            }
        } else {
            liveActivitySyncService.stopUpdateTimer()
            liveActivitySyncService.endActivity(immediate: true)
        }
    }

    /// Toggles the pause state. On pause: persists timing and stops motion.
    /// On resume: restarts the motion system.
    @MainActor
    func togglePause() {
        isPaused.toggle()

        guard let delegate = delegate else { return }

        if isPaused {
            // Pause: persist current timing and stop tracking
            if sessionStore.currentSession != nil && sessionStartTime != .distantPast {
                let currentTime = Date()
                if let startTime = poorPostureStartTime {
                    let episodeDuration = currentTime.timeIntervalSince(startTime)
                    accumulatedPoorPostureDuration += episodeDuration
                    poorPostureStartTime = nil
                }
                sessionTimingService.setLastPoorPostureUpdate(currentTime)
                sessionStore.updateCurrentSession(
                    poorPostureDuration: sessionTimingService.poorPostureDuration,
                    activeSessionDuration: sessionTimingService.totalSessionTime,
                    runningWalkingDuration: sessionTimingService.runningWalkingDuration
                )
            }

            delegate.pauseMotionTracking()
            delegate.hapticController.stopAllFeedback()
            delegate.updateLiveActivity(force: false)

            Logger.session.info("Session paused - Score: \(self.sessionTimingService.postureScorePercent)%, Poor: \(self.sessionTimingService.poorPostureDuration), Total: \(self.sessionTimingService.totalSessionTime)")
        } else {
            // Resume: restore timing continuity and restart motion
            if sessionStore.currentSession != nil && sessionStartTime != .distantPast {
                let currentTime = Date()
                sessionStartTime = currentTime.addingTimeInterval(-sessionTimingService.totalSessionTime)
                lastPoorPostureUpdate = currentTime
                #if !targetEnvironment(simulator)
                delegate.startResumeGracePeriod()
                #endif
            }

            delegate.resumeMotionTracking()
            delegate.updateLiveActivity(force: false)

            Logger.session.info("Session resumed - Score: \(self.sessionTimingService.postureScorePercent)%, Poor: \(self.sessionTimingService.poorPostureDuration), Total: \(self.sessionTimingService.totalSessionTime)")
        }
    }

    /// Saves the current session to the store if it has meaningful data.
    @MainActor
    func saveCurrentSessionIfNeeded() {
        guard sessionTimingService.totalSessionTime > 0 && sessionStore.currentSession != nil else { return }

        guard sessionTimingService.totalSessionTime > 10 || sessionTimingService.postureScorePercent > 0 else {
            Logger.session.debug("Skipping session save - No meaningful data collected (duration: \(self.sessionTimingService.totalSessionTime)s, poor posture: \(self.sessionTimingService.postureScorePercent)%)")
            sessionStore.currentSession = nil
            return
        }

        sessionStore.endCurrentSession(
            poorPostureDuration: sessionTimingService.poorPostureDuration,
            activeSessionDuration: sessionTimingService.totalSessionTime,
            runningWalkingDuration: sessionTimingService.runningWalkingDuration
        )

        delegate?.hapticController.resetState()
    }

    // MARK: - Background Update

    /// Updates session timing during background execution.
    @MainActor
    func performBackgroundUpdate() {
        guard
            !isPaused && sessionStore.currentSession != nil && sessionStartTime != .distantPast
        else { return }

        sessionTimingService.performBackgroundUpdate(hasActiveSession: true)

        guard let delegate = delegate else { return }
        delegate.updateLiveActivity(force: false)

        Logger.background.debug("Background update - Session: \(Int(self.sessionTimingService.totalSessionTime))s, Poor: \(Int(self.sessionTimingService.poorPostureDuration))s (\(self.sessionTimingService.postureScorePercent)%)")
    }

    /// Updates session timing during background session updates (the
    /// longer-running background path). Delegates to `sessionTimingService`
    /// for the actual timing math.
    @MainActor
    func updateBackgroundSession() {
        guard let delegate = delegate, delegate.isInBackground else { return }
        guard sessionStore.currentSession != nil else {
            Logger.background.debug("Skipping background session update - no active session")
            delegate.hapticController.cancelCountdownScheduler()
            return
        }
        guard sessionStartTime != .distantPast else { return }

        sessionTimingService.performBackgroundUpdate(hasActiveSession: true)
        lastPoorPostureUpdate = Date()

        delegate.updateLiveActivity(force: false)
    }

    // MARK: - Activity Update

    /// Handles a `CMMotionActivity` update. Forwards to `sessionTimingService`.
    @MainActor
    func handleActivityUpdate(_ isCurrentlyActive: Bool, at time: Date) {
        sessionTimingService.handleActivityUpdate(isCurrentlyActive: isCurrentlyActive, at: time)
        isUserRunningOrWalking = sessionTimingService.isUserRunningOrWalking
        lastPoorPostureUpdate = time
    }
}
