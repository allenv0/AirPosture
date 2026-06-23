#if os(iOS)
import UIKit
#endif
import SwiftUI

struct HeadVisualization: View, Equatable {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let postureState: PostureState
    let screenWidth: CGFloat
    let colorScheme: ColorScheme
    let currentAvatar: AvatarType
    let onAvatarTap: () -> Void
    let size: CGFloat
    let poorPostureThreshold: Double
    let normalAirPodsAngle: Double
    let isUserRunningOrWalking: Bool
    
    static func == (lhs: HeadVisualization, rhs: HeadVisualization) -> Bool {
        lhs.pitch == rhs.pitch &&
        lhs.roll == rhs.roll &&
        lhs.yaw == rhs.yaw &&
        lhs.postureState == rhs.postureState &&
        lhs.screenWidth == rhs.screenWidth &&
        lhs.colorScheme == rhs.colorScheme &&
        lhs.currentAvatar == rhs.currentAvatar &&
        lhs.size == rhs.size &&
        lhs.poorPostureThreshold == rhs.poorPostureThreshold &&
        lhs.normalAirPodsAngle == rhs.normalAirPodsAngle &&
        lhs.isUserRunningOrWalking == rhs.isUserRunningOrWalking
    }
    
    @State private var viewAppeared = false
    @State private var isAnimatingTransition = false
    
    private var isAlertActive: Bool {
        if case .alert = postureState {
            return true
        }
        return false
    }
    
    private var strokeColor: Color {
        let adjustedPitch = roundedPitch - normalAirPodsAngle
        return adjustedPitch < poorPostureThreshold ? PostureColors.poor : PostureColors.good
    }
    
    private var roundedPitch: Double {
        (pitch * 10).rounded() / 10
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            strokeColor,
                            style: StrokeStyle(
                                lineWidth: 14.4,
                                lineCap: .round
                            )
                        )
                        .animation(.easeInOut(duration: 0.3), value: roundedPitch)
                )
                .shadow(
                    color: strokeColor.opacity(colorScheme == .dark ? 0.5 : 0.3),
                    radius: roundedPitch < poorPostureThreshold ? 10 : 5,
                    x: 0,
                    y: 0
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: roundedPitch)
            
            Group {
                #if os(macOS)
                let avatarName = isUserRunningOrWalking ? "bear-running" : currentAvatar.rawValue
                if Bundle.main.path(forResource: avatarName, ofType: nil) != nil {
                    Image(avatarName)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: size * 0.8 * 0.6))
                }
                #else
                Image(isUserRunningOrWalking ? "bear-running" : currentAvatar.rawValue)
                    .resizable()
                    .scaledToFit()
                #endif
            }
            .frame(width: size * 0.8, height: size * 0.8)
            .foregroundColor(colorForState(postureState))
            .modifier(PulseEffect(isActive: isAlertActive))
            .rotationEffect(.degrees(pitch - normalAirPodsAngle))
            .onTapGesture {
                onAvatarTap()
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: currentAvatar)
            .animation(.easeInOut(duration: 0.3), value: roundedPitch)
        }
        .padding(0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Avatar posture indicator")
        .accessibilityValue("Pitch \(Int(roundedPitch)) degrees. \(currentAvatar.displayName).")
        .accessibilityHint("Double tap to switch avatar.")
        .accessibilityAddTraits(.isButton)
    }
    
    private func colorForState(_ state: PostureState) -> Color {
        switch state {
        case .alert:
            return Color(red: 1.0, green: 0.31, blue: 0.0)
        case .warning:
            return Color(red: 1.0, green: 0.76, blue: 0.03)
        default:
            return Color(red: 0.0, green: 0.8, blue: 0.4)
        }
    }
}
