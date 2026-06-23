#if os(iOS)
import UIKit
import CoreBluetooth
import AVFoundation
import AudioToolbox
import MediaPlayer
#endif
import Combine
import SwiftUI
import os

#if os(iOS)
struct BluetoothDevice {
    let name: String
    let identifier: String
    let isConnected: Bool
    let isPaired: Bool
    let deviceType: DeviceType

    enum DeviceType {
        case airPods
        case otherAudio
        case generic
    }
}

@MainActor
class BluetoothManager: NSObject, ObservableObject {
    @Published var isBluetoothEnabled = false
    @Published var isScanning = false
    @Published var availableDevices: [BluetoothDevice] = []
    @Published var connectionStatus = "Not connected"

    // Callback to notify ContentView when alerts are presented/dismissed
    var onAlertStateChange: ((Bool) -> Void)?

    private var centralManager: CBCentralManager?
    private var discoveredPeripherals: [CBPeripheral] = []
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        setupCentralManager()
    }

    private func setupCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)

        // 🚨 CRITICAL FIX: Setup audio session asynchronously to prevent freezing on app launch
        setupAudioSessionAsync()
    }

    private func setupAudioSessionAsync() {
        // 🛡️ Perform audio session setup on background queue to prevent main thread blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let audioSession = AVAudioSession.sharedInstance()
            do {
                // FIXED: Use .playback instead of .playAndRecord to prevent AirPods from switching to hands-free mode
                // This maintains high-quality A2DP audio for Spotify while still allowing motion tracking
                try audioSession.setCategory(.playback, mode: .default, options: [
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .mixWithOthers  // Allow other apps (Spotify, etc.) to play audio simultaneously at full volume
                ])
                try audioSession.setActive(true)
                Logger.bluetooth.info("Audio session configured for high-quality Bluetooth audio")
            } catch {
                Logger.bluetooth.error("Failed to setup audio session: \(error)")
            }
        }
    }

    func showBluetoothDevicePicker() {
        guard let centralManager = centralManager else { return }

        if centralManager.state == .poweredOn {
            // Skip device list - go directly to system audio picker
            openSystemAudioRoutePicker()
        } else {
            presentBluetoothDisabledAlert()
        }
    }

    // Direct system audio picker (like Spotify/Overcast)
    private func openSystemAudioRoutePicker() {
        Logger.bluetooth.debug("openSystemAudioRoutePicker called")
        Logger.bluetooth.debug("onAlertStateChange callback is \(self.onAlertStateChange != nil ? "SET" : "NIL")")

        Logger.bluetooth.debug("Calling onAlertStateChange(true) - system picker presented")
        onAlertStateChange?(true)

        // Create the route picker view - this is what Spotify/Overcast use
        let routePickerView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        routePickerView.showsVolumeSlider = false
        routePickerView.showsRouteButton = true

        // Add it temporarily to the current view to trigger the picker
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            Logger.bluetooth.error("Could not find window to present route picker")
            return
        }

        // Add the route picker to the window temporarily
        window.addSubview(routePickerView)
        for subview in routePickerView.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }

        // Remove the temporary view after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            routePickerView.removeFromSuperview()
        }

        // NEW ROBUST APPROACH: Monitor multiple indicators that the picker was dismissed
        setupSystemPickerDismissalMonitoring()

        connectionStatus = "Audio route picker opened"
    }

    @MainActor
    private func handleSystemRoutePickerDismissed() {
        Logger.bluetooth.debug("handleSystemRoutePickerDismissed called")
        Logger.bluetooth.debug("onAlertStateChange callback is \(self.onAlertStateChange != nil ? "SET" : "NIL")")

        // Clean up any existing monitoring
        cleanupDismissalMonitoring()

        // Notify ContentView that system picker was dismissed
        Logger.bluetooth.debug("Calling onAlertStateChange(false) - system picker dismissed")
        onAlertStateChange?(false)
    }

    private func setupSystemPickerDismissalMonitoring() {
        Logger.bluetooth.debug("Setting up robust dismissal monitoring")

        // Store monitoring state to avoid multiple dismissal handling
        var isMonitoringActive = true

        func handleDismissal(reason: String) {
            guard isMonitoringActive else {
                Logger.bluetooth.debug("Dismissal already handled, ignoring: \(reason)")
                return
            }
            isMonitoringActive = false

            Logger.bluetooth.debug("Handling system picker dismissal - reason: \(reason)")
            cleanupDismissalMonitoring()

            // Add small delay to ensure the system UI is fully dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.handleSystemRoutePickerDismissed()
            }
        }

        // 1. Monitor audio route changes (when user actually changes device)
        let routeChangeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            Logger.bluetooth.debug("Route change detected - picker likely dismissed")
            handleDismissal(reason: "route change")
        }

        // 2. Monitor app becoming active (when user returns from system UI)
        let didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] notification in
            Logger.bluetooth.debug("App became active - user likely returned from system picker")
            handleDismissal(reason: "app became active")
        }

        // 3. Monitor window scene activation
        var windowSceneObserver: NSObjectProtocol?
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowSceneObserver = NotificationCenter.default.addObserver(forName: UIWindowScene.didActivateNotification, object: windowScene, queue: .main) { [weak self] notification in
                Logger.bluetooth.debug("Window focus regained - system picker likely dismissed")
                handleDismissal(reason: "window scene activated")
            }
        }

        // Store cleanup function
        let cleanup = {
            NotificationCenter.default.removeObserver(routeChangeObserver)
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            if let observer = windowSceneObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        objc_setAssociatedObject(self, "dismissalCleanup", cleanup, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // 4. Timeout fallback - auto-dismiss after reasonable time
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            Logger.bluetooth.warning("Timeout reached - forcing dismissal handling")
            handleDismissal(reason: "timeout")
        }
    }

    private func cleanupDismissalMonitoring() {
        if let cleanup = objc_getAssociatedObject(self, "dismissalCleanup") as? (() -> Void) {
            cleanup()
            objc_setAssociatedObject(self, "dismissalCleanup", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func connectToPairedAirPodsDirectly() {
        Logger.bluetooth.debug("connectToPairedAirPodsDirectly called")
        Logger.bluetooth.debug("onAlertStateChange callback is \(self.onAlertStateChange != nil ? "SET" : "NIL")")

        // Check for paired AirPods immediately using existing method
        let pairedDevices = getPairedAudioDevices()
        let pairedAirPods = pairedDevices.filter { device in
            device.isPaired && device.deviceType == .airPods
        }

        if let airPods = pairedAirPods.first {
            Logger.bluetooth.info("Found paired AirPods device")
            // Try to connect directly
            connectToPairedDevice(airPods)
        } else {
            Logger.bluetooth.info("No paired AirPods found, showing device picker")
            // Fallback to device picker if no paired AirPods found
            showBluetoothDevicePicker()
        }
    }

    private func loadAvailableDevices() {
        availableDevices.removeAll()
        connectionStatus = "Scanning for devices..."

        // Refresh audio session first
        setupAudioSessionAsync()

        // Get paired devices from system
        let pairedDevices = getPairedAudioDevices()
        availableDevices.append(contentsOf: pairedDevices)

        Logger.bluetooth.debug("Found \(pairedDevices.count) paired/connected audio devices")

        // Start scanning for discoverable devices
        startScanning()

        // If no devices found after initial scan, add some helpful info
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.availableDevices.isEmpty == true {
                self?.connectionStatus = "No devices found. Make sure your AirPods are nearby and in pairing mode."
            }
        }
    }

    private func getPairedAudioDevices() -> [BluetoothDevice] {
        var devices: [BluetoothDevice] = []

        // Check current audio route for connected devices
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        // Check outputs (speakers/headphones)
        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
                let device = BluetoothDevice(
                    name: output.portName,
                    identifier: output.uid,
                    isConnected: true,
                    isPaired: true,
                    deviceType: output.portName.lowercased().contains("airpods") ? .airPods : .otherAudio
                )
                devices.append(device)
                Logger.bluetooth.debug("Found connected audio device of type: \(String(describing: device.deviceType))")
            }
        }

        // Check inputs (microphones)
        for input in currentRoute.inputs {
            if input.portType == .bluetoothHFP {
                // Avoid duplicates
                if !devices.contains(where: { $0.name == input.portName }) {
                    let device = BluetoothDevice(
                        name: input.portName,
                        identifier: input.uid,
                        isConnected: true,
                        isPaired: true,
                        deviceType: input.portName.lowercased().contains("airpods") ? .airPods : .otherAudio
                    )
                    devices.append(device)
                    Logger.bluetooth.debug("Found connected audio input of type: \(String(describing: device.deviceType))")
                }
            }
        }

        // Check for paired but disconnected devices
        Logger.bluetooth.debug("Checking for available audio inputs")
        let availableInputs = audioSession.availableInputs ?? []
        for input in availableInputs {
            if input.portType == .bluetoothHFP || input.portType == .bluetoothA2DP || input.portType == .bluetoothLE {
                // Check if this device is already in our connected list
                if !devices.contains(where: { $0.name == input.portName }) {
                    let inputName = input.portName.lowercased()
                    let isAirPods = inputName.contains("airpods") ||
                                   inputName.contains("beats") ||
                                   inputName.contains("powerbeats") ||
                                   inputName.contains("studio")

                    let device = BluetoothDevice(
                        name: input.portName,
                        identifier: input.uid,
                        isConnected: false,
                        isPaired: true,
                        deviceType: isAirPods ? .airPods : .otherAudio
                    )
                    devices.append(device)
                    Logger.bluetooth.debug("Found paired but disconnected audio device of type: \(String(describing: device.deviceType))")
                }
            }
        }

        // Also check Core Bluetooth for known peripherals
        if let centralManager = centralManager {
            // Get peripherals that were previously connected
            let knownPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [])
            for peripheral in knownPeripherals {
                let deviceName = peripheral.name ?? "Unknown Device"
                if !devices.contains(where: { $0.identifier == peripheral.identifier.uuidString }) &&
                   (deviceName.lowercased().contains("airpods") || deviceName.lowercased().contains("beats")) {
                    let device = BluetoothDevice(
                        name: deviceName,
                        identifier: peripheral.identifier.uuidString,
                        isConnected: false,
                        isPaired: true,
                        deviceType: deviceName.lowercased().contains("airpods") ? .airPods : .otherAudio
                    )
                    devices.append(device)
                    Logger.bluetooth.debug("Found known Core Bluetooth device of type: \(String(describing: device.deviceType))")
                }
            }
        }

        return devices
    }

    private func startScanning() {
        guard let centralManager = centralManager,
              centralManager.state == .poweredOn else { return }

        isScanning = true
        discoveredPeripherals.removeAll()
        connectionStatus = "Scanning for devices..."

        // Scan for all devices (no service filter to find AirPods)
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        // Stop scanning after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.stopScanning()
        }
    }

    private func stopScanning() {
        centralManager?.stopScan()
        isScanning = false

        // Add discovered devices to available devices list
        for peripheral in discoveredPeripherals {
            let deviceName = peripheral.name ?? "Unknown Device"
            if !availableDevices.contains(where: { $0.identifier == peripheral.identifier.uuidString }) {
                let device = BluetoothDevice(
                    name: deviceName,
                    identifier: peripheral.identifier.uuidString,
                    isConnected: false,
                    isPaired: false,
                    deviceType: deviceName.lowercased().contains("airpods") ? .airPods : .otherAudio
                )
                availableDevices.append(device)
            }
        }
    }

    private func presentDevicePickerAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        // Notify ContentView that alert is being presented
        Logger.bluetooth.info("Presenting device picker alert")
        onAlertStateChange?(true)

        Logger.bluetooth.debug("Available devices: \(self.availableDevices.count)")
        for device in availableDevices {
            Logger.bluetooth.debug("Device: connected=\(device.isConnected), paired=\(device.isPaired), type=\(String(describing: device.deviceType))")
        }

        let alert = UIAlertController(
            title: "Bluetooth Devices",
            message: availableDevices.isEmpty ? "Scanning for devices..." : "Select a device to connect",
            preferredStyle: .actionSheet
        )

        if availableDevices.isEmpty {
            // Show scanning message and refresh option
            alert.addAction(UIAlertAction(title: "Refresh Scan", style: .default) { [weak self] _ in
                self?.loadAvailableDevices()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.presentDevicePickerAlert()
                }
            })
        } else {
            // Add connected devices first
            let connectedDevices = availableDevices.filter { $0.isConnected }
            for device in connectedDevices {
                let icon = device.deviceType == .airPods ? "🎧" : "🔊"
                let title = "\(icon) \(device.name) (Connected)"
                alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    self?.connectionStatus = "Already connected to \(device.name)"
                    self?.presentAlreadyConnectedAlert(for: device)
                })
            }

            // Add paired but disconnected devices
            let pairedDevices = availableDevices.filter { $0.isPaired && !$0.isConnected }
            for device in pairedDevices {
                let icon = device.deviceType == .airPods ? "🎧" : "🔊"
                let title = "\(icon) \(device.name) (Tap to Connect)"
                alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    self?.connectToPairedDevice(device)
                })
            }

            // Add discoverable devices
            let discoverableDevices = availableDevices.filter { !$0.isPaired }
            for device in discoverableDevices {
                let icon = device.deviceType == .airPods ? "🎧" : "📱"
                let title = "\(icon) \(device.name) (Not Paired)"
                alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    self?.pairNewDevice(device)
                })
            }

            // Add refresh action
            alert.addAction(UIAlertAction(title: "Refresh", style: .default) { [weak self] _ in
                self?.loadAvailableDevices()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.presentDevicePickerAlert()
                }
            })
        }

        // Add manual pairing option
        alert.addAction(UIAlertAction(title: "Open Bluetooth Settings", style: .default) { _ in
            if let bluetoothURL = URL(string: "App-Prefs:Bluetooth") {
                UIApplication.shared.open(bluetoothURL) { success in
                    if !success {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                }
            }
        })

        // Add cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.stopScanning()
        })

        // For iPad, set up popover presentation
        if let popover = alert.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        window.rootViewController?.present(alert, animated: true) { [weak self] in
            // Notify ContentView that alert was dismissed
            Logger.bluetooth.info("Device picker alert dismissed")
            self?.onAlertStateChange?(false)
        }
    }

    private func presentAlreadyConnectedAlert(for device: BluetoothDevice) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        // Notify ContentView that alert is being presented
        onAlertStateChange?(true)

        let alert = UIAlertController(
            title: "Device Connected",
            message: "\(device.name) is already connected and ready to use!",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        window.rootViewController?.present(alert, animated: true) { [weak self] in
            // Notify ContentView that alert was dismissed
            self?.onAlertStateChange?(false)
        }
    }

    private func connectToPairedDevice(_ device: BluetoothDevice) {
        connectionStatus = "Connecting to \(device.name)..."
        Logger.bluetooth.info("Attempting to connect to paired device of type: \(String(describing: device.deviceType))")

        if device.deviceType == .airPods {
            // For AirPods, try multiple connection methods
            connectToAirPods(device)
        } else {
            // For other devices, try Core Bluetooth connection first
            if let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == device.identifier }) {
                connectToPeripheral(peripheral)
            } else {
                // Try audio session method for other Bluetooth audio devices
                attemptAudioDeviceConnection(device)
            }
        }
    }

    private func attemptAudioDeviceConnection(_ device: BluetoothDevice) {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // FIXED: Use .playback instead of .playAndRecord to maintain high-quality audio
            try audioSession.setCategory(.playback, mode: .default, options: [
                .allowBluetooth,
                .allowBluetoothA2DP,
                .mixWithOthers  // Allow other apps to continue playing audio at full volume
            ])
            try audioSession.setActive(true)

            // Try to set preferred input
            let availableInputs = audioSession.availableInputs ?? []
            for input in availableInputs {
                if input.portName == device.name || input.uid == device.identifier {
                    try audioSession.setPreferredInput(input)
                    Logger.bluetooth.info("Set preferred input to Bluetooth device")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.verifyDeviceConnection(device)
                    }
                    return
                }
            }

            // If no matching input found, fall back to manual connection
            presentAirPodsConnectionAlert(for: device)

        } catch {
            Logger.bluetooth.error("Failed to connect audio device: \(error)")
            presentAirPodsConnectionAlert(for: device)
        }
    }

    private func verifyDeviceConnection(_ device: BluetoothDevice) {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        for output in currentRoute.outputs {
            if output.portName == device.name || output.uid == device.identifier {
                connectionStatus = "✅ Connected to \(device.name)!"
                presentConnectionSuccessAlert(for: device)
                return
            }
        }

        connectionStatus = "Connection failed"
        presentAirPodsConnectionAlert(for: device)
    }

    private func connectToAirPods(_ device: BluetoothDevice) {
        connectionStatus = "Connecting to \(device.name)..."
        Logger.bluetooth.info("Attempting to connect to AirPods device")

        // Try to programmatically connect paired AirPods
        attemptAirPodsConnection(device)
    }

    private func attemptAirPodsConnection(_ device: BluetoothDevice) {
        connectionStatus = "Opening audio picker..."
        Logger.bluetooth.debug("Opening system audio route picker for device")

        // Open the system audio route picker directly - just like Spotify/Overcast
        openSystemAudioRoutePicker(device: device)
    }

    private func openSystemAudioRoutePicker(device: BluetoothDevice) {
        Logger.bluetooth.debug("Opening system audio route picker")

        // Create the route picker view - this is what Spotify/Overcast use
        let routePickerView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        routePickerView.showsVolumeSlider = false
        routePickerView.showsRouteButton = true

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            Logger.bluetooth.error("Could not find window to present route picker")
            return
        }

        // Add the route picker view temporarily (invisible)
        routePickerView.alpha = 0.0
        window.addSubview(routePickerView)

        // Trigger the route picker button immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for subview in routePickerView.subviews {
                if let button = subview as? UIButton {
                    Logger.bluetooth.debug("Triggering audio route picker button")
                    button.sendActions(for: .touchUpInside)
                    break
                }
            }

            // Remove the temporary view after triggering
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                routePickerView.removeFromSuperview()

                // Check if connection was successful after user interaction
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.verifyAirPodsConnection(device)
                }
            }
        }
    }

    private func triggerAudioConnectionPlayback() {
        // Play a very brief, silent audio to trigger AirPods connection
        // This is what apps like Spotify do to force the audio route
        Logger.bluetooth.debug("Triggering audio playback to force Bluetooth connection")

        // Method 1: Try to play a brief system sound to trigger audio routing
        AudioServicesPlaySystemSound(1000) // Brief system sound

        // Method 2: Create a brief audio session activation
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Force the audio session to route to Bluetooth
            try audioSession.setActive(false)
            try audioSession.setActive(true)
            Logger.bluetooth.debug("Audio session reactivated to trigger routing")
        } catch {
            Logger.bluetooth.error("Could not reactivate audio session: \(error)")
        }
    }

    private func attemptAlternativeConnection(_ device: BluetoothDevice) {
        Logger.bluetooth.debug("Trying alternative connection method")

        // Method 2: Use MPVolumeView approach (what many audio apps use)
        attemptMPVolumeViewConnection(device)
    }

    private func attemptMPVolumeViewConnection(_ device: BluetoothDevice) {
        Logger.bluetooth.debug("Trying MPVolumeView connection method")

        // This is the older method that some apps still use
        let volumeView = MPVolumeView()
        volumeView.showsVolumeSlider = false
        volumeView.showsRouteButton = true

        // Try to programmatically activate the route button
        for subview in volumeView.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }

        // Check if this worked
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.verifyAirPodsConnection(device)
        }
    }

    private func verifyAirPodsConnection(_ device: BluetoothDevice) {
        Logger.bluetooth.debug("Verifying Bluetooth connection for device type: \(String(describing: device.deviceType))")

        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        // Check if AirPods are now connected
        var isConnected = false
        var connectedDeviceName = ""

        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
                let outputName = output.portName.lowercased()
                let deviceName = device.name.lowercased()

                // More flexible matching for AirPods
                if outputName.contains("airpods") || outputName.contains("beats") ||
                   outputName.contains(deviceName) ||
                   deviceName.contains(outputName.replacingOccurrences(of: "'s ", with: "")) {
                    isConnected = true
                    connectedDeviceName = output.portName
                    break
                }
            }
        }

        if isConnected {
            connectionStatus = "✅ \(connectedDeviceName) connected!"
            Logger.bluetooth.info("Bluetooth connection verified")

            // Update device list
            if let index = availableDevices.firstIndex(where: { $0.identifier == device.identifier }) {
                availableDevices[index] = BluetoothDevice(
                    name: device.name,
                    identifier: device.identifier,
                    isConnected: true,
                    isPaired: true,
                    deviceType: device.deviceType
                )
            }

            // Show success alert
            presentConnectionSuccessAlert(for: device)
        } else {
            connectionStatus = "Audio picker opened - connect your AirPods and tap 'New Session'"
            Logger.bluetooth.info("Bluetooth device not detected yet - user may still be selecting in audio picker")

            // Don't show error immediately - user might still be in the audio picker
            // The "New Session" button will trigger a recheck when pressed
        }
    }

    private func presentConnectionSuccessAlert(for device: BluetoothDevice) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        // Notify ContentView that alert is being presented
        onAlertStateChange?(true)

        let alert = UIAlertController(
            title: "Connected Successfully! 🎉",
            message: "\(device.name) is now connected and ready for posture tracking. Tap 'New Session' to start tracking.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Great!", style: .default) { _ in
            // Post notification that AirPods were connected
            NotificationCenter.default.post(name: NSNotification.Name("AirPodsConnected"), object: nil)
        })

        window.rootViewController?.present(alert, animated: true) { [weak self] in
            // Notify ContentView that alert was dismissed
            self?.onAlertStateChange?(false)
        }
    }

    private func presentAirPodsConnectionAlert(for device: BluetoothDevice) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        // Notify ContentView that alert is being presented
        onAlertStateChange?(true)

        let alert = UIAlertController(
            title: "Connect \(device.name)",
            message: device.isPaired ?
                "Tap your AirPods in Bluetooth settings to connect them." :
                "Go to Settings > Bluetooth to pair and connect your AirPods.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Open Bluetooth Settings", style: .default) { _ in
            // Try to open Bluetooth settings directly
            if let bluetoothURL = URL(string: "App-Prefs:Bluetooth") {
                UIApplication.shared.open(bluetoothURL) { success in
                    if !success {
                        // Fallback to general settings
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                }
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.connectionStatus = "Connection cancelled"
        })

        window.rootViewController?.present(alert, animated: true) { [weak self] in
            // Notify ContentView that alert was dismissed
            self?.onAlertStateChange?(false)
        }
    }

    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        guard let centralManager = centralManager else { return }

        connectionStatus = "Connecting to \(peripheral.name ?? "device")..."
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }



    private func pairNewDevice(_ device: BluetoothDevice) {
        connectionStatus = "Pairing with \(device.name)..."
        Logger.bluetooth.info("Attempting to pair with new device of type: \(String(describing: device.deviceType))")

        if device.deviceType == .airPods {
            presentAirPodsConnectionAlert(for: device)
        } else {
            // Try Core Bluetooth connection for non-AirPods devices
            if let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == device.identifier }) {
                connectToPeripheral(peripheral)
            } else {
                presentAirPodsConnectionAlert(for: device)
            }
        }
    }

    private func presentBluetoothDisabledAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        // Notify ContentView that alert is being presented
        onAlertStateChange?(true)

        let alert = UIAlertController(
            title: "Bluetooth Disabled",
            message: "Please enable Bluetooth in Settings to connect to your AirPods.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        window.rootViewController?.present(alert, animated: true) { [weak self] in
            // Notify ContentView that alert was dismissed
            self?.onAlertStateChange?(false)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothEnabled = true
            connectionStatus = "Bluetooth ready"
        case .poweredOff:
            isBluetoothEnabled = false
            connectionStatus = "Bluetooth disabled"
        case .unauthorized:
            isBluetoothEnabled = false
            connectionStatus = "Bluetooth access denied"
        case .unsupported:
            isBluetoothEnabled = false
            connectionStatus = "Bluetooth not supported"
        case .resetting:
            isBluetoothEnabled = false
            connectionStatus = "Bluetooth resetting"
        case .unknown:
            isBluetoothEnabled = false
            connectionStatus = "Bluetooth state unknown"
        @unknown default:
            isBluetoothEnabled = false
            connectionStatus = "Unknown Bluetooth state"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Filter for devices that might be AirPods or other audio devices
        let deviceName = peripheral.name ?? ""
        let isAudioDevice = deviceName.lowercased().contains("airpods") ||
                           deviceName.lowercased().contains("beats") ||
                           deviceName.lowercased().contains("headphones") ||
                           deviceName.lowercased().contains("earbuds") ||
                           !deviceName.isEmpty // Include any named device

        if isAudioDevice && !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStatus = "Connected to \(peripheral.name ?? "device")"
        stopScanning()

        // Update device status in available devices
        if let index = availableDevices.firstIndex(where: { $0.identifier == peripheral.identifier.uuidString }) {
            availableDevices[index] = BluetoothDevice(
                name: availableDevices[index].name,
                identifier: availableDevices[index].identifier,
                isConnected: true,
                isPaired: true,
                deviceType: availableDevices[index].deviceType
            )
        }

        // Discover services
        peripheral.discoverServices(nil)
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionStatus = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionStatus = "Disconnected from \(peripheral.name ?? "device")"

            // Update device status in available devices
            if let index = availableDevices.firstIndex(where: { $0.identifier == peripheral.identifier.uuidString }) {
                availableDevices[index] = BluetoothDevice(
                    name: availableDevices[index].name,
                    identifier: availableDevices[index].identifier,
                    isConnected: false,
                    isPaired: true,
                    deviceType: availableDevices[index].deviceType
                )
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            Logger.bluetooth.error("Error discovering services: \(error.localizedDescription)")
            return
        }

        peripheral.services?.forEach { _ in
            Logger.bluetooth.debug("Discovered service")
        }
    }
}
#endif
