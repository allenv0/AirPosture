import SwiftUI

public struct PitchGraphView: View, Equatable {
    public let dataPoints: [Double]
    public let threshold: Double
    public let normalAirPodsAngle: Double
    public let currentPitch: Double
    public let poorPostureDuration: TimeInterval
    public let postureScorePercent: Int
    public let totalSessionTime: TimeInterval
    public let screenWidth: CGFloat
    public let colorScheme: ColorScheme
    public let isAnimatingLogo: Bool
    
    public static func == (lhs: PitchGraphView, rhs: PitchGraphView) -> Bool {
        lhs.dataPoints == rhs.dataPoints &&
        lhs.threshold == rhs.threshold &&
        lhs.normalAirPodsAngle == rhs.normalAirPodsAngle &&
        lhs.currentPitch == rhs.currentPitch &&
        lhs.poorPostureDuration == rhs.poorPostureDuration &&
        lhs.postureScorePercent == rhs.postureScorePercent &&
        lhs.totalSessionTime == rhs.totalSessionTime &&
        lhs.screenWidth == rhs.screenWidth &&
        lhs.colorScheme == rhs.colorScheme &&
        lhs.isAnimatingLogo == rhs.isAnimatingLogo
    }
    
    @State private var cachedDataPoints: [Double] = []
    @State private var cachedNormalizedData: [CGFloat] = []
    @State private var viewAppeared = false
    
    private var effectiveNormalizedData: [CGFloat] {
        if dataPoints != cachedDataPoints {
            cachedDataPoints = dataPoints
            cachedNormalizedData = computeNormalizedData()
        }
        return cachedNormalizedData.isEmpty ? computeNormalizedData() : cachedNormalizedData
    }
    
    private var lineColor: Color {
        let adjustedPitch = currentPitch - normalAirPodsAngle
        return adjustedPitch < threshold ? PostureColors.poor : PostureColors.good
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    private var graphBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.1) : Color.gray.opacity(0.08)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    private var secondaryTextColor: Color {
        SettingsColors.secondaryText(for: colorScheme)
    }
    
    public init(dataPoints: [Double], currentPitch: Double, poorPostureDuration: TimeInterval, postureScorePercent: Int, totalSessionTime: TimeInterval, screenWidth: CGFloat = 800, threshold: Double = -22.0, normalAirPodsAngle: Double = 0.0, colorScheme: ColorScheme = .dark, isAnimatingLogo: Bool = false) {
        self.dataPoints = dataPoints
        self.currentPitch = currentPitch
        self.poorPostureDuration = poorPostureDuration
        self.postureScorePercent = postureScorePercent
        self.totalSessionTime = totalSessionTime
        self.screenWidth = screenWidth
        self.threshold = threshold
        self.normalAirPodsAngle = normalAirPodsAngle
        self.colorScheme = colorScheme
        self.isAnimatingLogo = isAnimatingLogo
    }
    
    private var graphHeight: CGFloat = 120
    private var graphWidth: CGFloat { screenWidth - 74 }
    
    private var normalizedData: [CGFloat] {
        if dataPoints != cachedDataPoints {
            cachedDataPoints = dataPoints
            cachedNormalizedData = computeNormalizedData()
        }
        return cachedNormalizedData.isEmpty ? computeNormalizedData() : cachedNormalizedData
    }
    
    private func computeNormalizedData() -> [CGFloat] {
        guard !dataPoints.isEmpty else { return [] }

        let adjustedDataPoints = dataPoints.map { $0 - normalAirPodsAngle }
        
        let minValue = min(threshold - 10, adjustedDataPoints.min() ?? threshold - 10)
        let maxValue = max(10, adjustedDataPoints.max() ?? 10)
        let range = maxValue - minValue
        
        return adjustedDataPoints.map { point in
            let normalized = (point - minValue) / range
            return (1 - normalized) * graphHeight
        }
    }
    
    private var thresholdY: CGFloat {
        let minValue = min(threshold - 10, dataPoints.min() ?? threshold - 10)
        let maxValue = max(10, dataPoints.max() ?? 10)
        let range = maxValue - minValue
        let normalizedThreshold = (threshold - minValue) / range
        return (1 - normalizedThreshold) * graphHeight
    }
    
