import Foundation

enum CalibrationStep: String, CaseIterable {
    case idle = "Ready to Start"
    case goodPosture = "Recording Good Posture"
    case transition = "Get Ready for Bad Posture"
    case badPosture = "Recording Bad Posture"
    case complete = "Calibration Complete"
}

@MainActor
protocol CalibrationManaging: AnyObject {
    var isCalibrating: Bool { get }
    var calibrationStep: CalibrationStep { get }
    var calibrationProgress: Double { get }
    var goodPostureAverage: Double { get }
    var badPostureAverage: Double { get }
    var isCalibrationComplete: Bool { get }
    var calculatedThreshold: Double { get }

    func startCalibration()
    func cancelCalibration()
}
