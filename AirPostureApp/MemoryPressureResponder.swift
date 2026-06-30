import Foundation
import UIKit
import os.log

/// Responds to memory pressure by implementing feature degradation strategies
@MainActor
class MemoryPressureResponder: ObservableObject, MemoryPressureResponderProtocol {
    static let shared = MemoryPressureResponder()
    
    // MARK: - Published Properties
    @Published private(set) var currentDegradationLevel: DegradationLevel = .none
    @Published private(set) var isEmergencyModeActive: Bool = false
    @Published private(set) var degradedFeatures: Set<DegradedFeature> = []
    @Published private(set) var lastPressureResponse: Date?
    
    // MARK: - Degradation Levels
    enum DegradationLevel: String, CaseIterable {
        case none = "None"
        case light = "Light"
        case moderate = "Moderate"
        case aggressive = "Aggressive"
        
        var description: String {
            switch self {
            case .none:
                return "All features active"
            case .light:
                return "Optimizing performance"
            case .moderate:
                return "Reducing features for stability"
            case .aggressive:
                return "Emergency mode - core features only"
            }
        }
        
        var color: UIColor {
            switch self {
            case .none:
                return .systemGreen
            case .light:
                return .systemYellow
            case .moderate:
                return .systemOrange
            case .aggressive:
                return .systemRed
            }
        }
    }
    
    // MARK: - Degraded Features
    enum DegradedFeature: String, CaseIterable {
        // Motion tracking features
        case pitchHistoryReduced = "Pitch History Reduced"
        case connectionMonitoringSlowed = "Connection Monitoring Slowed"
        case motionUpdateReduced = "Motion Update Frequency Reduced"
        
        // Timer features
        case healthCheckPaused = "Health Check Paused"
        case calibrationPaused = "Calibration Paused"
        case reconnectionSlowed = "Reconnection Slowed"
        
        // Background features
        case backgroundTasksReduced = "Background Tasks Reduced"
        case backgroundAudioDisabled = "Background Audio Disabled"
        case backgroundMonitoringPaused = "Background Monitoring Paused"
        
        // UI features
        case animationsSimplified = "Animations Simplified"
        case uiUpdatesReduced = "UI Updates Reduced"
        case chartsSimplified = "Charts Simplified"
        
        // Advanced features
        case hapticFeedbackDisabled = "Haptic Feedback Disabled"
        case detailedAnalyticsDisabled = "Detailed Analytics Disabled"
        case sessionPaused = "Session Temporarily Paused"
        
        var priority: Int {
            switch self {
            case .pitchHistoryReduced, .animationsSimplified, .chartsSimplified:
                return 1 // Light degradation
            case .connectionMonitoringSlowed, .healthCheckPaused, .uiUpdatesReduced:
                return 2 // Moderate degradation
            case .backgroundTasksReduced, .motionUpdateReduced, .detailedAnalyticsDisabled:
                return 3 // Aggressive degradation
            case .backgroundAudioDisabled, .hapticFeedbackDisabled, .sessionPaused:
                return 4 // Emergency degradation
            default:
                return 2
            }
        }
    }
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.allenleee.AirPosture", category: "MemoryPressureResponder")
    private var degradationHistory: [DegradationEvent] = []
    private let maxHistorySize = 100
    
    // Feature controllers
    private weak var motionManager: HeadphoneMotionManager?
    private weak var backgroundTaskManager: BackgroundTaskManager?
    private weak var audioBackgroundManager: AudioBackgroundManager?
    
    // Original settings (for restoration)
    private var originalSettings = OriginalSettings()
    
    // MARK: - Degradation Event
    struct DegradationEvent {
        let timestamp: Date
        let pressureLevel: MemoryPressureMonitor.MemoryPressureLevel
        let degradationLevel: DegradationLevel
        let featuresAffected: Set<DegradedFeature>
        let memoryUsage: UInt64
    }
    
    // MARK: - Original Settings Storage
    struct OriginalSettings {
        var pitchHistorySize: Int = 50
        var connectionMonitoringInterval: TimeInterval = 0.5
        var motionUpdateInterval: TimeInterval = 1.0
        var maxBackgroundTasks: Int = 3
        var isBackgroundAudioEnabled: Bool = true
        var isHapticFeedbackEnabled: Bool = false
        var isHealthCheckEnabled: Bool = true
    }
    
