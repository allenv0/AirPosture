#if os(iOS)
import UIKit
#endif
import SwiftUI

struct PercentageCircle: View, Equatable {
    let percentage: Int
    let size: CGFloat
    let title: String
    let isPad: Bool
    let shouldAnimate: Bool
    let colorScheme: ColorScheme
    let isAnimatingLogo: Bool
    
    static func == (lhs: PercentageCircle, rhs: PercentageCircle) -> Bool {
        lhs.percentage == rhs.percentage &&
        lhs.size == rhs.size &&
        lhs.title == rhs.title &&
        lhs.isPad == rhs.isPad &&
        lhs.shouldAnimate == rhs.shouldAnimate &&
        lhs.colorScheme == rhs.colorScheme &&
        lhs.isAnimatingLogo == rhs.isAnimatingLogo
    }
    
    @State private var animatedPercentage: Double = 0
    @State private var animatedCounterValue: Int = 0
    @State private var isAnimating = false
    @State private var hasAnimated = false
    @State private var animationTimer: Timer?
    @State private var delayedTasks = DelayedTaskBag()
    @State private var viewAppeared = false
    
    init(percentage: Int, size: CGFloat, title: String, isPad: Bool, shouldAnimate: Bool = false, colorScheme: ColorScheme = .dark, isAnimatingLogo: Bool = false) {
        self.percentage = percentage
        self.size = size
        self.title = title
        self.isPad = isPad
        self.shouldAnimate = shouldAnimate
        self.colorScheme = colorScheme
        self.isAnimatingLogo = isAnimatingLogo
    }
    
    private var effectiveShouldAnimate: Bool {
        viewAppeared && shouldAnimate && !hasAnimated
    }
    
    private var color: Color {
        if percentage >= 60 {
            return PostureColors.good
        } else if percentage >= 40 {
            return PostureColors.warning
        } else {
            return PostureColors.poor
        }
    }
    
    private var backgroundStrokeColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.15)
    }
    
    private var titleColor: Color {
        colorScheme == .dark ? .secondary : Color.gray
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.1),
                            color.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    color.opacity(0.4),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            Color.black.opacity(0.25),
                            lineWidth: 1.5
                        )
                )
                .frame(width: size, height: size)

            Circle()
                .stroke(
                    backgroundStrokeColor,
                    style: StrokeStyle(lineWidth: 14.4, lineCap: .round)
                )
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: shouldAnimate ? (animatedPercentage / 100.0) : (Double(percentage) / 100.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 14.4, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: (shouldAnimate && isAnimating) ? color.opacity(0.6) : color.opacity(colorScheme == .dark ? 0.3 : 0.2),
                    radius: (shouldAnimate && isAnimating) ? 15 : (colorScheme == .dark ? 8 : 4),
                    x: 0,
                    y: 0
                )
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: shouldAnimate ? animatedPercentage : Double(percentage))

            VStack(spacing: 2) {
                Text("\(shouldAnimate ? animatedCounterValue : percentage)%")
                    .font(.system(size: isPad ? 30 : 24, weight: .bold, design: .rounded))
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
                    .scaleEffect((shouldAnimate && isAnimating) ? 1.1 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)

                Text(title)
                    .font(.system(size: isPad ? 13 : 11, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark ? [
                                Color.white.opacity(0.9),
                                Color.white.opacity(0.7)
                            ] : [
                                Color.black.opacity(0.7),
                                Color.black.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .shadow(color: color.opacity(0.15), radius: 4, x: 0, y: 2)
        .shadow(color: color.opacity(0.1), radius: 1, x: 0, y: 0.5)
        .scaleEffect((shouldAnimate && isAnimating) ? 1.05 : 1.0)
        .scaleEffect(isAnimatingLogo ? 1.02 : 1.0)
        .shadow(
            color: isAnimatingLogo ? .white.opacity(0.25) : .clear,
            radius: isAnimatingLogo ? 3 : 0,
            x: isAnimatingLogo ? 0 : 0.5,
            y: isAnimatingLogo ? 0 : 1
        )
        .shadow(
            color: color.opacity(isAnimatingLogo ? 0.15 : 0),
            radius: isAnimatingLogo ? 5 : 0,
            x: 0,
            y: 0
        )
        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: isAnimating)
        .animation(
            .spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0.3),
            value: isAnimatingLogo
        )
        .onAppear {
            viewAppeared = true
            if shouldAnimate && percentage > 0 && !hasAnimated {
                startAnimation()
            }
        }
        .onChange(of: percentage) { oldValue, newValue in
            if shouldAnimate && oldValue != newValue && newValue > 0 && viewAppeared {
                hasAnimated = false
                animatedPercentage = 0
                animatedCounterValue = 0
                startAnimation()
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
            delayedTasks.cancelAll()
            viewAppeared = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(shouldAnimate ? animatedCounterValue : percentage)%")
    }
    
    private func startAnimation() {
        guard shouldAnimate && !hasAnimated && percentage > 0 else { return }
        
        animationTimer?.invalidate()
        
        #if os(iOS)
        HapticManager.shared.impact(style: .medium)
        #endif
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            isAnimating = true
        }
        
        withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
            animatedPercentage = Double(percentage)
        }
        
        let animationDuration: Double = 1.2
        let steps = max(percentage, 30)
        let stepDuration = animationDuration / Double(steps)

        var currentStep = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let easedProgress = easeOutCubic(progress)
            animatedCounterValue = Int(easedProgress * Double(percentage))

            if currentStep >= steps {
                timer.invalidate()
                animationTimer = nil
                animatedCounterValue = percentage
                
                #if os(iOS)
                HapticManager.shared.impact(style: .light)
                #endif
                
                delayedTasks.schedule(id: "percentageAnimationCompletion", after: 0.2) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        isAnimating = false
                    }
                }
                
                hasAnimated = true
            }
        }
    }
    
    private func easeOutCubic(_ t: Double) -> Double {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }
}
