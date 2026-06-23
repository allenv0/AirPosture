import SwiftUI

struct PulseEffect: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.43 : 1.0)
            .animation(isActive ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: isActive)
    }
}