    // MARK: - Initialization
    private init() {
        // Register with memory pressure monitor
        MemoryPressureMonitor.shared.addPressureResponder(self)
        
        // Store original settings
        storeOriginalSettings()
    }
    
    // MARK: - MemoryPressureResponder Protocol
    func respondToMemoryPressure(_ level: MemoryPressureMonitor.MemoryPressureLevel) {
        lastPressureResponse = Date()
        
        logger.info("🧠 Responding to memory pressure: \(level.rawValue)")
        Logger.memory.info("Responding to memory pressure: \(level.rawValue)")
        
        let newDegradationLevel = mapPressureToDegradation(level)
        
        if newDegradationLevel != currentDegradationLevel {
            applyDegradation(newDegradationLevel)
        }
        
        recordDegradationEvent(level, degradationLevel: newDegradationLevel)
    }
    
    // MARK: - Public Methods
    func setManagers(
        motionManager: HeadphoneMotionManager?,
        backgroundTaskManager: BackgroundTaskManager?,
        audioBackgroundManager: AudioBackgroundManager?
    ) {
        self.motionManager = motionManager
        self.backgroundTaskManager = backgroundTaskManager
        self.audioBackgroundManager = audioBackgroundManager
        
        storeOriginalSettings()
    }
    
    func forceRecovery() {
        logger.info("🔄 Forcing recovery from degraded state")
        Logger.memory.info("Forcing recovery from degraded state")
        
        applyDegradation(.none)
    }
    
    func getDegradationReport() -> String {
        let recentEvents = Array(degradationHistory.suffix(10))
        
        var report = """
        🧠 Memory Pressure Response Report
        =================================
        Current Degradation: \(currentDegradationLevel.rawValue)
        Emergency Mode: \(isEmergencyModeActive)
        Degraded Features: \(degradedFeatures.count)
        Last Response: \(lastPressureResponse?.formatted() ?? "Never")
        
        Active Degradations:
        """
        
        for feature in degradedFeatures.sorted(by: { $0.rawValue < $1.rawValue }) {
            report += "\n  • \(feature.rawValue)"
        }
        
        if !recentEvents.isEmpty {
            report += "\n\nRecent Events:"
            for event in recentEvents {
                let timeAgo = Date().timeIntervalSince(event.timestamp)
                report += "\n  • \(String(format: "%.1f", timeAgo))s ago: \(event.pressureLevel.rawValue) → \(event.degradationLevel.rawValue)"
            }
        }
        
        return report
    }
    
    // MARK: - Private Implementation
    private func mapPressureToDegradation(_ level: MemoryPressureMonitor.MemoryPressureLevel) -> DegradationLevel {
        switch level {
        case .normal:
            return .none
        case .warning:
            return .light
        case .critical:
            return .moderate
        case .emergency:
            return .aggressive
        }
    }
    
    private func applyDegradation(_ level: DegradationLevel) {
        let previousLevel = currentDegradationLevel
        currentDegradationLevel = level
        isEmergencyModeActive = (level == .aggressive)
        
        logger.info("🎯 Applying degradation: \(previousLevel.rawValue) → \(level.rawValue)")
        Logger.memory.info("Applying degradation: \(previousLevel.rawValue) → \(level.rawValue)")
        
        // Clear previous degradations if recovering
        if level.rawValue < previousLevel.rawValue {
            restoreFeatures()
        }
        
        // Apply new degradations
        switch level {
        case .none:
            restoreAllFeatures()
        case .light:
            applyLightDegradation()
        case .moderate:
            applyModerateDegradation()
        case .aggressive:
            applyAggressiveDegradation()
        }
        
        // Notify user if significant degradation
        if level.rawValue > DegradationLevel.light.rawValue {
            notifyUserOfDegradation(level)
        }
    }
    
