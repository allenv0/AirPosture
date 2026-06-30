import Foundation
@preconcurrency import CoreMotion
import os

// MARK: - Delegate Protocol

/// Actions the health service cannot perform alone because they require
/// access to the parent's `CMHeadphoneMotionManager`, connection state,
/// or motion-update lifecycle.
@MainActor
protocol MotionHealthDelegate: AnyObject {
    var connectionCoordinator: HeadphoneConnectionCoordinator { get }
    var isPaused: Bool { get }
    var isForegroundTransitioning: Bool { get }
    var motionManager: CMHeadphoneMotionManager { get set }

    func startMotionUpdatesInternal()
}

// MARK: - Motion Health Service

/// Owns the motion-health monitoring lifecycle: periodic health checks,
/// motion-silence detection, and `CMHeadphoneMotionManager` restart logic
/// with cooldown and limit tracking.
///
/// `HeadphoneMotionManager` creates and owns this service and delegates
/// health-check actions to it. The service uses a delegate to request
/// hardware-level actions (restart motion, check connection state) without
/// coupling to the full manager interface.
@MainActor
final class MotionHealthService {

    // MARK: - Delegate

    weak var delegate: (any MotionHealthDelegate)?

    // MARK: - Restart Tracking

    private var motionManagerRestartCount: Int = 0
    private let maxMotionManagerRestarts: Int = MotionConstants.maxMotionManagerRestarts
    private var lastMotionManagerRestart: Date = Date.distantPast
    private let motionManagerRestartCooldown: TimeInterval = MotionConstants.motionManagerRestartCooldown

    // MARK: - Health Check Timer

    private var healthCheckTimer: Timer?
    private var healthCheckSource: DispatchSourceTimer?
    private let motionHealthCheckInterval: TimeInterval = MotionConstants.healthCheckInterval
    private let maxMotionSilenceDuration: TimeInterval = MotionConstants.maxSilenceDuration

    // MARK: - Last Successful Motion

    private(set) var lastSuccessfulMotionUpdate: Date = Date.distantPast

    // MARK: - Timer Source Utility

    private func cancelTimerSourceSafely(_ source: inout DispatchSourceTimer?) {
        SystemUtilities.cancelTimerSourceSafely(&source)
    }

    // MARK: - Public API

    /// Call this whenever the manager processes a valid motion sample or
    /// resets its connection state, so the health check can detect silence.
    func noteMotionUpdate(at time: Date) {
        lastSuccessfulMotionUpdate = time
    }

    /// Resets the restart counter. Called on a fresh start.
    func resetRestartCount() {
        motionManagerRestartCount = 0
    }

    /// Starts the periodic health-check timer. The delegate must be set
    /// before calling this.
    func startHealthCheck() {
        Logger.motion.debug("Starting motion health check")

        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        healthCheckSource?.cancel()
        healthCheckSource = nil

        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        source.schedule(
            deadline: .now() + motionHealthCheckInterval,
            repeating: motionHealthCheckInterval)
        source.setEventHandler { [weak self] in
            guard let self = self, !(self.delegate?.isForegroundTransitioning ?? true) else { return }
            // Use safe main actor dispatch to avoid deadlocks
            if Thread.isMainThread {
                self.performHealthCheck()
            } else {
                Task { @MainActor in
                    self.performHealthCheck()
                }
            }
        }
        healthCheckSource = source
        source.resume()
    }

    /// Stops the health-check timer and resets restart tracking.
    func cleanup() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        healthCheckSource?.cancel()
        healthCheckSource = nil
    }

    // MARK: - Health Check

    private func performHealthCheck() {
        guard let delegate = delegate else { return }

        let currentTime = Date()
        let timeSinceLastMotion = currentTime.timeIntervalSince(lastSuccessfulMotionUpdate)

        // Check if we haven't received motion data for too long
        if timeSinceLastMotion > maxMotionSilenceDuration
            && delegate.connectionCoordinator.isDeviceConnected
            && !delegate.isPaused
            && !delegate.connectionCoordinator.reconnecting
        {
            if motionManagerRestartCount < maxMotionManagerRestarts {
                Logger.motion.warning("Motion silence detected for \(timeSinceLastMotion)s - attempting recovery")
                handleMotionSilence()
            } else {
                Logger.motion.warning("Motion silence detected but restart limit reached. Skipping recovery attempt")
            }
        }

        // Check if motion manager is still active
        if delegate.connectionCoordinator.isDeviceConnected
            && !delegate.motionManager.isDeviceMotionActive
            && !delegate.isPaused
            && !delegate.connectionCoordinator.reconnecting
        {
            if motionManagerRestartCount < maxMotionManagerRestarts {
                Logger.motion.warning("Motion manager inactive but should be connected - restarting")
                restartMotionManager()
            } else {
                Logger.motion.warning("Motion manager inactive but restart limit reached. Skipping restart")
            }
        }
    }

    // MARK: - Motion Silence / Restart

    private func handleMotionSilence() {
        guard let delegate = delegate else { return }
        guard !delegate.connectionCoordinator.reconnecting else { return }

        guard motionManagerRestartCount < maxMotionManagerRestarts else {
            Logger.motion.warning("Motion silence detected but restart limit reached. Cannot recover")
            return
        }

        Logger.motion.debug("Handling motion silence")

        // Try to restart motion updates
        restartMotionManager()
    }

    /// Restarts the `CMHeadphoneMotionManager` with cooldown and limit
    /// enforcement. Creates a fresh instance and delegates to the parent
    /// to start motion updates.
    func restartMotionManager() {
        guard let delegate = delegate else { return }

        let currentTime = Date()
        let timeSinceLastRestart = currentTime.timeIntervalSince(lastMotionManagerRestart)

        // Check cooldown period
        if timeSinceLastRestart < motionManagerRestartCooldown {
            Logger.motion.debug("Motion manager restart on cooldown. \(Int(self.motionManagerRestartCooldown - timeSinceLastRestart))s remaining")
            return
        }

        // Check restart count limit
        if motionManagerRestartCount >= maxMotionManagerRestarts {
            Logger.motion.error("Maximum motion manager restarts reached (\(self.maxMotionManagerRestarts)). Stopping restart attempts")
            return
        }

        Logger.motion.info("Restarting motion manager... (attempt \(self.motionManagerRestartCount + 1)/\(self.maxMotionManagerRestarts))")

        // Update restart tracking
        motionManagerRestartCount += 1
        lastMotionManagerRestart = currentTime

        // Stop current motion updates
        delegate.motionManager.stopDeviceMotionUpdates()

        // Create new motion manager instance
        delegate.motionManager = CMHeadphoneMotionManager()

        // Wait a moment then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.delegate?.startMotionUpdatesInternal()
        }
    }
}
