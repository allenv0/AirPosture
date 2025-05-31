import Foundation

struct Session: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date
    var poorPostureDuration: TimeInterval
    var totalDuration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    var poorPosturePercentage: Int {
        guard totalDuration > 0 else { return 0 }
        return Int((poorPostureDuration / totalDuration) * 100)
    }
    
    init(startTime: Date = Date(), endTime: Date = Date(), poorPostureDuration: TimeInterval = 0) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.poorPostureDuration = poorPostureDuration
    }
}

class SessionStore: ObservableObject {
    static let shared = SessionStore()
    private let sessionsKey = "sessions"
    
    @Published var sessions: [Session] = []
    var currentSession: Session?
    
    init() {
        loadSessions()
    }
    
    func startNewSession() -> Session {
        let session = Session()
        currentSession = session
        return session
    }
    
    func endCurrentSession(poorPostureDuration: TimeInterval) {
        guard var session = currentSession else { return }
        session.poorPostureDuration = poorPostureDuration
        session.endTime = Date()
        sessions.insert(session, at: 0) // Add to beginning for chronological order
        saveSessions()
        currentSession = nil
    }
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: sessionsKey)
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([Session].self, from: data) {
            sessions = decoded
        }
    }
    
    func clearAllSessions() {
        sessions.removeAll()
        UserDefaults.standard.removeObject(forKey: sessionsKey)
    }
}
