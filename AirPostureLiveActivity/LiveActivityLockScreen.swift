import SwiftUI

struct LiveActivityLockScreenView: View {
    let snapshot: LiveActivitySnapshot

    var body: some View {
        let palette = snapshot.palette

        ZStack {
            // Premium glass morphism backdrop
            LockScreenBackdrop(palette: palette)

            // Main content with improved layout
            HStack(alignment: .center, spacing: 24) {
                // Leading: Large score medallion with glass effect
                ScoreMedallion(snapshot: snapshot, size: 100, compact: false)
                    .frame(width: 100, height: 100)

                // Center: Status and coaching info
                VStack(alignment: .leading, spacing: 14) {
                    StatusPill(snapshot: snapshot, compact: false)

                    CoachTextBlock(snapshot: snapshot, compact: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
        }
        .activityBackgroundTint(.clear)
    }
}

struct LockScreenBackdrop: View {
    let palette: LiveActivityPalette

    var body: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    palette.backgroundTop,
                    palette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Glass morphism layer
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.6)

            // Gradient border highlight
            RoundedRectangle(cornerRadius: 26, style: .continuous)
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
                .padding(1)

            // Subtle outer border
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .padding(2)

            // Status halo glow
            RadialGradient(
                colors: [
                    palette.halo,
                    Color.clear
                ],
                center: .leading,
                startRadius: 20,
                endRadius: 160
            )
            .offset(x: -20)
        }
        .ignoresSafeArea()
    }
}
