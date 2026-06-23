import Foundation
import SwiftUI
import UserNotifications
import os

struct Session: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: Date
    var endTime: Date
    var poorPostureDuration: TimeInterval
    var activeSessionDuration: TimeInterval = 0
    var runningWalkingDuration: TimeInterval = 0
    var avatarType: String = "bear-neck"
    var isStretchSession: Bool = false
    var stretchReps: [String: Int]?
    var stretchTotalDuration: TimeInterval = 0
    var primaryStretchType: String?

    var isDemo: Bool = false

    var totalDuration: TimeInterval {
        return activeSessionDuration > 0
            ? activeSessionDuration : endTime.timeIntervalSince(startTime)
    }

    var poorPosturePercentage: Int {
        guard totalDuration > 0 else { return 0 }
        return Int(((totalDuration - poorPostureDuration) / totalDuration) * 100)
    }

    var wasRunningOrWalking: Bool {
        return runningWalkingDuration >= 60
    }

    var runningWalkingPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (runningWalkingDuration / totalDuration) * 100
    }

    init(
        startTime: Date = Date(), endTime: Date = Date(), poorPostureDuration: TimeInterval = 0,
        activeSessionDuration: TimeInterval = 0, runningWalkingDuration: TimeInterval = 0,
        avatarType: String = "bear-neck"
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.poorPostureDuration = poorPostureDuration
        self.activeSessionDuration = activeSessionDuration
        self.runningWalkingDuration = runningWalkingDuration
        self.avatarType = avatarType
    }
}

class SessionStore: ObservableObject {
    static let shared = SessionStore()
    private let sessionsKey = UserDefaultsKeys.sessions
    private let hasShownDemoKey = UserDefaultsKeys.hasShownDemoSessions
    private let dataQueue = DispatchQueue(label: "com.airposture.data", qos: .utility)
    private let maxRecentSessions = 10

    static let minimumDisplayableDuration: TimeInterval = 10

    @Published var sessions: [Session] = []
    @Published var recentSessions: [Session] = []
    @Published var currentSession: Session?
    @Published var isShowingDemoSessions: Bool = false
    private var allSessions: [Session] = []

    var displayableSessions: [Session] {
        allSessions.filter { $0.totalDuration > Self.minimumDisplayableDuration || $0.poorPosturePercentage > 0 }
    }

    var hasRealSessions: Bool {
        !allSessions.filter { !$0.isDemo }.isEmpty
    }

    var hasShownDemoSessions: Bool {
        get { UserDefaults.standard.bool(forKey: hasShownDemoKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasShownDemoKey) }
    }

    private func createDemoSessions() -> [Session] {
        let calendar = Calendar.current
        let now = Date()
        
        var greenSession = Session(
            startTime: calendar.date(byAdding: .day, value: -1, to: now)!,
            endTime: calendar.date(byAdding: .minute, value: 25, to: calendar.date(byAdding: .day, value: -1, to: now)!)!,
            poorPostureDuration: 225,
            activeSessionDuration: 1500,
            avatarType: "bear-neck"
        )
        greenSession.isDemo = true
        
        var yellowSession = Session(
            startTime: calendar.date(byAdding: .day, value: -2, to: now)!,
            endTime: calendar.date(byAdding: .minute, value: 18, to: calendar.date(byAdding: .day, value: -2, to: now)!)!,
            poorPostureDuration: 486,
            activeSessionDuration: 1080,
            avatarType: "bear-neck"
        )
        yellowSession.isDemo = true
        
        var redSession = Session(
            startTime: calendar.date(byAdding: .day, value: -3, to: now)!,
            endTime: calendar.date(byAdding: .minute, value: 12, to: calendar.date(byAdding: .day, value: -3, to: now)!)!,
            poorPostureDuration: 518,
            activeSessionDuration: 720,
            avatarType: "bear-neck"
        )
        redSession.isDemo = true
        
        return [greenSession, yellowSession, redSession]
    }

    func loadDemoSessionsIfNeeded() {
        guard !hasRealSessions && !hasShownDemoSessions else {
            if hasRealSessions {
                isShowingDemoSessions = false
            }
            return
        }
        
        let demos = createDemoSessions()
        allSessions = demos
        sessions = demos
        recentSessions = Array(demos.prefix(maxRecentSessions))
        isShowingDemoSessions = true
        hasShownDemoSessions = true
    }

    func clearDemoSessions() {
        allSessions = allSessions.filter { !$0.isDemo }
        sessions = allSessions
        recentSessions = Array(allSessions.prefix(maxRecentSessions))
        isShowingDemoSessions = false
    }

    init() {
        Logger.session.debug("SessionStore: Initializing...")
        loadSessions()
    }

    deinit {
        Logger.session.debug("SessionStore deinit - ensuring data persistence")
        if !allSessions.isEmpty {
            do {
                let encoded = try JSONEncoder().encode(allSessions)
                UserDefaults.standard.set(encoded, forKey: sessionsKey)
                Logger.session.info("SessionStore: Final save completed in deinit")
            } catch {
                Logger.session.error("SessionStore: Error in final save: \(error)")
            }
        }
    }

