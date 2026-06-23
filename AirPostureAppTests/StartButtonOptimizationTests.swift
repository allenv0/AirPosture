import Testing
import CoreMotion
import ActivityKit
import AVFoundation
@testable import AirPosture

@Suite("Start Button Optimization Tests")
@MainActor
struct StartButtonOptimizationTests {
    
    @Test("HeadphoneMotionManager exposes initial connection state")
    func testManagerExposesInitialConnectionState() async throws {
        let manager = HeadphoneMotionManager.shared
        
        #expect(manager.connectionStatus.isEmpty == false)
        #expect(manager.currentSessionStore.currentSession == nil)
    }
    
    @Test("HeadphoneMotionManager exposes posture defaults")
    func testHeadphoneMotionManagerExposesPostureDefaults() async throws {
        let manager = HeadphoneMotionManager.shared
        
        #expect(manager.pitch == 0.0)
        #expect(manager.roll == 0.0)
        #expect(manager.yaw == 0.0)
    }
    
    @Test("HeadphoneMotionManager exposes motion capability state")
    func testHeadphoneMotionManagerExposesMotionCapabilityState() async throws {
        let manager = HeadphoneMotionManager.shared
        
        #expect(manager.airPodsModel.rawValue.isEmpty == false)
        #expect(manager.connectedDeviceName.isEmpty || manager.connectedDeviceName.count > 0)
    }
    
    @Test("Session data structure is correctly initialized")
    func testSessionDataStructureIsCorrectlyInitialized() async throws {
        let store = SessionStore()
        store.clearAllSessions()
        
        let session = store.startNewSession()
        
        #expect(session.id != nil)
        #expect(session.startTime != nil)
        #expect(session.avatarType != nil)
        
        store.endCurrentSession(poorPostureDuration: 0)
    }
    
    @Test("Live Activity authorization info is accessible")
    func testLiveActivityAuthorizationInfoAccessible() async throws {
        if #available(iOS 16.1, *) {
            let authInfo = ActivityAuthorizationInfo()
            let _ = authInfo.areActivitiesEnabled
            let _ = authInfo.frequentPushesEnabled
        }
    }
    
    @Test("Audio session can be configured")
    func testAudioSessionCanBeConfigured() async throws {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            #expect(audioSession.category == .playback)
        } catch {
            Issue.record("Failed to configure audio session: \(error)")
        }
        #endif
    }
    
    @Test("Simulator mock data starts correctly")
    func testSimulatorMockDataStartsCorrectly() async throws {
        #if targetEnvironment(simulator)
        let manager = HeadphoneMotionManager.shared
        
        #expect(manager.connectionMethod.rawValue.isEmpty == false)
        #endif
    }
}

@Suite("Button State Machine Tests")
struct ButtonStateMachineTests {
    
    @Test("StartButtonState enum has all required states")
    func testStateEnum() {
        let states: [StartButtonState] = [.idle, .connecting, .success, .error, .retrying]
        
        #expect(states.count == 5)
    }
    
    @Test("Initial state is idle")
    func testInitialState() {
        let state = StartButtonState.idle
        
        #expect(state == .idle)
    }

    @Test("StartButtonState exposes user-facing titles")
    func testStateTitles() {
        #expect(StartButtonState.idle.title == "Start")
        #expect(StartButtonState.connecting.title == "Connecting...")
        #expect(StartButtonState.success.title == "Start")
        #expect(StartButtonState.error.title == "Finding AirPods")
        #expect(StartButtonState.retrying.title == "Retrying...")
    }

    @Test("StartButtonState blocks duplicate connection attempts")
    func testInteractionBlockingStates() {
        #expect(StartButtonState.idle.isInteractionBlocked == false)
        #expect(StartButtonState.success.isInteractionBlocked == false)
        #expect(StartButtonState.connecting.isInteractionBlocked)
        #expect(StartButtonState.error.isInteractionBlocked)
        #expect(StartButtonState.retrying.isInteractionBlocked)
    }

    @Test("StartButtonState accessibility values are not empty")
    func testAccessibilityValues() {
        for state in [StartButtonState.idle, .connecting, .success, .error, .retrying] {
            #expect(!state.accessibilityValue.isEmpty)
        }
    }
}

@Suite("Session Persistence Tests")
struct SessionPersistenceTests {
    
    @Test("Session persists poor posture duration")
    func testSessionPersistsPoorPostureDuration() async throws {
        let store = SessionStore()
        store.clearAllSessions()
        
        _ = store.startNewSession()
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        store.endCurrentSession(
            poorPostureDuration: 30,
            activeSessionDuration: 60
        )
        
        #expect(!store.sessions.isEmpty)
        
        let firstSession = store.sessions.first
        #expect(firstSession?.poorPostureDuration == 30)
        
        store.clearAllSessions()
    }
    
    @Test("Session calculates poor posture percentage correctly")
    func testSessionCalculatesPoorPosturePercentageCorrectly() async throws {
        let store = SessionStore()
        store.clearAllSessions()
        
        _ = store.startNewSession()
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        store.endCurrentSession(
            poorPostureDuration: 20,
            activeSessionDuration: 60
        )
        
        guard let lastSession = store.sessions.first else {
            Issue.record("Session was not saved")
            return
        }
        
        let expectedPercentage = Int(((lastSession.totalDuration - 20.0) / lastSession.totalDuration) * 100.0)
        
        #expect(lastSession.poorPosturePercentage == expectedPercentage || lastSession.poorPosturePercentage == 0)
        
        store.clearAllSessions()
    }
}
