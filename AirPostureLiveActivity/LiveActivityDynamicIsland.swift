import SwiftUI

enum DynamicIslandLayoutMetrics {
    static let compactSlotSize: CGFloat = 36
    static let compactStatusMarkWidth: CGFloat = 34
    static let compactStatusMarkHeight: CGFloat = 28
    static let minimalStatusMarkSize: CGFloat = 24
}

struct ExpandedCenterView: View {
    let snapshot: LiveActivitySnapshot

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircleExpanded(snapshot: snapshot, size: 64)
            ScoreCircleExpanded(snapshot: snapshot, size: 64)
        }
    }
}

struct ExpandedBottomView: View {
    let snapshot: LiveActivitySnapshot

    var body: some View {
        VStack(spacing: 6) {
            StatusPill(snapshot: snapshot, compact: true)

            CoachTextBlock(snapshot: snapshot, compact: true)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
    }
}

struct CompactLeadingView: View {
    let snapshot: LiveActivitySnapshot

    var body: some View {
        CompactIslandStatusMark(snapshot: snapshot, compact: true)
            .frame(
                width: DynamicIslandLayoutMetrics.compactSlotSize,
                height: DynamicIslandLayoutMetrics.compactSlotSize
            )
    }
}

struct CompactTrailingView: View {
    let snapshot: LiveActivitySnapshot

    var body: some View {
        Text(snapshot.presentation.compactScoreText)
            .font(.system(size: DS(18), weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.white, Color.white.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

struct MinimalStatusView: View {
    let snapshot: LiveActivitySnapshot

    var body: some View {
        CompactIslandStatusMark(snapshot: snapshot, compact: false)
    }
}

struct CompactIslandStatusMark: View {
    let snapshot: LiveActivitySnapshot
    let compact: Bool

    var body: some View {
        let palette = snapshot.palette

        HStack(spacing: compact ? 4 : 0) {
            if compact {
                Capsule()
                    .fill(palette.activeAccent)
                    .frame(width: 3, height: 18)
                    .shadow(color: palette.activeAccent.opacity(0.45), radius: 2, x: 0, y: 0)
            }

            Image(systemName: snapshot.presentation.symbolName)
                .font(.system(size: DS(compact ? 17 : 18), weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.activeAccent)
                .frame(
                    width: compact ? 20 : DynamicIslandLayoutMetrics.minimalStatusMarkSize,
                    height: compact ? 20 : DynamicIslandLayoutMetrics.minimalStatusMarkSize
                )
        }
        .frame(
            width: compact ? DynamicIslandLayoutMetrics.compactStatusMarkWidth : DynamicIslandLayoutMetrics.minimalStatusMarkSize,
            height: compact ? DynamicIslandLayoutMetrics.compactStatusMarkHeight : DynamicIslandLayoutMetrics.minimalStatusMarkSize
        )
    }
}