    func startNewSession() -> Session {
        if isShowingDemoSessions {
            clearDemoSessions()
        }
        let currentAvatar = AvatarManager.shared.selectedAvatar.rawValue
        let session = Session(avatarType: currentAvatar)
        currentSession = session
        Logger.session.info(
            "SessionStore: Started new session with avatar: \(currentAvatar)"
        )
        return session
    }

    func updateCurrentSession(
        poorPostureDuration: TimeInterval, activeSessionDuration: TimeInterval = 0,
        runningWalkingDuration: TimeInterval = 0
    ) {
        guard var session = currentSession else { return }

        let hasChanges =
            session.poorPostureDuration != poorPostureDuration
            || (activeSessionDuration > 0 && session.activeSessionDuration != activeSessionDuration)
            || session.runningWalkingDuration != runningWalkingDuration

        guard hasChanges else { return }

        session.poorPostureDuration = poorPostureDuration
        session.endTime = Date()
        if activeSessionDuration > 0 {
            session.activeSessionDuration = activeSessionDuration
        }
        session.runningWalkingDuration = runningWalkingDuration
        currentSession = session
        Logger.session.debug(
            "SessionStore: Updated session - Poor Duration: \(poorPostureDuration), Active Duration: \(activeSessionDuration), Running/Walking Duration: \(runningWalkingDuration), Total: \(session.totalDuration)"
        )
    }

    func endCurrentSession(
        poorPostureDuration: TimeInterval, activeSessionDuration: TimeInterval = 0,
        runningWalkingDuration: TimeInterval = 0
    ) {
        guard var session = currentSession else {
            Logger.session.warning("SessionStore: No current session to end")
            return
        }
        session.poorPostureDuration = poorPostureDuration
        session.endTime = Date()
        if activeSessionDuration > 0 {
            session.activeSessionDuration = activeSessionDuration
        }
        session.runningWalkingDuration = runningWalkingDuration
        Logger.session.info(
            "SessionStore: Ending session - Poor Duration: \(poorPostureDuration), Active Duration: \(activeSessionDuration), Running/Walking Duration: \(runningWalkingDuration)"
        )
        Logger.session.info(
            "SessionStore: Session ending - Duration: \(session.totalDuration)s, Poor posture: \(session.poorPosturePercentage)%"
        )

        Task { @MainActor in
            NotificationManager.shared.sendSessionCompleteNotification(
                duration: session.totalDuration,
                poorPosturePercentage: session.poorPosturePercentage
            )
        }

        allSessions.insert(session, at: 0)
        sessions = allSessions
        updateRecentSessions()
        Logger.session.debug("SessionStore: Current sessions count: \(self.allSessions.count)")
        saveSessions()
        currentSession = nil
    }

    private func saveSessions() {
        let sessionsToSave = allSessions
        let saveStartTime = CFAbsoluteTimeGetCurrent()

        dataQueue.async { [weak self] in
            do {
                let encoded = try JSONEncoder().encode(sessionsToSave)
                UserDefaults.standard.set(encoded, forKey: self?.sessionsKey ?? UserDefaultsKeys.sessions)

                let saveTime = (CFAbsoluteTimeGetCurrent() - saveStartTime) * 1000

                DispatchQueue.main.async {
                    Logger.session.info(
                        "SessionStore: Successfully saved \(sessionsToSave.count) sessions in \(String(format: "%.1f", saveTime))ms"
                    )

                    if saveTime > 50 {
                        Logger.session.warning(
                            "Session save took \(String(format: "%.1f", saveTime))ms - consider optimization"
                        )
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    Logger.session.error("SessionStore: Error saving sessions: \(error)")
                }
            }
        }
    }

    private func loadSessions() {
        dataQueue.async { [weak self] in
            guard let self = self,
                let data = UserDefaults.standard.data(forKey: self.sessionsKey)
            else {
                DispatchQueue.main.async {
                    Logger.session.debug("SessionStore: No saved sessions found")
                    self?.loadDemoSessionsIfNeeded()
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode([Session].self, from: data)

                DispatchQueue.main.async { [weak self] in
                    self?.allSessions = decoded
                    self?.sessions = decoded
                    self?.updateRecentSessions()
                    self?.loadDemoSessionsIfNeeded()
                    Logger.session.info("SessionStore: Successfully loaded \(decoded.count) sessions")
                    for (index, session) in decoded.enumerated() {
                        Logger.session.debug(
                            "SessionStore: Session \(index + 1) - Poor Duration: \(session.poorPostureDuration), Active Duration: \(session.activeSessionDuration)"
                        )
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    Logger.session.error("SessionStore: Error loading sessions: \(error)")
                }
            }
        }
    }

    private func updateRecentSessions() {
        recentSessions = Array(allSessions.prefix(maxRecentSessions))
    }

    func clearAllSessions() {
        allSessions.removeAll()
        sessions.removeAll()
        recentSessions.removeAll()
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        Logger.session.info("SessionStore: Cleared all sessions")
    }
}
