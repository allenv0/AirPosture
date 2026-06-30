import AVFoundation
import Combine
@preconcurrency import CoreMotion
import Foundation
import os

#if os(iOS)
import UIKit
#endif

// MARK: - Delegate Protocol

/// Actions the coordinator cannot perform alone because they require access
/// to the parent's `CMHeadphoneMotionManager`, motion-update lifecycle, or
/// session-persistence logic.
@MainActor
protocol ConnectionCoordinatorDelegate: AnyObject {
    var motionManager: CMHeadphoneMotionManager { get set }
    var isPaused: Bool { get }
    var isForegroundTransitioning: Bool { get }
    var sessionStore: SessionStore { get }
    var liveActivityUpdateTimer: AnyCancellable? { get set }

    func startMotionUpdatesInternal()
    func parentRestart()
    func parentStart()
    func parentStop()
    func saveCurrentSessionIfNeeded()
}

// MARK: - Connection Coordinator

/// Owns all AirPods / Bluetooth connection lifecycle state and logic:
/// device detection, reconnection scheduling, connection monitoring, and
/// grace-period handling.
///
/// `HeadphoneMotionManager` creates and owns this coordinator, mirrors its
/// observable connection state, and provides system-level actions through
/// the `ConnectionCoordinatorDelegate` protocol. This follows the same
/// service-plus-mirror convention used by `HeadphoneMotionPipeline`,
/// `PostureEvaluationService`, and `SessionTimingService`.
@Observable
@MainActor
final class HeadphoneConnectionCoordinator {

    // MARK: - Delegate

    weak var delegate: (any ConnectionCoordinatorDelegate)?

    // MARK: - Connection State (mirrored onto manager's @Observable properties)

    private(set) var isDeviceConnected: Bool = false
    private(set) var connectionStatus: String = "Not started"
    private(set) var connectedDeviceName: String = ""
    private(set) var isInGracePeriod: Bool = false
    private(set) var connectionLostTime: Date?
    var showConnectionLostAlert: Bool = false

    /// Tracks whether the session is paused due to a connection interruption.
    /// Mirrored onto the manager so `updateSessionTimers` can gate on it.
    private(set) var sessionPaused: Bool = false

    // MARK: - Hardware Detection Results

    private(set) var connectionMethod: ConnectionMethod = .original
    private(set) var airPodsModel: AirPodsModel = .unknown
    private(set) var hasMotionCapability: Bool = false
    private(set) var hasGyroscope: Bool = false
    private(set) var hardwareDetectionSuccessful: Bool = false

    enum ConnectionMethod: String, CaseIterable {
        case original = "Original"
        case enhanced = "Enhanced"
        case hardware = "Hardware"
    }

    // MARK: - Private State

    private var connectionRetryCount: Int = 0
    private var isReconnecting: Bool = false
    private let maxRetryAttempts: Int = MotionConstants.maxRetryAttempts
    private let gracePeriodDuration: TimeInterval = MotionConstants.gracePeriodDuration

    private var reconnectionTimer: Timer?
    private var connectionMonitoringTimer: Timer?
    private var connectionMonitoringSource: DispatchSourceTimer?
    private var enhancedDetectionEnabled: Bool = true

    #if os(iOS)
    private let hardwareDetector = MotionHardwareDetector()
    #endif

    #if targetEnvironment(simulator)
    private let isSimulator = true
    #else
    private let isSimulator = false
    #endif

    // MARK: - Mirroring Helpers (called from manager's non-connection code)

    /// Called by the manager when non-connection code confirms the device is
    /// connected (e.g. inside `processMotionData` / `handleSuccessfulMotionData`).
    func confirmDeviceConnected(deviceName: String = "") {
        isDeviceConnected = true
        if !deviceName.isEmpty { connectedDeviceName = deviceName }
        connectionRetryCount = 0
        isReconnecting = false
    }

