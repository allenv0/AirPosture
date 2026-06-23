import SwiftUI

enum SettingsDesignTokens {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Icon {
        static let small: CGFloat = 20
        static let medium: CGFloat = 24
        static let large: CGFloat = 40
    }

    enum Animation {
        static let standard = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
}

struct SettingsColors {
    let colorScheme: ColorScheme
    
    var cardBackground: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    var cardShadow: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    var primaryText: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    var secondaryText: Color {
        colorScheme == .dark ? .secondary : Color.gray
    }
    
    var divider: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.2) : Color.gray.opacity(0.2)
    }
    
    static func divider(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.secondary.opacity(0.2) : Color.gray.opacity(0.2)
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .primary : .black
    }
    
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .secondary : Color.gray
    }
    
    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
}

extension View {
    func settingsCardStyle(colorScheme: ColorScheme) -> some View {
        self
            .padding(SettingsDesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                    .fill(SettingsColors.cardBackground(for: colorScheme))
                    .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
            )
    }
    
    func settingsCardSelectionStyle(isSelected: Bool, colorScheme: ColorScheme) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.large)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
    }
}

struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String?
    let colorScheme: ColorScheme
    
    init(title: String, subtitle: String? = nil, colorScheme: ColorScheme) {
        self.title = title
        self.subtitle = subtitle
        self.colorScheme = colorScheme
    }
    
    var body: some View {
        VStack(spacing: SettingsDesignTokens.Spacing.sm) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(SettingsColors.primaryText(for: colorScheme))
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, SettingsDesignTokens.Spacing.lg)
        .padding(.horizontal, SettingsDesignTokens.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsNavigationCard<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let colorScheme: ColorScheme
    let destination: Destination
    
    init(
        icon: String,
        iconColor: Color = .blue,
        title: String,
        subtitle: String,
        colorScheme: ColorScheme,
        @ViewBuilder destination: () -> Destination
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.colorScheme = colorScheme
        self.destination = destination()
    }
    
    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: SettingsDesignTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)
                    .background(
                        Circle()
                            .fill(iconColor.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }
            .padding(SettingsDesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                    .fill(SettingsColors.cardBackground(for: colorScheme))
                    .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
            )
        }
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}

struct SettingsSelectionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    init(
        icon: String,
        iconColor: Color = .blue,
        title: String,
        subtitle: String,
        isSelected: Bool,
        colorScheme: ColorScheme,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.colorScheme = colorScheme
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SettingsDesignTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(isSelected ? iconColor : SettingsColors.primaryText(for: colorScheme))
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)
                    .background(
                        Circle()
                            .fill(iconColor.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? iconColor : SettingsColors.primaryText(for: colorScheme))
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: SettingsDesignTokens.Icon.small, weight: .medium))
                    .foregroundColor(isSelected ? iconColor : SettingsColors.secondaryText(for: colorScheme))
            }
            .padding(SettingsDesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                    .fill(SettingsColors.cardBackground(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                            .stroke(isSelected ? iconColor : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct SettingsToggleCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let colorScheme: ColorScheme
    let onChange: ((Bool) -> Void)?
    
    init(
        icon: String,
        iconColor: Color = .blue,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        colorScheme: ColorScheme,
        onChange: ((Bool) -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.colorScheme = colorScheme
        self.onChange = onChange
    }
    
    var body: some View {
        HStack(spacing: SettingsDesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .scaleEffect(0.9)
                .onChange(of: isOn) { _, newValue in
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                    onChange?(newValue)
                }
        }
        .padding(SettingsDesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                .fill(SettingsColors.cardBackground(for: colorScheme))
                .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle), \(isOn ? "on" : "off")")
        .accessibilityAddTraits(.isButton)
    }
}

struct SettingsActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let colorScheme: ColorScheme
    let action: () -> Void
    
    init(
        icon: String,
        iconColor: Color = .blue,
        title: String,
        subtitle: String,
        colorScheme: ColorScheme,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.colorScheme = colorScheme
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
            action()
        }) {
            HStack(spacing: SettingsDesignTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: SettingsDesignTokens.Icon.medium, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: SettingsDesignTokens.Icon.large, height: SettingsDesignTokens.Icon.large)
                    .background(
                        Circle()
                            .fill(iconColor.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: SettingsDesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SettingsColors.primaryText(for: colorScheme))
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
            }
            .padding(SettingsDesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SettingsDesignTokens.CornerRadius.medium)
                    .fill(SettingsColors.cardBackground(for: colorScheme))
                    .shadow(color: SettingsColors.cardShadow(for: colorScheme), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}
