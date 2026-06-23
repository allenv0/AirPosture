import Foundation

@MainActor
protocol PostureStateManaging: AnyObject {
    var postureState: PostureState { get }
    var poorPostureDuration: TimeInterval { get }
    var postureScorePercent: Int { get }
    var poorPostureThreshold: Double { get set }
    var normalAirPodsAngle: Double { get set }
    var totalSessionTime: TimeInterval { get }
    var runningWalkingDuration: TimeInterval { get }
}
