import SwiftUI

struct FitnessComingSoonView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 80)

                Image("launch-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .padding(.bottom, 30)

                Text("Spatial Intelligence")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(primaryTextColor)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                ComingSoonBadge()

                Text("AI-powered motion tracking\nwith audio guided exercises")
                    .font(.body)
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                Spacer()

                Link("Stay tuned for updates", destination: URL(string: "https://x.com/allenleexyz")!)
                    .font(.caption)
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme).opacity(0.7))
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct PersonalizeRootView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var motionManager = HeadphoneMotionManager.shared
    @ObservedObject private var sessionStore = SessionStore.shared

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                PostureSettingsView(
                    colorScheme: colorScheme,
                    motionManager: motionManager,
                    sessionStore: sessionStore
                )
            }
        }
    }
}

struct SettingsRootView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var themeManager = ThemeManager.shared
    @State private var avatarManager = AvatarManager.shared

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SettingsDesignTokens.Spacing.md) {
                        SettingsSectionHeader(
                            title: "Settings",
                            subtitle: "Customize your experience",
                            colorScheme: colorScheme
                        )

                        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
                            SettingsNavigationCard(
                                icon: "person.circle",
                                iconColor: .blue,
                                title: "Avatar",
                                subtitle: avatarManager.selectedAvatar.displayName,
                                colorScheme: colorScheme
                            ) {
                                IconsSettingsView(
                                    currentAvatar: $avatarManager.selectedAvatar,
                                    colorScheme: colorScheme
                                )
                            }

                            SettingsNavigationCard(
                                icon: "circle.lefthalf.filled",
                                iconColor: .purple,
                                title: "Appearance",
                                subtitle: themeManager.selectedTheme.rawValue,
                                colorScheme: colorScheme
                            ) {
                                AppearanceSettingsView(colorScheme: colorScheme)
                            }

                            SettingsNavigationCard(
                                icon: "bell",
                                iconColor: .orange,
                                title: "Notifications",
                                subtitle: "Haptic and audio preferences",
                                colorScheme: colorScheme
                            ) {
                                NotificationSettingsView(colorScheme: colorScheme)
                            }

                            SettingsNavigationCard(
                                icon: "hand.thumbsup",
                                iconColor: .pink,
                                title: "Feedback",
                                subtitle: "Contact Allen Lee",
                                colorScheme: colorScheme
                            ) {
                                FeedbackSettingsView(colorScheme: colorScheme)
                            }
                        }
                        .padding(.horizontal, SettingsDesignTokens.Spacing.md)

                        Spacer(minLength: 50)
                    }
                }
            }
        }
    }
}

private struct ComingSoonBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
            Text("Coming Soon")
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
                    .stroke(Color.black.opacity(0.25), lineWidth: 1.5)
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
                .opacity(0.8)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
