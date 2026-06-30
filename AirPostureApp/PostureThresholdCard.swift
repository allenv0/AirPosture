#if os(iOS)
import UIKit
#endif
import SwiftUI

struct PostureThresholdCard: View {
    var motionManager: HeadphoneMotionManager
    let colorScheme: ColorScheme

    @State private var isEditing: Bool = false
    @State private var sliderValue: Double = 22.0
    @State private var normalAngleSliderValue: Double = 0.0

    private enum SensitivityPreset: String, CaseIterable {
        case relaxed = "Relaxed"
        case normal = "Normal"
        case strict = "Strict"

        var threshold: Double {
            switch self {
            case .relaxed: return 28.0
            case .normal: return 22.0
            case .strict: return 16.0
            }
        }

        var description: String {
            switch self {
            case .relaxed: return "More forgiving, fewer alerts"
            case .normal: return "Balanced sensitivity"
            case .strict: return "Catches subtle slouching"
            }
        }

        var icon: String {
            switch self {
            case .relaxed: return "leaf.fill"
            case .normal: return "slider.horizontal.3"
            case .strict: return "scope"
            }
        }
    }

    private var currentPreset: SensitivityPreset? {
        let absThreshold = abs(motionManager.poorPostureThreshold)
        return SensitivityPreset.allCases.first { abs(absThreshold - $0.threshold) < 2.0 }
    }

    private var isCustom: Bool {
        let absThreshold = abs(motionManager.poorPostureThreshold)
        return currentPreset == nil && abs(absThreshold - 22.0) > 2.0
    }

    var body: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.md) {
            headerSection

            Divider()
                .background(SettingsColors.divider(for: colorScheme))

            sliderSection

            Divider()
                .background(SettingsColors.divider(for: colorScheme))

            normalAngleSection

            Divider()
                .background(SettingsColors.divider(for: colorScheme))

            presetSection
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                .fill(SettingsColors.cardBackground(for: colorScheme))
                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Posture threshold settings")
        .onAppear {
            sliderValue = abs(motionManager.poorPostureThreshold)
            normalAngleSliderValue = motionManager.normalAirPodsAngle
        }
    }

    private var headerSection: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                    Text("Sensitivity")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                    if isCustom {
                        Text("Custom")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple))
                    }
                }

                Text("Adjust how posture is detected")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }

            Spacer()

            if !isCustom, let preset = currentPreset {
                Text(preset.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.1)))
            }
        }
    }

    private var sliderSection: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            HStack {
                Text("Detection Threshold")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

                Spacer()

                Text("\(String(format: "%.0f", sliderValue))°")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isEditing ? .blue : SettingsColors.primaryText(for: colorScheme))
            }

            Slider(value: $sliderValue, in: 1...39, step: 1) { editing in
                isEditing = editing
                if !editing {
                    motionManager.poorPostureThreshold = -sliderValue
                }
            }
            .accentColor(.blue)

            HStack {
                Text("More Lenient")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

                Spacer()

                Text("More Strict")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }
        }
    }

    private var normalAngleSection: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            HStack {
                Text("Normal AirPods Angle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

                Spacer()

                Text("\(String(format: "%.0f", normalAngleSliderValue))°")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(normalAngleSliderValue != 0 ? .orange : SettingsColors.primaryText(for: colorScheme))
            }

            Slider(value: $normalAngleSliderValue, in: -30...30, step: 1) { editing in
                isEditing = editing
                if !editing {
                    motionManager.normalAirPodsAngle = normalAngleSliderValue
                }
            }
            .accentColor(.orange)

            HStack {
                Text("Tilted Back")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

                Spacer()

                Text("Tilted Forward")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }

            if motionManager.isDeviceConnected {
                Button(action: setCurrentPitchAsNormal) {
                    HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12, weight: .medium))

                        Text("Set Current as Normal (\(String(format: "%.0f", motionManager.pitch))°)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .padding(.top, SettingsDesignTokens.Spacing.xs)
            }

            if normalAngleSliderValue != 0 {
                HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)

                    Text("Your typical head angle with AirPods")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }
            }
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.sm) {
            Text("Quick Presets")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

            ForEach(SensitivityPreset.allCases, id: \.self) { preset in
                presetButton(for: preset)
            }
        }
    }

    private func presetButton(for preset: SensitivityPreset) -> some View {
        let isSelected = currentPreset == preset

        return Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
            sliderValue = preset.threshold
            motionManager.poorPostureThreshold = -preset.threshold
        }) {
            HStack(spacing: SettingsDesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
                        .frame(width: 32, height: 32)

                    Image(systemName: preset.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : SettingsColors.secondaryText(for: colorScheme))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                    Text(preset.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }

                Spacer()

                Text("\(String(format: "%.0f", preset.threshold))°")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .blue : SettingsColors.secondaryText(for: colorScheme))
            }
            .padding(.horizontal, SettingsDesignTokens.Spacing.md)
            .padding(.vertical, SettingsDesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.rawValue) preset: \(preset.description)")
    }

    private func setCurrentPitchAsNormal() {
        #if os(iOS)
        HapticManager.shared.impact(style: .light)
        #endif
        let currentPitch = motionManager.pitch
        normalAngleSliderValue = currentPitch
        motionManager.normalAirPodsAngle = currentPitch
    }
}
