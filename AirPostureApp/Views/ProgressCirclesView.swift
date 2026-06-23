import SwiftUI

struct ProgressCirclesView: View, Equatable {
    let sessions: [Session]
    let colorScheme: ColorScheme
    let screenWidth: CGFloat
    
    static func == (lhs: ProgressCirclesView, rhs: ProgressCirclesView) -> Bool {
        lhs.sessions == rhs.sessions &&
        lhs.colorScheme == rhs.colorScheme &&
        lhs.screenWidth == rhs.screenWidth
    }
    
    private var cardWidth: CGFloat { screenWidth - 32 } // 16 points padding on each side (matches PitchGraphView)
    
    @State private var previousSessions: [Session] = []
    @State private var isAnimating = false
    
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
        colorScheme == .dark ? .secondary : Color.gray
    }
    
    private var backgroundStrokeColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.15)
    }
    
    private var recentSessions: [Session] {
        return sessions
            .sorted { $0.startTime > $1.startTime }
            .prefix(5)
            .sorted { $0.startTime < $1.startTime }
    }
    
    // Responsive circle sizing based on screen width
    private var circleSize: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 80 // Larger for iPad
        }
        // Responsive sizing for iPhone
        if screenWidth >= 430 { // iPhone 16 Pro Max and larger
            return 70
        } else if screenWidth >= 393 { // iPhone 16 Pro
            return 65
        } else { // iPhone 16 and smaller
            return 60
        }
        #else
        return 60
        #endif
    }
    
    // Responsive stroke width based on circle size
    private var strokeWidth: CGFloat {
        return circleSize * 0.12 // Proportional stroke width
    }
    
    // Responsive font size based on circle size
    private var percentageFontSize: CGFloat {
        return circleSize * 0.23 // Proportional font size
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Sessions")
                .font(.headline)
                .foregroundColor(primaryTextColor)
                .padding(.leading, 6)  // Add left padding to move text slightly right
            
            // Custom divider with width matching the title
            Rectangle()
                .frame(height: 1)
                .frame(width: 140, alignment: .leading)
                .foregroundColor(backgroundStrokeColor)
                .padding(.vertical, 4)
            
            HStack(spacing: 12) {  // Increased spacing from 12 to 24 for more space between circles
                Spacer(minLength: 0)  // Add flexible spacer on the left to help center the circles
                ForEach(recentSessions, id: \.startTime) { session in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(
                                    backgroundStrokeColor,
                                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                                )
                                .frame(width: circleSize, height: circleSize)
                            
                            let percentage = Double(session.poorPosturePercentage) / 100.0
                            let color: Color = {
                                if session.poorPosturePercentage >= 50 {
                                    return .red
                                } else if session.poorPosturePercentage >= 40 {
                                    return .orange
                                } else {
                                    return .green
                                }
                            }()
                            
                            Circle()
                                .trim(from: 0, to: percentage)
                                .stroke(
                                    color,
                                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                                )
                                .frame(width: circleSize, height: circleSize)
                                .rotationEffect(.degrees(-90))

                            // Show avatar based on running/walking percentage (>50%) or saved avatar type
                            Image(session.runningWalkingPercentage > 50 ? "bear-running" : session.avatarType)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: circleSize * 0.3325, height: circleSize * 0.3325)
                                .opacity(0.6)
                                .offset(y: -circleSize * 0.1) // Move up slightly to make room for percentage
                                .allowsHitTesting(false)

                            Text("\(session.poorPosturePercentage)%")
                                .font(.system(size: percentageFontSize, weight: .bold, design: .rounded))
                                .foregroundColor(color)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(session.poorPosturePercentage)% poor posture at \(session.startTime, format: .dateTime.hour().minute())")
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: session.startTime)
                        
                        Text(session.startTime, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: session.startTime)
                    }
                }
                
                ForEach(0..<(5 - recentSessions.count), id: \.self) { _ in
                    VStack(spacing: 8) {
                        Circle()
                            .stroke(
                                backgroundStrokeColor,
                                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                            )
                            .frame(width: circleSize, height: circleSize)
                        
                        Text("--:--")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                    }
                    .transition(.opacity)
                }
                Spacer(minLength: 0)  // Add flexible spacer on the right to help center the circles
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)  // Reduced horizontal padding to allow more space for circles
        .frame(width: cardWidth)
        .fixedSize(horizontal: false, vertical: true)  // Allow the view to size itself based on content
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: cardShadowColor, radius: 8, x: 0, y: 2)
        .onChange(of: recentSessions) { oldValue, newValue in
            if oldValue.count == 5 && newValue.count == 5 {
                let oldIds = Set(oldValue.map { $0.id })
                let newIds = Set(newValue.map { $0.id })
                
                if oldIds != newIds {
                    #if os(iOS)
                    HapticManager.shared.impact(style: .light)
                    #endif
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isAnimating = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isAnimating = false
                    }
                }
            }
        }
    }
}

