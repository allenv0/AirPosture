#if os(iOS)
import UIKit
#endif
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case avatar = "Avatar"
    case appearance = "Appearance"
    case notifications = "Notifications"
    case feedback = "Feedback"

    var icon: String {
        switch self {
        case .avatar:
            return "person.crop.circle.badge.plus"
        case .appearance:
            return "circle.lefthalf.filled"
        case .notifications:
            return "bell"
        case .feedback:
            return "envelope"
        }
    }
}

struct SettingsSheet: View {
    @Binding var selectedTab: SettingsTab
    @Binding var currentAvatar: AvatarType
    let colorScheme: ColorScheme
    var motionManager: HeadphoneMotionManager
    @ObservedObject var sessionStore: SessionStore
    @State private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private var backgroundColor: Color {
        themeManager.selectedTheme.colorScheme == .light ? Color(red: 0.95, green: 0.95, blue: 0.97) : Color.black
    }
    
    private var cardBackgroundColor: Color {
        themeManager.selectedTheme.colorScheme == .light ? Color.white : Color.secondary.opacity(0.05)
    }
    
    private var primaryTextColor: Color {
        themeManager.selectedTheme.colorScheme == .light ? .black : .primary
    }
    
    private var secondaryTextColor: Color {
        SettingsColors.secondaryText(for: themeManager.selectedTheme.colorScheme == .light ? .light : .dark)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Button(action: {
                            #if os(iOS)
                            HapticManager.shared.impact(style: .light)
                            #endif
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(
                                        selectedTab == tab ?
                                            LinearGradient(
                                                colors: [Color.white, Color.white.opacity(0.9)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ) :
                                            LinearGradient(
                                                colors: [primaryTextColor, primaryTextColor.opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                    )

                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(
                                        selectedTab == tab ?
                                            LinearGradient(
                                                colors: [Color.white, Color.white.opacity(0.9)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ) :
                                            LinearGradient(
                                                colors: [primaryTextColor, primaryTextColor.opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                // 🎨 Premium tab background
                                ZStack {
                                    if selectedTab == tab {
                                        // Glass morphism base for selected tab
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.3),
                                                                Color.white.opacity(0.1),
                                                                Color.clear
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            )

                                        // Premium blue gradient overlay
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.0, green: 0.6, blue: 1.0),
                                                        Color(red: 0.0, green: 0.5, blue: 0.9),
                                                        Color(red: 0.0, green: 0.4, blue: 0.8),
                                                        Color(red: 0.0, green: 0.3, blue: 0.7)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.4),
                                                                Color.white.opacity(0.2),
                                                                Color.clear
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1.5
                                                    )
                                            )
                                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                            .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)
                                    } else {
                                        // Subtle background for unselected tabs
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.clear)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Content area
                TabView(selection: $selectedTab) {
                    IconsSettingsView(currentAvatar: $currentAvatar, colorScheme: colorScheme)
                        .tag(SettingsTab.avatar)

                    AppearanceSettingsView(colorScheme: colorScheme)
                        .tag(SettingsTab.appearance)

                    NotificationSettingsView(colorScheme: colorScheme)
                        .tag(SettingsTab.notifications)

                    FeedbackSettingsView(colorScheme: colorScheme)
                        .tag(SettingsTab.feedback)
                }
                #if os(iOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                #endif
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        #if os(iOS)
                        HapticManager.shared.impact(style: .light)
                        #endif
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct IconsSettingsView: View {
    @Binding var currentAvatar: AvatarType
    let colorScheme: ColorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignTokens.Spacing.lg) {
                SettingsSectionHeader(
                    title: "Choose Your Profile",
                    subtitle: "Select an avatar to represent your posture tracking",
                    colorScheme: colorScheme
                )
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SettingsDesignTokens.Spacing.md), count: 2), spacing: SettingsDesignTokens.Spacing.md) {
                    ForEach(AvatarType.allCases, id: \.self) { avatar in
                        Button(action: {
                            #if os(iOS)
                            HapticManager.shared.impact(style: .medium)
                            #endif
                            withAnimation(SettingsDesignTokens.Animation.standard) {
                                currentAvatar = avatar
                            }
                        }) {
                            VStack(spacing: SettingsDesignTokens.Spacing.sm) {
                                Image(avatar.rawValue)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(currentAvatar == avatar ? .blue : SettingsColors.primaryText(for: colorScheme))
                                    .scaleEffect(currentAvatar == avatar ? 1.1 : 1.0)
                                    .animation(SettingsDesignTokens.Animation.standard, value: currentAvatar)
                                
                                Text(avatar.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(currentAvatar == avatar ? .blue : SettingsColors.primaryText(for: colorScheme))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.large)
                                    .fill(SettingsColors.cardBackground(for: colorScheme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.large)
                                            .stroke(currentAvatar == avatar ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SettingsDesignTokens.Spacing.md)
                
                Spacer(minLength: 50)
            }
        }
    }
}



struct AppearanceSettingsView: View {
    let colorScheme: ColorScheme
    @State private var themeManager = ThemeManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignTokens.Spacing.lg) {
                SettingsSectionHeader(
                    title: "Appearance",
                    subtitle: "Choose your preferred theme",
                    colorScheme: colorScheme
                )

                VStack(spacing: SettingsDesignTokens.Spacing.md) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        SettingsSelectionCard(
                            icon: theme.icon,
                            iconColor: .blue,
                            title: theme.rawValue,
                            subtitle: themeSubtitle(for: theme),
                            isSelected: themeManager.selectedTheme == theme,
                            colorScheme: colorScheme
                        ) {
                            #if os(iOS)
                            HapticManager.shared.impact(style: .medium)
                            #endif
                            // No animation - theme change should be instant
                            themeManager.selectedTheme = theme
                        }
                    }
                }
                .padding(.horizontal, SettingsDesignTokens.Spacing.md)

                Spacer(minLength: 50)
            }
        }
    }
    
    private func themeSubtitle(for theme: AppTheme) -> String {
        switch theme {
        case .dark:
            return "Always use dark mode"
        case .light:
            return "Always use light mode"
        case .system:
            return "Match your device settings"
        }
    }
}

