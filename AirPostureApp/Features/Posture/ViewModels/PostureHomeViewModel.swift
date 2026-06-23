import Foundation
import SwiftUI
import os

@MainActor
@Observable
final class PostureHomeViewModel {

    enum DelayedTaskID {
        static let initialConnectionCheck = "initialConnectionCheck"
        static let connectionProgressResult = "connectionProgressResult"
        static let startButtonSuccessReset = "startButtonSuccessReset"
        static let showAirPodsDropdown = "showAirPodsDropdown"
        static let resetConnectionProgress = "resetConnectionProgress"
        static let startAutoRetry = "startAutoRetry"
        static let airPodsConnectedCheck = "airPodsConnectedCheck"
        static let appBecameActiveCheck = "appBecameActiveCheck"
    }

    var startButtonState: StartButtonState = .idle
    var connectionProgress: Double = 0.0
    var connectionAttempts: Int = 0
    var shouldAutoRetry: Bool = false
    var retryCountdown: Int = 0
    var isFirstLaunch: Bool = true

    var showSettingsSheet: Bool = false
    var selectedSettingsTab: SettingsTab = .avatar
    var showAirPodsDropdown: Bool = false
    var isBluetoothPickerVisible: Bool = false

    var isSmartButtonPressed: Bool = false

    private var progressTimer: Timer?
    private var delayedTasks = DelayedTaskBag()
    private var wasPausedForSettings: Bool = false

    let motionManager: HeadphoneMotionManager
    let sessionStore: SessionStore
    #if os(iOS)
    let bluetoothManager: BluetoothManager
    #endif

    var postureHomeState: PostureHomeState {
        PostureHomeState(
            pitch: motionManager.pitch,
            roll: motionManager.roll,
            yaw: motionManager.yaw,
            postureState: motionManager.postureState,
            pitchHistory: motionManager.pitchHistory,
            postureScorePercent: motionManager.postureScorePercent,
            poorPostureDuration: motionManager.poorPostureDuration,
            totalSessionTime: motionManager.totalSessionTime,
            runningWalkingDuration: motionManager.runningWalkingDuration,
            isDeviceConnected: motionManager.isDeviceConnected,
            isPaused: motionManager.isPaused,
            connectionStatus: motionManager.connectionStatus,
            isInBackground: motionManager.isInBackground,
            isInWarningCountdown: motionManager.isInWarningCountdown,
            isInRecoveryCountdown: motionManager.isInRecoveryCountdown,
            warningCountdownSeconds: motionManager.warningCountdownSeconds,
            recoveryCountdownSeconds: motionManager.recoveryCountdownSeconds,
            poorPostureThreshold: motionManager.poorPostureThreshold,
            normalAirPodsAngle: motionManager.normalAirPodsAngle,
            isHapticFeedbackEnabled: motionManager.isHapticFeedbackEnabled
        )
    }

    #if os(iOS)
    init(
        motionManager: HeadphoneMotionManager,
        sessionStore: SessionStore,
        bluetoothManager: BluetoothManager
    ) {
        self.motionManager = motionManager
        self.sessionStore = sessionStore
        self.bluetoothManager = bluetoothManager
    }
    #else
    init(
        motionManager: HeadphoneMotionManager,
        sessionStore: SessionStore
    ) {
        self.motionManager = motionManager
        self.sessionStore = sessionStore
    }
    #endif

    // MARK: - Start Button

    func handleStartButtonPressed() {
        #if os(iOS)
        HapticManager.shared.impact(style: .heavy)
        HapticManager.shared.impact(style: .medium)
        #endif

        connectionAttempts += 1
        shouldAutoRetry = true

        startButtonState = .connecting
        connectionProgress = 0.0

        startConnectionProgress()

        let hasAirPods = motionManager.checkForAirPodsImmediate()

        if hasAirPods {
            simulateConnectionProgress(success: true)
        } else {
            simulateConnectionProgress(success: false)
        }
    }

    // MARK: - Connection Progress

