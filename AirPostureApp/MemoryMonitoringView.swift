import SwiftUI

/// Debug view for monitoring memory usage and performance
struct MemoryMonitoringView: View {
    let colorScheme: ColorScheme
    
    @State private var memoryMonitor: MemoryPressureMonitor? = nil
    @State private var timerTracker: TimerResourceTracker? = nil
    @State private var backgroundTaskTracker: BackgroundTaskTracker? = nil
    @State private var memoryResponder: MemoryPressureResponder? = nil
    
    @State private var showDetailedReport = false
    @State private var detailedReport = ""
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .secondary : Color.gray
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Memory Monitoring")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(primaryTextColor)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    // Memory Pressure Card
                    if let memoryMonitor = memoryMonitor {
                        MemoryPressureCard(
                            colorScheme: colorScheme,
                            memoryMonitor: memoryMonitor
                        )
                    }
                    
                    // Timer Tracking Card
                    if let timerTracker = timerTracker {
                        TimerTrackingCard(
                            colorScheme: colorScheme,
                            timerTracker: timerTracker
                        )
                    }
                    
                    // Background Task Card
                    if let backgroundTaskTracker = backgroundTaskTracker {
                        BackgroundTaskCard(
                            colorScheme: colorScheme,
                            backgroundTaskTracker: backgroundTaskTracker
                        )
                    }
                    
                    // Memory Degradation Card
                    if let memoryResponder = memoryResponder {
                        MemoryDegradationCard(
                            colorScheme: colorScheme,
                            memoryResponder: memoryResponder
                        )
                    }
                    
                    // Actions Card
                    MemoryActionsCard(
                        colorScheme: colorScheme,
                        onGenerateReport: generateDetailedReport,
                        onForceCleanup: performForceCleanup,
                        onForceRecovery: forceRecovery
                    )
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .onAppear {
            // Initialize memory management components
            if memoryMonitor == nil {
                memoryMonitor = MemoryPressureMonitor.shared
            }
            if timerTracker == nil {
                timerTracker = TimerResourceTracker.shared
            }
            if backgroundTaskTracker == nil {
                backgroundTaskTracker = BackgroundTaskTracker.shared
            }
            if memoryResponder == nil {
                memoryResponder = MemoryPressureResponder.shared
            }
        }
        .sheet(isPresented: $showDetailedReport) {
            MemoryReportView(report: detailedReport, colorScheme: colorScheme)
        }
    }
    
    private func generateDetailedReport() {
        let motionManager = HeadphoneMotionManager.shared
        detailedReport = motionManager.getMemoryReport()
        showDetailedReport = true
    }
    
    private func performForceCleanup() {
        HeadphoneMotionManager.shared.performMemoryCleanup()
    }
    
    private func forceRecovery() {
        memoryResponder?.forceRecovery()
    }
}

// MARK: - Memory Pressure Card
struct MemoryPressureCard: View {
    let colorScheme: ColorScheme
    @ObservedObject var memoryMonitor: MemoryPressureMonitor
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .secondary : Color.gray
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "memorychip")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color(memoryMonitor.currentPressureLevel.color))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(memoryMonitor.currentPressureLevel.color).opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory Pressure")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    Text(memoryMonitor.currentPressureLevel.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(memoryMonitor.currentPressureLevel.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(memoryMonitor.currentPressureLevel.color))
                    
                    if memoryMonitor.memoryWarningCount > 0 {
                        Text("\(memoryMonitor.memoryWarningCount) warnings")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
            
            // Memory usage details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Usage")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                    
                    Text(formatBytes(memoryMonitor.currentMemoryUsage))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Peak Usage")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                    
                    Text(formatBytes(memoryMonitor.peakMemoryUsage))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Timer Tracking Card
struct TimerTrackingCard: View {
    let colorScheme: ColorScheme
    @ObservedObject var timerTracker: TimerResourceTracker
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .secondary : Color.gray
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "timer")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timer Resources")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    Text("Active timer monitoring and leak detection")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(timerTracker.activeTimerCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text("active")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Created")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                    
                    Text("\(timerTracker.totalTimersCreated)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Memory Usage")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                    
                    Text(formatBytes(timerTracker.estimatedMemoryUsage))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Suspected Leaks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                    
                    Text("\(timerTracker.suspectedLeaks.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(timerTracker.suspectedLeaks.isEmpty ? primaryTextColor : .red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Background Task Card
struct BackgroundTaskCard: View {
    let colorScheme: ColorScheme
    @ObservedObject var backgroundTaskTracker: BackgroundTaskTracker
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .secondary : Color.gray
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "square.stack.3d.down.right")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.green)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.green.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Background Tasks")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    Text("Background task lifecycle tracking")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(backgroundTaskTracker.activeTaskCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("active")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BG Time Left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                    
                    Text("\(String(format: "%.1f", backgroundTaskTracker.backgroundTimeRemaining))s")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Suspected Leaks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                    
                    Text("\(backgroundTaskTracker.suspectedLeaks.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(backgroundTaskTracker.suspectedLeaks.isEmpty ? primaryTextColor : .red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Memory Degradation Card
struct MemoryDegradationCard: View {
    let colorScheme: ColorScheme
    @ObservedObject var memoryResponder: MemoryPressureResponder
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .primary : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .secondary : Color.gray
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: memoryResponder.isEmergencyModeActive ? "exclamationmark.triangle.fill" : "gauge")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color(memoryResponder.currentDegradationLevel.color))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(memoryResponder.currentDegradationLevel.color).opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Feature Degradation")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    Text(memoryResponder.currentDegradationLevel.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(memoryResponder.currentDegradationLevel.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(memoryResponder.currentDegradationLevel.color))
                    
                    if memoryResponder.isEmergencyModeActive {
                        Text("EMERGENCY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
            }
            
            if !memoryResponder.degradedFeatures.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Degraded Features:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryTextColor)
                    
                    ForEach(Array(memoryResponder.degradedFeatures.prefix(3)), id: \.self) { feature in
                        HStack {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            
                            Text(feature.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                            
                            Spacer()
                        }
                    }
                    
                    if memoryResponder.degradedFeatures.count > 3 {
                        Text("... and \(memoryResponder.degradedFeatures.count - 3) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Memory Actions Card
struct MemoryActionsCard: View {
    let colorScheme: ColorScheme
    let onGenerateReport: () -> Void
    let onForceCleanup: () -> Void
    let onForceRecovery: () -> Void
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Memory Actions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .primary : .black)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                Button(action: onGenerateReport) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Generate Detailed Report")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: onForceCleanup) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Force Memory Cleanup")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: onForceRecovery) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Force Feature Recovery")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: cardShadowColor, radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Memory Report View
struct MemoryReportView: View {
    let report: String
    let colorScheme: ColorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(report)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(colorScheme == .dark ? .primary : .black)
                        .padding()
                }
            }
            .navigationTitle("Memory Report")
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
}