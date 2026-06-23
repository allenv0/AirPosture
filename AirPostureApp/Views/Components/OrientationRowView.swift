import SwiftUI

struct OrientationRow: View {
    let label: String
    let value: Double
    let description: String
    let colorScheme: ColorScheme
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    private var secondaryTextColor: Color {
        SettingsColors.secondaryText(for: colorScheme)
    }
    
    private var backgroundBarColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.15)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .fontWeight(.medium)
                    .foregroundColor(primaryTextColor)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(SettingsColors.secondaryText(for: colorScheme))
                
                Spacer()
                
                Text(String(format: "%.1f°", value))
                    .fontWeight(.bold)
                    .foregroundColor(primaryTextColor)
                    .monospacedDigit()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(backgroundBarColor)
                        .frame(height: 6)
                    
                    let normalizedValue = ((value + 180) / 360).clamped(to: 0...1)
                    let width = normalizedValue * geometry.size.width
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: max(0, width), height: 6)
                        .shadow(
                            color: Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3),
                            radius: colorScheme == .dark ? 5 : 3,
                            x: 0,
                            y: 0
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: value)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value))°")
    }
}

fileprivate extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
