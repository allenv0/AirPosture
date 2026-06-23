import Foundation
import os

@MainActor
protocol CalibrationDependencies: AnyObject {
    var currentPitch: Double { get }
    var isSimulatorMode: Bool { get }
    var isMotionActive: Bool { get }
    var isMotionAvailable: Bool { get }
    var hasActiveSession: Bool { get }
    func startMotionUpdates()
    func stopDeviceMotionUpdates()
    func setPitch(_ pitch: Double)
    func applyThreshold(_ threshold: Double)
}

@Observable
@MainActor
final class CalibrationService {
    private(set) var isCalibrating: Bool = false
    private(set) var calibrationStep: CalibrationStep = .idle
    private(set) var calibrationProgress: Double = 0.0
    private(set) var goodPostureAverage: Double = 0.0
    private(set) var badPostureAverage: Double = 0.0
    private(set) var isCalibrationComplete: Bool = false
    private(set) var calculatedThreshold: Double = 0.0

    private var calibrationData: [Double] = []
    private var calibrationTimer: Timer?
    private var simulatorCalibrationTimer: Timer?
    private let calibrationDuration: TimeInterval = MotionConstants.calibrationDuration

    private weak var dependencies: CalibrationDependencies?

    func configure(dependencies: CalibrationDependencies) {
        self.dependencies = dependencies
    }

    func startCalibration() {
        Logger.motion.info("Starting posture calibration")
        isCalibrating = true
        calibrationStep = .goodPosture
        calibrationProgress = 0.0
        calibrationData.removeAll()
        goodPostureAverage = 0.0
        badPostureAverage = 0.0
        isCalibrationComplete = false

        ensureMotionUpdatesForCalibration()
        startCalibrationStep()
    }

    func cancelCalibration() {
        Logger.motion.info("Stopping posture calibration")
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        simulatorCalibrationTimer?.invalidate()
        simulatorCalibrationTimer = nil
        isCalibrating = false
        calibrationStep = .idle
        calibrationProgress = 0.0
        calibrationData.removeAll()

        goodPostureAverage = 0.0
        badPostureAverage = 0.0
        calculatedThreshold = 0.0
        isCalibrationComplete = false

        guard let deps = dependencies else { return }
        if !deps.isSimulatorMode && deps.isMotionActive && !deps.hasActiveSession {
            Logger.motion.info("Stopping motion updates after calibration (no active session)")
            deps.stopDeviceMotionUpdates()
        }
    }

    func saveCalibrationResults() {
        guard isCalibrationComplete else { return }

        dependencies?.applyThreshold(calculatedThreshold)

        Logger.motion.info("Calibration results saved")
        Logger.motion.info("Applied threshold: \(String(format: "%.1f", self.calculatedThreshold))°")

        cancelCalibration()
    }

    func resetToDefaultThreshold() {
        dependencies?.applyThreshold(MotionConstants.poorPostureThreshold)
        Logger.motion.info("Reset to default threshold: \(MotionConstants.poorPostureThreshold)°")
    }

    private func startCalibrationStep() {
        calibrationData.removeAll()
        calibrationProgress = 0.0

        let stepDuration = calibrationStep == .transition ? 3.0 : calibrationDuration

        calibrationTimer?.invalidate()
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.calibrationProgress += 0.1 / stepDuration

            if self.calibrationStep == .goodPosture || self.calibrationStep == .badPosture {
                let currentPitch =
                    (self.dependencies?.isSimulatorMode ?? false)
                    ? self.getSimulatorCalibrationPitch()
                    : (self.dependencies?.currentPitch ?? 0)
                self.calibrationData.append(currentPitch)
            }

            if self.calibrationProgress >= 1.0 {
                timer.invalidate()
                self.completeCalibrationStep()
            }
        }
    }

    private func getSimulatorCalibrationPitch() -> Double {
        switch calibrationStep {
        case .goodPosture:
            return -12.0 + Double.random(in: -3.0...3.0)
        case .badPosture:
            return -27.0 + Double.random(in: -3.0...3.0)
        default:
            return dependencies?.currentPitch ?? 0
        }
    }

    private func completeCalibrationStep() {
        switch calibrationStep {
        case .goodPosture:
            goodPostureAverage = calibrationData.reduce(0, +) / Double(max(calibrationData.count, 1))
            Logger.motion.info("Good posture average: \(String(format: "%.1f", self.goodPostureAverage))°")
            calibrationStep = .transition
            startCalibrationStep()

        case .transition:
            calibrationStep = .badPosture
            startCalibrationStep()

        case .badPosture:
            badPostureAverage = calibrationData.reduce(0, +) / Double(max(calibrationData.count, 1))
            Logger.motion.info("Bad posture average: \(String(format: "%.1f", self.badPostureAverage))°")
            calibrationStep = .complete
            calculatePersonalizedThreshold()

        case .complete, .idle:
            break
        }
    }

    private func calculatePersonalizedThreshold() {
        let rawThreshold = (goodPostureAverage + badPostureAverage) / 2.0
        let safeThreshold = max(-35.0, min(-5.0, rawThreshold))

        calculatedThreshold = safeThreshold
        isCalibrationComplete = true

        Logger.motion.info("Calibration complete")
        Logger.motion.info("Good posture: \(String(format: "%.1f", self.goodPostureAverage))°")
        Logger.motion.info("Bad posture: \(String(format: "%.1f", self.badPostureAverage))°")
        Logger.motion.info("Calculated threshold: \(String(format: "%.1f", safeThreshold))°")
    }

    private func ensureMotionUpdatesForCalibration() {
        guard let deps = dependencies else { return }

        guard !deps.isSimulatorMode else {
            Logger.motion.info("Simulator mode - using mock data for calibration")
            startSimulatorCalibrationUpdates()
            return
        }

        if deps.isMotionActive {
            Logger.motion.debug("Motion updates already active for calibration")
            return
        }

        guard deps.isMotionAvailable else {
            Logger.motion.warning("Device motion not available for calibration")
            return
        }

        Logger.motion.info("Starting motion updates for calibration")
        deps.startMotionUpdates()
    }

    private func startSimulatorCalibrationUpdates() {
        simulatorCalibrationTimer?.invalidate()

        simulatorCalibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] timer in
            guard let self = self, self.isCalibrating else {
                timer.invalidate()
                return
            }

            self.dependencies?.setPitch(self.getSimulatorCalibrationPitch())
        }
    }
}