    public var body: some View {
        VStack(alignment: .center, spacing: 8) {
            VStack(spacing: 12) {
                HStack {
                    Text("Live Session Timer")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colorScheme == .dark ? [
                                    Color.white,
                                    Color.white.opacity(0.95)
                                ] : [
                                    Color.black,
                                    Color.black.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Spacer()
                }

                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.6, blue: 1.0),
                                    Color(red: 0.0, green: 0.5, blue: 0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(String(format: "%02d:%02d:%02d",
                               Int(totalSessionTime) / 3600,
                               Int(totalSessionTime) % 3600 / 60,
                               Int(totalSessionTime) % 60))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colorScheme == .dark ? [
                                    Color.white,
                                    Color.white.opacity(0.9)
                                ] : [
                                    Color.black,
                                    Color.black.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Spacer()

                    Text("Active Session")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.6, blue: 1.0).opacity(0.8),
                                    Color(red: 0.0, green: 0.5, blue: 0.9).opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(1.05)
                }

                HStack {
                    Image(systemName: currentPitch < threshold ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: currentPitch < threshold ? [
                                    PostureColors.poor,
                                    Color(red: 0.95, green: 0.25, blue: 0.0)
                                ] : [
                                    PostureColors.good,
                                    Color(red: 0.0, green: 0.7, blue: 0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(currentPitch < threshold ?
                         String(format: "Poor: %02d:%02d since good posture",
                                Int(poorPostureDuration) / 60,
                                Int(poorPostureDuration) % 60) :
                         "Good posture maintained")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: currentPitch < threshold ? [
                                    PostureColors.poor,
                                    Color(red: 0.95, green: 0.25, blue: 0.0)
                                ] : [
                                    PostureColors.good,
                                    Color(red: 0.0, green: 0.7, blue: 0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Spacer()

                    Text("(\(postureScorePercent)%)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: currentPitch < threshold ? [
                                    PostureColors.poor,
                                    Color(red: 0.95, green: 0.25, blue: 0.0)
                                ] : [
                                    PostureColors.good,
                                    Color(red: 0.0, green: 0.7, blue: 0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.vertical, 4)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.4, blue: 1.0).opacity(0.05),
                                Color(red: 0.0, green: 0.2, blue: 0.8).opacity(0.02),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .opacity(0.7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color.black.opacity(0.25),
                                lineWidth: 1.5
                            )
                    )

                Path { path in
                    path.move(to: CGPoint(x: 0, y: thresholdY))
                    path.addLine(to: CGPoint(x: graphWidth, y: thresholdY))
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.8),
                            Color.orange.opacity(0.6),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )

                if normalizedData.count > 1 {
                    Path { path in
                        let step = graphWidth / CGFloat(normalizedData.count - 1)
                        path.move(to: CGPoint(x: 0, y: normalizedData[0]))

                        for i in 1..<normalizedData.count {
                            path.addLine(to: CGPoint(x: step * CGFloat(i), y: normalizedData[i]))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                lineColor.opacity(0.8),
                                lineColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .shadow(
                        color: lineColor.opacity(0.8),
                        radius: currentPitch < threshold ? 15 : 8,
                        x: 0,
                        y: 0
                    )
                    .shadow(
                        color: Color.white.opacity(0.6),
                        radius: currentPitch < threshold ? 8 : 4,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentPitch)

                    Path { path in
                        let step = graphWidth / CGFloat(normalizedData.count - 1)
                        path.move(to: CGPoint(x: 0, y: thresholdY))

                        for i in 0..<normalizedData.count {
                            let y = min(normalizedData[i], thresholdY)
                            path.addLine(to: CGPoint(x: step * CGFloat(i), y: y))
                        }

                        path.addLine(to: CGPoint(x: graphWidth, y: thresholdY))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                PostureColors.good.opacity(0.3),
                                Color(red: 0.0, green: 0.6, blue: 0.3).opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.6)
                }

                if !normalizedData.isEmpty {
                    let lastX = graphWidth - 4
                    let lastY = normalizedData.last ?? 0

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white,
                                        Color(red: 0.0, green: 0.6, blue: 1.0)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 6
                                )
                            )
                            .frame(width: 12, height: 12)
                            .shadow(color: Color.white.opacity(0.8), radius: 8, x: 0, y: 0)
                            .shadow(color: Color(red: 0.0, green: 0.6, blue: 1.0).opacity(0.6), radius: 12, x: 0, y: 0)
                            .scaleEffect(isAnimatingLogo ? 1.3 : 1.0)
                    }
                    .position(x: lastX, y: lastY)
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.7),
                        value: isAnimatingLogo
                    )
                }
            }
            .frame(width: graphWidth, height: graphHeight)
            .padding(.vertical, 12)

            HStack {
                Text("Good")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                PostureColors.good,
                                Color(red: 0.0, green: 0.7, blue: 0.35)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Spacer()
                Text("Poor")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                PostureColors.poor,
                                Color(red: 0.95, green: 0.25, blue: 0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.2, blue: 0.6).opacity(0.1),
                            Color(red: 0.0, green: 0.15, blue: 0.4).opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            Color.black.opacity(0.25),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color(red: 0.0, green: 0.4, blue: 1.0).opacity(0.15), radius: 6, x: 0, y: 3)
        .shadow(color: Color(red: 0.0, green: 0.4, blue: 1.0).opacity(0.1), radius: 2, x: 0, y: 1)
        .shadow(
            color: isAnimatingLogo ? .white.opacity(0.25) : .clear,
            radius: isAnimatingLogo ? 4 : 0,
            x: isAnimatingLogo ? 0 : 0.5,
            y: isAnimatingLogo ? 0 : 1
        )
        .shadow(
            color: Color(red: 0.0, green: 0.4, blue: 1.0).opacity(isAnimatingLogo ? 0.15 : 0),
            radius: isAnimatingLogo ? 8 : 0,
            x: 0,
            y: 0
        )
        .scaleEffect(isAnimatingLogo ? 1.02 : 1.0)
        .animation(
            .spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0.3),
            value: isAnimatingLogo
        )
        .onAppear {
            viewAppeared = true
        }
    }
}