struct PostureSettingsView: View {
    let colorScheme: ColorScheme
    var motionManager: HeadphoneMotionManager
    @ObservedObject var sessionStore: SessionStore
    
    @State private var isLiveTrackingEnabled = false
    
    private var hasActiveSession: Bool {
        sessionStore.currentSession != nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignTokens.Spacing.lg) {
                SettingsSectionHeader(
                    title: "Posture Settings",
                    subtitle: "Customize your tracking experience",
                    colorScheme: colorScheme
                )
                
                VStack(spacing: SettingsDesignTokens.Spacing.md) {
                    if hasActiveSession {
                        PostureStatusCard(
                            motionManager: motionManager,
                            colorScheme: colorScheme
                        )
                    } else if isLiveTrackingEnabled {
                        PostureStatusCard(
                            motionManager: motionManager,
                            colorScheme: colorScheme
                        )
                    } else {
                        LivePreviewCard(
                            motionManager: motionManager,
                            colorScheme: colorScheme,
                            onEnableTracking: {
                                isLiveTrackingEnabled = true
                                motionManager.start()
                            }
                        )
                    }
                    
                    PostureThresholdCard(
                        motionManager: motionManager,
                        colorScheme: colorScheme
                    )
                }
                .padding(.horizontal, SettingsDesignTokens.Spacing.md)
                
                Spacer(minLength: 50)
            }
        }
        .accessibilityElement(children: .contain)
        .onDisappear {
            isLiveTrackingEnabled = false
        }
    }
}

struct NotificationSettingsView: View {
    let colorScheme: ColorScheme
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignTokens.Spacing.lg) {
                SettingsSectionHeader(
                    title: "Notifications",
                    subtitle: "Manage your alert preferences",
                    colorScheme: colorScheme
                )
                
                VStack(spacing: SettingsDesignTokens.Spacing.md) {
                    NotificationPermissionCard(
                        notificationManager: notificationManager,
                        colorScheme: colorScheme
                    )
                    
                    NotificationModeCard(
                        notificationManager: notificationManager,
                        colorScheme: colorScheme,
                        isEnabled: notificationManager.isNotificationEnabled
                    )
                    
                    if notificationManager.notificationMode == .realTime {
                        RealtimeDelayCard(colorScheme: colorScheme)
                        AudioCueCard(colorScheme: colorScheme)
                    }
                    
                    HapticFeedbackCard(colorScheme: colorScheme)
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notification settings")
    }
}



struct HapticFeedbackCard: View {
    let colorScheme: ColorScheme
    @State private var motionManager = HeadphoneMotionManager.shared

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }

    private var secondaryTextColor: Color {
        SettingsColors.secondaryText(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.orange)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Haptic Feedback")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)

                    Text("Control vibration feedback")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }

                Spacer()

                Toggle("", isOn: $motionManager.isHapticFeedbackEnabled)
                    .labelsHidden()
                    .scaleEffect(0.9)
                    .onChange(of: motionManager.isHapticFeedbackEnabled) { _, _ in
                        #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        #endif
                    }
            }

            if motionManager.isHapticFeedbackEnabled {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)

                        Text("Includes posture alerts, button taps, and app interactions")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SettingsColors.secondaryText(for: colorScheme))

                        Spacer()
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 8, x: 0, y: 2)
        )
    }
}

struct FeedbackSettingsView: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: SettingsDesignTokens.Spacing.lg) {
                SettingsSectionHeader(
                    title: "Send Feedback",
                    subtitle: "Help us improve AirPosture with your feedback",
                    colorScheme: colorScheme
                )
                
                VStack(spacing: SettingsDesignTokens.Spacing.md) {
                    FeedbackCard(
                        title: "Report a Bug",
                        subtitle: "Let us know if you encounter any issues",
                        icon: "exclamationmark.triangle",
                        color: .orange,
                        colorScheme: colorScheme,
                        action: {
                            openEmail(subject: "AirPosture Bug Report")
                        }
                    )

                    FeedbackCard(
                        title: "Feature Request",
                        subtitle: "Suggest new features you'd like to see",
                        icon: "lightbulb",
                        color: .yellow,
                        colorScheme: colorScheme,
                        action: {
                            openEmail(subject: "AirPosture Feature Request")
                        }
                    )

                    FeedbackCard(
                        title: "General Feedback",
                        subtitle: "Share your thoughts about the app",
                        icon: "message",
                        color: .blue,
                        colorScheme: colorScheme,
                        action: {
                            openEmail(subject: "AirPosture Feedback")
                        }
                    )
                }
                .padding(.horizontal, SettingsDesignTokens.Spacing.md)
                
                Spacer(minLength: 50)
            }
        }
    }

    private static let feedbackEmail = "allenleexyz@gmail.com"

    private func openEmail(subject: String) {
        let email = Self.feedbackEmail
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "mailto:\(email)?subject=\(encodedSubject)"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

struct SettingsCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let colorScheme: ColorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    private var secondaryTextColor: Color {
        SettingsColors.secondaryText(for: colorScheme)
    }
    
    var body: some View {
        Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackgroundColor)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeedbackCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    let action: () -> Void

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }

    private var secondaryTextColor: Color {
        SettingsColors.secondaryText(for: colorScheme)
    }

    var body: some View {
        Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackgroundColor)
            )
        }
        .buttonStyle(.plain)
    }
}
