import SwiftUI

struct PostureWarningBanner: View, Equatable {
    let warningCountdownSeconds: Int
    let colorScheme: ColorScheme
    
    static func == (lhs: PostureWarningBanner, rhs: PostureWarningBanner) -> Bool {
        lhs.warningCountdownSeconds == rhs.warningCountdownSeconds &&
        lhs.colorScheme == rhs.colorScheme
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.orange)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Poor Posture Warning")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Haptic feedback will start in \(warningCountdownSeconds) seconds")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 3)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .trim(from: 0, to: Double(warningCountdownSeconds) / 10.0)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: warningCountdownSeconds)
                
                Text("\(warningCountdownSeconds)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange, lineWidth: 1)
                .opacity(0.3)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Poor posture warning")
        .accessibilityValue("Haptic feedback will start in \(warningCountdownSeconds) seconds.")
    }
}

struct PostureRecoveryBanner: View, Equatable {
    let recoveryCountdownSeconds: Int
    let colorScheme: ColorScheme
    
    static func == (lhs: PostureRecoveryBanner, rhs: PostureRecoveryBanner) -> Bool {
        lhs.recoveryCountdownSeconds == rhs.recoveryCountdownSeconds &&
        lhs.colorScheme == rhs.colorScheme
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.green)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Poor Posture Recovering")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)

                Text("Haptic feedback will disappear in \(recoveryCountdownSeconds) seconds")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 3)
                    .frame(width: 32, height: 32)

                Circle()
                    .trim(from: 0, to: Double(recoveryCountdownSeconds) / 5.0)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: recoveryCountdownSeconds)

                Text("\(recoveryCountdownSeconds)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, lineWidth: 1)
                .opacity(0.3)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Poor posture recovering")
        .accessibilityValue("Haptic feedback will disappear in \(recoveryCountdownSeconds) seconds.")
    }
}
