#if os(iOS)
import UIKit
#endif
import SwiftUI

struct LatestSessionRow: View, Equatable {
    let session: Session
    let colorScheme: ColorScheme
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let cardBackgroundColor: Color
    let cardShadowColor: Color
    
    static func == (lhs: LatestSessionRow, rhs: LatestSessionRow) -> Bool {
        lhs.session == rhs.session &&
        lhs.colorScheme == rhs.colorScheme &&
        lhs.primaryTextColor == rhs.primaryTextColor &&
        lhs.secondaryTextColor == rhs.secondaryTextColor &&
        lhs.cardBackgroundColor == rhs.cardBackgroundColor &&
        lhs.cardShadowColor == rhs.cardShadowColor
    }
    
    private var sessionDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: session.startTime)
    }
    
    private var durationText: String {
        let minutes = Int(session.totalDuration / 60)
        return "\(minutes) min"
    }
    
    private var postureColor: Color {
        session.poorPosturePercentage >= 60 ? PostureColors.good :
        session.poorPosturePercentage >= 40 ? PostureColors.warning :
        PostureColors.poor
    }
    
    private var iconSize: CGFloat {
        #if os(iOS)
        let screenWidth = UIScreen.main.bounds.width
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 50
        }
        if screenWidth >= 430 {
            return 45
        } else if screenWidth >= 393 {
            return 42
        } else {
            return 40
        }
        #else
        return 40
        #endif
    }
    
    private var iconFontSize: CGFloat {
        return iconSize * 0.4
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(
                        Color.gray.opacity(0.12),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: iconSize, height: iconSize)
                Circle()
                    .trim(from: 0, to: Double(session.poorPosturePercentage) / 100.0)
                    .stroke(
                        postureColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: iconSize, height: iconSize)
                    .animation(.easeInOut(duration: 0.3), value: session.poorPosturePercentage)
                Image(session.runningWalkingPercentage > 50 ? "bear-running" : session.avatarType)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize * 0.7, height: iconSize * 0.7)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(sessionDate)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(primaryTextColor)
                    
                    if session.isDemo {
                        Text("Demo")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text("\(session.poorPosturePercentage)%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(postureColor)
                        .animation(.easeInOut(duration: 0.3), value: session.poorPosturePercentage)
                }
                
                HStack {
                    Text(durationText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                    
                    Spacer()
                    
                    Text("good posture")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackgroundColor)
        .cornerRadius(25)
        .shadow(color: cardShadowColor, radius: 4, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(postureColor.opacity(0.2), lineWidth: 3)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.isDemo ? "Demo session" : "Session")
        .accessibilityValue("\(sessionDate). \(durationText). \(session.poorPosturePercentage)% good posture.")
    }
}
