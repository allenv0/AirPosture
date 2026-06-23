import SwiftUI

struct MinimalProgressBar: View {
    let progress: Double
    let isVisible: Bool
    
    private var progressColor: Color {
        if progress < 0.3 {
            return .orange
        } else if progress < 0.7 {
            return .blue
        } else {
            return .green
        }
    }
    
    var body: some View {
        if isVisible {
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [progressColor.opacity(0.8), progressColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 4)
                
                Text(getStatusText())
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Connection progress")
            .accessibilityValue("\(Int(isVisible ? progress * 100 : 0)) percent")
        }
    }
    
    private func getStatusText() -> String {
        if progress < 0.3 {
            return "Checking AirPods..."
        } else if progress < 0.7 {
            return "Connecting..."
        } else if progress < 1.0 {
            return "Almost ready..."
        } else {
            return "Starting session..."
        }
    }
}
