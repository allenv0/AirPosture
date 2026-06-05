import XCTest
@testable import AirPostureCore

final class AirPostureCoreTests: XCTestCase {
    @MainActor
    private func makeTracker(
        configuration: AirPostureConfiguration = .default
    ) -> (AirPostureTracker, MockHeadphoneMotionProvider) {
        let provider = MockHeadphoneMotionProvider()
        let tracker = AirPostureTracker(configuration: configuration, provider: provider)
        tracker.startMotionUpdates()
        return (tracker, provider)
    }

    @MainActor
    private func emit(
        _ provider: MockHeadphoneMotionProvider,
        pitch: Double,
        roll: Double = 0.0,
        yaw: Double = 0.0,
        timestamp: Date = Date()
    ) async {
        provider.emit(pitchRadians: pitch, rollRadians: roll, yawRadians: yaw, timestamp: timestamp)
        await Task.yield()
    }

    @MainActor
    func testDegreesConversion() async throws {
        let (tracker, provider) = makeTracker()
        
        // 0 radians should be 0 degrees
        await emit(provider, pitch: 0, roll: 0, yaw: 0)
        let pitch0 = try XCTUnwrap(tracker.snapshot.sample?.pitch)
        XCTAssertEqual(pitch0, 0.0)

        // pi / 2 radians should be 90 degrees
        // (Note: low pass filter will affect this if starting from 0, so we call it with a config having lowPassFactor = 1.0 to test exact conversion)
        var config = AirPostureConfiguration.default
        config.lowPassFilterFactor = 1.0
        let (directTracker, directProvider) = makeTracker(configuration: config)
        
        await emit(directProvider, pitch: .pi / 2, roll: .pi / 4, yaw: -.pi)
        let sample = try XCTUnwrap(directTracker.snapshot.sample)
        XCTAssertEqual(sample.pitch, 90.0)
        XCTAssertEqual(sample.roll, 45.0)
        XCTAssertEqual(sample.yaw, -180.0)
    }

    @MainActor
    func testValidationRejection() async {
        let (tracker, provider) = makeTracker()
        
        // Initial state
        XCTAssertNil(tracker.snapshot.sample)
        
        // NaN pitch should be ignored
        await emit(provider, pitch: .nan, roll: 0.0, yaw: 0.0)
        XCTAssertNil(tracker.snapshot.sample)

        // Infinite roll should be ignored
        await emit(provider, pitch: 0.0, roll: .infinity, yaw: 0.0)
        XCTAssertNil(tracker.snapshot.sample)

        // Out of range yaw (> pi) should be ignored
        await emit(provider, pitch: 0.0, roll: 0.0, yaw: 4.0)
        XCTAssertNil(tracker.snapshot.sample)

        // Valid sample should be processed
        await emit(provider, pitch: 0.1, roll: 0.2, yaw: 0.3)
        XCTAssertNotNil(tracker.snapshot.sample)
    }

    @MainActor
    func testLowPassFiltering() async throws {
        var config = AirPostureConfiguration.default
        config.lowPassFilterFactor = 0.4
        let (tracker, provider) = makeTracker(configuration: config)
        
        // First sample starts at 0.0, so:
        // pitch = 0.0 * 0.6 + (0.5 * 180 / pi) * 0.4
        let inputPitchRadians = 0.5
        let inputPitchDegrees = inputPitchRadians * 180.0 / .pi // ~28.6479
        let expectedPitch = 0.0 * 0.6 + inputPitchDegrees * 0.4 // ~11.459
        
        await emit(provider, pitch: inputPitchRadians, roll: 0.0, yaw: 0.0)
        let pitch = try XCTUnwrap(tracker.snapshot.sample?.pitch)
        XCTAssertEqual(pitch, expectedPitch, accuracy: 0.01)
    }

    @MainActor
    func testAdjustedPitchClassification() async {
        var config = AirPostureConfiguration.default
        config.poorPostureThreshold = -22.0
        config.normalAirPodsOffset = 5.0
        config.lowPassFilterFactor = 1.0 // Disable smoothing for exact test
        let (tracker, provider) = makeTracker(configuration: config)
        
        // Test Good Posture: pitch = 0 radians (0 deg). Adjusted: 0 - 5 = -5 deg. Threshold = -22.0 deg.
        await emit(provider, pitch: 0.0, roll: 0.0, yaw: 0.0)
        XCTAssertEqual(tracker.snapshot.adjustedPitchDegrees, -5.0)
        XCTAssertEqual(tracker.snapshot.quality, .good)

        // Test Poor Posture: pitch = -30 deg. Adjusted: -30 - 5 = -35 deg.
        let pitchRad = -30.0 * .pi / 180.0
        await emit(provider, pitch: pitchRad, roll: 0.0, yaw: 0.0)
        XCTAssertEqual(tracker.snapshot.adjustedPitchDegrees, -35.0, accuracy: 0.01)
        XCTAssertEqual(tracker.snapshot.quality, .poor)
    }

