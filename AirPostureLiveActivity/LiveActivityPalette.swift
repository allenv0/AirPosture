import SwiftUI

struct LiveActivityPalette {
    let statusTone: AirPostureActivityTone
    let scoreTone: AirPostureActivityTone
    let isMuted: Bool
    let statusAccent: Color
    let scoreAccent: Color
    let activeAccent: Color
    let textPrimary: Color
    let textSecondary: Color
    let border: Color
    let surfaceFill: Color
    let medallionFill: Color
    let chipFill: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let halo: Color

    init(
        statusTone: AirPostureActivityTone,
        scoreTone: AirPostureActivityTone,
        isMuted: Bool
    ) {
        let resolvedStatusTone: AirPostureActivityTone = isMuted ? .neutral : statusTone
        let resolvedScoreTone: AirPostureActivityTone = isMuted ? .neutral : scoreTone
        let statusAccent = Self.accent(for: resolvedStatusTone)
        let scoreAccent = Self.accent(for: resolvedScoreTone)
        let activeAccent = resolvedStatusTone == .neutral ? scoreAccent : statusAccent

        self.statusTone = resolvedStatusTone
        self.scoreTone = resolvedScoreTone
        self.isMuted = isMuted
        self.statusAccent = statusAccent
        self.scoreAccent = scoreAccent
        self.activeAccent = activeAccent
        self.textPrimary = .white
        self.textSecondary = Color.white.opacity(0.70)
        self.border = Color.white.opacity(0.12)
        self.surfaceFill = Color.white.opacity(0.06)
        self.medallionFill = Color.white.opacity(0.08)
        self.chipFill = Color.white.opacity(0.06)
        self.backgroundTop = .liveCoal
        self.backgroundBottom = .liveInkstone
        self.halo = activeAccent.opacity(isMuted ? 0.06 : 0.12)
    }

    func accent(for tone: AirPostureActivityTone) -> Color {
        Self.accent(for: tone)
    }

    private static func accent(for tone: AirPostureActivityTone) -> Color {
        switch tone {
        case .calm:
            return .liveCalm
        case .caution:
            return .liveCaution
        case .alert:
            return .liveAlert
        case .neutral:
            return .liveNeutral
        }
    }
}

extension LiveActivitySnapshot {
    var palette: LiveActivityPalette {
        LiveActivityPalette(
            statusTone: presentation.statusTone,
            scoreTone: presentation.scoreTone,
            isMuted: presentation.isMuted
        )
    }
}

extension Color {
    // Background colors matching main app
    static let liveCoal = Color(red: 0.09, green: 0.11, blue: 0.14)
    static let liveInkstone = Color(red: 0.05, green: 0.06, blue: 0.08)
    
    // Vibrant accent colors matching main app design system
    static let liveCalm = Color(red: 0.0, green: 0.8, blue: 0.4)      // Bright green for good posture
    static let liveCaution = Color(red: 1.0, green: 0.76, blue: 0.03) // Golden yellow for caution
    static let liveAlert = Color(red: 1.0, green: 0.31, blue: 0.0)   // Orange-red for alert
    static let liveNeutral = Color(red: 0.58, green: 0.63, blue: 0.72) // Slate blue for neutral/paused
    
    // Primary blue for general UI (matching Start button)
    static let livePrimary = Color(red: 0.0, green: 0.57, blue: 0.95)
}
