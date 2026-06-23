import ActivityKit
import Foundation
import WidgetKit

enum AirPostureActivityTone: Equatable {
    case calm
    case caution
    case alert
    case neutral
}

enum LiveActivityDominantAxis: Equatable {
    case tilt
    case lean

    var title: String {
        switch self {
        case .tilt:
            return "Tilt"
        case .lean:
            return "Lean"
        }
    }

    var systemName: String {
        switch self {
        case .tilt:
            return "arrow.up.and.down.circle.fill"
        case .lean:
            return "arrow.left.and.right.circle.fill"
        }
    }
}

enum LiveActivityHeroMode: Equatable {
    case score(Int)
    case calibration
}

struct LiveActivityCorrectionCue: Equatable {
    let title: String
    let value: String
    let detail: String
    let systemName: String
    let tone: AirPostureActivityTone
}

struct AirPostureLiveActivityPresentation {
    let statusTone: AirPostureActivityTone
    let scoreTone: AirPostureActivityTone
    let headline: String
    let detail: String
    let compactHeadline: String
    let compactDetail: String
    let statusLabel: String
    let symbolName: String
    let scorePercent: Int
    let tiltDegrees: Int
    let leanDegrees: Int
    let heroMode: LiveActivityHeroMode
    let correctionCue: LiveActivityCorrectionCue
    let dominantAxis: LiveActivityDominantAxis
    let avatarAssetName: String
    let avatarFallbackText: String
    let userDisplayName: String?
    let isMuted: Bool

