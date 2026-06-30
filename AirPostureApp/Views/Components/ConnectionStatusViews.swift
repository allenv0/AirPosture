import SwiftUI

struct ConnectionStatusBanner: View, Equatable {
    let isInGracePeriod: Bool
    let connectionStatus: String
    
    static func == (lhs: ConnectionStatusBanner, rhs: ConnectionStatusBanner) -> Bool {
        lhs.isInGracePeriod == rhs.isInGracePeriod &&
        lhs.connectionStatus == rhs.connectionStatus
    }
    
    var body: some View {
        HStack {
            Image(systemName: isInGracePeriod ? "bluetooth.slash" : "checkmark.circle.fill")
                .foregroundColor(isInGracePeriod ? .orange : .green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isInGracePeriod ? "Bluetooth Connection Lost" : "Session Resumed")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isInGracePeriod ? .orange : .green)
                
                Text(connectionStatus)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isInGracePeriod ? Color.orange : Color.green, lineWidth: 1)
                        .opacity(0.3)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isInGracePeriod ? "Bluetooth connection lost" : "Session resumed")
        .accessibilityValue(connectionStatus)
    }
}

struct ConnectedDeviceInfoView: View, Equatable {
    let isConnected: Bool
    let hasMotionCapability: Bool
    let connectedDeviceName: String
    let airPodsModel: AirPodsModel
    let colorScheme: ColorScheme?
    
    static func == (lhs: ConnectedDeviceInfoView, rhs: ConnectedDeviceInfoView) -> Bool {
        lhs.isConnected == rhs.isConnected &&
        lhs.hasMotionCapability == rhs.hasMotionCapability &&
        lhs.connectedDeviceName == rhs.connectedDeviceName &&
        lhs.airPodsModel == rhs.airPodsModel &&
        lhs.colorScheme == rhs.colorScheme
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var statusColor: Color {
        hasMotionCapability ? .green : .orange
    }
    
    private var statusIcon: String {
        hasMotionCapability ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }
    
    private var statusText: String {
        hasMotionCapability ? "Connected" : "Not Supported"
    }
    
    private var deviceText: String {
        // Prefer the detected model name ("AirPods Pro", "AirPods 3", etc.)
        // Fall back to the raw device name (e.g. "Allen's AirPods Pro") if available,
        // or a generic placeholder.
        let modelName = airPodsModel.rawValue
        if airPodsModel != .unknown {
            return modelName
        }
        if hasMotionCapability {
            return connectedDeviceName.isEmpty ? "AirPods" : connectedDeviceName
        }
        return "AirPods 1/2 (Limited)"
    }
    
    private var deviceSubtext: String {
        hasMotionCapability ? "Motion tracking active" : "No motion sensors"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [statusColor.opacity(0.15), statusColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: hasMotionCapability ? "airpods" : "airpods")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [statusColor, statusColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                    
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                }
                
                Text(deviceText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(deviceSubtext)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if hasMotionCapability {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(cardBackgroundColor)
                .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(statusColor.opacity(0.2), lineWidth: 3)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AirPods status")
        .accessibilityValue("\(statusText). \(deviceText). \(deviceSubtext).")
    }
}

struct ConnectionAnimationView: View {
    let startButtonState: StartButtonState
    @State private var isPulsing = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            switch startButtonState {
            case .connecting, .error:
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                    .frame(width: 70, height: 70)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
                
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5).delay(0.3).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.5), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
                
            case .retrying:
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 3)
                    .frame(width: 70, height: 70)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
                
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.orange)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
                
            case .success:
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.green)
                }
                
            case .idle:
                EmptyView()
            }
        }
        .onAppear {
            if startButtonState == .connecting || startButtonState == .error || startButtonState == .retrying {
                isPulsing = true
                rotationAngle = 360
            }
        }
        .onChange(of: startButtonState) { newState in
            if newState == .connecting || newState == .error || newState == .retrying {
                isPulsing = true
                rotationAngle = 360
            } else {
                isPulsing = false
                rotationAngle = 0
            }
        }
        .accessibilityHidden(true)
    }
}
