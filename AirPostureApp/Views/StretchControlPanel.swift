import SwiftUI

struct StretchControlPanel: View {
    @ObservedObject var tracker: StretchTracker
    var onStart: () -> Void
    var onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if tracker.isActive {
                activeControls
            } else {
                startButton
            }
            
            stretchTypeSelector
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var startButton: some View {
        Button(action: {
            AnalyticsManager.shared.logEvent("stretch_start_clicked")
            onStart()
        }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Stretch")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var activeControls: some View {
        HStack(spacing: 20) {
            Button(action: {
                AnalyticsManager.shared.logEvent("stretch_stop_clicked")
                onStop()
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var stretchTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(StretchType.allCases) { stretch in
                    StretchSelectorButton(
                        stretch: stretch,
                        isSelected: tracker.currentStretch == stretch,
                        isActive: tracker.isActive,
                        action: {
                            if tracker.isActive {
                                tracker.switchStretch(stretch)
                            } else {
                                tracker.currentStretch = stretch
                            }
                        }
                    )
                }
            }
        }
    }
}

struct StretchSelectorButton: View {
    let stretch: StretchType
    let isSelected: Bool
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: stretch.icon)
                    .font(.title3)
                Text(stretch.shortName)
                    .font(.caption2)
            }
            .frame(width: 65, height: 60)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
            .foregroundStyle(isSelected ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isActive && isSelected)
    }
}

struct StretchSettingsView: View {
    @ObservedObject var settingsManager = StretchSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SettingsDesignTokens.Spacing.lg) {
                    SettingsSectionHeader(
                        title: "Stretch Settings",
                        subtitle: "Customize your stretching experience",
                        colorScheme: colorScheme
                    )
                    
                    VStack(spacing: SettingsDesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.sm) {
                            HStack {
                                Text("Hold Duration")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                                Spacer()
                                Text("\(settingsManager.settings.holdDurationSeconds, specifier: "%.1f")s")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            Slider(
                                value: Binding(
                                    get: { settingsManager.settings.holdDurationSeconds },
                                    set: { settingsManager.updateHoldDuration($0) }
                                ),
                                in: 0.5...5.0,
                                step: 0.5
                            )
                            .tint(.blue)
                        }
                        .padding(SettingsDesignTokens.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                                .fill(SettingsColors.cardBackground(for: colorScheme))
                                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
                        )
                        
                        VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.sm) {
                            HStack {
                                Text("Recovery Delay")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                                Spacer()
                                Text("\(settingsManager.settings.recoveryDelaySeconds, specifier: "%.1f")s")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            Slider(
                                value: Binding(
                                    get: { settingsManager.settings.recoveryDelaySeconds },
                                    set: { settingsManager.updateRecoveryDelay($0) }
                                ),
                                in: 0.5...3.0,
                                step: 0.5
                            )
                            .tint(.blue)
                        }
                        .padding(SettingsDesignTokens.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                                .fill(SettingsColors.cardBackground(for: colorScheme))
                                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
                        )
                        
                        VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.sm) {
                            HStack {
                                Text("Angle Tolerance")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                                Spacer()
                                Text("±\(Int(settingsManager.settings.angleToleranceDegrees))°")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            Slider(
                                value: Binding(
                                    get: { settingsManager.settings.angleToleranceDegrees },
                                    set: { settingsManager.updateAngleTolerance($0) }
                                ),
                                in: 5...20,
                                step: 1
                            )
                            .tint(.blue)
                        }
                        .padding(SettingsDesignTokens.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                                .fill(SettingsColors.cardBackground(for: colorScheme))
                                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
                        )
                    }
                    .padding(.horizontal, SettingsDesignTokens.Spacing.md)
                    
                    VStack(spacing: SettingsDesignTokens.Spacing.sm) {
                        SettingsToggleCard(
                            icon: "speaker.wave.2",
                            iconColor: .green,
                            title: "Voice Feedback",
                            subtitle: "Audio guidance during stretches",
                            isOn: $settingsManager.voiceEnabled,
                            colorScheme: colorScheme
                        )
                        
                        SettingsToggleCard(
                            icon: "iphone.radiowaves.left.and.right",
                            iconColor: .orange,
                            title: "Haptic Feedback",
                            subtitle: "Vibration alerts for reps",
                            isOn: $settingsManager.hapticEnabled,
                            colorScheme: colorScheme
                        )
                    }
                    .padding(.horizontal, SettingsDesignTokens.Spacing.md)
                    
                    VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.sm) {
                        HStack {
                            Text("Target Reps")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                            Spacer()
                            Text("\(settingsManager.targetReps)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(SettingsDesignTokens.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                                .fill(SettingsColors.cardBackground(for: colorScheme))
                                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
                        )
                        
                        Stepper("", value: $settingsManager.targetReps, in: 1...50)
                            .labelsHidden()
                    }
                    .padding(.horizontal, SettingsDesignTokens.Spacing.md)
                    
                    Button(action: {
                        settingsManager.resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SettingsDesignTokens.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, SettingsDesignTokens.Spacing.md)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Stretch Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
