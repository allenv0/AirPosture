import SwiftUI

struct CosmicAuraBackground: View {
    let isAnimating: Bool
    @State private var particleScale: CGFloat = 0.8
    @State private var glowIntensity: Double = 0.3
    @State private var rainbowRotation: Double = 0
    @State private var delayedTasks = DelayedTaskBag()

    var body: some View {
        ZStack {
            baseCircle

            if isAnimating {
                rippleWaves
            }

            glowAura
        }
        .accessibilityHidden(true)
        .onChange(of: isAnimating) { newValue in
            handleAnimationChange(newValue)
        }
        .onDisappear {
            delayedTasks.cancelAll()
        }
    }

    private var baseCircle: some View {
        Circle()
            .fill(rainbowGradient)
            .scaleEffect(isAnimating ? particleScale : 1.0)
            .opacity(isAnimating ? glowIntensity : 0.8)
            .rotationEffect(.degrees(rainbowRotation))
    }

    private var rainbowGradient: RadialGradient {
        let colors = rainbowBaseColors
        return RadialGradient(
            gradient: Gradient(stops: colors),
            center: .center,
            startRadius: 10,
            endRadius: 60
        )
    }

    private var rainbowBaseColors: [Gradient.Stop] {
        return [
            .init(color: Color.white.opacity(0.9), location: 0.0),
            .init(color: Color.red.opacity(0.8), location: 0.15),
            .init(color: Color.orange.opacity(0.8), location: 0.25),
            .init(color: Color.yellow.opacity(0.8), location: 0.35),
            .init(color: Color.green.opacity(0.8), location: 0.45),
            .init(color: Color.blue.opacity(0.8), location: 0.55),
            .init(color: Color.indigo.opacity(0.8), location: 0.65),
            .init(color: Color.purple.opacity(0.8), location: 0.75),
            .init(color: Color.black.opacity(0.1), location: 1.0)
        ]
    }

    private var rippleWaves: some View {
        ForEach(0..<4, id: \.self) { index in
            createRippleWave(index: index)
        }
    }

    private func createRippleWave(index: Int) -> some View {
        let colors = createRippleColors(index: index)
        let scale = 1.0 + CGFloat(index) * 0.25
        let opacity = 0.7 - Double(index) * 0.15
        let duration = 1.0 + Double(index) * 0.15
        let delay = Double(index) * 0.08

        return Circle()
            .stroke(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3
            )
            .scaleEffect(isAnimating ? scale : 0.6)
            .opacity(isAnimating ? opacity : 0)
            .animation(
                .easeOut(duration: duration).delay(delay),
                value: isAnimating
            )
    }

    private func createRippleColors(index: Int) -> [Color] {
        if index == 0 {
            return redStartColors
        } else if index == 1 {
            return orangeStartColors
        } else if index == 2 {
            return yellowStartColors
        } else {
            return greenStartColors
        }
    }

    private var redStartColors: [Color] {
        return [
            Color.red.opacity(0.8),
            Color.orange.opacity(0.8),
            Color.yellow.opacity(0.8),
            Color.green.opacity(0.8),
            Color.blue.opacity(0.8),
            Color.indigo.opacity(0.8),
            Color.purple.opacity(0.8),
            Color.clear
        ]
    }

    private var orangeStartColors: [Color] {
        return [
            Color.orange.opacity(0.8),
            Color.yellow.opacity(0.8),
            Color.green.opacity(0.8),
            Color.blue.opacity(0.8),
            Color.indigo.opacity(0.8),
            Color.purple.opacity(0.8),
            Color.red.opacity(0.8),
            Color.clear
        ]
    }

    private var yellowStartColors: [Color] {
        return [
            Color.yellow.opacity(0.8),
            Color.green.opacity(0.8),
            Color.blue.opacity(0.8),
            Color.indigo.opacity(0.8),
            Color.purple.opacity(0.8),
            Color.red.opacity(0.8),
            Color.orange.opacity(0.8),
            Color.clear
        ]
    }

    private var greenStartColors: [Color] {
        return [
            Color.green.opacity(0.8),
            Color.blue.opacity(0.8),
            Color.indigo.opacity(0.8),
            Color.purple.opacity(0.8),
            Color.red.opacity(0.8),
            Color.orange.opacity(0.8),
            Color.yellow.opacity(0.8),
            Color.clear
        ]
    }

    private var glowAura: some View {
        Circle()
            .fill(glowGradient)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.7 : 0.4)
            .rotationEffect(.degrees(-rainbowRotation))
    }

    private var glowGradient: RadialGradient {
        let colors = glowColors
        let endRadius = isAnimating ? CGFloat(90) : CGFloat(70)

        return RadialGradient(
            gradient: Gradient(colors: colors),
            center: .center,
            startRadius: CGFloat(0),
            endRadius: endRadius
        )
    }

    private var glowColors: [Color] {
        return [
            Color.white.opacity(0.3),
            Color.red.opacity(0.2),
            Color.orange.opacity(0.15),
            Color.yellow.opacity(0.1),
            Color.green.opacity(0.1),
            Color.blue.opacity(0.1),
            Color.indigo.opacity(0.1),
            Color.purple.opacity(0.1),
            Color.clear
        ]
    }

    private func handleAnimationChange(_ newValue: Bool) {
        if newValue {
            startAnimation()
        } else {
            resetAnimation()
        }
    }

    private func startAnimation() {
        withAnimation(.easeOut(duration: 0.8)) {
            particleScale = 1.25
            glowIntensity = 1.0
            rainbowRotation = 180
        }

        delayedTasks.schedule(id: "cosmicAuraFinish", after: 2.0) {
            withAnimation(.easeInOut(duration: 1.0)) {
                particleScale = 1.1
                glowIntensity = 0.9
                rainbowRotation = 360
            }
        }
    }

    private func resetAnimation() {
        withAnimation(.easeInOut(duration: 0.6)) {
            particleScale = 1.0
            glowIntensity = 0.3
            rainbowRotation = 0
        }
    }
}
