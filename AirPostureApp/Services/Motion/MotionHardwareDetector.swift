import AVFoundation
@preconcurrency import CoreMotion
import Foundation
import os

#if os(iOS)
@MainActor
final class MotionHardwareDetector {
    private(set) var airPodsModel: AirPodsModel = .unknown
    private(set) var hasMotionCapability: Bool = false
    private(set) var hasGyroscope: Bool = false
    private(set) var hardwareDetectionSuccessful: Bool = false

    private final class MotionCapabilityProbe: @unchecked Sendable {
        private let lock = NSLock()
        private let motionManager = CMHeadphoneMotionManager()
        private let testQueue: OperationQueue = {
            let queue = OperationQueue()
            queue.name = "com.airposture.hardwareTest"
            queue.maxConcurrentOperationCount = 1
            return queue
        }()

        private var continuation: CheckedContinuation<Bool, Never>?
        private var didFinish = false

        func run(timeout: TimeInterval) async -> Bool {
            await withCheckedContinuation { continuation in
                lock.lock()
                self.continuation = continuation
                lock.unlock()

                motionManager.startDeviceMotionUpdates(to: testQueue) { [weak self] motion, _ in
                    self?.finish(motion != nil)
                }

                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) { [weak self] in
                    self?.finish(false)
                }
            }
        }

        private func finish(_ result: Bool) {
            lock.lock()
            guard !didFinish, let continuation else {
                lock.unlock()
                return
            }
            didFinish = true
            self.continuation = nil
            lock.unlock()

            motionManager.stopDeviceMotionUpdates()
            continuation.resume(returning: result)
        }
    }

    func detectAirPodsModelFromHardware(deviceName: String? = nil) async -> AirPodsModel {
        Logger.bluetooth.info("Starting hardware-based model detection")

        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        var hasBluetoothDevice = false
        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
                hasBluetoothDevice = true
                Logger.bluetooth.info("Found Bluetooth device")
                break
            }
        }

        if !hasBluetoothDevice {
            Logger.bluetooth.warning("No Bluetooth device found")
            hasMotionCapability = false
            hasGyroscope = false
            return .unknown
        }

        let motionCapabilityDetected = await MotionCapabilityProbe().run(timeout: 1.0)

        if motionCapabilityDetected {
            Logger.bluetooth.info("Hardware test: Motion sensors detected")
            Logger.bluetooth.info("Hardware detection: Motion-capable AirPods detected")
            hasMotionCapability = true
            hasGyroscope = true
            hardwareDetectionSuccessful = true

            if let deviceName = deviceName {
                return determineMotionCapableModel(deviceName: deviceName)
            } else {
                return .airPodsPro
            }
        } else {
            Logger.bluetooth.warning("Hardware test: No motion sensors found")
            Logger.bluetooth.info("Hardware detection: Non-motion-capable device detected")
            hasMotionCapability = false
            hasGyroscope = false
            hardwareDetectionSuccessful = true

            if let deviceName = deviceName {
                return determineNonMotionModel(deviceName: deviceName)
            } else {
                return .unknown
            }
        }
    }

    func checkAirPodsConnectionWithHardware() async -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
                let deviceName = output.portName
                let model = await detectAirPodsModelFromHardware(deviceName: deviceName)
                if model != .unknown {
                    airPodsModel = model
                    return true
                }
            }
        }

        for input in currentRoute.inputs {
            if input.portType == .bluetoothHFP {
                let deviceName = input.portName
                let model = await detectAirPodsModelFromHardware(deviceName: deviceName)
                if model != .unknown {
                    airPodsModel = model
                    return true
                }
            }
        }

        return false
    }

    func checkAirPodsAudioConnectionEnhanced() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
                let normalizedName = normalizeDeviceName(output.portName)
                if isAirPodsDevice(normalizedName) {
                    return true
                }
            }
        }

        for input in currentRoute.inputs {
            if input.portType == .bluetoothHFP {
                let normalizedName = normalizeDeviceName(input.portName)
                if isAirPodsDevice(normalizedName) {
                    return true
                }
            }
        }

        return false
    }

    private func determineMotionCapableModel(deviceName: String) -> AirPodsModel {
        let normalizedName = normalizeDeviceName(deviceName.lowercased())

        if normalizedName.contains("max") { return .airPodsMax }
        if normalizedName.contains("pro") {
            if normalizedName.contains("2") || normalizedName.contains("second") { return .airPodsPro2 }
            return .airPodsPro
        }
        if normalizedName.contains("3") || normalizedName.contains("third") { return .airPods3 }
        if normalizedName.contains("4") || normalizedName.contains("fourth") { return .airPods3 }
        if normalizedName.contains("beats") { return .beats }

        return .airPods3
    }

    private func determineNonMotionModel(deviceName: String) -> AirPodsModel {
        let normalizedName = normalizeDeviceName(deviceName.lowercased())
        if normalizedName.contains("airpods") { return .airPods1or2 }
        return .unknown
    }

    func normalizeDeviceName(_ name: String) -> String {
        return name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(
                of: "[\\p{Cf}\\p{Zl}\\p{Zp}]",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "[\"\u{2018}\u{2019}\u{201C}\u{201D}]",
                with: "'",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func isAirPodsDevice(_ normalizedName: String) -> Bool {
        let primaryPatterns = ["airpods", "air pod", "airpod"]
        for pattern in primaryPatterns {
            if normalizedName.contains(pattern) { return true }
        }

        let modelIndicators = ["pro", "max", "4", "3", "2", "1"]
        let containerWords = ["pod", "audio", "sound"]

        for model in modelIndicators {
            if normalizedName.contains(model) {
                for container in containerWords {
                    if normalizedName.contains(container) { return true }
                }
            }
        }

        if normalizedName.contains("beats") { return true }

        return false
    }

    func reset() {
        airPodsModel = .unknown
        hasMotionCapability = false
        hasGyroscope = false
        hardwareDetectionSuccessful = false
    }
}
#endif
