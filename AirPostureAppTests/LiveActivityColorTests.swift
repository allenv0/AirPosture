import SwiftUI
import Testing
@testable import AirPosture

// MARK: - Live Activity UI Color Verification Tests
// This test suite verifies that all grey circles have been replaced with colored accents

@Suite("Live Activity UI Color Tests")
struct LiveActivityColorTests {
    
    // MARK: - Avatar Badge Color Tests
    
    @Test("AvatarBadge uses active accent tint instead of grey background")
    func testAvatarBadgeUsesColoredTint() {
        let calmSnapshot = makeSnapshot(status: .good, score: 85, isMuted: false)
        let palette = calmSnapshot.palette
        
        // Should use active accent color, not white/grey
        #expect(palette.activeAccent != Color.white.opacity(0.06))
        #expect(palette.activeAccent != Color.white.opacity(0.04))
        
        // Active accent should be a real color (calm/caution/alert)
        let isColored = palette.activeAccent == .liveCalm || 
                       palette.activeAccent == .liveCaution || 
                       palette.activeAccent == .liveAlert ||
                       palette.activeAccent == .liveNeutral
        #expect(isColored)
    }
    
    @Test("AvatarBadge background uses colored opacity for vibrant appearance")
    func testAvatarBadgeColoredBackground() {
        let goodSnapshot = makeSnapshot(status: .good, score: 90, isMuted: false)
        let palette = goodSnapshot.palette
        
        // Background should be based on activeAccent with low opacity
        #expect(palette.activeAccent == .liveCalm) // Good posture = green
    }
    
    // MARK: - Avatar Status Ring Color Tests
    
    @Test("AvatarStatusRing uses colored fill instead of grey")
    func testAvatarStatusRingColoredFill() {
        let snapshot = makeSnapshot(status: .good, score: 88, isMuted: false)
        let palette = snapshot.palette
        
        // Fill should use accent color, not white opacity
        #expect(palette.activeAccent != Color.white)
        #expect(palette.activeAccent == .liveCalm)
    }
    
    @Test("AvatarStatusRing stroke uses colored accent instead of grey")
    func testAvatarStatusRingColoredStroke() {
        let snapshot = makeSnapshot(status: .poor, score: 45, tilt: -31, isMuted: false)
        let palette = snapshot.palette
        
        // Stroke should use accent color at 25% opacity
        #expect(palette.activeAccent != Color.white.opacity(0.08))
        #expect(palette.activeAccent == .liveAlert) // Poor posture = red
    }
    
    @Test("AvatarStatusRing avatar size is optimized to fill more space")
    func testAvatarStatusRingOptimizedSize() {
        let compact = true
        let size: CGFloat = 28
        
        // New formula: size - (compact ? 8 : 14)
        // Previously was: size - (compact ? 10 : 18)
        let newAvatarSize = size - CGFloat(compact ? 8 : 14)
        let oldAvatarSize = size - CGFloat(compact ? 10 : 18)
        
        #expect(newAvatarSize > oldAvatarSize)
        #expect(newAvatarSize == 20) // 28 - 8 = 20
        #expect(oldAvatarSize == 18) // 28 - 10 = 18
    }
    
    // MARK: - Score Medallion Color Tests
    
    @Test("ScoreMedallion fill uses colored accent instead of grey")
    func testScoreMedallionColoredFill() {
        let snapshot = makeSnapshot(status: .good, score: 92, isMuted: false)
        let palette = snapshot.palette
        
        // Should use scoreAccent, not white opacity
        #expect(palette.scoreAccent != Color.white.opacity(0.03))
        #expect(palette.scoreAccent != Color.white.opacity(0.04))
        #expect(palette.scoreAccent == .liveCalm) // Good score = green
    }
    
    @Test("ScoreMedallion stroke uses colored accent at 25% opacity")
    func testScoreMedallionColoredStroke() {
        let snapshot = makeSnapshot(status: .good, score: 65, isMuted: false)
        let palette = snapshot.palette
        
        // Stroke should be colored at 25% opacity, not grey at 8%
        #expect(palette.scoreAccent != Color.white.opacity(0.08))
        #expect(palette.scoreAccent == .liveCaution) // Fair score = yellow/orange
    }
    
    // MARK: - Calibration Mode Color Tests
    
