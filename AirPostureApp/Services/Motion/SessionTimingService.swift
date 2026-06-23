import Foundation
import os

@MainActor
protocol SessionTimingManaging: AnyObject {
    var totalSessionTime: TimeInterval { get }
    var poorPostureDuration: TimeInterval { get }
    var postureScorePercent: Int { get }
    var runningWalkingDuration: TimeInterval { get }
    var isPaused: Bool { get }
    var sessionPaused: Bool { get }

    func startNewSession()
    func resetSession()
    func togglePause()
    func updateSessionTimers(adjustedPitch: Double, threshold: Double, hasActiveSession: Bool)
    func performBackgroundUpdate(hasActiveSession: Bool)
    func endSession() -> (poorPostureDuration: TimeInterval, totalSessionTime: TimeInterval, runningWalkingDuration: TimeInterval)
    func handleActivityUpdate(isCurrentlyActive: Bool, at time: Date)
}

@Observable
@MainActor
final class SessionTimingService: SessionTimingManaging {
    private(set) var totalSessionTime: TimeInterval = 0
    private(set) var poorPostureDuration: TimeInterval = 0
    private(set) var postureScorePercent: Int = 0
    private(set) var runningWalkingDuration: TimeInterval = 0
    private(set) var isPaused: Bool = false
    private(set) var sessionPaused: Bool = false

    private var sessionStartTime: Date = Date.distantPast
    private var poorPostureStartTime: Date?
    private var accumulatedPoorPostureDuration: TimeInterval = 0
    private var lastPoorPostureUpdate: Date = Date.distantPast
    private var currentActivityStartTime: Date?
    private(set) var isUserRunningOrWalking: Bool = false

    private let sessionStore: SessionStore

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    var hasStarted: Bool {
        sessionStartTime != Date.distantPast
    }

    func startNewSession() {
        sessionStartTime = Date()
        totalSessionTime = 0
        poorPostureDuration = 0
        accumulatedPoorPostureDuration = 0
        poorPostureStartTime = nil
        postureScorePercent = 0
        lastPoorPostureUpdate = Date()
        runningWalkingDuration = 0
        isUserRunningOrWalking = false
        currentActivityStartTime = nil
    }

    func resetSession() {
        totalSessionTime = 0
        poorPostureDuration = 0
        accumulatedPoorPostureDuration = 0
        poorPostureStartTime = nil
        postureScorePercent = 0
        lastPoorPostureUpdate = Date.distantPast
        runningWalkingDuration = 0
        isUserRunningOrWalking = false
        currentActivityStartTime = nil
        isPaused = false
        sessionPaused = false
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            let currentTime = Date()
            if sessionStore.currentSession != nil && hasStarted {
                if poorPostureStartTime != nil {
                    if let startTime = poorPostureStartTime {
                        let episodeDuration = currentTime.timeIntervalSince(startTime)
                        accumulatedPoorPostureDuration += episodeDuration
                    }
                    poorPostureDuration = accumulatedPoorPostureDuration
                    poorPostureStartTime = nil
                }
                totalSessionTime = currentTime.timeIntervalSince(sessionStartTime)
                sessionStore.updateCurrentSession(
                    poorPostureDuration: poorPostureDuration,
                    activeSessionDuration: totalSessionTime,
                    runningWalkingDuration: runningWalkingDuration
                )
            }
        } else {
            if sessionStore.currentSession != nil && hasStarted {
                let currentTime = Date()
                sessionStartTime = currentTime.addingTimeInterval(-totalSessionTime)
                lastPoorPostureUpdate = currentTime
            }
        }
    }

    func updateSessionTimers(adjustedPitch: Double, threshold: Double, hasActiveSession: Bool) {
        guard !sessionPaused && !isPaused else { return }

        if !hasActiveSession {
            if totalSessionTime > 0 || poorPostureDuration > 0 || postureScorePercent > 0 {
                totalSessionTime = 0
                poorPostureDuration = 0
                accumulatedPoorPostureDuration = 0
                postureScorePercent = 0
                poorPostureStartTime = nil
            }
            return
        }

        guard hasStarted else { return }

        let currentTime = Date()
        totalSessionTime = currentTime.timeIntervalSince(sessionStartTime)

        if adjustedPitch < threshold {
            if poorPostureStartTime == nil {
                poorPostureStartTime = currentTime
            }
            let currentEpisodeDuration = poorPostureStartTime.map { currentTime.timeIntervalSince($0) } ?? 0
            poorPostureDuration = accumulatedPoorPostureDuration + currentEpisodeDuration
        } else {
            if let startTime = poorPostureStartTime {
                let episodeDuration = currentTime.timeIntervalSince(startTime)
                accumulatedPoorPostureDuration += episodeDuration
                poorPostureDuration = accumulatedPoorPostureDuration
                poorPostureStartTime = nil
            }
        }

        if totalSessionTime > 0 {
            recalculateScore()
            sessionStore.updateCurrentSession(
                poorPostureDuration: poorPostureDuration,
                runningWalkingDuration: runningWalkingDuration
            )
        }
    }

    func performBackgroundUpdate(hasActiveSession: Bool) {
        guard hasActiveSession && hasStarted && !isPaused else { return }

        let currentTime = Date()
        let timeSinceLastUpdate = currentTime.timeIntervalSince(lastPoorPostureUpdate)
        totalSessionTime += timeSinceLastUpdate

        if let startTime = poorPostureStartTime {
            poorPostureDuration += timeSinceLastUpdate
            accumulatedPoorPostureDuration = poorPostureDuration
        }

        if totalSessionTime > 0 {
            recalculateScore()
        }

        sessionStore.updateCurrentSession(
            poorPostureDuration: poorPostureDuration,
            runningWalkingDuration: runningWalkingDuration
        )

        lastPoorPostureUpdate = currentTime
    }

    func endSession() -> (poorPostureDuration: TimeInterval, totalSessionTime: TimeInterval, runningWalkingDuration: TimeInterval) {
        let result = (poorPostureDuration: poorPostureDuration, totalSessionTime: totalSessionTime, runningWalkingDuration: runningWalkingDuration)
        resetSession()
        return result
    }

    func handleActivityUpdate(isCurrentlyActive: Bool, at time: Date) {
        if isCurrentlyActive {
            if !isUserRunningOrWalking {
                currentActivityStartTime = time
                isUserRunningOrWalking = true
            }
        } else {
            if let startTime = currentActivityStartTime, isUserRunningOrWalking {
                let activeDuration = time.timeIntervalSince(startTime)
                runningWalkingDuration += activeDuration
                currentActivityStartTime = nil
                isUserRunningOrWalking = false
            }
        }
    }

    func setSessionPaused(_ paused: Bool) {
        sessionPaused = paused
    }

    func setLastPoorPostureUpdate(_ date: Date) {
        lastPoorPostureUpdate = date
    }

    private func recalculateScore() {
        guard totalSessionTime > 0 else {
            postureScorePercent = 0
            return
        }
        let score = ((totalSessionTime - poorPostureDuration) / totalSessionTime) * 100
        postureScorePercent = max(0, min(100, Int(score)))
    }
}
