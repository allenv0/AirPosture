import Foundation
import UIKit
import os

/// Monitors and logs foreground transition performance to detect UI freeze issues
@MainActor
class ForegroundTransitionMonitor: ObservableObject {
    static let shared = ForegroundTransitionMonitor()
    
    // MARK: - Performance Metrics
    @Published private(set) var lastTransitionTime: TimeInterval = 0
    @Published private(set) var averageTransitionTime: TimeInterval = 0
    @Published private(set) var slowTransitionCount: Int = 0
    @Published private(set) var totalTransitions: Int = 0
    
    // MARK: - Thresholds
    private let warningThreshold: TimeInterval = 100 // 100ms
    private let criticalThreshold: TimeInterval = 500 // 500ms
    private let maxHistorySize = 50
    
    // MARK: - History
    private var transitionHistory: [TransitionRecord] = []
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Transition Record
    struct TransitionRecord {
        let timestamp: Date
        let duration: TimeInterval
        let components: [String: TimeInterval]
        let wasSlowTransition: Bool
        
        var description: String {
            let status = wasSlowTransition ? "SLOW" : "FAST"
            return "\(status): \(String(format: "%.1f", duration))ms at \(timestamp)"
        }
    }
    
    // MARK: - Public Methods
    func startTransition(identifier: String = "unknown") -> TransitionTracker {
        return TransitionTracker(monitor: self, identifier: identifier)
    }
    
    func recordTransition(duration: TimeInterval, components: [String: TimeInterval] = [:], identifier: String = "unknown") {
        let record = TransitionRecord(
            timestamp: Date(),
            duration: duration,
            components: components,
            wasSlowTransition: duration > warningThreshold
        )
        
        // Update metrics
        lastTransitionTime = duration
        totalTransitions += 1
        
        if duration > warningThreshold {
            slowTransitionCount += 1
        }
        
        // Add to history
        transitionHistory.append(record)
        if transitionHistory.count > maxHistorySize {
            transitionHistory.removeFirst()
        }
        
        // Calculate average
        let recentTransitions = Array(transitionHistory.suffix(10))
        averageTransitionTime = recentTransitions.reduce(0) { $0 + $1.duration } / Double(recentTransitions.count)
        
        // Log based on severity
        logTransition(record: record, identifier: identifier)
    }
    
    func getPerformanceReport() -> String {
        let slowPercentage = totalTransitions > 0 ? (Double(slowTransitionCount) / Double(totalTransitions)) * 100 : 0
        
        var report = """
        📊 Foreground Transition Performance Report
        ==========================================
        Total Transitions: \(totalTransitions)
        Average Time: \(String(format: "%.1f", averageTransitionTime))ms
        Last Transition: \(String(format: "%.1f", lastTransitionTime))ms
        Slow Transitions: \(slowTransitionCount) (\(String(format: "%.1f", slowPercentage))%)
        
        Recent History:
        """
        
        for record in transitionHistory.suffix(5) {
            report += "\n  • \(record.description)"
            
            if !record.components.isEmpty {
                for (component, time) in record.components.sorted(by: { $0.value > $1.value }) {
                    report += "\n    - \(component): \(String(format: "%.1f", time))ms"
                }
            }
        }
        
        return report
    }
    
    // MARK: - Private Methods
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppForeground() {
        // This is a fallback monitor for any untracked transitions
        Logger.ui.debug("ForegroundTransitionMonitor: App became active")
    }
    
    private func logTransition(record: TransitionRecord, identifier: String) {
        let duration = record.duration
        
        if duration > criticalThreshold {
            Logger.ui.error("CRITICAL: Foreground transition (\(identifier)) took \(String(format: "%.1f", duration))ms")
            Logger.ui.error("Components: \(record.components)")
        } else if duration > warningThreshold {
            Logger.ui.warning("Slow foreground transition (\(identifier)) took \(String(format: "%.1f", duration))ms")
        } else {
            Logger.ui.debug("Fast foreground transition (\(identifier)) completed in \(String(format: "%.1f", duration))ms")
        }
        
        // Log component breakdown for slow transitions
        if duration > warningThreshold && !record.components.isEmpty {
            Logger.ui.debug("Component breakdown:")
            for (component, time) in record.components.sorted(by: { $0.value > $1.value }) {
                let percentage = (time / duration) * 100
                Logger.ui.debug("  \(component): \(String(format: "%.1f", time))ms (\(String(format: "%.1f", percentage))%)")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Transition Tracker
class TransitionTracker {
    private let monitor: ForegroundTransitionMonitor
    private let identifier: String
    private let startTime: CFAbsoluteTime
    private var components: [String: TimeInterval] = [:]
    
    init(monitor: ForegroundTransitionMonitor, identifier: String) {
        self.monitor = monitor
        self.identifier = identifier
        self.startTime = CFAbsoluteTimeGetCurrent()
    }
    
    func recordComponent(_ name: String) {
        let componentTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        components[name] = componentTime
    }
    
    func complete() {
        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        Task { @MainActor in
            monitor.recordTransition(duration: totalTime, components: components, identifier: identifier)
        }
    }
}
