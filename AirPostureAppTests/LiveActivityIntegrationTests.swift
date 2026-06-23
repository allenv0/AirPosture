import ActivityKit
import Foundation
import Testing
@testable import AirPosture

@Suite("Live Activity Integration Tests")
struct LiveActivityIntegrationTests {
    @Test("Push mode stays local when relay is not configured")
    func testPushModeDefaultsToLocalOnly() {
        #expect(
            AirPosture.LiveActivityController.pushMode(relayBaseURLString: nil) == .localOnly
        )
        #expect(
            AirPosture.LiveActivityController.pushMode(relayBaseURLString: "") == .localOnly
        )
    }

    @Test("Push mode uses token updates when relay is configured")
    func testPushModeUsesTokenWhenRelayExists() {
        #expect(
            AirPosture.LiveActivityController.pushMode(
                relayBaseURLString: "https://relay.example.com"
            ) == .pushToken
        )
    }

    @Test("Live Activities authorization info is accessible")
    func testAuthorizationCheck() {
        let authInfo = ActivityAuthorizationInfo()
        let _ = authInfo.areActivitiesEnabled
        let _ = authInfo.frequentPushesEnabled
    }

    @Test("LiveActivityController singleton exists")
    func testControllerSingleton() {
        let controller = AirPosture.LiveActivityController.shared
        #expect(controller != nil)
    }

    @Test("Controller handles current start update end sequence")
    func testControllerLifecycleSequence() async throws {
        await MainActor.run {
            let controller = AirPosture.LiveActivityController.shared
            let sessionId = UUID()

            controller.start(
                sessionId: sessionId,
                avatarAssetName: "bear-neck",
                userDisplayName: "Test User",
                sessionStartTime: Date()
            )

            controller.update(
                sessionScorePercent: 64,
                status: AirPosture.PostureStatus.poor,
                calibratedTilt: -24,
                lean: 6,
                elapsedSeconds: 180,
                isPaused: false
            )

            controller.end(immediate: true)
            #expect(Activity<AirPosture.AirPostureActivityAttributes>.activities.isEmpty, "Activity should be ended after end(immediate:)")
        }
    }

    @Test("Controller update tolerates boundary values without an activity")
    func testControllerBoundaryUpdates() async throws {
        await MainActor.run {
            let controller = AirPosture.LiveActivityController.shared

            controller.update(
                sessionScorePercent: -10,
                status: AirPosture.PostureStatus.good,
                calibratedTilt: 0,
                lean: 0,
                elapsedSeconds: -1,
                isPaused: false
            )

            controller.update(
                sessionScorePercent: 150,
                status: AirPosture.PostureStatus.poor,
                calibratedTilt: -40,
                lean: 18,
                elapsedSeconds: 999,
                isPaused: true
            )

            #expect(Activity<AirPosture.AirPostureActivityAttributes>.activities.isEmpty, "Boundary updates without a running activity should not crash")
        }
    }

    @Test("App module content state clamps values and derives poor percentage")
    func testAppModuleContentState() {
        let state = AirPosture.AirPostureActivityAttributes.ContentState(
            postureStatus: AirPosture.PostureStatus.good,
            sessionScorePercent: 120,
            lastUpdate: Date(),
            tiltDegrees: -4,
            leanDegrees: 1,
            elapsedSeconds: -8,
            isSessionPaused: false
        )

        #expect(state.sessionScorePercent == 100)
        #expect(state.elapsedSeconds == 0)
        #expect(state.poorPosturePercent == 0)
    }
}