    /// Called by the manager when non-connection code sets the device as
    /// disconnected (e.g. inside `handleNoMotionData` / `stop`).
    func markDisconnected(status: String = "Not connected") {
        isDeviceConnected = false
        connectedDeviceName = ""
        connectionStatus = status
    }

    /// Updates only the connection status string without changing
    /// `isDeviceConnected` or `connectedDeviceName`. Used by foreground
    /// transition and other UI-state-only updates.
    func setStatusOnly(_ status: String) {
        connectionStatus = status
    }

    /// Resets retry count and reconnecting flag on a fresh start / reconnect.
    func resetRetryState() {
        connectionRetryCount = 0
        isReconnecting = false
    }

    /// Returns the current retry count so the manager can use it for delay
    /// calculations.
    var retryCount: Int { connectionRetryCount }
    var reconnecting: Bool { isReconnecting }

    // MARK: - Connection Detection

    /// Checks whether AirPods/Beats are connected via audio session or
    /// hardware detection. Returns `true` and updates internal state
    /// (`connectionMethod`, `airPodsModel`, capabilities) when connected.
    func checkAirPodsAudioConnection() async -> Bool {
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

    /// Quick synchronous check that AirPods are visible in the current audio
    /// route. Suitable for button taps and immediate UI queries.
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
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP
                || output.portType == .bluetoothLE
            {
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

    // MARK: - Connection Status Checks

    /// Updates `isDeviceConnected` and `connectionStatus` by checking the
    /// current audio route. Safe to call from UI contexts.
    func checkConnectionStatusForUI() {
        if isSimulator {
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

    private func checkConnectionStatusForUIAsync() async {
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

        if !isDeviceConnected && !(delegate?.isPaused ?? false) && !isReconnecting {
            scheduleOptimizedReconnection()
        }
    }

    // MARK: - Force Connection Check

    /// Forcefully re-evaluates the AirPods connection. Stops current motion
    /// updates, creates a fresh motion manager, and attempts connection.
    func forceCheckAirPodsConnection() {
        Logger.bluetooth.info("Force checking AirPods connection")

        if isSimulator { return }

        Task { @MainActor in
            await forceCheckAirPodsConnectionAsync()
        }
    }

    private func forceCheckAirPodsConnectionAsync() async {
        if await checkAirPodsAudioConnection() {
            Logger.bluetooth.info("AirPods found immediately via audio session")
            isDeviceConnected = true
            connectionStatus = "AirPods connected"
            return
        }

        guard let delegate = delegate else { return }

        delegate.motionManager.stopDeviceMotionUpdates()
        delegate.motionManager = CMHeadphoneMotionManager()

        isDeviceConnected = false
        connectedDeviceName = ""
        connectionStatus = "Checking for AirPods..."

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            Task { @MainActor in
                await self?.attemptConnection()
            }
        }
    }

    // MARK: - Full Connection Attempt

    /// Attempts to establish a connection with AirPods. Starts motion updates
    /// if the device is available, and retries with a timeout.
    func attemptConnection() async {
        Logger.bluetooth.info("Attempting to connect to AirPods")

        guard let delegate = delegate else { return }

        if await checkAirPodsAudioConnection() {
            Logger.bluetooth.info("AirPods already connected via audio session")
            connectionStatus = "AirPods connected"
            isDeviceConnected = true
            return
        }

        guard delegate.motionManager.isDeviceMotionAvailable else {
            connectionStatus = "AirPods motion not available"
            Logger.bluetooth.warning("Device motion not available")

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                Task { @MainActor in
                    await self?.attemptConnection()
                }
            }
            return
        }

        connectionStatus = "Connecting to AirPods..."
        Logger.bluetooth.info("Device motion available, starting updates")

        delegate.startMotionUpdatesInternal()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            Task { @MainActor in
                guard let self, let delegate = self.delegate else { return }
                if !self.isDeviceConnected {
                    Logger.bluetooth.warning("Connection timeout, checking audio session")
                    if await self.checkAirPodsAudioConnection() {
                        Logger.bluetooth.info("Found AirPods via audio session on retry")
                        self.connectionStatus = "AirPods connected"
                        self.isDeviceConnected = true
                    } else {
                        self.connectionStatus =
                            "No AirPods found - Connect your AirPods and tap 'New Session'"
                    }
                }
            }
        }
    }

    // MARK: - Optimized Reconnection

    private func scheduleOptimizedReconnection() {
        guard !isReconnecting else { return }
        isReconnecting = true

        let baseDelay = 1.0
        let adaptiveDelay = min(baseDelay * pow(1.5, Double(connectionRetryCount)), 10.0)

        Logger.bluetooth.info("Scheduling optimized reconnection in \(adaptiveDelay)s (attempt \(self.connectionRetryCount + 1))")

        DispatchQueue.main.asyncAfter(deadline: .now() + adaptiveDelay) { [weak self] in
            guard let self = self else { return }

            if !self.isDeviceConnected && !(self.delegate?.isPaused ?? true) {
                self.attemptOptimizedReconnection()
            } else {
                self.isReconnecting = false
            }
        }
    }

    private func attemptOptimizedReconnection() {
        Logger.bluetooth.info("Attempting optimized AirPods reconnection")

        guard let delegate = delegate else { return }

        if connectionRetryCount < 3 {
            // Quick restart for first few attempts
            delegate.parentRestart()
        } else if connectionRetryCount < 6 {
            // Full reset for persistent issues
            performFullConnectionReset()
        } else {
            Logger.bluetooth.error("Maximum reconnection attempts reached - waiting for user action")
            isReconnecting = false
            return
        }

        connectionRetryCount += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.verifyReconnectionSuccess()
        }
    }

