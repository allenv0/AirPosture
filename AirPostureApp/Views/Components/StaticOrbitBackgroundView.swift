import SwiftUI

struct StaticOrbitBackground: View {
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                createStaticRing(index: index)
            }
        }
    }

    private func createStaticRing(index: Int) -> some View {
        let colors = getStaticRingColors(index: index)
        let scale = 1.0 + CGFloat(index) * 0.15
        let opacity = 1.0 - Double(index) * 0.05
        let lineWidth = 3.5 - Double(index) * 0.3

        return Circle()
            .stroke(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: lineWidth
            )
            .scaleEffect(scale)
            .opacity(opacity)
    }

    private func getStaticRingColors(index: Int) -> [Color] {
        switch index {
        case 0:
            return [
                Color(red: 1.0, green: 0.25, blue: 0.35),
                Color(red: 1.0, green: 0.45, blue: 0.55),
                Color(red: 1.0, green: 0.55, blue: 0.25),
                Color.clear
            ]
        case 1:
            return [
                Color(red: 1.0, green: 0.58, blue: 0.0),
                Color(red: 1.0, green: 0.85, blue: 0.2),
                Color(red: 1.0, green: 0.35, blue: 0.15),
                Color.clear
            ]
        case 2:
            return [
                Color(red: 0.0, green: 0.85, blue: 0.45),
                Color(red: 0.1, green: 0.92, blue: 0.7),
                Color(red: 0.15, green: 0.75, blue: 0.95),
                Color.clear
            ]
        case 3:
            return [
                Color(red: 0.25, green: 0.55, blue: 1.0),
                Color(red: 0.4, green: 0.8, blue: 1.0),
                Color(red: 0.55, green: 0.35, blue: 0.95),
                Color.clear
            ]
        case 4:
            return [
                Color(red: 0.75, green: 0.35, blue: 0.95),
                Color(red: 0.55, green: 0.4, blue: 0.85),
                Color(red: 1.0, green: 0.35, blue: 0.65),
                Color.clear
            ]
        default:
            return [Color.gray.opacity(0.8), Color.clear]
        }
    }
}
