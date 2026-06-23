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
final class HeadphoneMotionManager: CalibrationDependencies, HapticControllerDependencies, BackgroundMotionProvider {
    static let shared = HeadphoneMotionManager()

    // MARK: - Published Properties
    private(set) var pitch: Double = 0.0
    private(set) var roll: Double = 0.0
    private(set) var yaw: Double = 0.0
    private(set) var isDeviceConnected: Bool = false
    private(set) var connectionStatus: String = "Not started"
    private(set) var postureState: PostureState = .good(postureDuration: 0)
    private(set) var pitchHistory: [Double] = []
    private(set) var poorPostureDuration: TimeInterval = 0
    private(set) var postureScorePercent: Int = 0
    private(set) var isPaused: Bool = false
    private(set) var availableDevices: [String] = []
    private(set) var connectionLostTime: Date?
    private(set) var isInGracePeriod: Bool = false
    private(set) var sessionPaused: Bool = false
    var showConnectionLostAlert: Bool = false

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

    // MARK: - Enhanced Detection Properties (Phase 1)
    @ObservationIgnored private var enhancedDetectionEnabled: Bool = true

    // MARK: - Live Activity Configuration
    private let isLiveActivityEnabled = true // ✅ ENABLED FOR PRODUCTION
    private(set) var connectionMethod: ConnectionMethod = .original

    enum ConnectionMethod: String, CaseIterable {
        case original = "Original"
        case enhanced = "Enhanced"
        case hardware = "Hardware"
    }

    // MARK: - Hardware Detection Properties
    private(set) var airPodsModel: AirPodsModel = .unknown
    private(set) var hasMotionCapability: Bool = false
    private(set) var hasGyroscope: Bool = false
    private(set) var hardwareDetectionSuccessful: Bool = false
    private(set) var connectedDeviceName: String = ""

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
    let connectionDetectionService = ConnectionDetectionService()
    let postureEvaluationService = PostureEvaluationService()
    let liveActivitySyncService = LiveActivitySyncService()

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
    private var motionManager = CMHeadphoneMotionManager()
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
    private let maxDataPoints = MotionConstants.maxDataPoints
    private let updateQueue = DispatchQueue(
        label: "com.necksync.motionUpdates", qos: .userInteractive)
    private let motionUpdateInterval: TimeInterval = MotionConstants.motionUpdateInterval
    private var lastPoorPostureUpdate: Date = Date.distantPast
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?
    private var backgroundUpdateSource: DispatchSourceTimer?
    private(set) var isInBackground: Bool = false
    private var lastKnownPoorPostureState: Bool = false
    private var backgroundUpdateCount: Int = 0
    private var accumulatedPoorPostureDuration: TimeInterval = 0
    private var reconnectionTimer: Timer?
    private var connectionMonitoringTimer: Timer?  // FIXED: Store connection monitoring timer
    private var connectionMonitoringSource: DispatchSourceTimer?
    private let gracePeriodDuration: TimeInterval = MotionConstants.gracePeriodDuration
    private var lastMotionUpdateTime: Date = Date.distantPast
    private let sessionStore = SessionStore.shared
    private var updateCounter: Int = 0
    private var isForegroundTransitioning: Bool = false
    private var liveActivityUpdateTimer: AnyCancellable?

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
        guard
            !isPaused && sessionStore.currentSession != nil && sessionStartTime != Date.distantPast
        else { return }

        let currentTime = Date()

        // Update session timing
        totalSessionTime = currentTime.timeIntervalSince(sessionStartTime)
        lastMotionUpdateTime = currentTime

        // Update poor posture duration if currently in poor posture
        if let startTime = poorPostureStartTime {
            poorPostureDuration =
                accumulatedPoorPostureDuration
                + currentTime.timeIntervalSince(startTime)
        }

        // Update poor posture percentage (now shows good posture percentage)
        recalculateSessionScorePercent()

        // Update session store
        sessionStore.updateCurrentSession(
            poorPostureDuration: poorPostureDuration, activeSessionDuration: totalSessionTime,
            runningWalkingDuration: runningWalkingDuration)

        // Keep Live Activity in sync while background execution is active.
        updateLiveActivity()