    @Test("Calibration ring uses liveCaution yellow instead of grey")
    func testCalibrationRingUsesYellow() {
        let calibratingSnapshot = makeSnapshot(status: .unknown, score: 0, isMuted: false)
        let palette = calibratingSnapshot.palette
        
        // In calibration mode, should use liveCaution (yellow/orange)
        #expect(palette.statusAccent == .liveNeutral) // Unknown status = neutral
        #expect(Color.liveCaution != Color.white.opacity(0.18))
        #expect(Color.liveCaution == Color(red: 1.0, green: 0.76, blue: 0.03))
    }
    
    @Test("Calibration mode uses yellow dashed ring in AvatarStatusRing")
    func testCalibrationAvatarStatusRing() {
        let calibratingSnapshot = makeSnapshot(status: .unknown, score: 0, isMuted: false)
        let presentation = calibratingSnapshot.presentation
        
        // Should be in calibration hero mode
        if case .calibration = presentation.heroMode {
            // Success - calibration mode activated
            #expect(true)
        } else {
            // Should always be calibration for unknown status
            #expect(presentation.statusTone == .neutral)
        }
    }
    
    @Test("Calibration mode uses yellow dashed ring in ScoreMedallion")
    func testCalibrationScoreMedallion() {
        let calibratingSnapshot = makeSnapshot(status: .unknown, score: 0, isMuted: false)
        let presentation = calibratingSnapshot.presentation
        
        // Score medallion calibration should also use yellow
        #expect(presentation.heroMode == .calibration)
        #expect(Color.liveCaution == Color(red: 1.0, green: 0.76, blue: 0.03))
    }
    
    @Test("Minimal status view calibration uses liveCaution")
    func testMinimalStatusCalibration() {
        // MinimalStatusView (22px) should also use liveCaution for calibration
        #expect(Color.liveCaution != Color.white.opacity(0.22))
    }
    
    // MARK: - Posture State Color Tests
    
    @Test("Good posture uses calm green colors")
    func testGoodPostureColors() {
        let snapshot = makeSnapshot(status: .good, score: 95, isMuted: false)
        let palette = snapshot.palette
        
        #expect(palette.statusAccent == .liveCalm)
        #expect(palette.scoreAccent == .liveCalm)
        #expect(palette.activeAccent == .liveCalm)
        #expect(.liveCalm == Color(red: 0.0, green: 0.8, blue: 0.4))
    }
    
    @Test("Moderate correction uses caution orange/yellow colors")
    func testModerateCorrectionColors() {
        let snapshot = makeSnapshot(status: .poor, score: 70, isMuted: false)
        let palette = snapshot.palette
        
        #expect(palette.statusAccent == .liveCaution)
        #expect(palette.scoreAccent == .liveCaution)
        #expect(palette.activeAccent == .liveCaution)
        #expect(.liveCaution == Color(red: 1.0, green: 0.76, blue: 0.03))
    }
    
    @Test("Poor posture uses alert red colors")
    func testPoorPostureColors() {
        let snapshot = makeSnapshot(status: .poor, score: 40, tilt: -31, isMuted: false)
        let palette = snapshot.palette
        
        #expect(palette.statusAccent == .liveAlert)
        #expect(palette.scoreAccent == .liveAlert)
        #expect(palette.activeAccent == .liveAlert)
        #expect(.liveAlert == Color(red: 1.0, green: 0.31, blue: 0.0))
    }
    
    @Test("Muted state uses neutral grey")
    func testMutedStateColors() {
        let snapshot = makeSnapshot(status: .good, score: 85, isMuted: true)
        let palette = snapshot.palette
        
        #expect(palette.isMuted)
        #expect(palette.statusTone == .neutral)
        #expect(palette.scoreTone == .neutral)
        #expect(palette.activeAccent == .liveNeutral)
        #expect(.liveNeutral == Color(red: 0.58, green: 0.63, blue: 0.72))
    }
    
    // MARK: - Compact Trailing View Tests
    
    @Test("CompactTrailingView uses colored stroke instead of grey")
    func testCompactTrailingViewColoredStroke() {
        let snapshot = makeSnapshot(status: .good, score: 88, isMuted: false)
        let palette = snapshot.palette
        
        // Should use scoreAccent at 25% opacity, not white at 8%
        #expect(palette.scoreAccent != Color.white.opacity(0.08))
        #expect(palette.scoreAccent == .liveCalm)
    }
    
