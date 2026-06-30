import CoreMotion
import XCTest
@testable import AirPosture

/// Focused tests for the extracted motion pipeline.
///
/// Marked `@MainActor` because `HeadphoneMotionPipeline` is main-actor-isolated;
/// this avoids the main-actor-in-nonisolated-context errors seen in
/// `PostureEvaluationServiceTests`.
@MainActor
final class HeadphoneMotionPipelineTests: XCTestCase {

    private var pipeline: HeadphoneMotionPipeline!

    override func setUp() {
        super.setUp()
        pipeline = HeadphoneMotionPipeline()
    }

    override func tearDown() {
        pipeline = nil
        super.tearDown()
    }

    // MARK: - Low-Pass Filter

    func testLowPassFilterStaysBetweenCurrentAndPrevious() {
        // factor = 0.4 -> output = previous * 0.6 + current * 0.4
        let filtered = pipeline.lowPassFilter(current: 10.0, previous: 0.0)

        XCTAssertEqual(filtered, 4.0, accuracy: 0.0001)
        XCTAssertLessThan(filtered, 10.0)
        XCTAssertGreaterThan(filtered, 0.0)
    }

    func testLowPassFilterEqualsCurrentWhenPreviousMatches() {
        let filtered = pipeline.lowPassFilter(current: 7.0, previous: 7.0)
        XCTAssertEqual(filtered, 7.0, accuracy: 0.0001)
    }

    // MARK: - Validation

    func testValidSampleIsAccepted() {
        let motion = Self.makeMotion(pitch: 0.0, roll: 0.0, yaw: 0.0)
        XCTAssertTrue(pipeline.validate(motion))
    }

    func testNaNIsRejected() {
        let motion = Self.makeMotion(pitch: .nan, roll: 0.0, yaw: 0.0)
        XCTAssertFalse(pipeline.validate(motion))
    }

    func testInfiniteIsRejected() {
        let motion = Self.makeMotion(pitch: 0.0, roll: .infinity, yaw: 0.0)
        XCTAssertFalse(pipeline.validate(motion))
    }

    func testOutOfRangeIsRejected() {
        // Just beyond the [-pi, pi] valid range.
        let motion = Self.makeMotion(pitch: Double.pi + 0.1, roll: 0.0, yaw: 0.0)
        XCTAssertFalse(pipeline.validate(motion))
    }

    // MARK: - Sample Processing

    func testProcessReturnsNilForInvalidSampleAndLeavesHistoryUntouched() {
        // Seed one good sample so we can assert history is not mutated later.
        _ = pipeline.process(Self.makeMotion(pitch: 0.1, roll: 0.0, yaw: 0.0), previousPitch: 0.0)
        let seededCount = pipeline.pitchHistory.count

        let result = pipeline.process(Self.makeMotion(pitch: .nan, roll: 0.0, yaw: 0.0), previousPitch: 0.0)

        XCTAssertNil(result)
        XCTAssertEqual(pipeline.pitchHistory.count, seededCount)
    }

    func testProcessConvertsRadiansToDegrees() {
        // pitch = pi/2 rad -> 90 deg. With previousPitch 0 and factor 0.4:
        // newPitch = 0 * 0.6 + 90 * 0.4 = 36
        let motion = Self.makeMotion(pitch: Double.pi / 2, roll: 0.0, yaw: 0.0)
        let sample = pipeline.process(motion, previousPitch: 0.0)

        XCTAssertEqual(sample?.pitch, 36.0, accuracy: 0.0001)
        XCTAssertEqual(sample?.roll, 0.0, accuracy: 0.0001)
        XCTAssertEqual(sample?.yaw, 0.0, accuracy: 0.0001)
    }

    // MARK: - Pitch History

    func testPitchHistoryAppendsEachAcceptedSample() {
        _ = pipeline.process(Self.makeMotion(pitch: 0.0, roll: 0.0, yaw: 0.0), previousPitch: 0.0)
        _ = pipeline.process(Self.makeMotion(pitch: 0.1, roll: 0.0, yaw: 0.0), previousPitch: 0.0)

        XCTAssertEqual(pipeline.pitchHistory.count, 2)
    }

    func testPitchHistoryCapsAtMaxDataPointsAndEvictsOldest() {
        let cap = MotionConstants.maxDataPoints

        for _ in 0..<(cap + 5) {
            _ = pipeline.process(Self.makeMotion(pitch: 0.1, roll: 0.0, yaw: 0.0), previousPitch: 0.0)
        }

        XCTAssertEqual(pipeline.pitchHistory.count, cap)
    }

    func testResetClearsPitchHistoryAndSmoothedPitch() {
        _ = pipeline.process(Self.makeMotion(pitch: 0.1, roll: 0.0, yaw: 0.0), previousPitch: 0.0)
        XCTAssertFalse(pipeline.pitchHistory.isEmpty)

        pipeline.reset()

        XCTAssertTrue(pipeline.pitchHistory.isEmpty)
        XCTAssertEqual(pipeline.pitch, 0.0)
    }

    // MARK: - Helpers

    /// Builds a `CMDeviceMotion` mock with the supplied attitude (radians),
    /// reusing the test target's shared `CMDeviceMotion.mock()` infrastructure.
    private static func makeMotion(pitch: Double, roll: Double, yaw: Double) -> CMDeviceMotion {
        let motion = CMDeviceMotion.mock()
        let attitude = CMAttitude()
        attitude.pitch = pitch
        attitude.roll = roll
        attitude.yaw = yaw
        motion.setValue(attitude, forKey: "attitude")
        return motion
    }
}
