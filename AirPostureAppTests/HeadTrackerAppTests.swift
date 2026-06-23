import Testing
import CoreMotion
@testable import AirPosture

@Suite("HeadphoneMotionManager Tests")
@MainActor
struct HeadphoneMotionManagerTests {
    
    @Test("Initial state is correct") func testInitialState() async throws {
        let manager = HeadphoneMotionManager.shared
        #expect(manager.pitch == 0.0)
        #expect(manager.roll == 0.0)
        #expect(manager.yaw == 0.0)
        #expect(manager.isDeviceConnected == false)
        #expect(manager.pitchHistory.isEmpty)
    }
    
    @Test("Low pass filter works correctly") func testLowPassFilter() async throws {
        let manager = HeadphoneMotionManager.shared
        let filtered = manager.lowPassFilter(current: 10.0, previous: 0.0)
        #expect(filtered > 0.0 && filtered < 10.0)
    }
    
    @Test("Pitch history is updated correctly") func testPitchHistory() async throws {
        let manager = HeadphoneMotionManager.shared
        let motion = CMDeviceMotion.mock()
        
        // Simulate motion data
        motion.setValue(0.5, forKeyPath: "attitude.pitch") // ~28.65 degrees
        manager.processMotionData(motion)
        
        // Wait for async updates
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #expect(!manager.pitchHistory.isEmpty)
        #expect(manager.pitch > 0.0)
    }
    
    @Test("Posture state updates correctly") func testPostureState() async throws {
        let manager = HeadphoneMotionManager.shared
        let motion = CMDeviceMotion.mock()
        
        // Simulate poor posture (pitch > warning threshold)
        motion.setValue(0.5, forKeyPath: "attitude.pitch") // ~28.65 degrees (above 20° warning threshold)
        manager.processMotionData(motion)
        
        // Wait for async updates
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        if case .warning = manager.postureState {
            // Expected case - test passes
        } else {
            Issue.record("Expected warning state, got \(String(describing: manager.postureState))")
        }
    }
}

@Suite("Session Model Tests")
struct SessionModelTests {

    @Test("Session initialization") func testSessionInit() {
        let now = Date()
        let session = Session(startTime: now, endTime: now.addingTimeInterval(60), poorPostureDuration: 30, avatarType: "cat-neck")

        #expect(session.totalDuration == 60)
        #expect(session.poorPosturePercentage == 50)
        #expect(session.avatarType == "cat-neck")
    }

    @Test("SessionStore operations") func testSessionStore() async throws {
        let store = SessionStore()
        store.clearAllSessions()

        _ = store.startNewSession()
        #expect(store.currentSession != nil)

        store.endCurrentSession(
            poorPostureDuration: 30,
            activeSessionDuration: 60
        )
        #expect(store.currentSession == nil)
        #expect(!store.sessions.isEmpty)

        if let savedSession = store.sessions.first {
            #expect(savedSession.poorPostureDuration == 30)
        } else {
            Issue.record("Session was not saved correctly")
        }

        store.clearAllSessions()
        #expect(store.sessions.isEmpty)
    }
}

@Suite("Running Duration & Bear-Running Avatar Tests")
struct RunningDurationTests {

    // MARK: - Core Functionality Tests

    @Test("runningWalkingDuration is saved when ending session") func testRunningWalkingDurationSaved() async throws {
        let store = SessionStore()
        store.clearAllSessions()

        _ = store.startNewSession()

        // Simulate a session with 60 seconds total, 30 seconds of running (50%)
        let poorPostureDuration: TimeInterval = 10
        let activeSessionDuration: TimeInterval = 60
        let runningWalkingDuration: TimeInterval = 30

        store.endCurrentSession(
            poorPostureDuration: poorPostureDuration,
            activeSessionDuration: activeSessionDuration,
            runningWalkingDuration: runningWalkingDuration
        )

        #expect(store.currentSession == nil)
        #expect(!store.sessions.isEmpty)

        guard let savedSession = store.sessions.first else {
            Issue.record("Session was not saved correctly")
            return
        }

        #expect(savedSession.runningWalkingDuration == runningWalkingDuration,
               "Expected runningWalkingDuration to be \(runningWalkingDuration), got \(savedSession.runningWalkingDuration)")