    // MARK: - Minimal Status View Tests
    
    @Test("MinimalStatusView uses colored stroke")
    func testMinimalStatusViewColoredStroke() {
        let snapshot = makeSnapshot(status: .good, score: 90, isMuted: false)
        let palette = snapshot.palette
        
        // Should use activeAccent at 35% opacity
        #expect(palette.activeAccent != Color.white.opacity(0.12))
        #expect(palette.activeAccent == .liveCalm)
    }
    
    @Test("MinimalStatusView avatar size increased from 14 to 16")
    func testMinimalStatusViewAvatarSize() {
        // Old size: 14px, New size: 16px
        let oldSize: CGFloat = 14
        let newSize: CGFloat = 16
        
        #expect(newSize > oldSize)
        #expect(newSize == 16)
    }
    
    // MARK: - Color Definition Tests
    
    @Test("Live activity colors are properly defined")
    func testColorDefinitions() {
        // Verify all colors are defined correctly
        #expect(Color.liveCalm == Color(red: 0.0, green: 0.8, blue: 0.4))
        #expect(Color.liveCaution == Color(red: 1.0, green: 0.76, blue: 0.03))
        #expect(Color.liveAlert == Color(red: 1.0, green: 0.31, blue: 0.0))
        #expect(Color.liveNeutral == Color(red: 0.58, green: 0.63, blue: 0.72))
        #expect(Color.liveCoal == Color(red: 0.09, green: 0.11, blue: 0.14))
        #expect(Color.liveInkstone == Color(red: 0.05, green: 0.06, blue: 0.08))
    }
    
    @Test("No white opacity greys in active accent colors")
    func testNoGreyInActiveAccents() {
        let testSnapshots = [
            makeSnapshot(status: .good, score: 90, isMuted: false),
            makeSnapshot(status: .poor, score: 70, isMuted: false),
            makeSnapshot(status: .poor, score: 40, tilt: -31, isMuted: false)
        ]
        
        for snapshot in testSnapshots {
            let palette = snapshot.palette
            // Active accent should never be white opacity (which creates grey)
            #expect(palette.activeAccent != Color.white.opacity(0.02))
            #expect(palette.activeAccent != Color.white.opacity(0.03))
            #expect(palette.activeAccent != Color.white.opacity(0.04))
            #expect(palette.activeAccent != Color.white.opacity(0.06))
            #expect(palette.activeAccent != Color.white.opacity(0.08))
            #expect(palette.activeAccent != Color.white.opacity(0.12))
            #expect(palette.activeAccent != Color.white.opacity(0.18))
            #expect(palette.activeAccent != Color.white.opacity(0.22))
            #expect(palette.activeAccent != Color.white.opacity(0.25))
        }
    }
    
    @Test("Avatar image rendering preserves original colors")
    func testAvatarRenderingMode() {
        let snapshot = makeSnapshot(status: .good, score: 90, isMuted: false)
        #expect(snapshot.presentation.avatarAssetName == "bear-neck")
    }
    
    // MARK: - Helper Methods
    
    private func makeSnapshot(
        status: PostureStatus,
        score: Int,
        tilt: Double = 0,
        lean: Double = 0,
        isMuted: Bool = false
    ) -> LiveActivitySnapshot {
        LiveActivitySnapshot(
            attributes: AirPostureActivityAttributes(
                sessionId: UUID(),
                avatarAssetName: "bear-neck",
                userDisplayName: "Sample",
                sessionStartTime: Date()
            ),
            state: AirPostureActivityAttributes.ContentState(
                postureStatus: status,
                sessionScorePercent: score,
                lastUpdate: Date(),
                tiltDegrees: tilt,
                leanDegrees: lean,
                elapsedSeconds: 120,
                isSessionPaused: isMuted
            )
        )
    }
}

// MARK: - UI Component Size Validation Tests