    init(
        attributes: AirPostureActivityAttributes,
        state: AirPostureActivityAttributes.ContentState
    ) {
        let scorePercent = max(0, min(100, state.sessionScorePercent))
        let tiltDegrees = Int(state.tiltDegrees.rounded())
        let leanDegrees = Int(state.leanDegrees.rounded())
        let dominantAxis: LiveActivityDominantAxis = abs(leanDegrees) > abs(tiltDegrees) ? .lean : .tilt
        let dominantMagnitude = dominantAxis == .tilt ? abs(tiltDegrees) : abs(leanDegrees)
        let isMuted = state.isSessionPaused
        let staleInterval: TimeInterval = isMuted ? 30 * 60 : 5 * 60
        let isStale = Date().timeIntervalSince(state.lastUpdate) > staleInterval

        self.scorePercent = scorePercent
        self.tiltDegrees = tiltDegrees
        self.leanDegrees = leanDegrees
        self.dominantAxis = dominantAxis
        self.avatarAssetName = attributes.avatarAssetName
        self.userDisplayName = attributes.userDisplayName
        self.avatarFallbackText = Self.avatarFallbackText(
            userDisplayName: attributes.userDisplayName,
            avatarAssetName: attributes.avatarAssetName
        )
        self.isMuted = isMuted

        if isStale {
            self.statusTone = .neutral
            self.scoreTone = Self.scoreTone(for: scorePercent)
            self.statusLabel = "Sync Stale"
            self.symbolName = "clock.badge.exclamationmark.fill"
            self.heroMode = .score(scorePercent)
            self.headline = "Last Known"
            self.detail = "Open AirPosture to refresh posture data."
            self.compactHeadline = "Last Known"
            self.compactDetail = "Open app."
            self.correctionCue = LiveActivityCorrectionCue(
                title: "Sync",
                value: "Stale",
                detail: "Showing the last posture update.",
                systemName: "clock.badge.exclamationmark.fill",
                tone: .neutral
            )
            return
        }

        if isMuted {
            self.statusTone = .neutral
            self.scoreTone = .neutral
            self.statusLabel = "Paused"
            self.symbolName = "pause.circle.fill"
            self.heroMode = .score(scorePercent)
            self.headline = "Paused"
            self.detail = "Resume in app to keep tracking."
            self.compactHeadline = "Paused"
            self.compactDetail = "Resume in app."
            self.correctionCue = LiveActivityCorrectionCue(
                title: "Session",
                value: "Resume in app",
                detail: "Tracking is currently muted.",
                systemName: "pause.fill",
                tone: .neutral
            )
            return
        }

        switch state.postureStatus {
        case .good:
            self.statusTone = .calm
            self.scoreTone = Self.scoreTone(for: scorePercent)
            self.statusLabel = "On Target"
            self.symbolName = "checkmark.circle.fill"
            self.heroMode = .score(scorePercent)

            if scorePercent >= 90 && dominantMagnitude <= 6 {
                self.headline = "Locked In"
                self.detail = "Posture is holding steady."
                self.compactHeadline = "Locked In"
                self.compactDetail = "Holding steady."
            } else if scorePercent >= 75 {
                self.headline = "Aligned"
                self.detail = "You're in the target zone."
                self.compactHeadline = "Aligned"
                self.compactDetail = "In range."
            } else {
                self.headline = "Back on Track"
                self.detail = "Keep this angle for a stronger streak."
                self.compactHeadline = "Recovered"
                self.compactDetail = "Keep it steady."
            }

            self.correctionCue = LiveActivityCorrectionCue(
                title: dominantAxis.title,
                value: dominantAxis == .tilt ? Self.signedDegreesText(tiltDegrees) : Self.signedDegreesText(leanDegrees),
                detail: "Holding steady.",
                systemName: dominantAxis.systemName,
                tone: .calm
            )

        case .poor:
            let severeTilt = dominantAxis == .tilt && dominantMagnitude >= 30
            let severeLean = dominantAxis == .lean && dominantMagnitude >= 15
            let alertTone = severeTilt || severeLean

            self.statusTone = alertTone ? .alert : .caution
            self.scoreTone = Self.scoreTone(for: scorePercent)
            self.statusLabel = "Needs Correction"
            self.symbolName = dominantAxis == .tilt ? "arrow.up.circle.fill" : "arrow.left.and.right.circle.fill"
            self.heroMode = .score(scorePercent)

            if dominantAxis == .tilt {
                self.headline = severeTilt ? "Lift Chin" : "Sit Taller"
                self.detail = "Bring your head back toward neutral."
                self.compactHeadline = severeTilt ? "Lift Chin" : "Sit Taller"
                self.compactDetail = "Back to neutral."
            } else {
                self.headline = "Recenter"
                self.detail = "Shift gently back toward the middle."
                self.compactHeadline = "Recenter"
                self.compactDetail = "Shift to center."
            }

            self.correctionCue = LiveActivityCorrectionCue(
                title: dominantAxis.title,
                value: dominantAxis == .tilt ? Self.signedDegreesText(tiltDegrees) : Self.signedDegreesText(leanDegrees),
                detail: dominantAxis == .tilt ? "Lift toward neutral." : "Ease back to center.",
                systemName: dominantAxis.systemName,
                tone: self.statusTone
            )

        case .unknown:
            self.statusTone = .neutral
            self.scoreTone = .neutral
            self.statusLabel = "Calibrating"
            self.symbolName = "dot.radiowaves.left.and.right"
            self.heroMode = .calibration
            self.headline = "Calibrating"
            self.detail = "Hold still while AirPosture settles in."
            self.compactHeadline = "Calibrating"
            self.compactDetail = "Hold still."
            self.correctionCue = LiveActivityCorrectionCue(
                title: "Calibration",
                value: "Hold still",
                detail: "Reading your baseline posture.",
                systemName: "dot.radiowaves.left.and.right",
                tone: .neutral
            )
        }
    }

    var scoreText: String {
        "\(scorePercent)%"
    }

    var compactScoreText: String {
        switch heroMode {
        case .score(let score):
            return "\(score)"
        case .calibration:
            return "--"
        }
    }

    var tiltText: String {
        Self.signedDegreesText(tiltDegrees)
    }

    var leanText: String {
        Self.signedDegreesText(leanDegrees)
    }

    private static func scoreTone(for scorePercent: Int) -> AirPostureActivityTone {
        switch scorePercent {
        case 85...:
            return .calm
        case 60...84:
            return .caution
        default:
            return .alert
        }
    }

    private static func avatarFallbackText(
        userDisplayName: String?,
        avatarAssetName: String
    ) -> String {
        if let initial = userDisplayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .first
        {
            return String(initial).uppercased()
        }

        if let initial = avatarAssetName
            .split(separator: "-")
            .first?
            .first
        {
            return String(initial).uppercased()
        }

        return "A"
    }

    private static func signedDegreesText(_ value: Int) -> String {
        if value > 0 {
            return "+\(value)°"
        }

        if value < 0 {
            return "\(value)°"
        }

        return "0°"
    }
}

struct LiveActivitySnapshot {
    let attributes: AirPostureActivityAttributes
    let state: AirPostureActivityAttributes.ContentState
    let presentation: AirPostureLiveActivityPresentation