    func startConnectionProgress() {
        progressTimer?.invalidate()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 0.1)) {
                self.connectionProgress += 0.02

                if self.connectionProgress >= 1.0 {
                    timer.invalidate()
                    self.connectionProgress = 1.0
                }
            }
        }
    }

    func simulateConnectionProgress(success: Bool) {
        delayedTasks.schedule(id: DelayedTaskID.connectionProgressResult, after: 0.2) { [weak self] in
            guard let self else { return }

            if success {
                #if os(iOS)
                HapticManager.shared.impact(style: .light)
                #endif

                startButtonState = .success
                motionManager.resetSession(shouldStartNew: true)
                motionManager.start()

                delayedTasks.schedule(id: DelayedTaskID.startButtonSuccessReset, after: 0.2) { [weak self] in
                    self?.startButtonState = .idle
                    self?.connectionProgress = 0.0
                }
            } else {
                startButtonState = .error

                delayedTasks.schedule(id: DelayedTaskID.showAirPodsDropdown, after: 1.5) { [weak self] in
                    guard let self else { return }
                    Logger.bluetooth.debug("About to show AirPods dropdown")
                    showAirPodsDropdown = true
                    Logger.bluetooth.debug("AirPods dropdown shown, calling connectToPairedAirPodsDirectly")
                    #if os(iOS)
                    bluetoothManager.connectToPairedAirPodsDirectly()
                    #endif
                }

                delayedTasks.schedule(id: DelayedTaskID.resetConnectionProgress, after: 2.0) { [weak self] in
                    self?.connectionProgress = 0.0
                }
            }
        }
    }

    // MARK: - Auto Retry

    func startAutoRetry() {
        retryCountdown = 5
        startButtonState = .retrying

        progressTimer?.invalidate()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            retryCountdown -= 1

            if retryCountdown <= 0 {
                timer.invalidate()
                handleStartButtonPressed()
            }
        }
    }

    func cancelAutoRetry() {
        progressTimer?.invalidate()
        progressTimer = nil
        retryCountdown = 0
        startButtonState = .idle
        connectionProgress = 0.0
    }

    // MARK: - State Reset

    func resetStartButtonState() {
        progressTimer?.invalidate()
        progressTimer = nil
        retryCountdown = 0
        startButtonState = .idle
        connectionProgress = 0.0
    }

    func tearDownTransientConnectionUI() {
        shouldAutoRetry = false
        delayedTasks.cancelAll()
        resetStartButtonState()
        showAirPodsDropdown = false
        isBluetoothPickerVisible = false
        #if os(iOS)
        bluetoothManager.onAlertStateChange = nil
        #endif
    }

    // MARK: - Session Control

    func stopSession() {
        #if os(iOS)
        HapticManager.shared.impact(style: .heavy)
        #endif
        if sessionStore.currentSession != nil {
            sessionStore.endCurrentSession(
                poorPostureDuration: motionManager.poorPostureDuration,
                activeSessionDuration: motionManager.totalSessionTime,
                runningWalkingDuration: motionManager.runningWalkingDuration
            )
        }
        motionManager.stop()
    }

    func togglePause() {
        #if os(iOS)
        HapticManager.shared.impact(style: .heavy)
        #endif
        motionManager.togglePause()
    }

    func reconnect() {
        #if os(iOS)
        HapticManager.shared.impact(style: .medium)
        #endif
        motionManager.forceReconnect()
    }

    // MARK: - Settings Sheet

    func handleSettingsSheetChange(_ isPresented: Bool) {
        if isPresented {
            if !motionManager.isPaused && motionManager.isDeviceConnected {
                wasPausedForSettings = true
                motionManager.togglePause()
                Logger.session.info("Paused session for settings")
            } else {
                wasPausedForSettings = false
            }
        } else {
            if wasPausedForSettings && motionManager.isPaused {
                motionManager.togglePause()
                Logger.session.info("Resumed session after settings")
            }
            wasPausedForSettings = false
        }
    }

    // MARK: - Lifecycle

    func handleInitialAppearance() {
        if isFirstLaunch {
            delayedTasks.schedule(id: DelayedTaskID.initialConnectionCheck, after: 0.2) { [weak self] in
                Logger.bluetooth.debug("Delayed AirPods connection check starting...")
                self?.motionManager.checkConnectionStatusForUI()
            }

            Logger.ui.debug("ContentView loaded - connection check deferred to prevent freeze")
        } else {
            motionManager.checkConnectionStatusForUI()
        }

        if isFirstLaunch {
            Logger.ui.info("First launch setup completed")
            isFirstLaunch = false
        }
    }

    func handleAirPodsConnectedNotification() {
        Logger.bluetooth.info("Received AirPods connected notification, checking connection...")
        delayedTasks.schedule(id: DelayedTaskID.airPodsConnectedCheck, after: 1.0) { [weak self] in
            self?.motionManager.forceCheckAirPodsConnection()
        }
    }

    func handleAppBecameActive() {
        Logger.bluetooth.debug("App became active, checking for AirPods...")
        delayedTasks.schedule(id: DelayedTaskID.appBecameActiveCheck, after: 0.5) { [weak self] in
            self?.motionManager.forceCheckAirPodsConnection()
            #if os(iOS)
            NotificationManager.shared.forceRefreshPermissionStatus()
            #endif
        }
    }

    // MARK: - Connection State Monitoring

    func handleConnectionStateChanged(isConnected: Bool) {
        if !isConnected && startButtonState == .connecting {
            startButtonState = .error
            cancelAutoRetry()

            delayedTasks.schedule(id: DelayedTaskID.startAutoRetry, after: 1.0) { [weak self] in
                self?.startAutoRetry()
            }
        }
    }

    // MARK: - AirPods Dropdown

    func handleAirPodsDropdownComplete() {
        startButtonState = .idle
        connectionProgress = 0.0

        if isBluetoothPickerVisible {
            isBluetoothPickerVisible = false
            #if os(iOS)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let presentedVC = window.rootViewController?.presentedViewController,
               presentedVC is UIAlertController {
                presentedVC.dismiss(animated: true)
            }
            #endif
        }
    }

    // MARK: - Bluetooth Callbacks

    #if os(iOS)
    func setupBluetoothCallbacks() {
        Logger.bluetooth.debug("Setting up BluetoothManager callback")
        bluetoothManager.onAlertStateChange = { [weak self] isPresented in
            guard let self else { return }
            Logger.bluetooth.debug("Bluetooth alert state changed: \(isPresented ? "presented" : "dismissed")")
            Logger.bluetooth.debug("showAirPodsDropdown: \(self.showAirPodsDropdown)")
            Logger.bluetooth.debug("isBluetoothPickerVisible: \(self.isBluetoothPickerVisible)")

            if isPresented {
                isBluetoothPickerVisible = true
            } else {
                isBluetoothPickerVisible = false
                if showAirPodsDropdown {
                    Logger.bluetooth.debug("Auto-closing AirPods dropdown due to alert dismissal")
                    showAirPodsDropdown = false
                    startButtonState = .idle
                    connectionProgress = 0.0
                } else {
                    Logger.bluetooth.debug("AirPods dropdown is already hidden, no action needed")
                }
            }
        }
    }
    #endif
}