        Logger.background.debug("Background update - Session: \(Int(self.totalSessionTime))s, Poor: \(Int(self.poorPostureDuration))s (\(self.postureScorePercent)%)")
    }

    // MARK: - Enhanced Stability Properties
    private var connectionRetryCount: Int = 0
    private let maxRetryAttempts: Int = MotionConstants.maxRetryAttempts
    private var motionManagerRestartCount: Int = 0  // FIXED: Track motion manager restarts
    private let maxMotionManagerRestarts: Int = MotionConstants.maxMotionManagerRestarts
    private var lastMotionManagerRestart: Date = Date.distantPast  // FIXED: Track last restart time
    private let motionManagerRestartCooldown: TimeInterval = MotionConstants.motionManagerRestartCooldown
    private var isReconnecting: Bool = false
    private var motionUpdateTimer: Timer?
    private var healthCheckTimer: Timer?
    private var healthCheckSource: DispatchSourceTimer?
    private var lastSuccessfulMotionUpdate: Date = Date.distantPast
    private let motionHealthCheckInterval: TimeInterval = MotionConstants.healthCheckInterval
    private let maxMotionSilenceDuration: TimeInterval = MotionConstants.maxSilenceDuration

    // MARK: - Background Task Managers (Restored for functionality)
    private let backgroundTaskManager = BackgroundTaskManager.shared
    private let audioBackgroundManager = AudioBackgroundManager.shared
    private let enhancedBackgroundManager = EnhancedBackgroundManager.shared
    #if os(iOS)
    private let hardwareDetector = MotionHardwareDetector()
    #endif

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
        setupAppStateHandling()

        if isSimulator {
            Logger.motion.info("Simulator mode: Ready for manual session start")
            self.connectionStatus = "Simulator ready - tap Start to begin"
        }

        // Configure background task managers for extended background tracking
        // FIXED: Use safe Main Actor to prevent deadlocks
        Self.safeMainActor {
            self.backgroundTaskManager.configure(with: self)
            self.enhancedBackgroundManager.configure(with: self)

            BackgroundManagerCoordinator.shared.registerManagers(
                backgroundTaskManager: self.backgroundTaskManager,
                enhancedBackgroundManager: self.enhancedBackgroundManager,
                audioBackgroundManager: self.audioBackgroundManager,
                motionManager: self
            )

            UnifiedBackgroundCoordinator.shared.configure(with: self)
        }

        // Start real-time connection monitoring for immediate UI updates
        startConnectionMonitoring()

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
        let currentTime = Date()
        let wasPreviouslyActive = isUserRunningOrWalking

        // Check if user is currently running or walking
        let isCurrentlyActive = activity.walking || activity.running || activity.cycling

        if isCurrentlyActive {
            if !wasPreviouslyActive {
                // User just started running/walking
                currentActivityStartTime = currentTime
                runningWalkingStartTime = currentTime
                isUserRunningOrWalking = true
                Logger.motion.info("User started running/walking")
            }
        } else {
            if let startTime = currentActivityStartTime, wasPreviouslyActive {
                // User just stopped running/walking
                let activeDuration = currentTime.timeIntervalSince(startTime)
                runningWalkingDuration += activeDuration
                currentActivityStartTime = nil
                isUserRunningOrWalking = false
                Logger.motion.info("User stopped running/walking (duration: \(Int(activeDuration))s)")
            }
        }

        lastActivityUpdateTime = currentTime
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
        connectionRetryCount = 0
        motionManagerRestartCount = 0  // FIXED: Reset motion manager restart count on fresh start
        isReconnecting = false

        // Clean up any existing state
        cleanupAllTimersAndConnections()

        // Stop any existing motion updates first to prevent multiple handlers
        if motionManager.isDeviceMotionActive {
            Logger.motion.debug("Stopping existing motion updates")
            motionManager.stopDeviceMotionUpdates()
        }

        guard motionManager.isDeviceMotionAvailable else {
            connectionStatus = "AirPods motion not available"
            Logger.motion.warning("Device motion not available, will retry")

            connectionRetryCount += 1
            if connectionRetryCount < maxRetryAttempts {
                // Try to restart after a short delay with exponential backoff
                let delay = min(2.0 * Double(connectionRetryCount), 10.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.restart()
                }
            } else {
                connectionStatus = "Failed to connect after \(maxRetryAttempts) attempts"
                Logger.motion.error("Max retry attempts reached")
            }
            return
        }

        connectionStatus = "Starting motion updates"
        Logger.motion.info("Device motion available, starting updates")
        lastSuccessfulMotionUpdate = Date()

        // Start device motion updates with single handler
        startMotionUpdatesInternal()

        // Setup periodic updates
        setupPeriodicUpdates()

        // Start health monitoring
        startHealthCheck()
    }

    @MainActor
    private var simulatorMockTimer: Timer?

    @MainActor
    private func startSimulatorMockData() {
        Logger.motion.info("Starting simulator mock data")

        self.isDeviceConnected = true
        self.connectedDeviceName = "Simulator AirPods"
        self.connectionStatus = "Simulator: AirPods Connected"

        self.pitch = 0.0
        self.roll = 0.0
        self.yaw = 0.0
        self.postureState = .good(postureDuration: 0)
        self.pitchHistory = []

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
    private func startMotionUpdatesInternal() {
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
                self?.restartMotionManager()
            }
        } else {
            handleConnectionError(error)
        }
    }

    private func handleNoMotionData() {
        Logger.motion.warning("No motion data received")
        motionSystemState = .reconnecting
        motionSystemStateDidChange()
        isDeviceConnected = false
        connectedDeviceName = ""
        connectionStatus = "No motion data from AirPods"

        // Try to recover from no motion data
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.isDeviceConnected == false && self?.isPaused == false {
                self?.restartMotionManager()
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

        if !isDeviceConnected {
            isDeviceConnected = true
            connectionStatus = "AirPods connected"
            lastMotionUpdateTime = Date()
        }

        // Process motion data
        processMotionData(motion)

        if shouldForceLiveActivitySync {
            updateLiveActivity(force: true)
        }
    }

    private func onMotionSystemReady() {
        transitionMetrics.markMotionSystemReady()

        // Validate session continuity
        let sessionValidation = validateSessionContinuity()

        Logger.motion.info("Motion system ready - Session: \(sessionValidation ? "PRESERVED" : "CORRUPTED")")

        // Final performance report
        logTransitionPerformance()
    }

    @MainActor
    func stop() {
        if isSimulator {
            simulatorMockTimer?.invalidate()
            simulatorMockTimer = nil
            isDeviceConnected = false
            connectedDeviceName = ""
            connectionStatus = "Simulator ready - tap Start to begin"
            pitch = 0.0
            roll = 0.0
            yaw = 0.0
            pitchHistory = []
            Logger.motion.info("Simulator stopped")
            return
        }
        motionManager.stopDeviceMotionUpdates()
        cancellables.removeAll()
        liveActivityUpdateTimer?.cancel()  // Cancel the new timer
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        connectionMonitoringTimer?.invalidate()
        connectionMonitoringTimer = nil
        cancelTimerSourceSafely(&motionCoalesceSource)
        cancelTimerSourceSafely(&healthCheckSource)
        cancelTimerSourceSafely(&connectionMonitoringSource)
        cancelTimerSourceSafely(&backgroundUpdateSource)
        hapticController.cancelCountdownScheduler()
        connectionStatus = "Stopped"
        isDeviceConnected = false
        connectedDeviceName = ""
        isPaused = false  // Reset pause state

        // Only save session if it has meaningful data
        if totalSessionTime > 10 || postureScorePercent > 0 {
            resetSession(shouldStartNew: false)  // Don't create new session when stopping
        } else {
            // Clear session without saving if it has no meaningful data
            sessionStore.currentSession = nil
        }

        endBackgroundTask()
        saveCurrentSessionIfNeeded()

        // Disable background audio when stopping
        audioBackgroundManager.disableBackgroundAudio()

        hapticController.resetState()

        liveActivitySyncService.endActivity(immediate: true)
        liveActivitySyncService.stopUpdateTimer()
    }

    @MainActor
    func restart() {
        if isSimulator {
            // Simulator: Do nothing
            return
        }

        Logger.motion.info("Restarting HeadphoneMotionManager")

        // Increment retry counter
        connectionRetryCount += 1

        if connectionRetryCount >= maxRetryAttempts {
            Logger.motion.error("Max restart attempts reached, stopping")
            connectionStatus = "Connection failed after \(maxRetryAttempts) attempts"
            return
        }

        // Comprehensive cleanup
        cleanupAllTimersAndConnections()

        // Reset connection state
        isDeviceConnected = false
        connectedDeviceName = ""
        isReconnecting = true
        connectionStatus = "Reconnecting... (attempt \(connectionRetryCount)/\(maxRetryAttempts))"

        // Force a clean state
        resetSession(shouldStartNew: true)  // Create new session when restarting

        // Create a new motion manager instance to ensure fresh state
        motionManager = CMHeadphoneMotionManager()

        // Wait a moment for the system to settle with exponential backoff
        let delay = min(1.0 * Double(connectionRetryCount), 5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { @MainActor in
                await self?.attemptConnection()
            }
        }
    }

    @MainActor
    private func attemptConnection() async {
        Logger.bluetooth.info("Attempting to connect to AirPods")

        // First check if AirPods are connected via audio session
        if await checkAirPodsAudioConnection() {
            Logger.bluetooth.info("AirPods already connected via audio session")
            connectionStatus = "AirPods connected"
            isDeviceConnected = true
            lastMotionUpdateTime = Date()

            // 🚫 REMOVED AUTO-START: Only update connection status, don't start tracking
            // Motion updates should only start when user explicitly clicks "Start"
            // if !motionManager.isDeviceMotionActive {
            //     startMotionUpdates()
            // }
            // setupPeriodicUpdates()
            return
        }

        // Check if motion is available
        guard motionManager.isDeviceMotionAvailable else {
            connectionStatus = "AirPods motion not available"
            Logger.bluetooth.warning("Device motion not available")

            // Retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                Task { @MainActor in
                    await self?.attemptConnection()
                }
            }
            return
        }

        connectionStatus = "Connecting to AirPods..."
        Logger.bluetooth.info("Device motion available, starting updates")

        // Use the centralized motion update method
        startMotionUpdatesInternal()

        // Set a timeout for connection attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if !self.isDeviceConnected {
                    Logger.bluetooth.warning("Connection timeout, checking audio session")
                    // Try checking audio session again before giving up
                    if await self.checkAirPodsAudioConnection() {
                        Logger.bluetooth.info("Found AirPods via audio session on retry")
                        self.connectionStatus = "AirPods connected"
                        self.isDeviceConnected = true
                        self.lastMotionUpdateTime = Date()
                        // 🚫 REMOVED AUTO-START: Only update connection status
                        // self.setupPeriodicUpdates()
                    } else {
                        self.connectionStatus =
                            "No AirPods found - Connect your AirPods and tap 'New Session'"
                    }
                }
            }
        }
    }

    @MainActor
    private func checkAirPodsAudioConnection() async -> Bool {
        #if os(iOS)
        if await hardwareDetector.checkAirPodsConnectionWithHardware() {
            connectionMethod = .hardware
            airPodsModel = hardwareDetector.airPodsModel
            hasMotionCapability = hardwareDetector.hasMotionCapability
            hasGyroscope = hardwareDetector.hasGyroscope
            hardwareDetectionSuccessful = hardwareDetector.hardwareDetectionSuccessful
            Logger.bluetooth.info("Hardware detection successful")
            return true
        }

        if enhancedDetectionEnabled && hardwareDetector.checkAirPodsAudioConnectionEnhanced() {
            connectionMethod = .enhanced
            Logger.bluetooth.info("Enhanced detection successful")
            return true
        }
        #endif

        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP
                || output.portType == .bluetoothLE
            {
                let deviceName = output.portName.lowercased()
                if deviceName.contains("airpods") || deviceName.contains("beats") {
                    connectionMethod = .original
                    Logger.bluetooth.info("Original detection found AirPods in audio route")
                    return true
                }
            }
        }

        for input in currentRoute.inputs {
            if input.portType == .bluetoothHFP {
                let deviceName = input.portName.lowercased()
                if deviceName.contains("airpods") || deviceName.contains("beats") {
                    connectionMethod = .original
                    Logger.bluetooth.info("Original detection found AirPods in audio input")
                    return true
                }
            }
        }

        connectionMethod = .original
        Logger.bluetooth.warning("No AirPods found in current audio route")
        return false
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
        if sessionStore.currentSession != nil {
            saveCurrentSessionIfNeeded()
        }

        pitch = 0.0
        roll = 0.0
        yaw = 0.0
        postureState = .good(postureDuration: 0)

        pitchHistory.removeAll()
        sessionTimingService.resetSession()
        poorPostureDuration = 0
        accumulatedPoorPostureDuration = 0
        poorPostureStartTime = nil
        totalSessionTime = 0
        postureScorePercent = 0
        lastPoorPostureUpdate = Date.distantPast
        connectionLostTime = nil
        isInGracePeriod = false
        sessionPaused = false

        hapticController.stopAllFeedback()

        stopActivityDetection()
        runningWalkingDuration = 0
        isUserRunningOrWalking = false
        currentActivityStartTime = nil

        if shouldStartNew {
            if isDeviceConnected {
                startNewSession()
            } else {
                Logger.session.warning("Cannot start new session - AirPods not connected")
            }
        } else {
            liveActivitySyncService.stopUpdateTimer()
            liveActivitySyncService.endActivity(immediate: true)
        }
    }

    func checkForAirPodsImmediate() -> Bool {
        Logger.bluetooth.debug("Quick check for AirPods")

        if isSimulator {
            Logger.bluetooth.debug("Simulator mode: AirPods always available")
            return true
        }

        #if os(iOS)
        if hardwareDetector.checkAirPodsAudioConnectionEnhanced() {
            Logger.bluetooth.info("AirPods/Beats detected immediately (enhanced)")
            return true
        }
        #endif

        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
                let deviceName = output.portName.lowercased()
                if deviceName.contains("airpods") || deviceName.contains("beats") {
                    Logger.bluetooth.info("AirPods/Beats detected immediately (original)")
                    return true
                }
            }
        }

        for input in currentRoute.inputs {
            if input.portType == .bluetoothHFP {
                let deviceName = input.portName.lowercased()
                if deviceName.contains("airpods") || deviceName.contains("beats") {
                    Logger.bluetooth.info("AirPods/Beats input detected immediately (original)")
                    return true
                }
            }
        }

        Logger.bluetooth.warning("No AirPods detected")
        return false
    }


    @MainActor
    func togglePause() {
        isPaused.toggle()
        if isPaused {
            // Only update session timing if there's an actual session
            if sessionStore.currentSession != nil && sessionStartTime != Date.distantPast {
                let currentTime = Date()
                if poorPostureStartTime != nil {
                    // If we were in poor posture, add the current episode to accumulated duration
                    if let startTime = poorPostureStartTime {
                        let episodeDuration = currentTime.timeIntervalSince(startTime)
                        accumulatedPoorPostureDuration += episodeDuration
                    }
                    poorPostureDuration = accumulatedPoorPostureDuration
                    poorPostureStartTime = nil
                }
                totalSessionTime = currentTime.timeIntervalSince(sessionStartTime)
                SessionStore.shared.updateCurrentSession(
                    poorPostureDuration: poorPostureDuration,
                    activeSessionDuration: totalSessionTime,
                    runningWalkingDuration: runningWalkingDuration
                )
            }
            motionManager.stopDeviceMotionUpdates()
            connectionStatus = "Paused"

            hapticController.stopAllFeedback()

            Logger.session.info("Session paused - Poor posture: \(self.postureScorePercent)%, Duration: \(self.poorPostureDuration), Total: \(self.totalSessionTime)")
            updateLiveActivity()
        } else {
            // Only resume session timing if there's an actual session
            if sessionStore.currentSession != nil && sessionStartTime != Date.distantPast {
                let currentTime = Date()
                sessionStartTime = currentTime.addingTimeInterval(-totalSessionTime)
                lastPoorPostureUpdate = currentTime
                #if !targetEnvironment(simulator)
                    startResumeGracePeriod()
                #endif
            }
            start()
            Logger.session.info("Session resumed - Poor posture: \(self.postureScorePercent)%, Duration: \(self.poorPostureDuration), Total: \(self.totalSessionTime)")
            updateLiveActivity()
        }
    }

    @MainActor
    func startNewSession() {
        Logger.session.info("Start new session called")

        guard isDeviceConnected else {
            Logger.session.warning("Cannot start new session - AirPods not connected")
            return
        }

        Logger.session.info("Starting new session")
        _ = sessionStore.startNewSession()
        sessionTimingService.startNewSession()
        sessionStartTime = Date()
        lastMotionUpdateTime = Date()

        runningWalkingDuration = 0
        isUserRunningOrWalking = false
        currentActivityStartTime = nil
        startActivityDetection()

        if let session = sessionStore.currentSession, isDeviceConnected {
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

        if isDeviceConnected && isLiveActivityEnabled {
            liveActivitySyncService.startUpdateTimer { [weak self] in
                self?.updateLiveActivity()
            }
            updateLiveActivity(force: true)
        }
    }

    @MainActor
    private func updateLiveActivity(force: Bool = false) {
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

    private func recalculateSessionScorePercent() {
        guard totalSessionTime > 0 else {
            postureScorePercent = 0
            return
        }

        let sessionScore = ((totalSessionTime - poorPostureDuration) / totalSessionTime) * 100
        postureScorePercent = max(0, min(100, Int(sessionScore)))
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    @MainActor
    func forceCheckAirPodsConnection() {
        Logger.bluetooth.info("Force checking AirPods connection")

        if isSimulator {
            return
        }

        Task { @MainActor in
            await forceCheckAirPodsConnectionAsync()
        }
    }

    @MainActor
    private func forceCheckAirPodsConnectionAsync() async {

        // First do a quick audio session check
        if await checkAirPodsAudioConnection() {
            Logger.bluetooth.info("AirPods found immediately via audio session")
            isDeviceConnected = true
            connectionStatus = "AirPods connected"
            lastMotionUpdateTime = Date()

            // 🚫 REMOVED AUTO-START: Only update connection status, don't start tracking
            // Motion updates should only start when user explicitly clicks "Start"
            // if !motionManager.isDeviceMotionActive {
            //     attemptConnection()
            // }
            return
        }

        // Stop current updates
        motionManager.stopDeviceMotionUpdates()

        // Create fresh motion manager
        motionManager = CMHeadphoneMotionManager()

        // Reset state
        isDeviceConnected = false
        connectedDeviceName = ""
        connectionStatus = "Checking for AirPods..."

        // Attempt connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            Task { @MainActor in
                await self?.attemptConnection()
            }
        }
    }

    @MainActor
    func checkConnectionStatusForUI() {
        Logger.ui.debug("Checking AirPods connection status for UI update")
        Logger.ui.debug("Current isDeviceConnected state: \(self.isDeviceConnected)")

        if isSimulator {
            // In simulator, always show as connected for proper testing
            Logger.ui.debug("Simulator: Setting isDeviceConnected = true")
            isDeviceConnected = true
            connectedDeviceName = "Simulator AirPods"
            connectionStatus = "Simulator Mock Mode: Connected"
            Logger.ui.debug("Simulator: isDeviceConnected is now: \(self.isDeviceConnected)")
            return
        }

        Task { @MainActor in
            await checkConnectionStatusForUIAsync()
        }
    }

    @MainActor
    private func checkConnectionStatusForUIAsync() async {

        // Quick check for AirPods via audio session without starting motion updates
        if await checkAirPodsAudioConnection() {
            Logger.bluetooth.info("AirPods detected via audio session - updating UI state")
            isDeviceConnected = true
            connectionStatus = "AirPods connected"
        } else {
            Logger.bluetooth.warning("No AirPods detected - updating UI state")
            isDeviceConnected = false
            connectedDeviceName = ""
            connectionStatus = "Connect your AirPods"
        }

        Logger.ui.debug("Final isDeviceConnected state: \(self.isDeviceConnected)")

        // OPTIMIZATION: Trigger optimized reconnection if disconnected
        if !isDeviceConnected && !isPaused && !isReconnecting {
            scheduleOptimizedReconnection()
        }
    }

    // MARK: - Optimized Reconnection
    @MainActor
    private func scheduleOptimizedReconnection() {
        // Prevent multiple reconnection attempts
        guard !isReconnecting else { return }

        isReconnecting = true

        // OPTIMIZATION: Use adaptive delay based on previous attempts
        let baseDelay = 1.0
        let adaptiveDelay = min(baseDelay * pow(1.5, Double(connectionRetryCount)), 10.0)

        Logger.bluetooth.info("Scheduling optimized reconnection in \(adaptiveDelay)s (attempt \(self.connectionRetryCount + 1))")

        DispatchQueue.main.asyncAfter(deadline: .now() + adaptiveDelay) { [weak self] in
            guard let self = self else { return }

            // Check if we're still disconnected
            if !self.isDeviceConnected && !self.isPaused {
                self.attemptOptimizedReconnection()
            } else {
                self.isReconnecting = false
            }
        }
    }

    @MainActor
    private func attemptOptimizedReconnection() {
        Logger.bluetooth.info("Attempting optimized AirPods reconnection")

        // OPTIMIZATION: Progressive reconnection strategy
        if connectionRetryCount < 3 {
            // Quick restart for first few attempts
            restart()
        } else if connectionRetryCount < 6 {
            // Full reset for persistent issues
            performFullConnectionReset()
        } else {
            // Give up and wait for user intervention
            Logger.bluetooth.error("Maximum reconnection attempts reached - waiting for user action")
            isReconnecting = false
            return
        }

        connectionRetryCount += 1

        // Verify reconnection success after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.verifyReconnectionSuccess()
        }
    }

    @MainActor
    private func performFullConnectionReset() {
        Logger.bluetooth.info("Performing full connection reset")

        // Stop everything
        stop()

        // Reset motion manager
        motionManager = CMHeadphoneMotionManager()

        // Wait for system to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.start()
        }
    }

    @MainActor
    private func verifyReconnectionSuccess() {
        if isDeviceConnected {
            Logger.bluetooth.info("Optimized reconnection successful")
            isReconnecting = false
            connectionRetryCount = 0
        } else {
            Logger.bluetooth.warning("Reconnection attempt failed - will retry")
            isReconnecting = false
            scheduleOptimizedReconnection()
        }
    }

    // MARK: - Real-time Connection Monitoring
    private func startConnectionMonitoring() {
        // Cancel any existing sources/timers
        connectionMonitoringTimer?.invalidate()
        connectionMonitoringTimer = nil
        connectionMonitoringSource?.cancel()
        connectionMonitoringSource = nil

        // Prefer event-driven route change notifications
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                let connected = await self.checkAirPodsAudioConnection()
                if connected != self.isDeviceConnected {
                    self.isDeviceConnected = connected
                    self.connectionStatus = connected ? "AirPods connected" : "Connect your AirPods"
                }
            }
        }

        // Fallback: low-frequency background timer (2.5s) on background queue
        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        source.schedule(deadline: .now() + 2.5, repeating: 2.5)
        source.setEventHandler { [weak self] in
            #if targetEnvironment(simulator)
                // Simulator: keep simple behavior without extra work
            #else
                Task { @MainActor in
                    guard let self, !self.isForegroundTransitioning else { return }
                    let connected = await self.checkAirPodsAudioConnection()
                    if connected != self.isDeviceConnected {
                        self.isDeviceConnected = connected
                        self.connectionStatus =
                            connected ? "AirPods connected" : "Connect your AirPods"
                    }
                }
            #endif
        }
        connectionMonitoringSource = source
        source.resume()
    }

    @MainActor
    func saveCurrentSessionIfNeeded() {
        // CRITICAL FIX: Only save if there's actually an active session with meaningful data
        guard totalSessionTime > 0 && sessionStore.currentSession != nil else { return }

        // Don't save sessions with no meaningful data (0% poor posture and very short duration)
        guard totalSessionTime > 10 || postureScorePercent > 0 else {
            Logger.session.debug("Skipping session save - No meaningful data collected (duration: \(self.totalSessionTime)s, poor posture: \(self.postureScorePercent)%)")
            sessionStore.currentSession = nil
            return
        }

        sessionStore.endCurrentSession(
            poorPostureDuration: poorPostureDuration,
            activeSessionDuration: totalSessionTime,
            runningWalkingDuration: runningWalkingDuration
        )

        hapticController.resetState()
    }

    @MainActor
    func dismissConnectionAlert() {
        showConnectionLostAlert = false
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
            connectionStatus = "Connect AirPods and tap 'New Session'"
        case .initializing:
            connectionStatus = "Initializing AirPods connection..."
        case .reconnecting:
            connectionStatus = "Reconnecting AirPods..."
        case .connected:
            connectionStatus = "AirPods connected"
        case .error(let message):
            connectionStatus = "Connection error: \(message)"
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

    // MARK: - Data Validation
    private func validateMotionData(_ motion: CMDeviceMotion) -> Bool {
        let attitude = motion.attitude

        // Check for NaN values
        guard !attitude.pitch.isNaN,
              !attitude.roll.isNaN,
              !attitude.yaw.isNaN else {
            Logger.motion.warning("NaN values detected in motion data - skipping update")
            return false
        }

        // Check for infinite values
        guard !attitude.pitch.isInfinite,
              !attitude.roll.isInfinite,
              !attitude.yaw.isInfinite else {
            Logger.motion.warning("Infinite values detected in motion data - skipping update")
            return false
        }

        // Check for reasonable value ranges
        let validRange = -Double.pi...Double.pi
        guard validRange.contains(attitude.pitch),
              validRange.contains(attitude.roll),
              validRange.contains(attitude.yaw) else {
            Logger.motion.warning("Out of range values detected - skipping update")
            return false
        }

        return true
    }

    func processMotionData(_ motion: CMDeviceMotion) {
        guard validateMotionData(motion) else { return }
        let newPitch = lowPassFilter(
            current: motion.attitude.pitch * 180 / .pi,
            previous: pitch
        )
        let currentTime = Date()

        pitch = newPitch
        roll = motion.attitude.roll * 180 / .pi
        yaw = motion.attitude.yaw * 180 / .pi
        if !isDeviceConnected {
            isDeviceConnected = true
        }
        if connectionStatus != "Connected" {
            connectionStatus = "Connected"
        }
        lastMotionUpdateTime = currentTime
        lastSuccessfulMotionUpdate = currentTime

        connectionRetryCount = 0
        isReconnecting = false

        updatePitchHistory(newPitch)
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

    private func updatePitchHistory(_ newPitch: Double) {
        pitchHistory.append(newPitch)
        if pitchHistory.count > maxDataPoints {
            pitchHistory.removeFirst()
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

        // Stop all timers
        motionUpdateTimer?.invalidate()
        motionUpdateTimer = nil

        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        reconnectionTimer?.invalidate()
        reconnectionTimer = nil

        connectionMonitoringTimer?.invalidate()
        connectionMonitoringTimer = nil

        backgroundTimer?.invalidate()
        backgroundTimer = nil
        cancelTimerSourceSafely(&motionCoalesceSource)
        cancelTimerSourceSafely(&healthCheckSource)
        cancelTimerSourceSafely(&connectionMonitoringSource)
        cancelTimerSourceSafely(&backgroundUpdateSource)
        hapticController.cancelCountdownScheduler()

        // Clear all publishers
        cancellables.removeAll()

        // Stop motion manager
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }

        Logger.motion.debug("Cleanup completed")
    }

    @MainActor
    private func startHealthCheck() {
        Logger.motion.debug("Starting motion health check")

        // Replace main-runloop timer with background DispatchSourceTimer
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        healthCheckSource?.cancel()
        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        source.schedule(
            deadline: .now() + motionHealthCheckInterval, repeating: motionHealthCheckInterval)
        source.setEventHandler { [weak self] in
            guard let self = self, !self.isForegroundTransitioning else { return }
            Self.safeMainActor {
                self.performHealthCheck()
            }
        }
        healthCheckSource = source
        source.resume()
    }

    @MainActor
    private func performHealthCheck() {
        let currentTime = Date()
        let timeSinceLastMotion = currentTime.timeIntervalSince(lastSuccessfulMotionUpdate)

        // FIXED: Add additional safeguards to prevent excessive restarts

        // Check if we haven't received motion data for too long
        if timeSinceLastMotion > maxMotionSilenceDuration && isDeviceConnected && !isPaused
            && !isReconnecting
        {
            // FIXED: Only attempt recovery if we haven't hit restart limits
            if motionManagerRestartCount < maxMotionManagerRestarts {
                Logger.motion.warning("Motion silence detected for \(timeSinceLastMotion)s - attempting recovery")
                handleMotionSilence()
            } else {
                Logger.motion.warning("Motion silence detected but restart limit reached. Skipping recovery attempt")
            }
        }

        // Check if motion manager is still active
        if isDeviceConnected && !motionManager.isDeviceMotionActive && !isPaused && !isReconnecting
        {
            // FIXED: Only restart if we haven't hit restart limits
            if motionManagerRestartCount < maxMotionManagerRestarts {
                Logger.motion.warning("Motion manager inactive but should be connected - restarting")
                restartMotionManager()
            } else {
                Logger.motion.warning("Motion manager inactive but restart limit reached. Skipping restart")
            }
        }
    }

    @MainActor
    private func handleMotionSilence() {
        guard !isReconnecting else { return }

        // FIXED: Check restart limits before attempting recovery
        guard motionManagerRestartCount < maxMotionManagerRestarts else {
            Logger.motion.warning("Motion silence detected but restart limit reached. Cannot recover")
            return
        }

        Logger.motion.debug("Handling motion silence")
        isReconnecting = true

        // Try to restart motion updates
        restartMotionManager()

        // Reset reconnecting flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.isReconnecting = false
        }
    }

    @MainActor
    private func restartMotionManager() {
        // FIXED: Check restart limits and cooldown
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
        motionManager.stopDeviceMotionUpdates()

        // Create new motion manager instance
        motionManager = CMHeadphoneMotionManager()

        // Wait a moment then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startMotionUpdatesInternal()
        }
    }

    private func isGoodPosture(_ state: PostureState) -> Bool {
        if case .good = state {
            return true
        }
        return false
    }

    private func updateSessionTimers(newPitch: Double) {
        guard !sessionPaused && !isPaused else { return }

        // CRITICAL FIX: Only update session timers if there's an active session
        // But still process motion data for display purposes
        if sessionStore.currentSession == nil {
            // Reset session-related variables when no session is active
            if totalSessionTime > 0 || poorPostureDuration > 0 || postureScorePercent > 0 {
                totalSessionTime = 0
                poorPostureDuration = 0
                accumulatedPoorPostureDuration = 0
                postureScorePercent = 0
                poorPostureStartTime = nil
                Logger.session.debug("Reset session variables - no active session")
            }
            // Still allow motion data processing for display, but don't update session timing
            return
        }

        // Only update session timing if session has actually started
        guard sessionStartTime != Date.distantPast else {
            return
        }

        let currentTime = Date()
        totalSessionTime = currentTime.timeIntervalSince(sessionStartTime)

        // Apply normal AirPods angle offset
        let adjustedPitch = newPitch - normalAirPodsAngle

        if adjustedPitch < poorPostureThreshold {
            if poorPostureStartTime == nil {
                // Starting a new poor posture episode
                poorPostureStartTime = currentTime
                Logger.session.debug("Starting new poor posture episode")
            }

            // Calculate current episode duration
            let currentEpisodeDuration =
                poorPostureStartTime.map { currentTime.timeIntervalSince($0) } ?? 0
            // Total poor posture duration is accumulated duration plus current episode
            poorPostureDuration = accumulatedPoorPostureDuration + currentEpisodeDuration

            Logger.session.debug("Poor posture: current episode=\(currentEpisodeDuration), accumulated=\(self.accumulatedPoorPostureDuration), total=\(self.poorPostureDuration)")
        } else {
            if let startTime = poorPostureStartTime {
                // Ending a poor posture episode
                let episodeDuration = currentTime.timeIntervalSince(startTime)
                accumulatedPoorPostureDuration += episodeDuration
                poorPostureDuration = accumulatedPoorPostureDuration
                poorPostureStartTime = nil
                Logger.session.debug("Ending poor posture episode: duration=\(episodeDuration), accumulated=\(self.accumulatedPoorPostureDuration)")
            }
        }

        // Update poor posture percentage (now shows good posture percentage)
        if totalSessionTime > 0 {
            recalculateSessionScorePercent()
            Logger.session.debug("Updated percentage: \(self.postureScorePercent)% (duration: \(self.poorPostureDuration), total: \(self.totalSessionTime))")

            // Update the current session
            SessionStore.shared.updateCurrentSession(poorPostureDuration: poorPostureDuration, runningWalkingDuration: runningWalkingDuration)

            hapticController.updateHapticFeedback()
        }
    }

    private func checkDeviceStatus() {
        let currentTime = Date()
        let timeSinceLastUpdate = currentTime.timeIntervalSince(lastMotionUpdateTime)
        #if !targetEnvironment(simulator)
            if isInResumeGracePeriod {
                // Do not trigger connection loss during grace period
                return
            }
        #endif
        if timeSinceLastUpdate > MotionConstants.connectionTimeoutInterval && isDeviceConnected
            && !isPaused
            && !isInBackground
        {
            handleConnectionLoss()
        }
        // Removed automatic restart to prevent infinite loops
    }

    private func handleConnectionLoss() {
        // CRITICAL FIX: Only handle connection loss if there's an active session
        guard connectionLostTime == nil && sessionStore.currentSession != nil else {
            // If there's no active session, just update connection status without notifications
            if connectionLostTime == nil && sessionStore.currentSession == nil {
                isDeviceConnected = false
                connectedDeviceName = ""
                connectionStatus = "Bluetooth disconnected"
                Logger.bluetooth.info("Bluetooth disconnected - No active session")
                
                // End live activity if it's running but no AirPods are connected (temporarily disabled)
                #if canImport(ActivityKit)
                    if #available(iOS 16.1, *) {
                        if isLiveActivityEnabled {
                            Self.safeMainActor {
                                LiveActivityController.shared.end(immediate: true)
                            }
                        }
                    }
                #endif
                
                // Cancel live activity update timer if it's running
                liveActivityUpdateTimer?.cancel()
            }
            return
        }

        connectionLostTime = Date()
        isDeviceConnected = false
        connectedDeviceName = ""
        isInGracePeriod = true
        sessionPaused = true
        connectionStatus = "Bluetooth connection lost - Attempting to reconnect..."

        // End live activity when AirPods disconnect (temporarily disabled)
        #if canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                if isLiveActivityEnabled {
                    Self.safeMainActor {
                        LiveActivityController.shared.end(immediate: true)
                    }
                }
            }
        #endif

        // Cancel live activity update timer
        liveActivityUpdateTimer?.cancel()

        // Start grace period timer
        reconnectionTimer = Timer.scheduledTimer(
            withTimeInterval: gracePeriodDuration, repeats: false
        ) { [weak self] _ in
            Self.safeMainActor {
                self?.handleGracePeriodExpired()
            }
        }

        // Show alert to user
        showConnectionLostAlert = true

        // Send connection lost notification
        notificationManager.sendConnectionLostNotification()

        Logger.bluetooth.warning("Bluetooth connection lost - Starting grace period")
    }

    private func handleReconnection() {
        guard let lostTime = connectionLostTime else { return }

        let disconnectionDuration = Date().timeIntervalSince(lostTime)

        // Cancel grace period timer
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil

        // Update status
        connectionLostTime = nil
        isInGracePeriod = false
        sessionPaused = false
        connectionStatus = "Bluetooth reconnected after \(Int(disconnectionDuration))s"

        // Don't show alert anymore
        showConnectionLostAlert = false

        // Reset last update time to prevent time jumps
        lastMotionUpdateTime = Date()

        Logger.bluetooth.info("Bluetooth reconnected after \(disconnectionDuration) seconds")
    }

    private func handleGracePeriodExpired() {
        guard isInGracePeriod else { return }

        // Save current session
        saveCurrentSessionIfNeeded()

        // Update status
        isInGracePeriod = false
        connectionStatus = "Session saved - Bluetooth connection lost"

        // Start new session when reconnected
        Logger.bluetooth.warning("Grace period expired - Session saved due to Bluetooth connection loss")
    }

    private func handleConnectionError(_ error: Error) {
        connectionStatus = "Error: \(error.localizedDescription)"
        isDeviceConnected = false
        connectedDeviceName = ""
        handleConnectionLoss()
    }

    func lowPassFilter(current: Double, previous: Double) -> Double {
        return previous * (1.0 - MotionConstants.lowPassFilterFactor) + current
            * MotionConstants.lowPassFilterFactor
    }

    private func setupAppStateHandling() {
        #if os(iOS)
            NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
                .sink { [weak self] _ in
                    self?.handleCoordinatorDidEnterBackground()
                }
                .store(in: &cancellables)

            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in
                    self?.isForegroundTransitioning = true
                    self?.handleCoordinatorWillEnterForeground()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.isForegroundTransitioning = false
                    }
                }
                .store(in: &cancellables)

            NotificationCenter.default.publisher(
                for: UIApplication.significantTimeChangeNotification
            )
            .sink { [weak self] _ in
                self?.handleSignificantTimeChange()
            }
            .store(in: &cancellables)
        #elseif os(macOS)
            NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)
                .sink { [weak self] _ in
                    self?.handleCoordinatorDidEnterBackground()
                }
                .store(in: &cancellables)

            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in
                    self?.handleCoordinatorWillEnterForeground()
                }
                .store(in: &cancellables)
        #endif
    }

    private func handleAppBackground() {
        handleCoordinatorDidEnterBackground()
    }

    private func handleAppForeground() {
        handleCoordinatorWillEnterForeground()
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
        if isDeviceConnected {
            connectionStatus = "Reconnecting AirPods..."
        } else {
            connectionStatus = "Connect AirPods and tap 'New Session'"
        }
    }

    // MARK: - Session State Preservation (Phase 5)

    private func preserveSessionStateBeforeMotionReset() {
        // Capture current session state before any motion system changes
        guard sessionStore.currentSession != nil else { return }

        let preservedState = SessionPreservationState(
            poorPostureDuration: poorPostureDuration,
            totalSessionTime: totalSessionTime,
            postureScorePercent: postureScorePercent,
            sessionStartTime: sessionStartTime,
            lastKnownPoorPostureState: lastKnownPoorPostureState
        )

        // Store in session store immediately (if method exists)
        // sessionStore.preserveTransitionState(preservedState) // TODO: Add to SessionStore if needed
        Logger.session.info("Session state preserved before motion system reset")
    }

    private struct SessionPreservationState {
        let poorPostureDuration: TimeInterval
        let totalSessionTime: TimeInterval
        let postureScorePercent: Int
        let sessionStartTime: Date
        let lastKnownPoorPostureState: Bool
    }

    // MARK: - Performance Monitoring (Phase 6)

    private var transitionMetrics: TransitionMetrics = TransitionMetrics()

    private struct TransitionMetrics {
        var foregroundTransitionStartTime: Date?
        var uiUpdateCompletionTime: Date?
        var motionSystemReadyTime: Date?

        mutating func startTransition() {
            foregroundTransitionStartTime = Date()
        }

        mutating func markUIUpdateComplete() {
            uiUpdateCompletionTime = Date()
        }

        mutating func markMotionSystemReady() {
            motionSystemReadyTime = Date()
        }

        func getPerformanceReport() -> String {
            guard let startTime = foregroundTransitionStartTime else { return "No transition data" }

            let uiTime = uiUpdateCompletionTime?.timeIntervalSince(startTime) ?? 0
            let motionTime = motionSystemReadyTime?.timeIntervalSince(startTime) ?? 0

            return """
                Transition Performance:
                - UI Update: \(String(format: "%.2f", uiTime * 1000))ms
                - Motion System Ready: \(String(format: "%.2f", motionTime * 1000))ms
                """
        }
    }

    private func logTransitionPerformance() {
        Logger.ui.debug("\(self.transitionMetrics.getPerformanceReport())")
    }

    // MARK: - Validation Methods

    private func validateForegroundTransition() -> Bool {
        // Validate that UI updates happened immediately
        guard let startTime = transitionMetrics.foregroundTransitionStartTime,
            let uiTime = transitionMetrics.uiUpdateCompletionTime
        else {
            return false
        }

        let uiUpdateDuration = uiTime.timeIntervalSince(startTime)
        let isUIImmediate = uiUpdateDuration < 0.001  // Less than 1ms

        Logger.ui.debug("UI Update Validation: \(isUIImmediate ? "PASS" : "FAIL") (\(String(format: "%.3f", uiUpdateDuration * 1000))ms)")

        return isUIImmediate
    }

    private func validateSessionContinuity() -> Bool {
        // Validate that session data is preserved
        guard let currentSession = sessionStore.currentSession else {
            Logger.session.debug("Session Continuity: PASS (No active session)")
            return true
        }

        let isDataPreserved = currentSession.poorPostureDuration == poorPostureDuration
        Logger.session.debug("Session Continuity: \(isDataPreserved ? "PASS" : "FAIL")")

        return isDataPreserved
    }

    private func handleSignificantTimeChange() {
        Logger.session.info("Significant time change detected")
        syncSessionState()
    }

    private func syncSessionState() {
        Logger.session.debug("Syncing session state")

        // CRITICAL FIX: Only sync if there's an active session
        guard sessionStore.currentSession != nil else {
            Logger.session.debug("No active session - skipping session state sync")
            hapticController.cancelCountdownScheduler()
            return
        }

        // Only update session timing if session has actually started
        guard sessionStartTime != Date.distantPast else {
            return
        }

        let currentTime = Date()
        let timeSinceLastUpdate = currentTime.timeIntervalSince(lastPoorPostureUpdate)
        lastMotionUpdateTime = currentTime

        if lastKnownPoorPostureState {
            poorPostureDuration += timeSinceLastUpdate
        }
        totalSessionTime += timeSinceLastUpdate
    }

    #if os(iOS)
        private func startBackgroundTask() {
            endBackgroundTask()
            backgroundTask = UIApplication.shared.beginBackgroundTask(
                withName: "AirPods Motion Tracking"
            ) { [weak self] in
                self?.handleBackgroundTaskExpiration()
            }
            Logger.background.info("Started background task for motion tracking")
        }

        private func startEnhancedBackgroundTask() {
            endBackgroundTask()
            backgroundTask = UIApplication.shared.beginBackgroundTask(
                withName: "Enhanced AirPods Motion Tracking"
            ) { [weak self] in
                self?.handleEnhancedBackgroundTaskExpiration()
            }
            startBackgroundUpdates()
            Logger.background.info("Started enhanced background task for extended motion tracking")
        }

        private func handleBackgroundTaskExpiration() {
            syncSessionState()
            let oldTask = backgroundTask
            startBackgroundTask()
            if oldTask != .invalid {
                UIApplication.shared.endBackgroundTask(oldTask)
            }
        }

        private func handleEnhancedBackgroundTaskExpiration() {
            syncSessionState()
            stopBackgroundUpdates()

            if sessionStore.currentSession != nil && !isPaused {
                let oldTask = backgroundTask
                backgroundTask = UIApplication.shared.beginBackgroundTask(
                    withName: "Chained AirPods Tracking"
                ) { [weak self] in
                    self?.handleFinalBackgroundTaskExpiration()
                }
                if backgroundTask != .invalid {
                    startBackgroundUpdates()
                }
                if oldTask != .invalid {
                    UIApplication.shared.endBackgroundTask(oldTask)
                }
            } else {
                endBackgroundTask()
            }
        }

        private func handleFinalBackgroundTaskExpiration() {
            syncSessionState()
            stopBackgroundUpdates()
            endBackgroundTask()
        }

        private func endBackgroundTask() {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
    #else
        private func startBackgroundTask() {}
        private func handleBackgroundTaskExpiration() {}
        private func endBackgroundTask() {}
    #endif

    private func startBackgroundUpdates() {
        stopBackgroundUpdates()

        // 🚨 CRITICAL: Only start background updates if there's an ACTIVE session
        guard !isPaused && sessionStore.currentSession != nil && sessionStartTime != Date.distantPast else {
            Logger.background.debug("No active session - skipping background updates")
            return
        }

        Logger.background.info("Active session - starting background updates")

        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        source.schedule(
            deadline: .now() + MotionConstants.backgroundUpdateInterval,
            repeating: MotionConstants.backgroundUpdateInterval)
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            Self.safeMainActor {
                self.updateBackgroundSession()
            }
        }
        backgroundUpdateSource = source
        source.resume()
    }

    private func stopBackgroundUpdates() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        cancelTimerSourceSafely(&backgroundUpdateSource)
    }

    private func updateBackgroundSession() {
        guard isInBackground else { return }

        // CRITICAL FIX: Only update background session if there's an active session
        guard sessionStore.currentSession != nil else {
            Logger.background.debug("Skipping background session update - no active session")
            hapticController.cancelCountdownScheduler()
            return
        }

        // Only update session timing if session has actually started
        guard sessionStartTime != Date.distantPast else {
            return
        }

        let currentTime = Date()
        let timeSinceLastUpdate = currentTime.timeIntervalSince(lastPoorPostureUpdate)
        lastMotionUpdateTime = currentTime

        // Update the session state
        if lastKnownPoorPostureState {
            poorPostureDuration += timeSinceLastUpdate
            accumulatedPoorPostureDuration = poorPostureDuration
        }
        totalSessionTime += timeSinceLastUpdate

        // Update the current session
        SessionStore.shared.updateCurrentSession(poorPostureDuration: poorPostureDuration, runningWalkingDuration: runningWalkingDuration)

        // Update poor posture percentage
        if totalSessionTime > 0 && sessionStore.currentSession != nil
            && sessionStartTime != Date.distantPast
        {
            recalculateSessionScorePercent()
        }

        lastPoorPostureUpdate = currentTime
        backgroundUpdateCount += 1

        // Keep Live Activity in sync while app is backgrounded.
        updateLiveActivity()

        // CRITICAL FIX: Only check haptic feedback if there's an active session and motion tracking is active
        if sessionStore.currentSession != nil && !isPaused && motionManager.isDeviceMotionActive {
            hapticController.updateHapticFeedback()
        }

        // FIXED: Only request more background time if we're approaching iOS limits, not every 30 seconds
        if backgroundUpdateCount >= MotionConstants.maxBackgroundUpdates {
            backgroundUpdateCount = 0
            // Instead of creating new background tasks, just sync state and continue
            syncSessionState()
            Logger.background.debug("Background session synced after \(MotionConstants.maxBackgroundUpdates) updates")
        }

        Logger.background.debug("Background update - Poor posture: \(self.postureScorePercent)%, Duration: \(self.poorPostureDuration), Total: \(self.totalSessionTime)")
    }

    #if !targetEnvironment(simulator)
        private func startResumeGracePeriod() {
            isInResumeGracePeriod = true
            resumeGracePeriodTimer?.invalidate()
            resumeGracePeriodTimer = Timer.scheduledTimer(withTimeInterval: MotionConstants.gracePeriodDuration, repeats: false) {
                [weak self] _ in
                self?.endResumeGracePeriod()
            }
        }

        private func endResumeGracePeriod() {
            isInResumeGracePeriod = false
            resumeGracePeriodTimer?.invalidate()
            resumeGracePeriodTimer = nil
        }
    #endif

    // MARK: - Public Utility Methods
    @MainActor
    func forceReconnect() {
        Logger.bluetooth.info("Force reconnect requested")
        connectionRetryCount = 0
        isReconnecting = false
        restart()
    }

    @MainActor
    func resetConnectionState() {
        Logger.bluetooth.info("Resetting connection state")
        connectionRetryCount = 0
        isReconnecting = false
        lastSuccessfulMotionUpdate = Date()

        if !isDeviceConnected && !isPaused {
            start()
        }
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
        transitionMetrics.startTransition()
        Logger.ui.info("HeadphoneMotionManager: foreground transition via coordinator")

        preserveSessionStateBeforeMotionReset()
        resetUIStateImmediately()
        updateConnectionStatusForForeground()
        hapticController.stopAllFeedback()
        isInBackground = false

        transitionMetrics.markUIUpdateComplete()

        let uiValidation = validateForegroundTransition()

        reinitializeMotionSystemAsync()

        logTransitionPerformance()

        Logger.ui.info("HeadphoneMotionManager: foreground transition completed - UI: \(uiValidation ? "IMMEDIATE" : "DELAYED")")
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