    private func applyLightDegradation() {
        logger.info("🟡 Applying light degradation")
        Logger.memory.info("Light degradation: Reducing polish, keeping core functionality")
        
        // Reduce pitch history size
        if let motionManager = motionManager {
            // Note: This would require adding a method to HeadphoneMotionManager
            degradedFeatures.insert(.pitchHistoryReduced)
        }
        
        // Simplify animations
        degradedFeatures.insert(.animationsSimplified)
        degradedFeatures.insert(.chartsSimplified)
        
        // Slow down connection monitoring
        degradedFeatures.insert(.connectionMonitoringSlowed)
    }
    
    private func applyModerateDegradation() {
        logger.info("🟠 Applying moderate degradation")
        Logger.memory.warning("Moderate degradation: Reducing features for stability")
        
        // Apply light degradation first
        applyLightDegradation()
        
        // Pause health monitoring
        degradedFeatures.insert(.healthCheckPaused)
        
        // Reduce UI updates
        degradedFeatures.insert(.uiUpdatesReduced)
        
        // Slow down reconnection attempts
        degradedFeatures.insert(.reconnectionSlowed)
        
        // Pause calibration if active
        if let motionManager = motionManager, motionManager.calibrationService.isCalibrating {
            // Note: This would require adding a method to pause calibration
            degradedFeatures.insert(.calibrationPaused)
        }
    }
    
    private func applyAggressiveDegradation() {
        logger.info("🔴 Applying aggressive degradation - Emergency mode")
        Logger.memory.error("Aggressive degradation: Emergency mode - core features only")
        
        // Apply moderate degradation first
        applyModerateDegradation()
        
        // Reduce background tasks
        degradedFeatures.insert(.backgroundTasksReduced)
        
        // Disable background audio
        if let audioManager = audioBackgroundManager {
            audioManager.disableBackgroundAudio()
            degradedFeatures.insert(.backgroundAudioDisabled)
        }
        
        // Disable haptic feedback if enabled
        if let motionManager = motionManager, motionManager.isHapticFeedbackEnabled {
            // Note: This would temporarily disable haptic feedback
            degradedFeatures.insert(.hapticFeedbackDisabled)
        }
        
        // Reduce motion update frequency
        degradedFeatures.insert(.motionUpdateReduced)
        
        // Disable detailed analytics
        degradedFeatures.insert(.detailedAnalyticsDisabled)
        
        // In extreme cases, pause session temporarily
        if degradedFeatures.count > 8 {
            degradedFeatures.insert(.sessionPaused)
        }
    }
    
    private func restoreFeatures() {
        logger.info("🔄 Restoring degraded features")
        Logger.memory.info("Restoring degraded features")
        
        // Restore background audio if it was disabled
        if degradedFeatures.contains(.backgroundAudioDisabled) {
            if let audioManager = audioBackgroundManager {
                audioManager.enableBackgroundAudio()
            }
        }
        
        // Clear degraded features
        degradedFeatures.removeAll()
    }
    
    private func restoreAllFeatures() {
        logger.info("✅ Restoring all features to normal operation")
        Logger.memory.info("Restoring all features to normal operation")
        
        restoreFeatures()
        isEmergencyModeActive = false
    }
    
    private func storeOriginalSettings() {
        // Store original settings for restoration
        // Note: This would require accessing the actual settings from managers
        originalSettings = OriginalSettings()
    }
    
    private func notifyUserOfDegradation(_ level: DegradationLevel) {
        // Post notification for UI to show degradation indicator
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryDegradationChanged"),
            object: nil,
            userInfo: [
                "level": level,
                "description": level.description,
                "features": Array(degradedFeatures)
            ]
        )
    }
    
    private func recordDegradationEvent(_ pressureLevel: MemoryPressureMonitor.MemoryPressureLevel, degradationLevel: DegradationLevel) {
        let memoryUsage = MemoryPressureMonitor.shared.getCurrentMemoryUsage().current
        
        let event = DegradationEvent(
            timestamp: Date(),
            pressureLevel: pressureLevel,
            degradationLevel: degradationLevel,
            featuresAffected: degradedFeatures,
            memoryUsage: memoryUsage
        )
        
        degradationHistory.append(event)
        
        // Limit history size
        if degradationHistory.count > maxHistorySize {
            degradationHistory.removeFirst()
        }
    }
}