    init(context: ActivityViewContext<AirPostureActivityAttributes>) {
        self.init(attributes: context.attributes, state: context.state)
    }

    init(
        attributes: AirPostureActivityAttributes,
        state: AirPostureActivityAttributes.ContentState
    ) {
        self.attributes = attributes
        self.state = state
        self.presentation = AirPostureLiveActivityPresentation(
            attributes: attributes,
            state: state
        )
    }
}

extension LiveActivitySnapshot {
    static let alignedPreview = LiveActivitySnapshot(
        attributes: AirPostureActivityAttributes(
            sessionId: UUID(),
            avatarAssetName: "bear-neck",
            userDisplayName: "Sample",
            sessionStartTime: Date().addingTimeInterval(-14 * 60)
        ),
        state: AirPostureActivityAttributes.ContentState(
            postureStatus: .good,
            sessionScorePercent: 88,
            lastUpdate: Date(),
            tiltDegrees: -6,
            leanDegrees: 2,
            elapsedSeconds: 14 * 60,
            isSessionPaused: false
        )
    )

    static let tiltingPreview = LiveActivitySnapshot(
        attributes: AirPostureActivityAttributes(
            sessionId: UUID(),
            avatarAssetName: "cat-neck",
            userDisplayName: "A",
            sessionStartTime: Date().addingTimeInterval(-7 * 60)
        ),
        state: AirPostureActivityAttributes.ContentState(
            postureStatus: .poor,
            sessionScorePercent: 54,
            lastUpdate: Date(),
            tiltDegrees: -31,
            leanDegrees: -8,
            elapsedSeconds: 7 * 60,
            isSessionPaused: false
        )
    )

    static let leaningPreview = LiveActivitySnapshot(
        attributes: AirPostureActivityAttributes(
            sessionId: UUID(),
            avatarAssetName: "dog-neck",
            userDisplayName: "Sam",
            sessionStartTime: Date().addingTimeInterval(-5 * 60)
        ),
        state: AirPostureActivityAttributes.ContentState(
            postureStatus: .poor,
            sessionScorePercent: 62,
            lastUpdate: Date(),
            tiltDegrees: -8,
            leanDegrees: 19,
            elapsedSeconds: 5 * 60,
            isSessionPaused: false
        )
    )

    static let correctingPreview = tiltingPreview

    static let pausedPreview = LiveActivitySnapshot(
        attributes: AirPostureActivityAttributes(
            sessionId: UUID(),
            avatarAssetName: "bear-neck",
            userDisplayName: "Sample",
            sessionStartTime: Date().addingTimeInterval(-18 * 60)
        ),
        state: AirPostureActivityAttributes.ContentState(
            postureStatus: .good,
            sessionScorePercent: 82,
            lastUpdate: Date(),
            tiltDegrees: -4,
            leanDegrees: 1,
            elapsedSeconds: 18 * 60,
            isSessionPaused: true
        )
    )

    static let monitoringPreview = LiveActivitySnapshot(
        attributes: AirPostureActivityAttributes(
            sessionId: UUID(),
            avatarAssetName: "dog-neck",
            userDisplayName: nil,
            sessionStartTime: Date().addingTimeInterval(-90)
        ),
        state: AirPostureActivityAttributes.ContentState(
            postureStatus: .unknown,
            sessionScorePercent: 100,
            lastUpdate: Date(),
            tiltDegrees: 0,
            leanDegrees: 0,
            elapsedSeconds: 90,
            isSessionPaused: false
        )
    )

    static let missingAvatarPreview = LiveActivitySnapshot(
        attributes: AirPostureActivityAttributes(
            sessionId: UUID(),
            avatarAssetName: "ghost-neck",
            userDisplayName: "Kai",
            sessionStartTime: Date().addingTimeInterval(-12 * 60)
        ),
        state: AirPostureActivityAttributes.ContentState(
            postureStatus: .good,
            sessionScorePercent: 91,
            lastUpdate: Date(),
            tiltDegrees: -3,
            leanDegrees: 1,
            elapsedSeconds: 12 * 60,
            isSessionPaused: false
        )
    )

    var elapsedAnchorDate: Date {
        state.lastUpdate.addingTimeInterval(-TimeInterval(max(0, state.elapsedSeconds)))
    }

    var formattedElapsed: String {
        let totalSeconds = max(0, state.elapsedSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}
