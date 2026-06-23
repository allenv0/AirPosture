import XCTest
@testable import AirPosture

final class SessionTimingServiceTests: XCTestCase {

    private var sessionStore: SessionStore!
    private var service: SessionTimingService!

    override func setUp() {
        super.setUp()
        sessionStore = SessionStore.shared
        service = SessionTimingService(sessionStore: sessionStore)
    }

    override func tearDown() {
        service = nil
        sessionStore = nil
        super.tearDown()
    }

    // MARK: - Session Start

    func testStartNewSessionResetsAllState() {
        service.startNewSession()

        XCTAssertEqual(service.totalSessionTime, 0)
        XCTAssertEqual(service.poorPostureDuration, 0)
        XCTAssertEqual(service.postureScorePercent, 0)
        XCTAssertEqual(service.runningWalkingDuration, 0)
        XCTAssertFalse(service.isPaused)
        XCTAssertFalse(service.sessionPaused)
        XCTAssertTrue(service.hasStarted)
    }

    // MARK: - Score Calculation

    func testScoreIs100WhenNoPoorPosture() {
        service.startNewSession()
        service.updateSessionTimers(adjustedPitch: 0, threshold: -22, hasActiveSession: true)

        XCTAssertEqual(service.postureScorePercent, 100)
    }

    func testScoreIs0WhenEntirelyPoorPosture() {
        service.startNewSession()
        service.updateSessionTimers(adjustedPitch: -30, threshold: -22, hasActiveSession: true)

        XCTAssertEqual(service.postureScorePercent, 0)
    }

    func testScoreClampsTo0And100() {
        service.startNewSession()
        service.updateSessionTimers(adjustedPitch: 0, threshold: -22, hasActiveSession: true)
        XCTAssertGreaterThanOrEqual(service.postureScorePercent, 0)
        XCTAssertLessThanOrEqual(service.postureScorePercent, 100)
    }

    // MARK: - Pause/Resume

    func testTogglePauseTogglesState() {
        service.startNewSession()
        XCTAssertFalse(service.isPaused)

        service.togglePause()
        XCTAssertTrue(service.isPaused)

        service.togglePause()
        XCTAssertFalse(service.isPaused)
    }

    func testSessionTimersDoNotUpdateWhenPaused() {
        service.startNewSession()
        service.togglePause()

        let before = service.totalSessionTime
        service.updateSessionTimers(adjustedPitch: 0, threshold: -22, hasActiveSession: true)
        XCTAssertEqual(service.totalSessionTime, before)
    }

    // MARK: - No Active Session

    func testSessionTimersResetWhenNoActiveSession() {
        service.startNewSession()
        service.updateSessionTimers(adjustedPitch: 0, threshold: -22, hasActiveSession: true)
        XCTAssertGreaterThan(service.totalSessionTime, 0)

        service.updateSessionTimers(adjustedPitch: 0, threshold: -22, hasActiveSession: false)
        XCTAssertEqual(service.totalSessionTime, 0)
    }

    // MARK: - Reset

    func testResetClearsAllState() {
        service.startNewSession()
        service.updateSessionTimers(adjustedPitch: 0, threshold: -22, hasActiveSession: true)

        service.resetSession()

        XCTAssertEqual(service.totalSessionTime, 0)
        XCTAssertEqual(service.poorPostureDuration, 0)
        XCTAssertEqual(service.postureScorePercent, 0)
        XCTAssertFalse(service.isPaused)
        XCTAssertFalse(service.sessionPaused)
    }

    // MARK: - Background Update

    func testBackgroundUpdateAdvancesTime() {
        service.startNewSession()
        service.setLastPoorPostureUpdate(Date().addingTimeInterval(-1))

        let before = service.totalSessionTime
        service.performBackgroundUpdate(hasActiveSession: true)

        XCTAssertGreaterThan(service.totalSessionTime, before)
    }

    func testBackgroundUpdateSkipsWhenNoSession() {
        service.startNewSession()
        service.setLastPoorPostureUpdate(Date())

        let before = service.totalSessionTime
        service.performBackgroundUpdate(hasActiveSession: false)

        XCTAssertEqual(service.totalSessionTime, before)
    }

    // MARK: - Activity Detection

    func testHandleActivityUpdateStartsTracking() {
        let now = Date()
        service.handleActivityUpdate(isCurrentlyActive: true, at: now)
        XCTAssertTrue(service.isUserRunningOrWalking)
    }

    func testHandleActivityUpdateStopsTrackingAndAccumulates() {
        let now = Date()
        service.handleActivityUpdate(isCurrentlyActive: true, at: now)
        let later = now.addingTimeInterval(30)
        service.handleActivityUpdate(isCurrentlyActive: false, at: later)

        XCTAssertFalse(service.isUserRunningOrWalking)
        XCTAssertGreaterThanOrEqual(service.runningWalkingDuration, 30)
    }

    // MARK: - End Session

    func testEndSessionReturnsCorrectValues() {
        service.startNewSession()
        service.updateSessionTimers(adjustedPitch: 0, threshold: -22, hasActiveSession: true)

        let result = service.endSession()
        XCTAssertGreaterThan(result.totalSessionTime, 0)
        XCTAssertEqual(service.totalSessionTime, 0)
    }
}
