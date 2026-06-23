import AVFoundation
import Foundation
import os

#if os(iOS)
import UIKit
#endif

@MainActor
protocol ConnectionDetecting: AnyObject {
    var isDeviceConnected: Bool { get }
    var connectionStatus: String { get }
    var connectedDeviceName: String { get }
    var isInGracePeriod: Bool { get }
    var connectionLostTime: Date? { get }
    var showConnectionLostAlert: Bool { get set }

    func checkForAirPodsImmediate() -> Bool
    func checkConnectionStatusForUI()
    func forceCheckAirPodsConnection()
    func handleConnectionLoss(hasActiveSession: Bool, notificationManager: NotificationManaging)
    func handleReconnection()
    func updateConnected(_ connected: Bool, deviceName: String)
}

@Observable
@MainActor
final class ConnectionDetectionService: ConnectionDetecting {
    private(set) var isDeviceConnected: Bool = false
    private(set) var connectionStatus: String = "Not started"
    private(set) var connectedDeviceName: String = ""
    private(set) var isInGracePeriod: Bool = false
    private(set) var connectionLostTime: Date?
    var showConnectionLostAlert: Bool = false

    private var reconnectionTimer: Timer?
    private var connectionMonitoringTimer: Timer?
    private var connectionMonitoringSource: DispatchSourceTimer?
    private var isReconnecting: Bool = false
    private var connectionRetryCount: Int = 0

    private let gracePeriodDuration: TimeInterval = MotionConstants.gracePeriodDuration
    private let maxRetryAttempts: Int = MotionConstants.maxRetryAttempts

    #if os(iOS)
    private let hardwareDetector = MotionHardwareDetector()
    #endif

    #if targetEnvironment(simulator)
    private let isSimulator = true
    #else
    private let isSimulator = false
    #endif

    func checkForAirPodsImmediate() -> Bool {
        if isSimulator { return true }

        #if os(iOS)
        if hardwareDetector.checkAirPodsAudioConnectionEnhanced() {
            return true
        }
        #endif

        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
                let deviceName = output.portName.lowercased()
                if deviceName.contains("airpods") || deviceName.contains("beats") {
                    return true
                }
            }
        }

        for input in currentRoute.inputs {
            if input.portType == .bluetoothHFP {
                let deviceName = input.portName.lowercased()
                if deviceName.contains("airpods") || deviceName.contains("beats") {
                    return true
                }
            }
        }

        return false
    }

    func checkConnectionStatusForUI() {
        if isSimulator {
            isDeviceConnected = true
            connectedDeviceName = "Simulator AirPods"
            connectionStatus = "Simulator Mock Mode: Connected"
            return
        }

        if checkForAirPodsImmediate() {
            isDeviceConnected = true
            connectionStatus = "AirPods connected"
        } else {
            isDeviceConnected = false
            connectedDeviceName = ""
            connectionStatus = "Connect your AirPods"
        }
    }

    func forceCheckAirPodsConnection() {
        if isSimulator { return }

        if checkForAirPodsImmediate() {
            isDeviceConnected = true
            connectionStatus = "AirPods connected"
        } else {
            isDeviceConnected = false
            connectedDeviceName = ""
            connectionStatus = "Checking for AirPods..."
        }
    }

    func handleConnectionLoss(hasActiveSession: Bool, notificationManager: NotificationManaging) {
        guard connectionLostTime == nil && hasActiveSession else {
            if connectionLostTime == nil && !hasActiveSession {
                isDeviceConnected = false
                connectedDeviceName = ""
                connectionStatus = "Bluetooth disconnected"
            }
            return
        }

        connectionLostTime = Date()
        isDeviceConnected = false
        connectedDeviceName = ""
        isInGracePeriod = true
        connectionStatus = "Bluetooth connection lost - Attempting to reconnect..."

        reconnectionTimer = Timer.scheduledTimer(
            withTimeInterval: gracePeriodDuration, repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleGracePeriodExpired()
            }
        }

        showConnectionLostAlert = true
        notificationManager.sendConnectionLostNotification()
    }

    func handleReconnection() {
        guard let lostTime = connectionLostTime else { return }

        let disconnectionDuration = Date().timeIntervalSince(lostTime)

        reconnectionTimer?.invalidate()
        reconnectionTimer = nil

        connectionLostTime = nil
        isInGracePeriod = false
        connectionStatus = "Bluetooth reconnected after \(Int(disconnectionDuration))s"

        showConnectionLostAlert = false
    }

    func updateConnected(_ connected: Bool, deviceName: String = "") {
        isDeviceConnected = connected
        if connected {
            connectedDeviceName = deviceName
            connectionStatus = "AirPods connected"
            connectionRetryCount = 0
            isReconnecting = false
        }
    }

    func resetRetryCount() {
        connectionRetryCount = 0
        isReconnecting = false
    }

    func incrementRetryCount() {
        connectionRetryCount += 1
    }

    var retryCount: Int { connectionRetryCount }
    var maxRetriesReached: Bool { connectionRetryCount >= maxRetryAttempts }
    var reconnecting: Bool { isReconnecting }
    var hardwareDetectorRef: MotionHardwareDetector {
        #if os(iOS)
        return hardwareDetector
        #else
        fatalError("No hardware detector on macOS")
        #endif
    }

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
                let connected = self.checkForAirPodsImmediate()
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
                guard let self else { return }
                let connected = self.checkForAirPodsImmediate()
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

    func cleanupTimers() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        connectionMonitoringTimer?.invalidate()
        connectionMonitoringTimer = nil
        connectionMonitoringSource?.cancel()
        connectionMonitoringSource = nil
    }

    private func handleGracePeriodExpired() {
        guard isInGracePeriod else { return }
        isInGracePeriod = false
        connectionStatus = "Session saved - Bluetooth connection lost"
    }
}
