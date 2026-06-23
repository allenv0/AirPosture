import SwiftUI

struct PremiumButton: View {
    let title: String
    let icon: String
    let colors: [Color]
    var showRainbowAccent: Bool = false
    let isAnimating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.white,
                        Color.white.opacity(0.95),
                        Color.white.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)

                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.6),
                                    colors.first?.opacity(0.6) ?? Color.white.opacity(0.6),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .padding(1)

                    Capsule()
                        .stroke(
                            Color.black.opacity(0.25),
                            lineWidth: 1.5
                        )
                    
                    if showRainbowAccent {
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.4),
                                        Color.orange.opacity(0.4),
                                        Color.yellow.opacity(0.4),
                                        Color.green.opacity(0.4),
                                        Color.blue.opacity(0.4),
                                        Color.purple.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .padding(1.5)
                    }
                }
            )
            .shadow(color: colors.first?.opacity(0.15) ?? Color.clear, radius: 4, x: 0, y: 2)
            .shadow(color: colors.first?.opacity(0.1) ?? Color.clear, radius: 1, x: 0, y: 0.5)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: colors.map { $0.opacity(0.9) },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(y: 0.5)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 1.0 : 0.8)
            )
            .scaleEffect(isAnimating ? 1.03 : 1.0)
            .shadow(
                color: isAnimating ? .white.opacity(0.25) : .clear,
                radius: isAnimating ? 3 : 0,
                x: isAnimating ? 0 : 0.5,
                y: isAnimating ? 0 : 1
            )
            .shadow(
                color: (colors.first ?? .clear).opacity(isAnimating ? 0.15 : 0),
                radius: isAnimating ? 5 : 0,
                x: 0,
                y: 0
            )
            .animation(
                .spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0.3),
                value: isAnimating
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Activates \(title.lowercased()).")
    }
}
