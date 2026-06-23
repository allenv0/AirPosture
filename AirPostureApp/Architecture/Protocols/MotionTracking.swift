import Foundation

@MainActor
protocol MotionTracking: AnyObject {
    var pitch: Double { get }
    var roll: Double { get }
    var yaw: Double { get }
    var isPaused: Bool { get }
    var pitchHistory: [Double] { get }

    func start()
    func stop()
    func restart()
    func performBackgroundUpdate()
    func togglePause()
}
