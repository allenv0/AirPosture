import AVFoundation
import Combine
@preconcurrency import CoreMotion
import Foundation
import Observation
import os
import SwiftUI
import UserNotifications

#if os(iOS)
    import UIKit
    import ActivityKit
#endif
#if os(macOS)
    import AppKit
#endif

@Observable
@MainActor
final class HeadphoneMotionManager: CalibrationDependencies, HapticControllerDependencies, BackgroundMotionProvider, ConnectionCoordinatorDelegate, SessionControllerDelegate, MotionHealthDelegate {
    static let shared = HeadphoneMotionManager()

    // MARK: - Published Properties
    private(set) var pitch: Double = 0.0
    private(set) var roll: Double = 0.0
    private(set) var yaw: Double = 0.0
    private(set) var postureState: PostureState = .good(postureDuration: 0)
    private(set) var pitchHistory: [Double] = []
    private(set) var poorPostureDuration: TimeInterval = 0
    private(set) var postureScorePercent: Int = 0
    var isPaused: Bool { sessionController.isPaused }
    private(set) var availableDevices: [String] = []

    // MARK: - Connection State (mirrored from HeadphoneConnectionCoordinator)
    var isDeviceConnected: Bool { connectionCoordinator.isDeviceConnected }
    var connectionStatus: String { connectionCoordinator.connectionStatus }
    var connectedDeviceName: String { connectionCoordinator.connectedDeviceName }
    var connectionLostTime: Date? { connectionCoordinator.connectionLostTime }
    var isInGracePeriod: Bool { connectionCoordinator.isInGracePeriod }
    var sessionPaused: Bool { connectionCoordinator.sessionPaused }
    var showConnectionLostAlert: Bool {
        get { connectionCoordinator.showConnectionLostAlert }
        set { connectionCoordinator.showConnectionLostAlert = newValue }
    }
    var connectionMethod: HeadphoneConnectionCoordinator.ConnectionMethod { connectionCoordinator.connectionMethod }
    var airPodsModel: AirPodsModel { connectionCoordinator.airPodsModel }
    var hasMotionCapability: Bool { connectionCoordinator.hasMotionCapability }
    var hasGyroscope: Bool { connectionCoordinator.hasGyroscope }
    var hardwareDetectionSuccessful: Bool { connectionCoordinator.hardwareDetectionSuccessful }

    // MARK: - Warning Countdown Properties
    private(set) var isInWarningCountdown: Bool = false
    private(set) var warningCountdownSeconds: Int = 0

    // MARK: - Recovery Countdown Properties
    private(set) var isInRecoveryCountdown: Bool = false
    private(set) var recoveryCountdownSeconds: Int = 0

    // MARK: - Haptic Feedback Controller
    let hapticController = HapticFeedbackController()

    // MARK: - HapticControllerDependencies Conformance
    func sendPostureWarningNotification() { notificationManager.sendPostureWarningNotification() }
    func sendHapticStartNotification() { notificationManager.sendHapticStartNotification() }

    // MARK: - Motion System State Properties (Phase 1)
    private(set) var motionSystemState: MotionSystemState = .disconnected
    private(set) var isMotionSystemInitializing: Bool = false

    // MARK: - Live Activity Configuration
    private let isLiveActivityEnabled = true // ✅ ENABLED FOR PRODUCTION

    // MARK: - Dynamic Threshold Properties
    var poorPostureThreshold: Double {
        didSet {
            UserDefaults.standard.set(poorPostureThreshold, forKey: UserDefaultsKeys.poorPostureThreshold)
            Logger.motion.info("Posture threshold updated to: \(self.poorPostureThreshold)°")
        }
    }

    // Normal AirPods angle offset (for users with unique ear shapes)
    var normalAirPodsAngle: Double {
        didSet {
            UserDefaults.standard.set(normalAirPodsAngle, forKey: UserDefaultsKeys.normalAirPodsAngle)
            Logger.motion.info("Normal AirPods angle updated to: \(self.normalAirPodsAngle)°")
        }
    }