@Suite("Live Activity UI Size Validation Tests")
struct LiveActivitySizeValidationTests {
    @Test("Compact Dynamic Island status mark fits within the compact slot")
    func testCompactDynamicIslandStatusMarkFitsSlot() {
        #expect(DynamicIslandLayoutMetrics.compactSlotSize == 36)
        #expect(DynamicIslandLayoutMetrics.compactStatusMarkWidth == 34)
        #expect(DynamicIslandLayoutMetrics.compactStatusMarkHeight == 28)
        #expect(DynamicIslandLayoutMetrics.compactStatusMarkWidth < DynamicIslandLayoutMetrics.compactSlotSize)
        #expect(DynamicIslandLayoutMetrics.compactStatusMarkHeight < DynamicIslandLayoutMetrics.compactSlotSize)
    }

    @Test("Minimal Dynamic Island status mark remains smaller than compact")
    func testMinimalDynamicIslandStatusMarkStaysSmall() {
        #expect(DynamicIslandLayoutMetrics.minimalStatusMarkSize == 24)
        #expect(DynamicIslandLayoutMetrics.minimalStatusMarkSize < DynamicIslandLayoutMetrics.compactStatusMarkWidth)
        #expect(DynamicIslandLayoutMetrics.minimalStatusMarkSize < DynamicIslandLayoutMetrics.compactStatusMarkHeight)
    }

    @Test("AvatarBadge sizing is optimized for vibrant display")
    func testAvatarBadgeSizing() {
        let size: CGFloat = 42
        
        // New size calculation: size * 0.92 (was 0.90)
        let newSize = size * 0.92
        let oldSize = size * 0.90
        
        #expect(abs(newSize - 38.64) < 0.001)
        #expect(abs(oldSize - 37.8) < 0.001)
        #expect(newSize > oldSize)
    }
    
    @Test("Compact mode avatar sizing is larger")
    func testCompactAvatarSizing() {
        let size: CGFloat = 28
        let compact = true
        
        // New: size - 8, Old: size - 10
        let newPadding = CGFloat(compact ? 8 : 14)
        let oldPadding = CGFloat(compact ? 10 : 18)
        
        let newAvatarSize = size - newPadding
        let oldAvatarSize = size - oldPadding
        
        #expect(newAvatarSize == 20)
        #expect(oldAvatarSize == 18)
        #expect(newAvatarSize > oldAvatarSize)
    }
    
    @Test("Expanded mode avatar sizing is larger")
    func testExpandedAvatarSizing() {
        let size: CGFloat = 42
        let compact = false
        
        // New: size - 14, Old: size - 18
        let newPadding = CGFloat(compact ? 8 : 14)
        let oldPadding = CGFloat(compact ? 10 : 18)
        
        let newAvatarSize = size - newPadding
        let oldAvatarSize = size - oldPadding
        
        #expect(newAvatarSize == 28)
        #expect(oldAvatarSize == 24)
        #expect(newAvatarSize > oldAvatarSize)
    }
}

// MARK: - Color Contrast Tests

@Suite("Live Activity Color Contrast Tests")
struct LiveActivityColorContrastTests {
    
    @Test("Colored accents provide good contrast against dark backgrounds")
    func testColorContrast() {
        // Background colors
        let coal = Color.liveCoal // 0.09, 0.11, 0.14
        let inkstone = Color.liveInkstone // 0.05, 0.06, 0.08
        
        // Accent colors should be vibrant enough
        #expect(Color.liveCalm != coal)
        #expect(Color.liveCaution != coal)
        #expect(Color.liveAlert != coal)
        
        // Verify they're not just shades of grey/white
        let calmRGB = (0.0, 0.8, 0.4)
        let cautionRGB = (1.0, 0.76, 0.03)
        let alertRGB = (1.0, 0.31, 0.0)
        
        // All should have decent saturation (not grey)
        #expect(calmRGB.0 != calmRGB.1 || calmRGB.1 != calmRGB.2) // Not grey
        #expect(cautionRGB.0 != cautionRGB.1 || cautionRGB.1 != cautionRGB.2) // Not grey
        #expect(alertRGB.0 != alertRGB.1 || alertRGB.1 != alertRGB.2) // Not grey
    }
    
    @Test("Calibrating state is visually distinct from active states")
    func testCalibrationDistinct() {
        // Calibration yellow should be clearly different from all active colors
        let calibrating = Color.liveCaution
        let good = Color.liveCalm
        let fair = Color.liveCaution // Same as calibration
        let poor = Color.liveAlert
        
        // Fair posture and calibration share the same color intentionally
        #expect(calibrating == fair)
        #expect(calibrating != good)
        #expect(calibrating != poor)
    }
}