        store.clearAllSessions()
    }

    @Test("runningWalkingPercentage is calculated correctly") func testRunningWalkingPercentageCalculation() async throws {
        // Test Case 1: 50% running
        let session1 = Session(
            startTime: Date(),
            endTime: Date().addingTimeInterval(60),
            poorPostureDuration: 0,
            activeSessionDuration: 60,
            runningWalkingDuration: 30,
            avatarType: "bear-neck"
        )
        #expect(session1.runningWalkingPercentage == 50.0,
               "Expected 50% running, got \(session1.runningWalkingPercentage)%")

        // Test Case 2: 75% running
        let session2 = Session(
            startTime: Date(),
            endTime: Date().addingTimeInterval(100),
            poorPostureDuration: 0,
            activeSessionDuration: 100,
            runningWalkingDuration: 75,
            avatarType: "bear-neck"
        )
        #expect(session2.runningWalkingPercentage == 75.0,
               "Expected 75% running, got \(session2.runningWalkingPercentage)%")

        // Test Case 3: 0% running (no running)
        let session3 = Session(
            startTime: Date(),
            endTime: Date().addingTimeInterval(60),
            poorPostureDuration: 0,
            activeSessionDuration: 60,
            runningWalkingDuration: 0,
            avatarType: "bear-neck"
        )
        #expect(session3.runningWalkingPercentage == 0.0,
               "Expected 0% running, got \(session3.runningWalkingPercentage)%")

        // Test Case 4: 100% running (entire session)
        let session4 = Session(
            startTime: Date(),
            endTime: Date().addingTimeInterval(60),
            poorPostureDuration: 0,
            activeSessionDuration: 60,
            runningWalkingDuration: 60,
            avatarType: "bear-neck"
        )
        #expect(session4.runningWalkingPercentage == 100.0,
               "Expected 100% running, got \(session4.runningWalkingPercentage)%")
    }

    @Test("SessionData model preserves runningWalkingPercentage") func testSessionDataPreservesRunningPercentage() async throws {
        let now = Date()
        let session = Session(
            startTime: now,
            endTime: now.addingTimeInterval(120),
            poorPostureDuration: 20,
            activeSessionDuration: 120,
            runningWalkingDuration: 70, // ~58.3%
            avatarType: "bear-neck"
        )

        let sessionData = SessionData(from: session)

        // Verify SessionData correctly calculates running percentage
        let expectedPercentage = (70.0 / 120.0) * 100
        #expect(abs(sessionData.runningWalkingPercentage - expectedPercentage) < 0.01,
               "Expected runningWalkingPercentage to be \(expectedPercentage)%, got \(sessionData.runningWalkingPercentage)%")

        #expect(sessionData.runningWalkingDuration == 70,
               "Expected runningWalkingDuration to be 70, got \(sessionData.runningWalkingDuration)")
    }

    // MARK: - Bear-Running Avatar Logic Tests

    @Test("Bear-running avatar shows when running > 50%") func testBearRunningAvatarShowsAbove50Percent() async throws {
        let now = Date()

        // Test with 55% running (should show bear-running)
        let sessionAbove50 = Session(
            startTime: now,
            endTime: now.addingTimeInterval(100),
            poorPostureDuration: 0,
            activeSessionDuration: 100,
            runningWalkingDuration: 55, // 55%
            avatarType: "cat-neck"
        )

        // The avatar logic: session.runningWalkingPercentage > 50 ? "bear-running" : session.avatarType
        let shouldShowBearRunning = sessionAbove50.runningWalkingPercentage > 50
        #expect(shouldShowBearRunning,
               "Expected bear-running avatar for 55% running, got percentage: \(sessionAbove50.runningWalkingPercentage)%")
    }

    @Test("Default avatar shows when running <= 50%") func testDefaultAvatarShowsAtOrBelow50Percent() async throws {
        let now = Date()

        // Test with exactly 50% running (should show default avatar)
        let sessionAt50 = Session(
            startTime: now,
            endTime: now.addingTimeInterval(100),
            poorPostureDuration: 0,
            activeSessionDuration: 100,
            runningWalkingDuration: 50, // Exactly 50%
            avatarType: "dog-neck"
        )

        // The avatar logic: session.runningWalkingPercentage > 50 ? "bear-running" : session.avatarType
        let shouldShowDefault = sessionAt50.runningWalkingPercentage <= 50
        #expect(shouldShowDefault,
               "Expected default avatar for 50% running")

        // Test with 30% running (should show default avatar)
        let sessionBelow50 = Session(
            startTime: now,
            endTime: now.addingTimeInterval(100),
            poorPostureDuration: 0,
            activeSessionDuration: 100,
            runningWalkingDuration: 30, // 30%
            avatarType: "bear-neck"
        )

        let shouldShowDefault2 = sessionBelow50.runningWalkingPercentage <= 50
        #expect(shouldShowDefault2,
               "Expected default avatar for 30% running")
    }

    // MARK: - Edge Cases

    @Test("Session with zero running duration") func testZeroRunningDuration() async throws {
        let store = SessionStore()
        store.clearAllSessions()

        _ = store.startNewSession()

        // End session with no running activity
        store.endCurrentSession(
            poorPostureDuration: 15,
            activeSessionDuration: 60,
            runningWalkingDuration: 0
        )

        guard let session = store.sessions.first else {
            Issue.record("Session was not saved")
            return
        }

        #expect(session.runningWalkingDuration == 0,
               "Expected runningWalkingDuration to be 0")
        #expect(session.runningWalkingPercentage == 0.0,
               "Expected runningWalkingPercentage to be 0%")

        // Should use default avatar, not bear-running
        #expect(session.runningWalkingPercentage <= 50,
               "Should not show bear-running avatar for 0% running")

        store.clearAllSessions()
    }

    @Test("Session with zero total duration handles gracefully") func testZeroTotalDuration() async throws {
        let session = Session(
            startTime: Date(),
            endTime: Date(),
            poorPostureDuration: 0,
            activeSessionDuration: 0,
            runningWalkingDuration: 0,
            avatarType: "bear-neck"
        )

        // Should handle division by zero gracefully
        #expect(session.runningWalkingPercentage == 0.0,
               "Expected runningWalkingPercentage to be 0 for zero duration")
    }

    @Test("Session persistence saves runningWalkingDuration to UserDefaults") func testRunningDurationPersistence() async throws {
        let store = SessionStore()
        store.clearAllSessions()

        try await Task.sleep(nanoseconds: 200_000_000)

        _ = store.startNewSession()

        let runningDuration: TimeInterval = 90
        store.endCurrentSession(
            poorPostureDuration: 10,
            activeSessionDuration: 120,
            runningWalkingDuration: runningDuration
        )

        try await Task.sleep(nanoseconds: 1_000_000_000)

        guard let persistedData = UserDefaults.standard.data(forKey: "sessions"),
              let restoredSessions = try? JSONDecoder().decode([Session].self, from: persistedData),
              let restoredSession = restoredSessions.first else {
            Issue.record("Session was not persisted")
            return
        }

        #expect(restoredSession.runningWalkingDuration == runningDuration,
               "Expected persisted runningWalkingDuration to be \(runningDuration), got \(restoredSession.runningWalkingDuration)")

        let expectedPercentage = (90.0 / 120.0) * 100
        #expect(abs(restoredSession.runningWalkingPercentage - expectedPercentage) < 0.01,
               "Expected runningWalkingPercentage to be \(expectedPercentage)% after persistence, got \(restoredSession.runningWalkingPercentage)%")

        store.clearAllSessions()
    }

    @Test("wasRunningOrWalking property works correctly") func testWasRunningOrWalkingProperty() async throws {
        let now = Date()

        // Less than 1 minute (60 seconds) should return false
        let sessionShort = Session(
            startTime: now,
            endTime: now.addingTimeInterval(60),
            poorPostureDuration: 0,
            activeSessionDuration: 60,
            runningWalkingDuration: 30, // Only 30 seconds of running
            avatarType: "bear-neck"
        )
        #expect(!sessionShort.wasRunningOrWalking,
               "Expected wasRunningOrWalking to be false for 30 seconds of running")

        // Exactly 1 minute should return true
        let sessionExactly1Min = Session(
            startTime: now,
            endTime: now.addingTimeInterval(60),
            poorPostureDuration: 0,
            activeSessionDuration: 60,
            runningWalkingDuration: 60, // Exactly 60 seconds
            avatarType: "bear-neck"
        )
        #expect(sessionExactly1Min.wasRunningOrWalking,
               "Expected wasRunningOrWalking to be true for exactly 60 seconds of running")

        // More than 1 minute should return true
        let sessionLong = Session(
            startTime: now,
            endTime: now.addingTimeInterval(120),
            poorPostureDuration: 0,
            activeSessionDuration: 120,
            runningWalkingDuration: 90, // 90 seconds of running
            avatarType: "bear-neck"
        )
        #expect(sessionLong.wasRunningOrWalking,
               "Expected wasRunningOrWalking to be true for 90 seconds of running")
    }

    @Test("Equality includes runningWalkingDuration") func testSessionEqualityIncludesRunningDuration() async throws {
        let now = Date()

        let session1 = Session(
            startTime: now,
            endTime: now.addingTimeInterval(60),
            poorPostureDuration: 10,
            activeSessionDuration: 60,
            runningWalkingDuration: 30,
            avatarType: "bear-neck"
        )

        let session2 = Session(
            startTime: now,
            endTime: now.addingTimeInterval(60),
            poorPostureDuration: 10,
            activeSessionDuration: 60,
            runningWalkingDuration: 30,
            avatarType: "bear-neck"
        )

        // Same values should be equal
        #expect(session1 == session2,
               "Expected sessions with identical runningWalkingDuration to be equal")

        // Different running duration should not be equal
        let session3 = Session(
            startTime: now,
            endTime: now.addingTimeInterval(60),
            poorPostureDuration: 10,
            activeSessionDuration: 60,
            runningWalkingDuration: 45, // Different!
            avatarType: "bear-neck"
        )

        #expect(session1 != session3,
               "Expected sessions with different runningWalkingDuration to not be equal")
    }
}

