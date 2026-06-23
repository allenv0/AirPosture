import SwiftUI
import WidgetKit

#if canImport(UIKit)
import UIKit
#endif

struct SyncedElapsedTimeText: View {
    let snapshot: LiveActivitySnapshot
    let font: Font
    let foregroundColor: Color

    var body: some View {
        Group {
            if snapshot.state.isSessionPaused {
                Text(snapshot.formattedElapsed)
            } else {
                Text(snapshot.elapsedAnchorDate, style: .timer)
            }
        }
        .font(font)
        .monospacedDigit()
        .foregroundStyle(
            LinearGradient(
                colors: [
                    foregroundColor,
                    foregroundColor.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct AvatarBadge: View {
    let snapshot: LiveActivitySnapshot
    let size: CGFloat

    var body: some View {
        let palette = snapshot.palette
        let avatarAssetName = snapshot.attributes.avatarAssetName

        ZStack {
            // Glass morphism background
            Circle()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
            
            // Inner glow
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            AvatarImage(
                assetName: avatarAssetName,
                fallbackText: snapshot.presentation.avatarFallbackText,
                size: size * 0.88,
                scaledToFit: false
            )
        }
        .frame(width: size, height: size)
        .shadow(color: palette.activeAccent.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct StatusPill: View {
    let snapshot: LiveActivitySnapshot
    let compact: Bool

    var body: some View {
        let palette = snapshot.palette

        HStack(spacing: compact ? 5 : 6) {
            Image(systemName: snapshot.presentation.symbolName)
                .font(.system(size: DS(compact ? 10 : 11), weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            palette.activeAccent,
                            palette.activeAccent.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(snapshot.presentation.statusLabel)
                .font(
                    .system(
                        size: DS(compact ? 10 : 11),
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            palette.activeAccent,
                            palette.activeAccent.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .foregroundColor(palette.activeAccent)
        .padding(.horizontal, compact ? 9 : 11)
        .padding(.vertical, compact ? 6 : 7)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            palette.border
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: palette.activeAccent.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

struct TimerRail: View {
    let snapshot: LiveActivitySnapshot
    let compact: Bool

    var body: some View {
        let palette = snapshot.palette

        HStack(alignment: .center, spacing: compact ? 8 : 10) {
            // Animated capsule indicator
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.scoreAccent,
                            palette.scoreAccent.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: compact ? 28 : 36)
                .shadow(color: palette.scoreAccent.opacity(0.4), radius: 4, x: 0, y: 0)

            VStack(alignment: .trailing, spacing: compact ? 2 : 3) {
                Text("Elapsed")
                    .font(.system(size: DS(compact ? 10 : 11), weight: .semibold, design: .rounded))
                    .foregroundColor(palette.textSecondary)

                SyncedElapsedTimeText(
                    snapshot: snapshot,
                    font: .system(size: DS(compact ? 17 : 20), weight: .bold, design: .rounded),
                    foregroundColor: palette.textPrimary
                )
            }
        }
    }
}

struct ScoreMedallion: View {
    let snapshot: LiveActivitySnapshot
    let size: CGFloat
    let compact: Bool

    var body: some View {
        let palette = snapshot.palette
        let lineWidth: CGFloat = compact ? 5 : 7

        ZStack {
            // Glass morphism base
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.scoreAccent.opacity(0.15),
                            palette.scoreAccent.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .overlay(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.4)
                )

            // Background ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )

            // Gradient border highlight
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(compact ? 2 : 3)

            heroContent(lineWidth: lineWidth, palette: palette)
        }
        .frame(width: size, height: size)
        .shadow(color: palette.scoreAccent.opacity(0.25), radius: compact ? 8 : 12, x: 0, y: 4)
    }

    @ViewBuilder
    private func heroContent(lineWidth: CGFloat, palette: LiveActivityPalette) -> some View {
        switch snapshot.presentation.heroMode {
        case .score(let score):
            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(
                    LinearGradient(
                        colors: [
                            palette.scoreAccent,
                            palette.scoreAccent.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(compact ? 3 : 4)
                .shadow(color: palette.scoreAccent.opacity(0.5), radius: 6, x: 0, y: 0)

            VStack(spacing: compact ? 1 : 2) {
                Text("\(score)")
                    .font(
                        .system(
                            size: DS(compact ? 22 : 38),
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                if !compact {
                    Text("score")
                        .font(.system(size: DS(11), weight: .semibold, design: .rounded))
                        .foregroundColor(palette.textSecondary)
                        .textCase(.uppercase)
                }
            }

        case .calibration:
            // Animated calibration ring
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    Color.liveCaution,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [6, 8])
                )
                .rotationEffect(.degrees(-90))
                .padding(compact ? 3 : 4)

            VStack(spacing: compact ? 2 : 4) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: DS(compact ? 16 : 24), weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                palette.activeAccent,
                                palette.activeAccent.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("CAL")
                    .font(.system(size: DS(compact ? 10 : 11), weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}

struct AvatarStatusRing: View {
    let snapshot: LiveActivitySnapshot
    let size: CGFloat
    let compact: Bool

    var body: some View {
        let palette = snapshot.palette
        let lineWidth: CGFloat = compact ? 4 : 5.5

        ZStack {
            // Glass morphism base
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.activeAccent.opacity(0.12),
                            palette.activeAccent.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .overlay(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.4)
                )

            // Background ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )

            // Gradient border highlight
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(compact ? 2 : 3)

            ringStroke(palette: palette, lineWidth: lineWidth)

            AvatarBadge(snapshot: snapshot, size: size - (compact ? 10 : 16))
        }
        .frame(width: size, height: size)
        .shadow(color: palette.activeAccent.opacity(0.2), radius: compact ? 6 : 10, x: 0, y: 3)
    }

    @ViewBuilder
    private func ringStroke(
        palette: LiveActivityPalette,
        lineWidth: CGFloat
    ) -> some View {
        switch snapshot.presentation.heroMode {
        case .score:
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    LinearGradient(
                        colors: [
                            palette.activeAccent,
                            palette.activeAccent.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(compact ? 3 : 4)
                .shadow(color: palette.activeAccent.opacity(0.4), radius: 4, x: 0, y: 0)

        case .calibration:
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    Color.liveCaution,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [5, 6])
                )
                .rotationEffect(.degrees(-90))
                .padding(compact ? 3 : 4)
        }
    }
}

struct CoachTextBlock: View {
    let snapshot: LiveActivitySnapshot
    let compact: Bool

    var body: some View {
        let palette = snapshot.palette

        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            Text(compact ? snapshot.presentation.compactHeadline : snapshot.presentation.headline)
                .font(
                    .system(
                        size: DS(compact ? 16 : 24),
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(compact ? snapshot.presentation.compactDetail : snapshot.presentation.detail)
                .font(
                    .system(
                        size: DS(compact ? 12 : 15),
                        weight: .medium,
                        design: .rounded
                    )
                )
                .foregroundColor(palette.textSecondary)
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(0.88)
        }
    }
}

struct LiveActivityCorrectionChip: View {
    let cue: LiveActivityCorrectionCue
    let palette: LiveActivityPalette
    let compact: Bool

    var body: some View {
        let accent = palette.accent(for: cue.tone)

        Group {
            if compact {
                HStack(spacing: 6) {
                    Image(systemName: cue.systemName)
                        .font(.system(size: DS(10), weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    accent,
                                    accent.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("\(cue.title) \(cue.value)")
                        .font(.system(size: DS(11), weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.5)
                            .overlay(
                                Circle()
                                    .stroke(accent.opacity(0.3), lineWidth: 1)
                            )

                        Image(systemName: cue.systemName)
                            .font(.system(size: DS(13), weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        accent,
                                        accent.opacity(0.8)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(cue.title)
                            .font(.system(size: DS(11), weight: .semibold, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                            .textCase(.uppercase)

                        Text(cue.value)
                            .font(.system(size: DS(20), weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.95)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .monospacedDigit()

                        Text(cue.detail)
                            .font(.system(size: DS(12), weight: .medium, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            palette.border
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: accent.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

struct CompactPostureRing: View {
    let snapshot: LiveActivitySnapshot
    let size: CGFloat

    private var strokeWidth: CGFloat { size >= 40 ? 3 : 2 }
    private var avatarSize: CGFloat { size * 0.62 }
    private var progress: CGFloat {
        switch snapshot.presentation.heroMode {
        case .score(let score): return CGFloat(score) / 100.0
        case .calibration: return 0.25
        }
    }

    var body: some View {
        let palette = snapshot.palette

        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: strokeWidth)

            switch snapshot.presentation.heroMode {
            case .score:
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [palette.activeAccent, palette.activeAccent.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: palette.activeAccent.opacity(0.4), radius: size >= 40 ? 3 : 2, x: 0, y: 0)

            case .calibration:
                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(
                        Color.liveCaution,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, dash: [4, 5])
                    )
                    .rotationEffect(.degrees(-90))
            }

            AvatarImage(
                assetName: snapshot.attributes.avatarAssetName,
                fallbackText: snapshot.presentation.avatarFallbackText,
                size: avatarSize,
                scaledToFit: true
            )
        }
        .frame(width: size, height: size)
    }
}

struct AvatarCircleExpanded: View {
    let snapshot: LiveActivitySnapshot
    let size: CGFloat

    private let lineWidth: CGFloat = 5.5

    var body: some View {
        let palette = snapshot.palette
        let isPoor = snapshot.presentation.statusTone == .alert || snapshot.presentation.statusTone == .caution

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.activeAccent.opacity(0.12),
                            palette.activeAccent.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .overlay(
                    Circle().fill(.ultraThinMaterial).opacity(0.4)
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(3)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [palette.activeAccent, palette.activeAccent.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .shadow(color: palette.activeAccent.opacity(isPoor ? 0.5 : 0.3), radius: isPoor ? 8 : 4, x: 0, y: 0)

            AvatarImage(
                assetName: snapshot.attributes.avatarAssetName,
                fallbackText: snapshot.presentation.avatarFallbackText,
                size: size * 0.78,
                scaledToFit: true
            )
        }
        .frame(width: size, height: size)
        .shadow(color: palette.activeAccent.opacity(0.2), radius: 8, x: 0, y: 3)
    }
}

struct ScoreCircleExpanded: View {
    let snapshot: LiveActivitySnapshot
    let size: CGFloat

    private let lineWidth: CGFloat = 5.5

    var body: some View {
        let palette = snapshot.palette

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.scoreAccent.opacity(0.15),
                            palette.scoreAccent.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .overlay(
                    Circle().fill(.ultraThinMaterial).opacity(0.4)
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(3)

            progressArc(palette: palette)

            VStack(spacing: 1) {
                Text(snapshot.presentation.compactScoreText)
                    .font(.system(size: DS(18), weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("score")
                    .font(.system(size: DS(8), weight: .medium, design: .rounded))
                    .foregroundColor(palette.textSecondary)
                    .textCase(.uppercase)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: palette.scoreAccent.opacity(0.25), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func progressArc(palette: LiveActivityPalette) -> some View {
        switch snapshot.presentation.heroMode {
        case .score(let score):
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(
                    LinearGradient(
                        colors: [palette.scoreAccent, palette.scoreAccent.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(4)
                .shadow(color: palette.scoreAccent.opacity(0.5), radius: 6, x: 0, y: 0)

        case .calibration:
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    Color.liveCaution,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [6, 8])
                )
                .rotationEffect(.degrees(-90))
                .padding(4)
        }
    }
}

struct AvatarImage: View {
    let assetName: String
    let fallbackText: String
    let size: CGFloat
    let scaledToFit: Bool

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let uiImage = UIImage(named: assetName)?.withRenderingMode(.alwaysOriginal) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .modifier(AvatarImageModifier(
                        size: size,
                        scaledToFit: scaledToFit
                    ))
            } else {
                fallback
            }
            #else
            Image(assetName)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .modifier(AvatarImageModifier(
                    size: size,
                    scaledToFit: scaledToFit
                ))
            #endif
        }
    }

    private var fallback: some View {
        Text(fallbackText)
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
    }
}

struct AvatarImageModifier: ViewModifier {
    let size: CGFloat
    let scaledToFit: Bool

    func body(content: Content) -> some View {
        content
            .if(scaledToFit) { view in
                view.scaledToFit()
            }
            .if(!scaledToFit) { view in
                view.scaledToFill()
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

func DS(_ size: CGFloat) -> CGFloat {
    #if canImport(UIKit)
    UIFontMetrics.default.scaledValue(for: size)
    #else
    size
    #endif
}
