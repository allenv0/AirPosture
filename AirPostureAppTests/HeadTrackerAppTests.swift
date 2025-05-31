import Testing
import CoreMotion
@testable import AirPostureApp

@Suite("HeadphoneMotionManager Tests")
struct HeadphoneMotionManagerTests {
    
    @Test("Initial state is correct") func testInitialState() async throws {
        let manager = HeadphoneMotionManager()
        #expect(manager.pitch == 0.0)
        #expect(manager.roll == 0.0)
        #expect(manager.yaw == 0.0)
        #expect(manager.isDeviceConnected == false)
        #expect(manager.pitchHistory.isEmpty)
    }
    
    @Test("Low pass filter works correctly") func testLowPassFilter() async throws {
        let manager = HeadphoneMotionManager()
        let filtered = manager.lowPassFilter(current: 10.0, previous: 0.0)
        #expect(filtered > 0.0 && filtered < 10.0)
    }
    
    @Test("Pitch history is updated correctly") func testPitchHistory() async throws {
        let manager = HeadphoneMotionManager()
        let motion = CMDeviceMotion()
        
        // Simulate motion data
        motion.attitude.pitch = 0.5 // ~28.65 degrees
        manager.processMotionData(motion)
        
        // Wait for async updates
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #expect(!manager.pitchHistory.isEmpty)
        #expect(manager.pitch > 0.0)
    }
    
    @Test("Posture state updates correctly") func testPostureState() async throws {
        let manager = HeadphoneMotionManager()
        let motion = CMDeviceMotion()
        
        // Simulate poor posture (pitch > warning threshold)
        motion.attitude.pitch = 0.5 // ~28.65 degrees (above 20° warning threshold)
        manager.processMotionData(motion)
        
        // Wait for async updates
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        if case .warning = manager.postureState {
            // Expected case - test passes
        } else {
            Issue.record("Expected warning state, got \(manager.postureState)")
        }
    }
}

@Suite("Session Model Tests")
struct SessionModelTests {
    
    @Test("Session initialization") func testSessionInit() {
        let now = Date()
        let session = Session(startTime: now, endTime: now.addingTimeInterval(60), poorPostureDuration: 30)
        
        #expect(session.totalDuration == 60)
        #expect(session.poorPosturePercentage == 50)
    }
    
    @Test("SessionStore operations") func testSessionStore() async throws {
        let store = SessionStore()
        store.clearAllSessions() // Start with clean state
        
        // Test starting a new session
        let newSession = store.startNewSession()
        #expect(store.currentSession != nil)
        
        // Test ending the session
        store.endCurrentSession(poorPostureDuration: 30)
        #expect(store.currentSession == nil)
        #expect(!store.sessions.isEmpty)
        
        // Test session data
        if let savedSession = store.sessions.first {
            #expect(savedSession.poorPostureDuration == 30)
        } else {
            Issue.record("Session was not saved correctly")
        }
        
        // Test clearing sessions
        store.clearAllSessions()
        #expect(store.sessions.isEmpty)
    }
}

// MARK: - Test Utilities

// Mock CMDeviceMotion for testing
extension CMDeviceMotion {
    convenience init() {
        self.init()
        let attitude = CMAttitude()
        attitude.roll = 0
        attitude.pitch = 0
        attitude.yaw = 0
        self.setValue(attitude, forKey: "attitude")
    }
}

// Mock CMAttitude for testing
class CMAttitude: NSObject {
    var roll: Double = 0
    var pitch: Double = 0
    var yaw: Double = 0
}
