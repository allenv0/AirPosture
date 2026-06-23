import Foundation
import Testing

@Suite("Widget Preview Snapshot Tests")
struct WidgetSnapshotTests {
    @Test("Preview snapshots cover score and calibration hero states")
    func testPreviewHeroCoverage() {
        #expect(LiveActivitySnapshot.alignedPreview.presentation.heroMode == .score(88))
        #expect(LiveActivitySnapshot.correctingPreview.presentation.heroMode == .score(54))
        #expect(LiveActivitySnapshot.monitoringPreview.presentation.heroMode == .calibration)
        #expect(LiveActivitySnapshot.pausedPreview.presentation.heroMode == .score(82))
    }

    @Test("Preview snapshots cover tilt and lean dominant corrections")
    func testPreviewDominantAxisCoverage() {
        #expect(LiveActivitySnapshot.tiltingPreview.presentation.dominantAxis == .tilt)
        #expect(LiveActivitySnapshot.tiltingPreview.presentation.correctionCue.title == "Tilt")
        #expect(LiveActivitySnapshot.leaningPreview.presentation.dominantAxis == .lean)
        #expect(LiveActivitySnapshot.leaningPreview.presentation.correctionCue.title == "Lean")
    }

    @Test("Paused preview stays muted while keeping its score")
    func testPausedPreviewPresentation() {
        let snapshot = LiveActivitySnapshot.pausedPreview

        #expect(snapshot.presentation.isMuted)
        #expect(snapshot.palette.isMuted)
        #expect(snapshot.presentation.statusLabel == "Paused")
        #expect(snapshot.presentation.compactScoreText == "82")
    }

    @Test("Monitoring preview never exposes a misleading perfect score")
    func testMonitoringPreviewScoreSuppression() {
        let snapshot = LiveActivitySnapshot.monitoringPreview

        #expect(snapshot.presentation.heroMode == .calibration)
        #expect(snapshot.presentation.compactScoreText == "--")
        #expect(snapshot.presentation.correctionCue.value == "Hold still")
    }

    @Test("Missing avatar preview falls back to initials")
    func testMissingAvatarPreviewFallback() {
        let snapshot = LiveActivitySnapshot.missingAvatarPreview

        #expect(snapshot.presentation.avatarFallbackText == "K")
    }

    @Test("Elapsed formatting switches to hour clock when needed")
    func testFormattedElapsedWithHours() {
        let snapshot = LiveActivitySnapshot(
            attributes: AirPostureActivityAttributes(
                sessionId: UUID(),
                avatarAssetName: "bear-neck",
                userDisplayName: "Sample",
                sessionStartTime: Date()
            ),
            state: AirPostureActivityAttributes.ContentState(
                postureStatus: .good,
                sessionScorePercent: 90,
                lastUpdate: Date(),
                tiltDegrees: -5,
                leanDegrees: 0,
                elapsedSeconds: 3_661,
                isSessionPaused: true
            )
        )

        #expect(snapshot.formattedElapsed == "1:01:01")
    }
}