@Suite("Avatar Manager Tests")
struct AvatarManagerTests {

    @Test("Avatar persistence works correctly") func testAvatarPersistence() async throws {
        // Clear any existing avatar preference
        UserDefaults.standard.removeObject(forKey: "selectedAvatar")

        // Create a new avatar manager instance
        let manager = AvatarManager.shared

        // Default should be bear
        #expect(manager.selectedAvatar == .bear)

        // Change to cat
        manager.selectedAvatar = .cat

        // Verify it's saved to UserDefaults
        let savedValue = UserDefaults.standard.string(forKey: "selectedAvatar")
        #expect(savedValue == "cat-neck")

        // Change to dog
        manager.selectedAvatar = .dog

        // Verify it's updated in UserDefaults
        let updatedValue = UserDefaults.standard.string(forKey: "selectedAvatar")
        #expect(updatedValue == "dog-neck")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "selectedAvatar")
    }

    @Test("Avatar manager loads saved preference") func testAvatarManagerLoading() async throws {
        // Set a saved preference
        UserDefaults.standard.set("cat-neck", forKey: "selectedAvatar")

        // Create a new manager instance (simulating app restart)
        // Note: Since AvatarManager is a singleton, we can't easily test this
        // without resetting the singleton, but we can test the initialization logic
        let savedAvatar = UserDefaults.standard.string(forKey: "selectedAvatar") ?? AvatarType.bear.rawValue
        let loadedAvatar = AvatarType(rawValue: savedAvatar) ?? .bear

        #expect(loadedAvatar == .cat)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "selectedAvatar")
    }

    @Test("Sessions capture current avatar") func testSessionCapturesAvatar() async throws {
        // Set a specific avatar
        UserDefaults.standard.set("dog-neck", forKey: "selectedAvatar")

        // Create a new session store to test session creation
        let store = SessionStore()
        store.clearAllSessions()

        // Start a new session
        let session = store.startNewSession()

        // Verify the session captured the current avatar
        #expect(session.avatarType == "dog-neck")

        // Clean up
        store.clearAllSessions()
        UserDefaults.standard.removeObject(forKey: "selectedAvatar")
    }
}

// MARK: - Test Utilities

extension CMDeviceMotion {
    static func mock() -> CMDeviceMotion {
        let motion = CMDeviceMotion()
        let attitude = CMAttitude()
        attitude.roll = 0
        attitude.pitch = 0
        attitude.yaw = 0
        motion.setValue(attitude, forKey: "attitude")
        return motion
    }
}

// Mock CMAttitude for testing
class CMAttitude: NSObject {
    var roll: Double = 0
    var pitch: Double = 0
    var yaw: Double = 0
}
