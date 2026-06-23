import Foundation

@MainActor
protocol SessionStoring: AnyObject {
    var sessions: [Session] { get }
    var recentSessions: [Session] { get }
    var currentSession: Session? { get set }
    var isShowingDemoSessions: Bool { get }

    @discardableResult
    func startNewSession() -> Session
    func updateCurrentSession(poorPostureDuration: TimeInterval, activeSessionDuration: TimeInterval, runningWalkingDuration: TimeInterval)
    func endCurrentSession(poorPostureDuration: TimeInterval, activeSessionDuration: TimeInterval, runningWalkingDuration: TimeInterval)
    func clearAllSessions()
    func loadDemoSessionsIfNeeded()
}
