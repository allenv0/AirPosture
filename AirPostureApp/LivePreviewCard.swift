#if os(iOS)
import UIKit
#endif
import SwiftUI

struct LivePreviewCard: View {
    var motionManager: HeadphoneMotionManager
    let colorScheme: ColorScheme
    let onEnableTracking: () -> Void

    @State private var isPulsing: Bool = false

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }

    var body: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.lg) {
            headerSection

            Divider()
                .background(SettingsColors.divider(for: colorScheme))

            enableButton

            featureList
        }
        .padding(SettingsDesignTokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.large)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live Preview - Tap to enable live posture tracking")
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            Image("air-launch")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)

            Text("Live Preview")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(primaryTextColor)

            Text("Enable to see real-time head position")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
    }

    private var enableButton: some View {
        Button(action: enableTracking) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Enable Live Tracking")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
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
            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.2, blue: 0.6),
                                    Color(red: 0.6, green: 0.3, blue: 1.0),
                                    Color(red: 0.3, green: 0.5, blue: 1.0),
                                    Color(red: 0.2, green: 0.8, blue: 0.9),
                                    Color(red: 0.3, green: 0.9, blue: 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)

                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.red.opacity(0.6),
                                    Color.orange.opacity(0.6),
                                    Color.yellow.opacity(0.6),
                                    Color.green.opacity(0.6),
                                    Color.blue.opacity(0.6),
                                    Color.indigo.opacity(0.6),
                                    Color.purple.opacity(0.6),
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
                }
            )
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.9),
                                Color.orange.opacity(0.9),
                                Color.yellow.opacity(0.9),
                                Color.green.opacity(0.9),
                                Color.blue.opacity(0.9),
                                Color.indigo.opacity(0.9),
                                Color.purple.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blur(radius: 12)
                    .offset(y: 6)
                    .scaleEffect(1.0)
                    .opacity(0.8)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var featureList: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            featureRow(icon: "checkmark.circle.fill", text: "Real-time pitch, roll, and yaw")
            featureRow(icon: "checkmark.circle.fill", text: "Live posture status indicator")
            featureRow(icon: "checkmark.circle.fill", text: "Head visualization")

            if motionManager.isDeviceConnected {
                featureRow(icon: "checkmark.circle.fill", text: "AirPods connected")
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: SettingsDesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

            Spacer()
        }
    }

    private func enableTracking() {
        #if os(iOS)
        HapticManager.shared.impact(style: .medium)
        #endif
        onEnableTracking()
    }
}
