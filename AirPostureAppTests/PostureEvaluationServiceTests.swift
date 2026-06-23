import XCTest
@testable import AirPosture

final class PostureEvaluationServiceTests: XCTestCase {

    private var service: PostureEvaluationService!
    private var hapticController: HapticFeedbackController!

    override func setUp() {
        super.setUp()
        service = PostureEvaluationService()
        hapticController = HapticFeedbackController()
    }

    override func tearDown() {
        service = nil
        hapticController = nil
        super.tearDown()
    }

    // MARK: - Good Posture

    func testGoodPostureWithUprightPitch() {
        service.evaluatePosture(newPitch: -5, sessionStartTime: Date(), hapticController: hapticController)

        if case .good = service.postureState {
            // pass
        } else {
            XCTFail("Expected good posture state for upright pitch")
        }
    }

    // MARK: - Poor Posture Detection

    func testIsPoorPostureWhenBelowThreshold() {
        XCTAssertTrue(service.isPoorPosture(pitch: -30))
    }

    func testIsNotPoorPostureWhenAboveThreshold() {
        XCTAssertFalse(service.isPoorPosture(pitch: -10))
    }

    func testIsPoorPostureRespectsNormalAngleOffset() {
        service.normalAirPodsAngle = -10
        XCTAssertTrue(service.isPoorPosture(pitch: -35))
    }

    // MARK: - Threshold Persistence

    func testThresholdDefaultsToMotionConstants() {
        XCTAssertEqual(service.poorPostureThreshold, MotionConstants.poorPostureThreshold)
    }

    func testNormalAngleDefaultsToMotionConstants() {
        XCTAssertEqual(service.normalAirPodsAngle, MotionConstants.normalAirPodsAngle)
    }
}
