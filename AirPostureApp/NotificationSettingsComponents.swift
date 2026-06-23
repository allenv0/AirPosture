#if os(iOS)
import UIKit
#endif
import SwiftUI

enum NotificationPermissionStatus {
    case notRequested
    case granted
    case denied
}

struct NotificationPermissionCard: View {
    @ObservedObject var notificationManager: NotificationManager
    let colorScheme: ColorScheme
    @State private var isRequesting = false
    
    private var permissionStatus: NotificationPermissionStatus {
        if notificationManager.isNotificationEnabled {
            return .granted
        }
        return .notRequested
    }
    
    var body: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.md) {
            headerSection
            
            switch permissionStatus {
            case .notRequested:
                requestPermissionButton
            case .granted:
                grantedStatusView
            case .denied:
                deniedStatusView
            }
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                .fill(SettingsColors.cardBackground(for: colorScheme))
                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notification permission status")
        .accessibilityHint(permissionStatus == .granted ? "Notifications are enabled" : "Tap to enable notifications")
    }
    
    private var headerSection: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(permissionStatus == .granted ? Color.green.opacity(0.15) : Color.blue.opacity(0.1))
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)
                
                Image(systemName: permissionStatus == .granted ? "bell.badge.fill" : "bell.fill")
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(permissionStatus == .granted ? .green : .blue)
            }
            
            VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                Text("Notifications")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                
                Text(permissionStatus == .granted ? "Enabled" : "Get posture session summaries")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }
            
            Spacer()
            
            if permissionStatus == .granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.green)
            }
        }
    }
    
    private var requestPermissionButton: some View {
        Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .medium)
            #endif
            isRequesting = true
            Task {
                await notificationManager.requestNotificationPermission()
                isRequesting = false
            }
        }) {
            HStack(spacing: SettingsDesignTokens.Spacing.sm) {
                if isRequesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(isRequesting ? "Requesting..." : "Enable Notifications")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRequesting)
        .accessibilityLabel("Enable notifications button")
        .accessibilityHint("Opens system permission dialog")
    }
    
    private var grantedStatusView: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            Divider()
                .background(SettingsColors.divider(for: colorScheme))
            
            Button(action: {
                #if os(iOS)
                HapticManager.shared.impact(style: .light)
                #endif
                notificationManager.openNotificationSettings()
            }) {
                HStack(spacing: SettingsDesignTokens.Spacing.sm) {
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open Notification Settings")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open notification settings")
            .accessibilityHint("Opens iOS Settings for notification customization")
        }
    }
    
    private var deniedStatusView: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            HStack(spacing: SettingsDesignTokens.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Notifications are disabled in Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }
            
            Button(action: {
                #if os(iOS)
                HapticManager.shared.impact(style: .light)
                #endif
                notificationManager.openNotificationSettings()
            }) {
                HStack(spacing: SettingsDesignTokens.Spacing.sm) {
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open Settings")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                        .fill(Color.orange)
                )
            }
            .buttonStyle(.plain)
        }
        .accessibilityLabel("Notifications disabled")
        .accessibilityHint("Tap to open Settings and enable notifications")
    }
}

struct NotificationModeCard: View {
    @ObservedObject var notificationManager: NotificationManager
    let colorScheme: ColorScheme
    let isEnabled: Bool
    
    var body: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.md) {
            headerSection
            
            VStack(spacing: SettingsDesignTokens.Spacing.sm) {
                ForEach(NotificationMode.allCases, id: \.self) { mode in
                    modeButton(for: mode)
                }
            }
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                .fill(SettingsColors.cardBackground(for: colorScheme))
                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
        )
        .opacity(isEnabled ? 1.0 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notification mode selection")
    }
    
    private var headerSection: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)
                
                Image(systemName: "bell.badge.waveform")
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                    Text("Notification Mode")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                }
                
                Text("Choose when to receive alerts")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }
            
            Spacer()
        }
    }
    
    private func modeButton(for mode: NotificationMode) -> some View {
        let isSelected = notificationManager.notificationMode == mode
        
        return Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
            notificationManager.notificationMode = mode
        }) {
            HStack(spacing: SettingsDesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                    
                    Text(mode.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, SettingsDesignTokens.Spacing.md)
            .padding(.vertical, SettingsDesignTokens.Spacing.sm + 4)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(mode.rawValue)
        .accessibilityHint(isSelected ? "Selected" : "Tap to select")
    }
}

struct RealtimeDelayCard: View {
    let colorScheme: ColorScheme
    @State private var motionManager = HeadphoneMotionManager.shared

    private struct DelayOption {
        let seconds: TimeInterval
        let label: String
        let description: String
    }

    private let options: [DelayOption] = [
        .init(seconds: 0, label: "Immediate", description: "Notify as soon as bad posture is detected"),
        .init(seconds: 2, label: "2 seconds", description: "Brief delay to filter momentary slouches"),
        .init(seconds: 5, label: "5 seconds", description: "Balanced detection"),
        .init(seconds: 30, label: "30 seconds", description: "Only notify for sustained poor posture"),
        .init(seconds: 60, label: "1 minute", description: "Minimal interruptions"),
    ]

    var body: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.md) {
            headerSection

            VStack(spacing: SettingsDesignTokens.Spacing.sm) {
                ForEach(options, id: \.seconds) { option in
                    delayButton(for: option)
                }
            }
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                .fill(SettingsColors.cardBackground(for: colorScheme))
                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Real-time notification delay")
    }

    private var headerSection: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)

                Image(systemName: "timer")
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                Text("Notification Delay")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                Text("How long bad posture must continue before you're notified")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }

            Spacer()
        }
    }

    private func delayButton(for option: DelayOption) -> some View {
        let isSelected = abs(motionManager.realtimeNotificationDelay - option.seconds) < 0.01

        return Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
            motionManager.realtimeNotificationDelay = option.seconds
        }) {
            HStack(spacing: SettingsDesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SettingsDesignTokens.Spacing.xs) {
                        Text(option.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                        if abs(option.seconds - MotionConstants.defaultRealtimeNotificationDelay) < 0.01 {
                            Text("Default")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                )
                        }
                    }

                    Text(option.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, SettingsDesignTokens.Spacing.md)
            .padding(.vertical, SettingsDesignTokens.Spacing.sm + 4)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityHint(isSelected ? "Selected" : "Tap to select")
    }
}

struct AudioCueCard: View {
    let colorScheme: ColorScheme
    @ObservedObject private var notificationManager = NotificationManager.shared

    var body: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.md) {
            headerSection

            VStack(spacing: SettingsDesignTokens.Spacing.sm) {
                ForEach(AudioCueStyle.allCases, id: \.self) { style in
                    cueButton(for: style)
                }
            }
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                .fill(SettingsColors.cardBackground(for: colorScheme))
                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Audio cue selection")
    }

    private var headerSection: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)

                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                Text("Audio Cue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                Text("Sound played with posture notifications")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }

            Spacer()
        }
    }

    private func cueButton(for style: AudioCueStyle) -> some View {
        let isSelected = notificationManager.audioCueStyle == style

        return Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
            notificationManager.audioCueStyle = style
            notificationManager.previewAudioCue()
        }) {
            HStack(spacing: SettingsDesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SettingsColors.primaryText(for: colorScheme))

                    Text(style.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : SettingsColors.secondaryText(for: colorScheme).opacity(0.5))
            }
            .padding(.horizontal, SettingsDesignTokens.Spacing.md)
            .padding(.vertical, SettingsDesignTokens.Spacing.sm + 4)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.small)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.displayName)
        .accessibilityHint(isSelected ? "Selected" : "Tap to select and preview")
    }
}