    private func performFullConnectionReset() {
        Logger.bluetooth.info("Performing full connection reset")

        guard let delegate = delegate else { return }

        delegate.parentStop()

        delegate.motionManager = CMHeadphoneMotionManager()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let delegate = self?.delegate else { return }
            delegate.parentStart()
        }
    }

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

    // MARK: - Connection Monitoring

    /// Starts event-driven (route change) and polling (2.5s) monitoring of
    /// the AirPods connection. Called once from the manager's `init`.
    func startConnectionMonitoring() {
        connectionMonitoringTimer?.invalidate()
        connectionMonitoringTimer = nil
        connectionMonitoringSource?.cancel()
        connectionMonitoringSource = nil

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

        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        source.schedule(deadline: .now() + 2.5, repeating: 2.5)
        source.setEventHandler { [weak self] in
            #if !targetEnvironment(simulator)
            Task { @MainActor in
                guard let self, !(self.delegate?.isForegroundTransitioning ?? true) else { return }
                let connected = await self.checkAirPodsAudioConnection()
                if connected != self.isDeviceConnected {
                    self.isDeviceConnected = connected
                    self.connectionStatus = connected ? "AirPods connected" : "Connect your AirPods"
                }
            }
            #endif
        }
        connectionMonitoringSource = source
        source.resume()
    }

    // MARK: - Device Status Check

    /// Checks whether motion data has been received recently. If silence
    /// exceeds the timeout, triggers connection loss handling.
    /// Called from the manager's periodic timer.
    func checkDeviceStatus(timeSinceLastMotion: TimeInterval) {
        #if !targetEnvironment(simulator)
        // isInResumeGracePeriod is managed by the parent; we gate on isDeviceConnected only.
        #endif
        guard timeSinceLastMotion > MotionConstants.connectionTimeoutInterval,
              isDeviceConnected,
              !(delegate?.isPaused ?? true) else { return }

        handleConnectionLoss()
    }

    // MARK: - Connection Loss / Recovery / Grace Period

    func handleConnectionLoss() {
        guard let delegate = delegate else { return }

        guard connectionLostTime == nil && delegate.sessionStore.currentSession != nil else {
            if connectionLostTime == nil && delegate.sessionStore.currentSession == nil {
                isDeviceConnected = false
                connectedDeviceName = ""
                connectionStatus = "Bluetooth disconnected"
                Logger.bluetooth.info("Bluetooth disconnected - No active session")

                #if canImport(ActivityKit)
                if #available(iOS 16.1, *) {
                    LiveActivityController.shared.end(immediate: true)
                }
                #endif

                delegate.liveActivityUpdateTimer?.cancel()
                delegate.liveActivityUpdateTimer = nil
            }
            return
        }

        connectionLostTime = Date()
        isDeviceConnected = false
        connectedDeviceName = ""
        isInGracePeriod = true
        sessionPaused = true
        connectionStatus = "Bluetooth connection lost - Attempting to reconnect..."

        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            LiveActivityController.shared.end(immediate: true)
        }
        #endif

        delegate.liveActivityUpdateTimer?.cancel()
        delegate.liveActivityUpdateTimer = nil

        reconnectionTimer = Timer.scheduledTimer(
            withTimeInterval: gracePeriodDuration, repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleGracePeriodExpired()
            }
        }

        showConnectionLostAlert = true

        NotificationManager.shared.sendConnectionLostNotification()

        Logger.bluetooth.warning("Bluetooth connection lost - Starting grace period")
    }

    func handleReconnection() {
        guard let lostTime = connectionLostTime else { return }

        let disconnectionDuration = Date().timeIntervalSince(lostTime)

        reconnectionTimer?.invalidate()
        reconnectionTimer = nil

        connectionLostTime = nil
        isInGracePeriod = false
        sessionPaused = false
        connectionStatus = "Bluetooth reconnected after \(Int(disconnectionDuration))s"

        showConnectionLostAlert = false

        Logger.bluetooth.info("Bluetooth reconnected after \(disconnectionDuration) seconds")
    }

    private func handleGracePeriodExpired() {
        guard isInGracePeriod else { return }

        delegate?.saveCurrentSessionIfNeeded()

        isInGracePeriod = false
        connectionStatus = "Session saved - Bluetooth connection lost"
        Logger.bluetooth.warning("Grace period expired - Session saved due to Bluetooth connection loss")
    }

    func handleConnectionError(_ error: Error) {
        connectionStatus = "Error: \(error.localizedDescription)"
        isDeviceConnected = false
        connectedDeviceName = ""
        handleConnectionLoss()
    }

    // MARK: - Public Actions

    /// Forcefully restarts the reconnection process regardless of current
    /// state. Safe to call from UI (e.g. from `forceReconnect` button).
    func forceReconnect() {
        Logger.bluetooth.info("Force reconnect requested")
        connectionRetryCount = 0
        isReconnecting = false
        delegate?.parentRestart()
    }

    /// Resets the connection state and attempts a fresh start if not already
    /// connected and not paused.
    func resetConnectionState() {
        Logger.bluetooth.info("Resetting connection state")
        connectionRetryCount = 0
        isReconnecting = false

        if !isDeviceConnected && !(delegate?.isPaused ?? true) {
            delegate?.parentStart()
        }
    }

    /// Dismisses the "connection lost" alert in the UI.
    func dismissConnectionAlert() {
        showConnectionLostAlert = false
    }

    // MARK: - Cleanup

    /// Cleans up all connection timers and sources. Called from the manager's
    /// own `cleanupAllTimersAndConnections` and `stop` methods.
    func cleanupConnectionTimers() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        connectionMonitoringTimer?.invalidate()
        connectionMonitoringTimer = nil
        connectionMonitoringSource?.cancel()
        connectionMonitoringSource = nil
    }

    /// Resets all state to a clean disconnected base. Used when starting
    /// fresh or after a full teardown.
    func resetToDisconnected() {
        isDeviceConnected = false
        connectedDeviceName = ""
        connectionStatus = "Not started"
        isInGracePeriod = false
        connectionLostTime = nil
        sessionPaused = false
        connectionRetryCount = 0
        isReconnecting = false
        showConnectionLostAlert = false
        cleanupConnectionTimers()
    }
}
