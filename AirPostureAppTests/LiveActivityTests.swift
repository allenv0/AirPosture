import Foundation
import Testing

@Suite("Live Activity Presentation Tests")
struct LiveActivityTests {
    @Test("Good posture uses calm status and score hero")
    func testGoodPosturePresentation() {
        let presentation = makePresentation(
            status: .good,
            score: 88,
            tilt: -6,
            lean: 2
        )

        #expect(presentation.statusTone == .calm)
        #expect(presentation.statusLabel == "On Target")
        #expect(presentation.heroMode == .score(88))
        #expect(presentation.correctionCue.title == "Tilt")
    }

    @Test("Tilt dominant correction is selected when tilt exceeds lean")
    func testTiltDominantCorrection() {
        let presentation = makePresentation(
            status: .poor,
            score: 54,
            tilt: -31,
            lean: -8
        )

        #expect(presentation.dominantAxis == .tilt)
        #expect(presentation.correctionCue.title == "Tilt")
        #expect(presentation.correctionCue.value == "-31°")
        #expect(presentation.symbolName == "arrow.up.circle.fill")
    }

    @Test("Lean dominant correction is selected when lean exceeds tilt")
    func testLeanDominantCorrection() {
        let presentation = makePresentation(
            status: .poor,
            score: 62,
            tilt: -8,
            lean: 19
        )

        #expect(presentation.dominantAxis == .lean)
        #expect(presentation.correctionCue.title == "Lean")
        #expect(presentation.correctionCue.value == "+19°")
        #expect(presentation.symbolName == "arrow.left.and.right.circle.fill")
    }

    @Test("Unknown state suppresses score hero")
    func testUnknownStateUsesCalibrationHero() {
        let presentation = makePresentation(
            status: .unknown,
            score: 100,
            tilt: 0,
            lean: 0
        )

        #expect(presentation.statusTone == .neutral)
        #expect(presentation.heroMode == .calibration)
        #expect(presentation.compactScoreText == "--")
        #expect(presentation.correctionCue.title == "Calibration")
    }

    @Test("Paused state mutes palette styling")
    func testPausedStateMutedPalette() {
        let snapshot = makeSnapshot(
            status: .good,
            score: 82,
            tilt: -4,
            lean: 1,
            paused: true
        )

        #expect(snapshot.presentation.isMuted)
        #expect(snapshot.palette.isMuted)
        #expect(snapshot.palette.statusTone == .neutral)
        #expect(snapshot.presentation.heroMode == .score(82))
    }

    @Test("Session score is clamped by content state")
    func testSessionScoreClamp() {
        let high = AirPostureActivityAttributes.ContentState(
            postureStatus: .good,
            sessionScorePercent: 140,
            lastUpdate: Date(),
            tiltDegrees: 0,
            leanDegrees: 0,
            elapsedSeconds: 0,
            isSessionPaused: false
        )
        let low = AirPostureActivityAttributes.ContentState(
            postureStatus: .poor,
            sessionScorePercent: -12,
            lastUpdate: Date(),
            tiltDegrees: 0,
            leanDegrees: 0,
            elapsedSeconds: 0,
            isSessionPaused: false
        )

        #expect(high.sessionScorePercent == 100)
        #expect(low.sessionScorePercent == 0)
    }

    @Test("Avatar fallback prefers display name initial")
    func testAvatarFallbackUsesDisplayNameInitial() {
        let presentation = makePresentation(
            status: .good,
            score: 91,
            tilt: -3,
            lean: 1,
            avatarAssetName: "ghost-neck",
            userDisplayName: "Kai"
        )

        #expect(presentation.avatarFallbackText == "K")
    }

    private func makePresentation(
        status: PostureStatus,
        score: Int,
        tilt: Double,
        lean: Double,
        avatarAssetName: String = "bear-neck",
        userDisplayName: String? = "Allen",
        paused: Bool = false
    ) -> AirPostureLiveActivityPresentation {
        AirPostureLiveActivityPresentation(
            attributes: AirPostureActivityAttributes(
                sessionId: UUID(),
                avatarAssetName: avatarAssetName,
                userDisplayName: userDisplayName,
                sessionStartTime: Date()
            ),
            state: AirPostureActivityAttributes.ContentState(
                postureStatus: status,
                sessionScorePercent: score,
                lastUpdate: Date(),
                tiltDegrees: tilt,
                leanDegrees: lean,
                elapsedSeconds: 120,
                isSessionPaused: paused
            )
        )
    }

    private func makeSnapshot(
        status: PostureStatus,
        score: Int,
        tilt: Double,
        lean: Double,
        paused: Bool = false
    ) -> LiveActivitySnapshot {
        LiveActivitySnapshot(
            attributes: AirPostureActivityAttributes(
                sessionId: UUID(),
                avatarAssetName: "bear-neck",
                userDisplayName: "Allen",
                sessionStartTime: Date()
            ),
            state: AirPostureActivityAttributes.ContentState(
                postureStatus: status,
                sessionScorePercent: score,
                lastUpdate: Date(),
                tiltDegrees: tilt,
                leanDegrees: lean,
                elapsedSeconds: 120,
                isSessionPaused: paused
            )
        )
    }
}
