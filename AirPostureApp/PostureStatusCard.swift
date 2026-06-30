#if os(iOS)
import UIKit
#endif
import SwiftUI

struct PostureStatusCard: View {
    var motionManager: HeadphoneMotionManager
    let colorScheme: ColorScheme

    @State private var animatedPitch: Double = 0

    private var isGoodPosture: Bool {
        let adjustedPitch = motionManager.pitch - motionManager.normalAirPodsAngle
        return adjustedPitch >= motionManager.poorPostureThreshold
    }

    private var postureColor: Color {
        if !motionManager.isDeviceConnected {
            return .gray
        }
        if isGoodPosture {
            return PostureColors.good
        } else {
            let adjustedPitch = motionManager.pitch - motionManager.normalAirPodsAngle
            let severity = abs(adjustedPitch - motionManager.poorPostureThreshold)
            if severity > 10 {
                return PostureColors.alert
            } else if severity > 5 {
                return Color(red: 1.0, green: 0.5, blue: 0.0)
            } else {
                return Color(red: 1.0, green: 0.7, blue: 0.0)
            }
        }
    }

    private var postureLabel: String {
        if !motionManager.isDeviceConnected {
            return "Disconnected"
        }
        return isGoodPosture ? "Good" : "Poor"
    }

    private var postureIcon: String {
        if !motionManager.isDeviceConnected {
            return "airpods"
        }
        return isGoodPosture ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    var body: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.md) {
            headerSection

            if motionManager.isDeviceConnected {
                postureVisualization

                Divider()
                    .background(SettingsColors.divider(for: colorScheme))

                thresholdIndicator
            } else {
                disconnectedState
            }
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                .fill(SettingsColors.cardBackground(for: colorScheme))
                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Posture status: \(postureLabel)")
    }

    private var headerSection: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(postureColor.opacity(0.15))
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)

                Image(systemName: postureIcon)
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(postureColor)
            }

            VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                Text("Live Posture")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                Text(motionManager.isDeviceConnected ? "Real-time head position" : "Connect AirPods to track")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }

            Spacer()
        }
    }

    private var postureVisualization: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.lg) {
            HeadVisualization(
                pitch: animatedPitch,
                roll: motionManager.roll,
                yaw: motionManager.yaw,
                postureState: motionManager.postureState,
                screenWidth: 120,
                colorScheme: colorScheme,
                currentAvatar: .bear,
                onAvatarTap: {},
                size: 90,
                poorPostureThreshold: motionManager.poorPostureThreshold,
                normalAirPodsAngle: motionManager.normalAirPodsAngle,
                isUserRunningOrWalking: false
            )
            .onAppear {
                animatedPitch = motionManager.pitch
            }
            .onChange(of: motionManager.pitch) { _, newValue in
                animatedPitch = newValue
            }

            VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.sm) {
                HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                    Circle()
                        .fill(postureColor)
                        .frame(width: 8, height: 8)
                    Text(postureLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(postureColor)
                }

                Divider()
                    .background(SettingsColors.divider(for: colorScheme))

                postureMetric(icon: "arrow.up", label: "Pitch", value: "\(String(format: "%.1f", motionManager.pitch))°")
                postureMetric(icon: "arrow.left.and.right", label: "Roll", value: "\(String(format: "%.1f", motionManager.roll))°")
                postureMetric(icon: "arrow.clockwise", label: "Yaw", value: "\(String(format: "%.1f", motionManager.yaw))°")
            }

            Spacer()
        }
    }

    private func postureMetric(icon: String, label: String, value: String) -> some View {
        HStack(spacing: SettingsDesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(SettingsColors.primaryText(for: colorScheme))
        }
    }

    private var thresholdIndicator: some View {
        let absThreshold = abs(motionManager.poorPostureThreshold)
        return HStack(spacing: SettingsDesignTokens.Spacing.sm) {
            Image(systemName: "waveform.path")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Threshold: \(String(format: "%.0f", absThreshold))°")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                Text(abs(absThreshold - 22.0) > 2.0 ? "Custom threshold" : "Default threshold")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }

            Spacer()

            if abs(absThreshold - 22.0) > 2.0 {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
            }
        }
    }

    private var disconnectedState: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.md) {
            Image(systemName: "airpods")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

            Text("Connect your AirPods")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SettingsColors.primaryText(for: colorScheme))

            Text("Head motion tracking requires AirPods with motion sensors")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SettingsDesignTokens.Spacing.md)
    }
}