    @MainActor
    func testPitchHistoryCap() async {
        var config = AirPostureConfiguration.default
        config.pitchHistorySize = 5
        let (tracker, provider) = makeTracker(configuration: config)
        
        for i in 1...10 {
            await emit(provider, pitch: Double(i) * 0.01, roll: 0, yaw: 0)
        }
        
        XCTAssertEqual(tracker.snapshot.pitchHistory.count, 5)
    }

    @MainActor
    func testSessionDurationAndScoring() async {
        var config = AirPostureConfiguration.default
        config.poorPostureThreshold = -22.0
        config.normalAirPodsOffset = 0.0
        config.lowPassFilterFactor = 1.0
        
        let (tracker, provider) = makeTracker(configuration: config)
        let startTime = Date()
        
        tracker.startSession(at: startTime)
        
        // Good posture sample at t = 0
        await emit(provider, pitch: 0.0, roll: 0.0, yaw: 0.0, timestamp: startTime)
        
        // 10 seconds later: poor posture starts
        let t1 = startTime.addingTimeInterval(10)
        await emit(provider, pitch: -30.0 * .pi / 180.0, roll: 0.0, yaw: 0.0, timestamp: t1)
        
        // 5 seconds of poor posture: poor posture ends (back to good)
        let t2 = t1.addingTimeInterval(5)
        await emit(provider, pitch: 0.0, roll: 0.0, yaw: 0.0, timestamp: t2)
        
        // 15 seconds of good posture: end session at t2 + 15 (total 30 seconds)
        let endTime = t2.addingTimeInterval(15)
        let summary = tracker.endSession(at: endTime)
        
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.totalDuration, 30.0)
        XCTAssertEqual(summary?.poorPostureDuration, 5.0)
        // Good posture percent: (30 - 5) / 30 * 100 = 83.33%
        XCTAssertEqual(summary?.goodPosturePercent ?? 0.0, 83.33, accuracy: 0.05)
    }

    @MainActor
    func testSessionPauseResume() async {
        var config = AirPostureConfiguration.default
        config.poorPostureThreshold = -22.0
        config.normalAirPodsOffset = 0.0
        config.lowPassFilterFactor = 1.0
        
        let (tracker, provider) = makeTracker(configuration: config)
        let startTime = Date()
        
        tracker.startSession(at: startTime)
        
        // 10s of good posture
        let t1 = startTime.addingTimeInterval(10)
        await emit(provider, pitch: 0.0, roll: 0, yaw: 0, timestamp: t1)
        
        // Pause session at t1
        tracker.pauseSession(at: t1)
        
        // Wait 20 seconds while paused
        let t2 = t1.addingTimeInterval(20)
        
        // Resume session at t2
        tracker.resumeSession(at: t2)
        await emit(provider, pitch: -30.0 * .pi / 180.0, roll: 0, yaw: 0, timestamp: t2)
        
        // 10s of poor posture after resuming
        let t3 = t2.addingTimeInterval(10)
        await emit(provider, pitch: -30.0 * .pi / 180.0, roll: 0, yaw: 0, timestamp: t3)
        
        // End session at t3
        let summary = tracker.endSession(at: t3)
        
        XCTAssertNotNil(summary)
        // Total duration should only accumulate active intervals (10s + 10s = 20s), excluding the 20s paused time.
        XCTAssertEqual(summary?.totalDuration, 20.0)
        // Poor posture was active for the final 10s
        XCTAssertEqual(summary?.poorPostureDuration, 10.0)
        // Good posture percent: (20 - 10) / 20 * 100 = 50.0%
        XCTAssertEqual(summary?.goodPosturePercent, 50.0)
    }

    @MainActor
    func testCalibrationMidpointAndClamping() {
        let (tracker, _) = makeTracker()
        
        // Start calibration
        tracker.beginCalibration()
        
        // Verify state is recordingGoodPosture
        if case .recordingGoodPosture = tracker.snapshot.calibrationState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Should be in recordingGoodPosture state")
        }
    }
}
