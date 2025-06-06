import SwiftUI
import SceneKit
import CoreMotion
import Combine
import AppKit

struct ContentView: View {
    @StateObject private var headphoneMotionManager = HeadphoneMotionManager()
    @State private var connectionAttempts = 0
    @State private var showDebugInfo = false
    
    var body: some View {
        ZStack {
            Color.primary.opacity(0.05)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    if headphoneMotionManager.isDeviceConnected {
                        // Visual head tracker
                        VStack(spacing: 8) {
                            // Head visualization and posture percentage in a centered horizontal stack
                            HStack(alignment: .center, spacing: 60) {
                                // Head Visualization
                                HeadVisualization(
                                    pitch: headphoneMotionManager.pitch,
                                    roll: headphoneMotionManager.roll,
                                    yaw: headphoneMotionManager.yaw,
                                    postureState: headphoneMotionManager.postureState
                                )
                                .frame(width: 176, height: 176)
                                .padding(.trailing, 10)
                                
                                // Poor Posture Percentage Circle
                                VStack {
                                    ZStack {
                                        // Background circle
                                        Circle()
                                            .stroke(
                                                Color.gray.opacity(0.2),
                                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                            )
                                            .frame(width: 154, height: 154)
                                        
                                        // Progress circle
                                        let percentage = Double(headphoneMotionManager.poorPosturePercentage) / 100.0
                                        let color: Color = headphoneMotionManager.poorPosturePercentage >= 40 ? .red : .green
                                        
                                        Circle()
                                            .trim(from: 0, to: percentage)
                                            .stroke(
                                                color,
                                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                            )
                                            .frame(width: 154, height: 154)
                                            .rotationEffect(.degrees(-90))
                                            .animation(.easeInOut(duration: 0.3), value: headphoneMotionManager.poorPosturePercentage)
                                        
                                        // Percentage text
                                        VStack(spacing: 2) {
                                            Text("\(Int(headphoneMotionManager.poorPosturePercentage))%")
                                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                                .foregroundColor(color)
                                            
                                            Text("Poor Posture")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Text("Time in poor posture")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                }
                                .frame(width: 154)
                                .padding(.leading, 10)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 90)
                            .padding(.bottom, 90)
                            
                            PitchGraphView(
                                dataPoints: headphoneMotionManager.pitchHistory,
                                currentPitch: headphoneMotionManager.pitch,
                                poorPostureDuration: headphoneMotionManager.poorPostureDuration,
                                poorPosturePercentage: headphoneMotionManager.poorPosturePercentage
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 20)
                            
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Head Orientation")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                OrientationRow(label: "Pitch", value: headphoneMotionManager.pitch, description: "Up/Down")
                                OrientationRow(label: "Roll", value: headphoneMotionManager.roll, description: "Tilt Left/Right")
                                OrientationRow(label: "Yaw", value: headphoneMotionManager.yaw, description: "Turn Left/Right")
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                            
                            Spacer(minLength: NSScreen.main?.frame.height ?? 800 * 0.1)
                        }
                        
                    } else {
                        Spacer()
                        
                        VStack(spacing: 25) {
                            Image(systemName: "airpodspro")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Waiting for AirPods Pro...")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                connectionAttempts += 1
                                headphoneMotionManager.restart()
                            }) {
                                Text("Retry Connection")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            if showDebugInfo {
                                Text("Connection Status: \(headphoneMotionManager.connectionStatus)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 10)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Debug info footer
                    HStack {
                        if showDebugInfo {
                            Text("Attempts: \(connectionAttempts)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showDebugInfo.toggle()
                        }) {
                            Image(systemName: showDebugInfo ? "info.circle.fill" : "info.circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                }
                .padding(.horizontal, 5)
            }
        }
        .onAppear {
            headphoneMotionManager.start()
        }
        .onDisappear {
            headphoneMotionManager.stop()
        }
    }
}

struct HeadVisualization: View {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let postureState: PostureState
    
    private var isAlertActive: Bool {
        if case .alert = postureState {
            return true
        }
        return false
    }
    
    var body: some View {
        ZStack {
            // Background circle with alert indicator
            Circle()
                .fill(Color.clear)
                .frame(width: 340, height: 240)
                .overlay(
                    Circle()
                        .stroke(
                            pitch < -22 ? Color.red : Color.green,
                            style: StrokeStyle(
                                lineWidth: 8,
                                lineCap: .round
                            )
                        )
                        .opacity(0.7)
                        .animation(.easeInOut(duration: 0.3), value: pitch)
                )
                .shadow(
                    color: (pitch < -22 ? Color.red : Color.green).opacity(0.5),
                    radius: pitch < -22 ? 10 : 5,
                    x: 0,
                    y: 0
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pitch)
            
            // Bear neck image
            Image("bear-neck")
                .resizable()
                .scaledToFit()
                .frame(width: 196, height: 196)
                .foregroundColor(colorForState(postureState))
                .modifier(PulseEffect(isActive: isAlertActive))
                .rotationEffect(.degrees(pitch))
        }
        .padding(20)
    }
    
    private func colorForState(_ state: PostureState) -> Color {
        switch state {
        case .alert:
            return .red
        case .warning:
            return .orange
        default:
            return .blue
        }
    }
}

private struct PulseEffect: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.43 : 1.0)
            .animation(isActive ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: isActive)
    }
}

struct OrientationRow: View {
    let label: String
    let value: Double
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.1f°", value))
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            
            // Progress bar visualization
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    // Value indicator
                    let normalizedValue = ((value + 180) / 360).clamped(to: 0...1)
                    let width = normalizedValue * geometry.size.width
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: max(0, width), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

public struct PitchGraphView: View {
    public let dataPoints: [Double]
    public let threshold: Double = -22.0
    public let currentPitch: Double
    public let poorPostureDuration: TimeInterval
    public let poorPosturePercentage: Int
    
    // Add a computed property to determine line color
    private var lineColor: Color {
        currentPitch < threshold ? .red : .green
    }
    
    // Make initializer public
    public init(dataPoints: [Double], currentPitch: Double, poorPostureDuration: TimeInterval, poorPosturePercentage: Int) {
        self.dataPoints = dataPoints
        self.currentPitch = currentPitch
        self.poorPostureDuration = poorPostureDuration
        self.poorPosturePercentage = poorPosturePercentage
    }
    
    private var graphHeight: CGFloat = 120
    private var graphWidth: CGFloat = (NSScreen.main?.frame.width ?? 800) - 60
    
    private var normalizedData: [CGFloat] {
        guard !dataPoints.isEmpty else { return [] }
        let minValue = min(threshold - 10, dataPoints.min() ?? threshold - 10)
        let maxValue = max(10, dataPoints.max() ?? 10)
        let range = maxValue - minValue
        
        return dataPoints.map { point in
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Poor Posture Timer")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(String(format: "Poor Posture: %02d:%02d", 
                               Int(poorPostureDuration) / 60, 
                               Int(poorPostureDuration) % 60))
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("(\(poorPosturePercentage)% of session)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            ZStack {
                // Graph background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                
                // Threshold line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: thresholdY))
                    path.addLine(to: CGPoint(x: graphWidth, y: thresholdY))
                }
                .stroke(Color.red.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5]))
                
                // Graph line
                if normalizedData.count > 1 {
                    Path { path in
                        let step = graphWidth / CGFloat(normalizedData.count - 1)
                        path.move(to: CGPoint(x: 0, y: normalizedData[0]))
                        
                        for i in 1..<normalizedData.count {
                            path.addLine(to: CGPoint(x: step * CGFloat(i), y: normalizedData[i]))
                        }
                    }
                    .stroke(lineColor, lineWidth: 6) // Increased line width by 300%
                    
                    // Fill below threshold
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
                    .fill(Color.green.opacity(0.2))
                }
                
                // Current pitch indicator
                if !normalizedData.isEmpty {
                    let lastX = graphWidth - 10
                    let lastY = normalizedData.last ?? 0
                    
                    Circle()
                        .fill(Color.blue)  
                        .frame(width: 8, height: 8)
                        .position(x: lastX, y: lastY)
                }
            }
            .frame(height: graphHeight)
            .padding(.vertical, 8)
            
            HStack {
                Text("Good")
                    .font(.caption2)
                    .foregroundColor(.green)
                Spacer()
                Text("Poor")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// PostureState is defined in HeadphoneMotionManager.swift
