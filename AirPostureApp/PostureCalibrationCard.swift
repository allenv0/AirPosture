#if os(iOS)
import UIKit
#endif
import SwiftUI

struct PostureCalibrationCard: View {
    var motionManager: HeadphoneMotionManager
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.md) {
            headerSection

            if motionManager.calibrationService.isCalibrating {
                calibrationInProgress
            } else {
                calibrationIdle
            }
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                .fill(SettingsColors.cardBackground(for: colorScheme))
                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Posture calibration")
    }

    private var headerSection: some View {
        let absThreshold = abs(motionManager.poorPostureThreshold)
        return HStack(spacing: SettingsDesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)

                Image(systemName: "scope")
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                Text("Calibration")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                Text(motionManager.calibrationService.isCalibrating ? motionManager.calibrationService.calibrationStep.rawValue : "Personalize your posture detection")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }

            Spacer()

            if abs(absThreshold - 22.0) > 2.0 && !motionManager.calibrationService.isCalibrating {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.green)
            }
        }
    }

    private var calibrationIdle: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.md) {
            if motionManager.isDeviceConnected {
                VStack(spacing: SettingsDesignTokens.Spacing.sm) {
                    HStack(spacing: SettingsDesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Threshold")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

                            HStack(spacing: 4) {
                                Text("\(String(format: "%.0f", abs(motionManager.poorPostureThreshold)))°")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)

                                if abs(abs(motionManager.poorPostureThreshold) - 22.0) > 2.0 {
                                    Text("Custom")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.green))
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(SettingsDesignTokens.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                            .fill(Color.secondary.opacity(0.08))
                    )

                    Text("Sit with your best posture, then calibrate for personalized detection.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                }

                Button(action: startCalibration) {
                    HStack(spacing: SettingsDesignTokens.Spacing.sm) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))

                        Text("Start Calibration")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                            .fill(Color.orange)
                    )
                }
                .buttonStyle(.plain)
            } else {
                disconnectedCalibrationState
            }

            if abs(abs(motionManager.poorPostureThreshold) - 22.0) > 2.0 {
                Button(action: resetToDefaultThreshold) {
                    HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .medium))

                        Text("Reset to Default")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var disconnectedCalibrationState: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            Image(systemName: "airpods")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

            Text("Connect AirPods to calibrate")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(SettingsColors.primaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SettingsDesignTokens.Spacing.lg)
    }

    private var calibrationInProgress: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.lg) {
            stepIndicator

            progressSection

            instructionSection

            if motionManager.calibrationService.calibrationStep == .complete {
                resultsSection

                actionButtons
            } else {
                cancelButton
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            stepCircle(number: 1, title: "Good", isActive: motionManager.calibrationService.calibrationStep == .goodPosture, isComplete: motionManager.calibrationService.calibrationStep == .badPosture || motionManager.calibrationService.calibrationStep == .complete)
            stepConnector(isComplete: motionManager.calibrationService.calibrationStep == .badPosture || motionManager.calibrationService.calibrationStep == .complete)
            stepCircle(number: 2, title: "Bad", isActive: motionManager.calibrationService.calibrationStep == .badPosture, isComplete: motionManager.calibrationService.calibrationStep == .complete)
            stepConnector(isComplete: motionManager.calibrationService.calibrationStep == .complete)
            stepCircle(number: 3, title: "Done", isActive: motionManager.calibrationService.calibrationStep == .complete, isComplete: motionManager.calibrationService.calibrationStep == .complete)
        }
        .padding(.horizontal, SettingsDesignTokens.Spacing.sm)
    }

    private func stepCircle(number: Int, title: String, isActive: Bool, isComplete: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : (isActive ? Color.orange : Color.secondary.opacity(0.2)))
                    .frame(width: 32, height: 32)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isActive ? .white : SettingsColors.secondaryText(for: colorScheme))
                }
            }

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActive ? SettingsColors.primaryText(for: colorScheme) : SettingsColors.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    private func stepConnector(isComplete: Bool) -> some View {
        Rectangle()
            .fill(isComplete ? Color.green : Color.secondary.opacity(0.2))
            .frame(height: 2)
            .frame(maxWidth: 24)
    }

    private var progressSection: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            ProgressView(value: motionManager.calibrationService.calibrationProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(x: 1, y: 2, anchor: .center)

            HStack {
                Text(motionManager.calibrationService.calibrationStep.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                Spacer()

                Text("\(Int(motionManager.calibrationService.calibrationProgress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            }
        }
    }

    private var instructionSection: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(stepColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: stepIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(stepColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stepTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                Text(stepInstruction)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }

            Spacer()
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                .fill(stepColor.opacity(0.05))
        )
    }

    private var stepColor: Color {
        switch motionManager.calibrationService.calibrationStep {
        case .goodPosture: return .green
        case .badPosture: return .red
        case .transition: return .orange
        case .complete: return .blue
        case .idle: return .gray
        }
    }

    private var stepIcon: String {
        switch motionManager.calibrationService.calibrationStep {
        case .goodPosture: return "figure.stand"
        case .badPosture: return "figure.walk"
        case .transition: return "arrow.right"
        case .complete: return "checkmark.circle.fill"
        case .idle: return "circle"
        }
    }

    private var stepTitle: String {
        switch motionManager.calibrationService.calibrationStep {
        case .goodPosture: return "Good Posture"
        case .badPosture: return "Poor Posture"
        case .transition: return "Get Ready"
        case .complete: return "Complete"
        case .idle: return "Ready"
        }
    }

    private var stepInstruction: String {
        switch motionManager.calibrationService.calibrationStep {
        case .goodPosture: return "Sit up straight in your ideal posture"
        case .badPosture: return "Lean forward into your typical slouch"
        case .transition: return "Prepare to record poor posture"
        case .complete: return "Your personalized threshold is ready"
        case .idle: return "Ready to start calibration"
        }
    }

    private var resultsSection: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            HStack {
                Text("Results")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                Spacer()
            }

            HStack(spacing: SettingsDesignTokens.Spacing.md) {
                resultItem(label: "Good", value: "\(String(format: "%.1f", motionManager.calibrationService.goodPostureAverage))°", color: .green)
                resultItem(label: "Poor", value: "\(String(format: "%.1f", motionManager.calibrationService.badPostureAverage))°", color: .red)
                resultItem(label: "Threshold", value: "\(String(format: "%.1f", motionManager.calibrationService.calculatedThreshold))°", color: .blue)
            }
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func resultItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.md) {
            Button(action: cancelCalibrationLight) {
                HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))

                    Text("Discard")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                        .fill(Color.red.opacity(0.1))
                )
            }
            .buttonStyle(.plain)

            Button(action: saveCalibrationResults) {
                HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))

                    Text("Save")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                        .fill(Color.green)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var cancelButton: some View {
        Button(action: cancelCalibrationLight) {
            HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))

                Text("Cancel Calibration")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                    .fill(Color.red.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    private func startCalibration() {
        #if os(iOS)
        HapticManager.shared.impact(style: .medium)
        #endif
        motionManager.calibrationService.startCalibration()
    }

    private func resetToDefaultThreshold() {
        #if os(iOS)
        HapticManager.shared.impact(style: .light)
        #endif
        motionManager.calibrationService.resetToDefaultThreshold()
    }

    private func cancelCalibrationLight() {
        #if os(iOS)
        HapticManager.shared.impact(style: .light)
        #endif
        motionManager.calibrationService.cancelCalibration()
    }

    private func saveCalibrationResults() {
        #if os(iOS)
        HapticManager.shared.impact(style: .medium)
        #endif
        motionManager.calibrationService.saveCalibrationResults()
    }
}
