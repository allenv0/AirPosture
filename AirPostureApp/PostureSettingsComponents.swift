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
                Button(action: {
                    #if os(iOS)
                    HapticManager.shared.impact(style: .light)
                    #endif
                    let currentPitch = motionManager.pitch
                    normalAngleSliderValue = currentPitch
                    motionManager.normalAirPodsAngle = currentPitch
                }) {
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
}

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
                
                Button(action: {
                    #if os(iOS)
                    HapticManager.shared.impact(style: .medium)
                    #endif
                    motionManager.calibrationService.startCalibration()
                }) {
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
                Button(action: {
                    #if os(iOS)
                    HapticManager.shared.impact(style: .light)
                    #endif
                    motionManager.calibrationService.resetToDefaultThreshold()
                }) {
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
            Button(action: {
                #if os(iOS)
                HapticManager.shared.impact(style: .light)
                #endif
                motionManager.calibrationService.cancelCalibration()
            }) {
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
            
            Button(action: {
                #if os(iOS)
                HapticManager.shared.impact(style: .medium)
                #endif
                motionManager.calibrationService.saveCalibrationResults()
            }) {
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
        Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
            motionManager.calibrationService.cancelCalibration()
        }) {
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
}

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
        Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .medium)
            #endif
            onEnableTracking()
        }) {
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
                    // Colorful gradient background (matches Fitness "Coming Soon" badge)
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
                    
                    // Glass morphism overlay
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                    
                    // Rainbow inner highlight for depth
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
                    
                    // Outer dark stroke
                    Capsule()
                        .stroke(
                            Color.black.opacity(0.25),
                            lineWidth: 1.5
                        )
                }
            )
            // Rainbow underglow effect
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
}