    // MARK: - Advanced Timer Settings (Default: OFF for better stability)
    var isHapticFeedbackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHapticFeedbackEnabled, forKey: UserDefaultsKeys.isHapticFeedbackEnabled)
            Logger.haptics.info("Haptic feedback enabled: \(self.isHapticFeedbackEnabled)")

            // If haptic feedback is disabled while active, stop it immediately
            if !isHapticFeedbackEnabled {
                hapticController.stopAllFeedback()
            }
        }
    }

    var isBadPostureHapticEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBadPostureHapticEnabled, forKey: UserDefaultsKeys.isBadPostureHapticEnabled)
            Logger.haptics.info("Bad posture haptic feedback enabled: \(self.isBadPostureHapticEnabled)")
        }
    }


    var isWarningCountdownEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                isWarningCountdownEnabled, forKey: UserDefaultsKeys.isWarningCountdownEnabled)
            Logger.haptics.info("Warning countdown enabled: \(self.isWarningCountdownEnabled)")

            // If countdown is disabled while active, stop it immediately
            if !isWarningCountdownEnabled && isInWarningCountdown {
                hapticController.stopWarningCountdown()
            }
        }
    }

    var isRecoveryCountdownEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                isRecoveryCountdownEnabled, forKey: UserDefaultsKeys.isRecoveryCountdownEnabled)
            Logger.haptics.info("Recovery countdown enabled: \(self.isRecoveryCountdownEnabled)")

            // If countdown is disabled while active, stop it immediately
            if !isRecoveryCountdownEnabled && isInRecoveryCountdown {
                hapticController.stopRecoveryCountdown()
            }
        }
    }

    var realtimeNotificationDelay: TimeInterval {
        didSet {
            UserDefaults.standard.set(
                realtimeNotificationDelay, forKey: UserDefaultsKeys.realtimeNotificationDelay)
            Logger.notifications.info("Real-time notification delay updated to: \(self.realtimeNotificationDelay)s")
            hapticController.badPostureNoticeThreshold = realtimeNotificationDelay
        }
    }

    // MARK: - Calibration Service
    let calibrationService = CalibrationService()
    let sessionTimingService = SessionTimingService(sessionStore: SessionStore.shared)
    let postureEvaluationService = PostureEvaluationService()
    let liveActivitySyncService = LiveActivitySyncService()

    // MARK: - Connection Coordinator
    /// Owns connection lifecycle state and logic (detection, reconnection,
    /// monitoring, grace-period handling). The manager mirrors connection
    /// state from the coordinator via computed properties. See
    /// `HeadphoneConnectionCoordinator`.
    let connectionCoordinator = HeadphoneConnectionCoordinator()

    // MARK: - Session Controller
    /// Owns tracking-session lifecycle orchestration (start, reset, pause,
    /// save). Delegates hardware actions (motion start/stop, activity
    /// detection) back to the manager via `SessionControllerDelegate`.
    let sessionController = PostureTrackingSessionController()

    // MARK: - Motion Pipeline Service
    /// Owns motion-sample validation, low-pass filtering, and pitch history.
    /// The manager mirrors its outputs onto its own observable state so UI
    /// call sites and public APIs (e.g. `pitchHistory`, `lowPassFilter`) behave
    /// exactly as before. See `HeadphoneMotionPipeline`.
    let motionPipeline = HeadphoneMotionPipeline()

    // MARK: - Motion Health Service
    /// Owns periodic health-check timers, motion-silence detection, and
    /// `CMHeadphoneMotionManager` restart logic with cooldown enforcement.
    /// See `MotionHealthService`.
    let healthService = MotionHealthService()

    var currentPitch: Double { pitch }
    var isSimulatorMode: Bool { isSimulator }
    var isMotionActive: Bool { motionManager.isDeviceMotionActive }
    var isMotionAvailable: Bool { motionManager.isDeviceMotionAvailable }
    var hasActiveSession: Bool { sessionStore.currentSession != nil }

    func startMotionUpdates() {
        startMotionUpdatesInternal()
    }

    func stopDeviceMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    func setPitch(_ value: Double) {
        pitch = value
    }

    func applyThreshold(_ threshold: Double) {
        poorPostureThreshold = threshold
    }

    // MARK: - Private Properties
    var motionManager = CMHeadphoneMotionManager()
    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()
    private var cancellables = Set<AnyCancellable>()
    private var poorPostureStartTime: Date?
    private var sessionStartTime: Date = Date.distantPast
    private var lastActivityUpdateTime: Date = Date.distantPast
    private var currentActivityStartTime: Date?
    private var runningWalkingStartTime: Date?
    private(set) var totalSessionTime: TimeInterval = 0

    // MARK: - Activity Detection Properties
    private(set) var runningWalkingDuration: TimeInterval = 0
    private(set) var isUserRunningOrWalking: Bool = false
    private let updateQueue = DispatchQueue(
        label: "com.necksync.motionUpdates", qos: .userInteractive)
    private let motionUpdateInterval: TimeInterval = MotionConstants.motionUpdateInterval
    private var lastPoorPostureUpdate: Date = Date.distantPast
    private var backgroundTimer: Timer?
    private(set) var isInBackground: Bool = false
    var lastKnownPoorPostureState: Bool = false
    private var lastMotionUpdateTime: Date = Date.distantPast
    let sessionStore = SessionStore.shared
    private var updateCounter: Int = 0
    var isForegroundTransitioning: Bool = false
    var liveActivityUpdateTimer: AnyCancellable?

    // MARK: - Motion Processing Off-Main (Coalesced)
    private let motionProcessingQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.necksync.motionProcessing"
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private var motionCoalesceSource: DispatchSourceTimer?
    private let uiMotionDispatchInterval: TimeInterval = 1.0 / 15.0  // 15 Hz UI update cap

    // Thread-safe buffer for latest motion sample (coalesced)
    private final class MotionSampleBuffer: @unchecked Sendable {
        private let queue = DispatchQueue(label: "com.necksync.motionSampleBuffer")
        private var latest: CMDeviceMotion?

        func set(_ motion: CMDeviceMotion) {
            queue.async {
                self.latest = motion
            }
        }

        func take() -> CMDeviceMotion? {
            var result: CMDeviceMotion?
            queue.sync {
                result = self.latest
                self.latest = nil
            }
            return result
        }
    }
    private let motionSampleBuffer = MotionSampleBuffer()

    // Safe cancellation utility
    private func cancelTimerSourceSafely(_ source: inout DispatchSourceTimer?) {
        SystemUtilities.cancelTimerSourceSafely(&source)
    }

    // MARK: - Public Accessors
    var currentSessionStore: SessionStore {
        return sessionStore
    }

    // MARK: - Background Update Method
    func performBackgroundUpdate() {
        sessionController.performBackgroundUpdate()
    }

    // MARK: - Enhanced Stability Properties

    // MARK: - Background Task Managers
    private let backgroundTaskManager = BackgroundTaskManager.shared
    private let audioBackgroundManager = AudioBackgroundManager.shared

    private let notificationManager = NotificationManager.shared

    #if targetEnvironment(simulator)
        private let isSimulator = true
    #else
        private let isSimulator = false
    #endif
    #if !targetEnvironment(simulator)
        private var resumeGracePeriodTimer: Timer?
        private var isInResumeGracePeriod: Bool = false
    #endif



    // MARK: - Initialization
    private init() {
        // Initialize threshold from UserDefaults
        let savedThreshold = UserDefaults.standard.object(forKey: UserDefaultsKeys.poorPostureThreshold) as? Double
        self.poorPostureThreshold = savedThreshold ?? MotionConstants.poorPostureThreshold

        // Initialize normal AirPods angle offset
        let savedNormalAngle = UserDefaults.standard.object(forKey: UserDefaultsKeys.normalAirPodsAngle) as? Double
        self.normalAirPodsAngle = savedNormalAngle ?? MotionConstants.normalAirPodsAngle

        // Initialize advanced timer settings from UserDefaults (default: ENABLED)
        let savedHapticSetting =
            UserDefaults.standard.object(forKey: UserDefaultsKeys.isHapticFeedbackEnabled) as? Bool
        self.isHapticFeedbackEnabled = savedHapticSetting ?? true

        let savedBadPostureHapticSetting =
            UserDefaults.standard.object(forKey: UserDefaultsKeys.isBadPostureHapticEnabled) as? Bool
        self.isBadPostureHapticEnabled = savedBadPostureHapticSetting ?? false

        let savedWarningCountdownSetting =
            UserDefaults.standard.object(forKey: UserDefaultsKeys.isWarningCountdownEnabled) as? Bool
        self.isWarningCountdownEnabled = savedWarningCountdownSetting ?? false

        let savedRecoveryCountdownSetting =
            UserDefaults.standard.object(forKey: UserDefaultsKeys.isRecoveryCountdownEnabled) as? Bool
        self.isRecoveryCountdownEnabled = savedRecoveryCountdownSetting ?? false

        let savedRealtimeDelay =
            UserDefaults.standard.object(forKey: UserDefaultsKeys.realtimeNotificationDelay) as? Double
        self.realtimeNotificationDelay = savedRealtimeDelay ?? MotionConstants.defaultRealtimeNotificationDelay


        // Shared instance is now automatically created via singleton pattern

        // Both simulator and real device now behave the same way
        // User must manually start sessions by clicking the "Start" button
        // App lifecycle notifications are handled by UnifiedBackgroundCoordinator

        if isSimulator {
            Logger.motion.info("Simulator mode: Ready for manual session start")
            connectionCoordinator.markDisconnected(status: "Simulator ready - tap Start to begin")
        }

        // Configure background task managers for extended background tracking
        // FIXED: Use safe Main Actor to prevent deadlocks
        Self.safeMainActor {
            self.backgroundTaskManager.configure(with: self)

            UnifiedBackgroundCoordinator.shared.configure(with: self)
        }

        // Start real-time connection monitoring for immediate UI updates
        connectionCoordinator.startConnectionMonitoring()
        connectionCoordinator.delegate = self
        sessionController.delegate = self
        healthService.delegate = self

        // Setup activity detection
        setupActivityDetection()

        // Configure calibration service
        calibrationService.configure(dependencies: self)

        // Configure haptic controller
        hapticController.configure(dependencies: self)
        hapticController.badPostureNoticeThreshold = realtimeNotificationDelay
    }

    // MARK: - Activity Detection Setup
    private func setupActivityDetection() {
        // Check if activity tracking is available
        guard CMMotionActivityManager.isActivityAvailable() else {
            Logger.motion.warning("Activity detection not available on this device")
            return
        }

        guard CMPedometer.isStepCountingAvailable() else {
            Logger.motion.warning("Step counting not available on this device")
            return
        }

        Logger.motion.info("Activity detection initialized successfully")
    }

    // MARK: - Activity Detection Methods
    func startActivityDetection() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        // Create an operation queue for activity updates
        let activityQueue = OperationQueue()
        activityQueue.maxConcurrentOperationCount = 1
        activityQueue.name = "com.airposture.activityUpdates"

        // Start real-time activity updates
        activityManager.startActivityUpdates(to: activityQueue) { [weak self] (activity) in
            guard let self = self, let activity = activity else { return }

            Task { @MainActor in
                self.handleActivityUpdate(activity)
            }
        }
    }

    func stopActivityDetection() {
        activityManager.stopActivityUpdates()
        isUserRunningOrWalking = false
        Logger.motion.info("Activity detection stopped")
    }

    private func handleActivityUpdate(_ activity: CMMotionActivity) {
        let isCurrentlyActive = activity.walking || activity.running || activity.cycling
        sessionController.handleActivityUpdate(isCurrentlyActive, at: Date())
    }

    // MARK: - Memory Reporting Methods
    func getMemoryReport() -> String {
        let usage = SystemUtilities.getCurrentMemoryUsage()
        return """
            HeadphoneMotionManager Memory Report
            =====================================
            Pitch history: \(pitchHistory.count) entries
            Current memory: \(SystemUtilities.formatBytes(Int64(usage.used)))
            """
    }

    func performMemoryCleanup() {
        if pitchHistory.count > 10 {
            let keepCount = max(10, pitchHistory.count / 2)
            pitchHistory = Array(pitchHistory.suffix(keepCount))
        }
    }

    deinit {
        // Main cleanup runs through explicit lifecycle methods (stop/reset/cleanupAllTimersAndConnections).
        // Keep deinit side effects minimal because deinit is nonisolated under strict concurrency.
        Logger.motion.debug("HeadphoneMotionManager deinit")
    }

    // MARK: - Audio Session Management
    @MainActor
    private func setupHighQualityAudioSession() {
        #if os(iOS)
            do {
                let audioSession = AVAudioSession.sharedInstance()

                // FIXED: Use .playback category to maintain high-quality A2DP audio for Spotify
                // This prevents AirPods from switching to hands-free mode during motion tracking
                try audioSession.setCategory(
                    .playback, mode: .default,
                    options: [
                        .allowBluetooth,
                        .allowBluetoothA2DP,  // Ensure high-quality stereo audio
                        .mixWithOthers,  // Allow Spotify and other apps to play simultaneously at full volume
                    ])

                try audioSession.setActive(true)
                Logger.motion.info("High-quality audio session configured")

            } catch {
                Logger.motion.error("Failed to setup high-quality audio session: \(error)")
            }
        #endif
    }

    // MARK: - Public Methods
    @MainActor
    func start() {
        if isSimulator {
            // Simulator: Start mock motion data when user actually starts a session
            startSimulatorMockData()
            return
        }

        Logger.motion.info("Starting HeadphoneMotionManager")

        // FIXED: Ensure high-quality audio session before starting motion tracking
        setupHighQualityAudioSession()

        // Enable background audio for extended tracking
        audioBackgroundManager.enableBackgroundAudio()

        // Reset retry counter on fresh start
        connectionCoordinator.resetRetryState()
        healthService.resetRestartCount()

        // Clean up any existing state
        cleanupAllTimersAndConnections()

        // Stop any existing motion updates first to prevent multiple handlers
        if motionManager.isDeviceMotionActive {
            Logger.motion.debug("Stopping existing motion updates")
            motionManager.stopDeviceMotionUpdates()
        }

        guard motionManager.isDeviceMotionAvailable else {
            connectionCoordinator.markDisconnected(status: "AirPods motion not available")
            Logger.motion.warning("Device motion not available, will retry")

            Task { @MainActor in
                await connectionCoordinator.attemptConnection()
            }
            return
        }

        Logger.motion.info("Device motion available, starting updates")
        healthService.noteMotionUpdate(at: Date())

        // Start device motion updates with single handler
        startMotionUpdatesInternal()

        // Setup periodic updates
        setupPeriodicUpdates()

        // Start health monitoring
        healthService.startHealthCheck()
    }

    @MainActor
    private var simulatorMockTimer: Timer?

    @MainActor
    private func startSimulatorMockData() {
        Logger.motion.info("Starting simulator mock data")

        connectionCoordinator.confirmDeviceConnected(deviceName: "Simulator AirPods")

        self.pitch = 0.0
        self.roll = 0.0
        self.yaw = 0.0
        self.postureState = .good(postureDuration: 0)
        self.pitchHistory = []
        // The simulator mock bypasses the pipeline; reset it so a later switch
        // to real motion updates starts from a clean, zeroed base.
        self.motionPipeline.reset()

        simulatorMockTimer?.invalidate()
        simulatorMockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }

            Self.safeMainActor {
                guard self.sessionStore.currentSession != nil else {
                    self.pitch = 0.0
                    self.roll = 0.0
                    self.yaw = 0.0
                    return
                }

                let time = Date().timeIntervalSince1970
                let simulatedPitch = sin(time / 3.0) * 35.0 - 5.0

                self.pitch = simulatedPitch
                self.roll = cos(time / 7.0) * 10.0
                self.yaw = sin(time / 9.0) * 15.0

                self.pitchHistory.append(simulatedPitch)
                if self.pitchHistory.count > MotionConstants.maxDataPoints { self.pitchHistory.removeFirst() }

                self.updatePostureState(newPitch: simulatedPitch)
                self.updateSessionTimers(newPitch: simulatedPitch)

                    Logger.motion.debug("Simulator - Pitch: \(String(format: "%.1f", simulatedPitch))°, Poor Posture: \(self.postureScorePercent)%")
            }
        }
    }

    @MainActor
    func startMotionUpdatesInternal() {
        Logger.motion.info("Starting motion updates")

        // Update state
        motionSystemState = .initializing

        // Ensure we're not already running motion updates
        if motionManager.isDeviceMotionActive {
            Logger.motion.warning("Motion updates already active, stopping first")
            motionManager.stopDeviceMotionUpdates()
        }

        // Start motion updates on a dedicated background OperationQueue
        motionManager.startDeviceMotionUpdates(to: motionProcessingQueue) {
            [weak self] motion, error in
            guard let self = self else { return }

            if let error = error {
                // FIXED: Use safe Main Actor to prevent deadlocks
                Self.safeMainActor {
                    self.handleMotionError(error)
                }
                return
            }

            guard let motion = motion else {
                // FIXED: Use safe Main Actor to prevent deadlocks
                Self.safeMainActor {
                    self.handleNoMotionData()
                }
                return
            }

            // Coalesce samples off-main; UI will consume at capped rate
            self.motionSampleBuffer.set(motion)
        }

        // Start (or restart) coalesced UI dispatcher
        motionCoalesceSource?.cancel()
        let source = DispatchSource.makeTimerSource(
            queue: DispatchQueue.global(qos: .userInitiated))
        source.schedule(
            deadline: .now() + uiMotionDispatchInterval, repeating: uiMotionDispatchInterval)
        source.setEventHandler { [weak self] in
            guard let self = self, !self.isForegroundTransitioning else { return }
            if let sample = self.motionSampleBuffer.take() {
                // FIXED: Use safe Main Actor to prevent deadlocks
                Self.safeMainActor {
                    self.handleSuccessfulMotionData(sample)
                }
            }
        }
        motionCoalesceSource = source
        source.resume()
    }

    private func handleMotionError(_ error: Error) {
        Logger.motion.error("Motion error: \(error.localizedDescription)")
        motionSystemState = .error(error.localizedDescription)
        motionSystemStateDidChange()

        // Check if this is a recoverable error
        let errorCode = (error as NSError).code
        if errorCode == -1 || errorCode == -2 {
            Logger.motion.warning("Attempting to recover from motion error")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.healthService.restartMotionManager()
            }
        } else {
            connectionCoordinator.handleConnectionError(error)
        }
    }

    private func handleNoMotionData() {
        Logger.motion.warning("No motion data received")
        motionSystemState = .reconnecting
        motionSystemStateDidChange()
        connectionCoordinator.markDisconnected(status: "No motion data from AirPods")

        // Try to recover from no motion data
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.connectionCoordinator.isDeviceConnected == false && self?.isPaused == false {
                self?.healthService.restartMotionManager()
            }
        }
    }

    private func handleSuccessfulMotionData(_ motion: CMDeviceMotion) {
        let shouldForceLiveActivitySync = motionSystemState != .connected

        // Update connection state
        if motionSystemState != .connected {
            Logger.motion.info("AirPods motion detected")
            motionSystemState = .connected
            motionSystemStateDidChange()
            isMotionSystemInitializing = false
            onMotionSystemReady()
        }

        if !connectionCoordinator.isDeviceConnected {
            connectionCoordinator.confirmDeviceConnected()
            lastMotionUpdateTime = Date()
        }

        // Process motion data
        processMotionData(motion)

        if shouldForceLiveActivitySync {
            updateLiveActivity(force: true)
        }
    }

    private func onMotionSystemReady() {
        Logger.motion.info("Motion system ready")
    }

    @MainActor
    func stop() {
        if isSimulator {
            simulatorMockTimer?.invalidate()
            simulatorMockTimer = nil
            connectionCoordinator.markDisconnected(status: "Simulator ready - tap Start to begin")
            pitch = 0.0
            roll = 0.0
            yaw = 0.0
            pitchHistory = []
            Logger.motion.info("Simulator stopped")
            return
        }
        motionManager.stopDeviceMotionUpdates()
        cancellables.removeAll()
        liveActivityUpdateTimer?.cancel()
        cancelTimerSourceSafely(&motionCoalesceSource)
        healthService.cleanup()
        connectionCoordinator.cleanupConnectionTimers()
        hapticController.cancelCountdownScheduler()
        connectionCoordinator.markDisconnected(status: "Stopped")

        // Only save session if it has meaningful data
        if sessionController.sessionTimingService.totalSessionTime > 10 || sessionController.sessionTimingService.postureScorePercent > 0 {
            sessionController.resetSession(shouldStartNew: false)
        } else {
            sessionController.sessionStore.currentSession = nil
        }

        sessionController.saveCurrentSessionIfNeeded()

        // Disable background audio when stopping
        audioBackgroundManager.disableBackgroundAudio()

        hapticController.resetState()

        sessionController.liveActivitySyncService.endActivity(immediate: true)
        sessionController.liveActivitySyncService.stopUpdateTimer()

        connectionCoordinator.resetToDisconnected()
    }

    @MainActor
    func restart() {
        if isSimulator {
            // Simulator: Do nothing
            return
        }

        Logger.motion.info("Restarting HeadphoneMotionManager")

        cleanupAllTimersAndConnections()
        connectionCoordinator.cleanupConnectionTimers()

        // Force a clean state — sessionController handles the session lifecycle
        sessionController.resetSession(shouldStartNew: true)

        // Create a new motion manager instance to ensure fresh state
        motionManager = CMHeadphoneMotionManager()

        // Delegate the connection attempt to the coordinator
        Task { @MainActor in
            await connectionCoordinator.attemptConnection()
        }
    }





    @MainActor
    private func setupPeriodicUpdates() {
        // Clear any existing timers
        cancellables.removeAll()

        // Setup a much less aggressive device status check (every 5 seconds)
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkDeviceStatus()
            }
            .store(in: &cancellables)

        Logger.motion.info("Periodic updates configured (5s interval)")
    }

    @MainActor
    func resetSession(shouldStartNew: Bool = true) {
        resetMotionDisplay()
        sessionController.resetSession(shouldStartNew: shouldStartNew)
        // Initialize the manager's own SessionTimingService instance so that
        // processMotionData can compute the posture score. The controller has
        // its own separate service instance.
        if shouldStartNew {
            sessionTimingService.startNewSession()
        }
    }

    func checkForAirPodsImmediate() -> Bool {
        connectionCoordinator.checkForAirPodsImmediate()
    }


    @MainActor
    func togglePause() {
        sessionController.togglePause()
        // Mirror isPaused state from the session controller
        // (the controller's togglePause sets its own isPaused)
    }

    @MainActor
    func startNewSession() {
        sessionController.startNewSession()
        // The manager has its own SessionTimingService instance for motion-data
        // mirroring (processMotionData), which must be started independently.
        sessionTimingService.startNewSession()
    }

    @MainActor
    func updateLiveActivity(force: Bool = false) {
        guard let currentSession = sessionStore.currentSession, isDeviceConnected, isLiveActivityEnabled else { return }
        guard force || !isForegroundTransitioning else { return }

        let adjustedPitch = pitch - normalAirPodsAngle
        let status: PostureStatus =
            isInBackground
            ? (lastKnownPoorPostureState ? .poor : .good)
            : ((adjustedPitch < poorPostureThreshold) ? .poor : .good)

        liveActivitySyncService.updateActivity(
            sessionId: currentSession.id,
            scorePercent: postureScorePercent,
            status: status,
            calibratedTilt: adjustedPitch,
            lean: roll,
            elapsedSeconds: Int(totalSessionTime.rounded(.down)),
            isPaused: isPaused,
            force: force
        )
    }



    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    @MainActor
    func forceCheckAirPodsConnection() {
        guard !isSimulator else { return }
        connectionCoordinator.forceCheckAirPodsConnection()
    }



    @MainActor
    func checkConnectionStatusForUI() {
        connectionCoordinator.checkConnectionStatusForUI()
    }







    @MainActor
    func saveCurrentSessionIfNeeded() {
        sessionController.saveCurrentSessionIfNeeded()
    }

    @MainActor
    func dismissConnectionAlert() {
        connectionCoordinator.dismissConnectionAlert()
    }

    // MARK: - Motion System Lifecycle Methods (Phase 1)

    private func initializeMotionSystem() {
        Logger.motion.info("Initializing motion system")
        motionSystemState = .initializing
        isMotionSystemInitializing = true

        // Use existing startMotionUpdates logic
        startMotionUpdatesInternal()
    }

    private func reinitializeMotionSystemAsync() {
        Logger.motion.info("Starting async motion system reinitialization")
        motionSystemState = .reconnecting
        isMotionSystemInitializing = true

        motionManager.stopDeviceMotionUpdates()

        // Brief delay to allow hardware cleanup without blocking a thread.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startMotionUpdatesInternal()
            self?.isMotionSystemInitializing = false
            Logger.motion.info("Motion system reinitialization completed")
        }
    }

    private func motionSystemStateDidChange() {
        updateConnectionStatusProgressive()
    }

    private func updateConnectionStatusProgressive() {
        switch motionSystemState {
        case .disconnected:
            connectionCoordinator.markDisconnected(status: "Connect AirPods and tap 'New Session'")
        case .initializing:
            connectionCoordinator.markDisconnected(status: "Initializing AirPods connection...")
        case .reconnecting:
            connectionCoordinator.markDisconnected(status: "Reconnecting AirPods...")
        case .connected:
            connectionCoordinator.markDisconnected(status: "AirPods connected")
        case .error(let message):
            connectionCoordinator.markDisconnected(status: "Connection error: \(message)")
        }
    }

    // MARK: - Private Methods

    // MARK: - Threading Safety
    /// FIXED: Safe Main Actor helper to prevent deadlocks
    private static func safeMainActor(operation: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            operation()
        } else {
            Task { @MainActor in
                operation()
            }
        }
    }

    func processMotionData(_ motion: CMDeviceMotion) {
        // Derive validated, filtered pitch/roll/yaw and append pitch history via
        // the motion pipeline service. Returns nil (and leaves history untouched)
        // for any sample that fails validation.
        guard let sample = motionPipeline.process(motion, previousPitch: pitch) else { return }

        let newPitch = sample.pitch
        let currentTime = sample.timestamp

        pitch = newPitch
        roll = sample.roll
        yaw = sample.yaw
        // Mirror the pipeline's bounded pitch history so existing UI call sites
        // and tests that read `pitchHistory` behave exactly as before.
        pitchHistory = motionPipeline.pitchHistory
        if !connectionCoordinator.isDeviceConnected {
            connectionCoordinator.confirmDeviceConnected()
        }
        lastMotionUpdateTime = currentTime
        healthService.noteMotionUpdate(at: currentTime)

        connectionCoordinator.resetRetryState()

        postureEvaluationService.evaluatePosture(newPitch: newPitch, sessionStartTime: sessionStartTime, hapticController: hapticController)
        postureState = postureEvaluationService.postureState
        sessionTimingService.updateSessionTimers(adjustedPitch: newPitch - normalAirPodsAngle, threshold: poorPostureThreshold, hasActiveSession: sessionStore.currentSession != nil)
        totalSessionTime = sessionTimingService.totalSessionTime
        poorPostureDuration = sessionTimingService.poorPostureDuration
        postureScorePercent = sessionTimingService.postureScorePercent
        runningWalkingDuration = sessionTimingService.runningWalkingDuration

        updateCounter += 1
        if updateCounter % 60 == 0 {
            Logger.motion.debug("Motion update - Pitch: \(String(format: "%.1f", newPitch))°, Score: \(self.postureScorePercent)%")
        }
    }

    private func updatePostureState(newPitch: Double) {
        let currentTime = Date()
        let _ = postureState  // Keep for potential future use

        // Apply normal AirPods angle offset
        let adjustedPitch = newPitch - normalAirPodsAngle

        let isPoorPosture = adjustedPitch < poorPostureThreshold
        let wasPoorPosture = hapticController.lastCircleIsRed()

        // Update posture state (keep existing logic for UI)
        if newPitch > MotionConstants.warningThreshold {
            let duration = postureState.lastGoodStateTime.distance(to: currentTime)
            postureState =
                duration > 2.0
                ? .alert(pitch: newPitch, duration: duration)
                : .warning(pitch: newPitch, timeAboveThreshold: duration)
        } else {
            // Only calculate duration based on session start time if session has actually started
            let duration =
                sessionStartTime != Date.distantPast
                ? currentTime.timeIntervalSince(sessionStartTime) : 0
            postureState = .good(postureDuration: duration)
        }

        hapticController.handleCircleColorTransition(fromPoorPosture: wasPoorPosture, toPoorPosture: isPoorPosture, at: currentTime)
        hapticController.updateLastCircleColor(isPoorPosture: isPoorPosture)
    }

    // MARK: - Enhanced Stability Methods
    @MainActor
    private func cleanupAllTimersAndConnections() {
        Logger.motion.debug("Cleaning up all timers and connections")

        healthService.cleanup()

        backgroundTimer?.invalidate()
        backgroundTimer = nil
        cancelTimerSourceSafely(&motionCoalesceSource)
        connectionCoordinator.cleanupConnectionTimers()
        hapticController.cancelCountdownScheduler()

        // Clear all publishers
        cancellables.removeAll()

        // Stop motion manager
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }

        Logger.motion.debug("Cleanup completed")
    }

    private func isGoodPosture(_ state: PostureState) -> Bool {
        if case .good = state {
            return true
        }
        return false
    }

    private func updateSessionTimers(newPitch: Double) {
        // Delegate to SessionTimingService for all session-timer logic.
        // This method is kept for the simulator mock data path.
        let adjustedPitch = newPitch - normalAirPodsAngle
        sessionTimingService.updateSessionTimers(
            adjustedPitch: adjustedPitch,
            threshold: poorPostureThreshold,
            hasActiveSession: sessionStore.currentSession != nil
        )
        // Mirror timing state on the manager for UI access
        totalSessionTime = sessionTimingService.totalSessionTime
        poorPostureDuration = sessionTimingService.poorPostureDuration
        postureScorePercent = sessionTimingService.postureScorePercent
    }

    private func checkDeviceStatus() {
        #if !targetEnvironment(simulator)
            if isInResumeGracePeriod {
                // Do not trigger connection loss during grace period
                return
            }
        #endif
        let currentTime = Date()
        let timeSinceLastUpdate = currentTime.timeIntervalSince(lastMotionUpdateTime)
        connectionCoordinator.checkDeviceStatus(timeSinceLastMotion: timeSinceLastUpdate)
    }

    /// Facade over the motion pipeline's low-pass filter, preserved for
    /// existing callers (including tests). The implementation lives in
    /// `HeadphoneMotionPipeline.lowPassFilter`.
    func lowPassFilter(current: Double, previous: Double) -> Double {
        return motionPipeline.lowPassFilter(current: current, previous: previous)
    }

    // MARK: - ConnectionCoordinatorDelegate

    func parentRestart() {
        restart()
    }

    func parentStart() {
        start()
    }

    func parentStop() {
        stop()
    }

    // MARK: - SessionControllerDelegate

    func resumeMotionTracking() {
        start()
    }

    func pauseMotionTracking() {
        motionManager.stopDeviceMotionUpdates()
        // Don't mark as disconnected — the AirPods are still physically connected.
        // Using setStatusOnly prevents the entire view hierarchy from swapping
        // to the idle UI, which would cause a jarring visual "splash."
        connectionCoordinator.setStatusOnly("Paused")
    }

    func resetMotionDisplay() {
        pitch = 0.0
        roll = 0.0
        yaw = 0.0
        pitchHistory.removeAll()
        motionPipeline.reset()
    }

    func startResumeGracePeriod() {
        #if !targetEnvironment(simulator)
        isInResumeGracePeriod = true
        resumeGracePeriodTimer?.invalidate()
        resumeGracePeriodTimer = Timer.scheduledTimer(withTimeInterval: MotionConstants.gracePeriodDuration, repeats: false) {
            [weak self] _ in
            guard let self = self else { return }
            self.isInResumeGracePeriod = false
            self.resumeGracePeriodTimer?.invalidate()
            self.resumeGracePeriodTimer = nil
        }
        #endif
    }



    private func resetUIStateImmediately() {
        // Reset motion display values for immediate UI responsiveness
        pitch = 0.0
        roll = 0.0
        yaw = 0.0

        // Reset posture state to neutral
        let currentTime = Date()
        postureState = .good(postureDuration: currentTime.timeIntervalSince(sessionStartTime))

        // Clear any stale visual indicators
    }

    private func updateConnectionStatusForForeground() {
        if connectionCoordinator.isDeviceConnected {
            connectionCoordinator.setStatusOnly("Reconnecting AirPods...")
        } else {
            connectionCoordinator.setStatusOnly("Connect AirPods and tap 'New Session'")
        }
    }

    private func handleSignificantTimeChange() {
        Logger.session.info("Significant time change detected")
    }



    func updateBackgroundSession() {
        guard isInBackground else { return }
        sessionController.updateBackgroundSession()
        lastMotionUpdateTime = Date()

        if sessionController.sessionStore.currentSession != nil && !isPaused && motionManager.isDeviceMotionActive {
            hapticController.updateHapticFeedback()
        }
    }

    // MARK: - Public Utility Methods
    @MainActor
    func forceReconnect() {
        connectionCoordinator.forceReconnect()
    }

    @MainActor
    func resetConnectionState() {
        connectionCoordinator.resetConnectionState()
        healthService.noteMotionUpdate(at: Date())
    }

    // MARK: - BackgroundMotionProvider Conformance

    func handleCoordinatorDidEnterBackground() {
        isInBackground = true
        lastKnownPoorPostureState = poorPostureStartTime != nil
        lastPoorPostureUpdate = Date()

        if sessionStore.currentSession != nil {
            updateLiveActivity(force: true)
            #if canImport(ActivityKit)
                if #available(iOS 16.1, *) {
                    LiveActivityController.shared.logDiagnostics(context: "app-background")
                }
            #endif
            Logger.background.info("Background tracking enabled - Session continues via coordinator")
        } else {
            Logger.background.debug("No active session - Background tracking not started")
        }
    }

    func handleCoordinatorWillEnterForeground() {
        isForegroundTransitioning = true
        Logger.ui.info("HeadphoneMotionManager: foreground transition via coordinator")

        resetUIStateImmediately()
        updateConnectionStatusForForeground()
        hapticController.stopAllFeedback()
        isInBackground = false

        reinitializeMotionSystemAsync()

        Logger.ui.info("HeadphoneMotionManager: foreground transition completed")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isForegroundTransitioning = false
        }
    }

}

// MARK: - Motion System State (Phase 1)
enum MotionSystemState: Equatable {
    case disconnected
    case initializing
    case connected
    case reconnecting
    case error(String)

    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .initializing:
            return "Initializing..."
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    static func == (lhs: MotionSystemState, rhs: MotionSystemState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
            (.initializing, .initializing),
            (.connected, .connected),
            (.reconnecting, .reconnecting):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
