import SwiftUI
import ARKit
import os

struct StretchTrackingView: View {
    @StateObject private var tracker = StretchTracker.shared
    @State private var airPods = HeadphoneMotionManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isARReady = false
    @State private var arSessionManager = ARSessionManager()
    var onDismiss: (() -> Void)?
    
    var body: some View {
        ZStack {
            if ARSessionManager.isSupported {
                if isARReady {
                    ARViewContainer(tracker: tracker)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    loadingView
                }
            } else {
                notSupportedView
            }
            
            VStack {
                topBar
                Spacer()
                metricsOverlay
                controlPanel
            }
            .padding()
            
            if tracker.showBodyWarning {
                bodyWarningOverlay
            }
        }
        .onAppear {
            Logger.ui.debug("StretchTrackingView: onAppear")
            tracker.start()
            isARReady = true
        }
        .onDisappear {
            Logger.ui.debug("StretchTrackingView: onDisappear - Cleaning up AR session")
            isARReady = false
            tracker.stop()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Initializing AR...")
                .font(.headline)
        }
    }
    
    private var notSupportedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("AR Body Tracking Not Supported")
                .font(.title2.bold())
            
            Text("This device doesn't support body tracking. You'll need an iPhone with A12 chip or later.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            if let onDismiss = onDismiss {
                Button("Go Back") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tracker.currentStretch.rawValue)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text(tracker.trackingStatus)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.leading, 4)
            
            Spacer()
            
            if airPods.isDeviceConnected {
                HStack(spacing: 4) {
                    Image(systemName: "airpodspro")
                        .font(.caption)
                    Text("AirPods")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var metricsOverlay: some View {
        VStack(spacing: 16) {
            Text("\(tracker.repCounter.currentReps)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("reps")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
            
            RepProgressRing(progress: tracker.repCounter.holdProgress)
                .frame(width: 100, height: 100)
            
            Text(tracker.stretchState.feedbackMessage)
                .font(.headline)
                .foregroundStyle(tracker.stretchState.phase == .holding ? .green : .white)
                .animation(.easeInOut(duration: 0.2), value: tracker.stretchState.phase)
            
            HStack {
                AngleIndicator(angle: tracker.currentAngle, target: tracker.currentStretch.targetAngle)
                    .frame(width: 60, height: 60)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
    
    private var controlPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StretchType.allCases) { stretch in
                    StretchTypeButton(
                        stretch: stretch,
                        isSelected: tracker.currentStretch == stretch,
                        action: {
                            tracker.switchStretch(stretch)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var bodyWarningOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "figure.stand")
                    .font(.title2)
                Text("Step into the camera view")
                    .font(.headline)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.bottom, 200)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: tracker.showBodyWarning)
    }
}

struct StretchTypeButton: View {
    let stretch: StretchType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: stretch.icon)
                    .font(.title2)
                Text(stretch.shortName)
                    .font(.caption2)
            }
            .frame(width: 70, height: 70)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.3))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RepProgressRing: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progress >= 1.0 ? Color.green : Color.blue,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)
            
            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
            }
        }
    }
}

struct AngleIndicator: View {
    let angle: Float
    let target: Float
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
            
            let diff = angle - target
            let normalized = min(max(diff / 30, -1), 1)
            
            Circle()
                .trim(from: 0.5, to: 0.5 + CGFloat(normalized) * 0.5)
                .stroke(
                    abs(diff) < 10 ? Color.green : Color.orange,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 0) {
                Text("\(Int(angle))°")
                    .font(.caption.bold())
                Text("target: \(Int(target))°")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
