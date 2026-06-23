import SwiftUI

struct ControlButtons: View, Equatable {
    let isPaused: Bool
    let isDeviceConnected: Bool
    let isAnimatingLogo: Bool
    let onPause: () -> Void
    let onStop: () -> Void
    let onReconnect: () -> Void
    let colorScheme: ColorScheme
    
    static func == (lhs: ControlButtons, rhs: ControlButtons) -> Bool {
        lhs.isPaused == rhs.isPaused &&
        lhs.isDeviceConnected == rhs.isDeviceConnected &&
        lhs.isAnimatingLogo == rhs.isAnimatingLogo &&
        lhs.colorScheme == rhs.colorScheme
    }
    
    var body: some View {
        HStack(spacing: 16) {
            PremiumButton(
                title: isPaused ? "Resume" : "Pause",
                icon: isPaused ? "play.fill" : "pause.fill",
                colors: isPaused ? [
                    Color(red: 0.0, green: 0.57, blue: 0.95),
                    Color(red: 0.0, green: 0.475, blue: 0.855),
                    Color(red: 0.0, green: 0.38, blue: 0.76),
                    Color(red: 0.0, green: 0.285, blue: 0.665)
                ] : [
                    Color(red: 0.0, green: 0.57, blue: 0.95),
                    Color(red: 0.0, green: 0.475, blue: 0.855),
                    Color(red: 0.0, green: 0.38, blue: 0.76),
                    Color(red: 0.0, green: 0.285, blue: 0.665)
                ],
                showRainbowAccent: true,
                isAnimating: isAnimatingLogo,
                action: onPause
            )

            if !isDeviceConnected {
                PremiumButton(
                    title: "Reconnect",
                    icon: "arrow.clockwise",
                    colors: [
                        Color(red: 0.8, green: 0.2, blue: 1.0),
                        Color(red: 0.75, green: 0.25, blue: 0.95),
                        Color(red: 0.7, green: 0.2, blue: 0.9),
                        Color(red: 0.65, green: 0.15, blue: 0.85)
                    ],
                    isAnimating: isAnimatingLogo,
                    action: onReconnect
                )
            }

            PremiumButton(
                title: isPaused ? "Store" : "Stop",
                icon: isPaused ? "square.and.arrow.down" : "stop.fill",
                colors: isPaused ? [
                    Color(red: 0.95, green: 0.0, blue: 0.0),
                    Color(red: 0.855, green: 0.0, blue: 0.0),
                    Color(red: 0.76, green: 0.0, blue: 0.0),
                    Color(red: 0.665, green: 0.0, blue: 0.0)
                ] : [
                    Color(red: 0.95, green: 0.0, blue: 0.0),
                    Color(red: 0.855, green: 0.0, blue: 0.0),
                    Color(red: 0.76, green: 0.0, blue: 0.0),
                    Color(red: 0.665, green: 0.0, blue: 0.0)
                ],
                showRainbowAccent: true,
                isAnimating: isAnimatingLogo,
                action: onStop
            )
        }
    }
}
