import SwiftUI

struct BackgroundTrackingStatusView: View {
    @ObservedObject private var backgroundTaskManager = BackgroundTaskManager.shared
    @ObservedObject private var audioBackgroundManager = AudioBackgroundManager.shared
    @ObservedObject private var enhancedBackgroundManager = EnhancedBackgroundManager.shared
    @State private var showingBackgroundInfo = false
    
    var body: some View {
        // Background Tracking Status Header
        HStack {
            Image(systemName: backgroundTaskManager.isBackgroundRefreshEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(backgroundTaskManager.isBackgroundRefreshEnabled ? .green : .orange)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Background Tracking")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(backgroundStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                showingBackgroundInfo = true
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            .accessibilityLabel("Background tracking information")
            .accessibilityHint("Opens detailed information about background tracking")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .sheet(isPresented: $showingBackgroundInfo) {
            BackgroundTrackingInfoSheet()
        }
        .onAppear {
            backgroundTaskManager.checkBackgroundRefreshStatus()
        }
    }
    
    private var backgroundStatusText: String {
        if enhancedBackgroundManager.isBackgroundTrackingActive {
            return "Active - Enhanced background tracking"
        } else if audioBackgroundManager.isAudioSessionActive {
            return "Ready - Audio session configured"
        } else {
            return "Development mode - Ready for background"
        }
    }
    
    private var backgroundActivityView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Background Tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(enhancedBackgroundManager.backgroundTaskCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(enhancedBackgroundManager.isBackgroundTrackingActive ? .green : .primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(enhancedBackgroundManager.getBackgroundStatus())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            // Activity Indicator
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(activityIndicatorColor(for: index))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.6).delay(Double(index) * 0.1), value: backgroundTaskManager.backgroundRefreshCount)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
        )
    }
    
    private var lastRefreshText: String {
        guard let lastRefresh = backgroundTaskManager.lastBackgroundRefresh else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastRefresh, relativeTo: Date())
    }
    
    private func activityIndicatorColor(for index: Int) -> Color {
        let isActive = (backgroundTaskManager.backgroundRefreshCount % 5) > index
        return isActive ? .green : .gray.opacity(0.3)
    }
}

struct BackgroundTrackingInfoSheet: View {
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background Tracking")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Keep monitoring your posture even when using other apps")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Status Section
                    statusSection

                    // Background Tasks Section
                    backgroundTasksSection

                    // How It Works Section
                    howItWorksSection
                    
                    // Settings Instructions
                    if !backgroundTaskManager.isBackgroundRefreshEnabled {
                        settingsInstructionsSection
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Status")
                .font(.headline)
            
            HStack {
                Image(systemName: backgroundTaskManager.isBackgroundRefreshEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(backgroundTaskManager.isBackgroundRefreshEnabled ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Background App Refresh")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(backgroundTaskManager.getBackgroundRefreshStatusDescription())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }

    private var backgroundTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background Tasks")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(EnhancedBackgroundManager.shared.backgroundTaskCount)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(EnhancedBackgroundManager.shared.isBackgroundTrackingActive ? .green : .primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(EnhancedBackgroundManager.shared.getBackgroundStatus())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Activity Indicator
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(activityIndicatorColor(for: index))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.6).delay(Double(index) * 0.1), value: backgroundTaskManager.backgroundRefreshCount)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(
                    icon: "clock.fill",
                    title: "Extended Tracking",
                    description: "Continues monitoring your posture for longer periods when you switch to other apps"
                )
                
                FeatureRow(
                    icon: "arrow.clockwise",
                    title: "Periodic Refresh",
                    description: "Automatically wakes up to collect motion data and update your session"
                )
                
                FeatureRow(
                    icon: "bell.fill",
                    title: "Smart Notifications",
                    description: "Sends posture alerts even when the app is in the background"
                )
            }
        }
    }
    
    private var settingsInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable Background Tracking")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("To enable full background tracking:")
                    .font(.body)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Open Settings app")
                    Text("2. Go to General → Background App Refresh")
                    Text("3. Enable Background App Refresh")
                    Text("4. Find AirPosture and enable it")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 16)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func activityIndicatorColor(for index: Int) -> Color {
        let isActive = (backgroundTaskManager.backgroundRefreshCount % 5) > index
        return isActive ? .green : .gray.opacity(0.3)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BackgroundTrackingStatusView()
}
