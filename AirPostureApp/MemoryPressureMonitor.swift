import Foundation
import UIKit
import os.log

/// Monitors system memory pressure and provides real-time memory usage tracking
@MainActor
class MemoryPressureMonitor: ObservableObject {
    static let shared = MemoryPressureMonitor()
    
    // MARK: - Published Properties
    @Published private(set) var currentPressureLevel: MemoryPressureLevel = .normal
    @Published private(set) var memoryWarningCount: Int = 0
    @Published private(set) var lastMemoryWarning: Date?
    @Published private(set) var currentMemoryUsage: UInt64 = 0
    @Published private(set) var peakMemoryUsage: UInt64 = 0
    @Published private(set) var isMonitoringActive: Bool = false
    
    // MARK: - Memory Pressure Levels
    enum MemoryPressureLevel: String, CaseIterable {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
        case emergency = "Emergency"
        
        var description: String {
            switch self {
            case .normal:
                return "Memory usage is normal"
            case .warning:
                return "Memory pressure detected - optimizing performance"
            case .critical:
                return "High memory pressure - reducing features"
            case .emergency:
                return "Critical memory pressure - emergency mode active"
            }
        }
        
        var color: UIColor {
            switch self {
            case .normal:
                return .systemGreen
            case .warning:
                return .systemYellow
            case .critical:
                return .systemOrange
            case .emergency:
                return .systemRed
            }
        }
    }
    
    // MARK: - Private Properties
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var memoryMonitoringTimer: Timer?
    private let logger = Logger(subsystem: "com.allenleee.AirPosture", category: "MemoryMonitor")
    
    // Memory tracking
    private var baselineMemory: UInt64 = 0
    private var memoryHistory: [MemorySnapshot] = []
    private let maxHistorySize = 100
    
    // Delegates for memory pressure response
    private var pressureResponders: [WeakMemoryPressureResponder] = []
    
    // MARK: - Memory Snapshot
    struct MemorySnapshot {
        let timestamp: Date
        let memoryUsage: UInt64
        let pressureLevel: MemoryPressureLevel
        let availableMemory: UInt64
        let memoryPressure: Double // 0.0-1.0
    }
    
    // MARK: - Initialization
    private init() {
        setupMemoryPressureMonitoring()
        startMemoryTracking()
        recordBaselineMemory()
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        guard !isMonitoringActive else { return }
        
        isMonitoringActive = true
        setupMemoryPressureSource()
        startPeriodicMemoryCheck()
        
        logger.info("🧠 Memory pressure monitoring started")
        Logger.memory.info("Memory pressure monitoring started - baseline: \(self.formatBytes(self.baselineMemory))")
    }
    
    func stopMonitoring() {
        guard isMonitoringActive else { return }
        
        isMonitoringActive = false
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        memoryMonitoringTimer?.invalidate()
        memoryMonitoringTimer = nil
        
        logger.info("🧠 Memory pressure monitoring stopped")
        Logger.memory.info("Memory pressure monitoring stopped")
    }
    
    func addPressureResponder(_ responder: MemoryPressureResponderProtocol) {
        let weakResponder = WeakMemoryPressureResponder(responder)
        pressureResponders.append(weakResponder)
        cleanupWeakResponders()
    }
    
    func getCurrentMemoryUsage() -> MemoryUsage {
        let usage = getMemoryUsage()
        return MemoryUsage(
            current: usage.current,
            peak: peakMemoryUsage,
            available: usage.available,
            pressure: calculateMemoryPressure(current: usage.current, available: usage.available)
        )
    }
    
    func getMemoryReport() -> String {
        let current = getCurrentMemoryUsage()
        let recentHistory = Array(memoryHistory.suffix(10))
        
        var report = """
        🧠 Memory Pressure Monitor Report
        ================================
        Current Usage: \(formatBytes(current.current))
        Peak Usage: \(formatBytes(current.peak))
        Available: \(formatBytes(current.available))
        Pressure Level: \(currentPressureLevel.rawValue)
        Memory Warnings: \(memoryWarningCount)
        Monitoring Active: \(isMonitoringActive)
        
        Recent History:
        """
        
        for snapshot in recentHistory {
            let timeAgo = Date().timeIntervalSince(snapshot.timestamp)
            report += "\n  • \(String(format: "%.1f", timeAgo))s ago: \(formatBytes(snapshot.memoryUsage)) (\(snapshot.pressureLevel.rawValue))"
        }
        
        return report
    }
    
    // MARK: - Private Implementation
    private func setupMemoryPressureMonitoring() {
        // Listen for system memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // Starts periodic memory tracking and system pressure source
    private func startMemoryTracking() {
        // Delegate to existing monitoring pipeline
        startMonitoring()
    }
    
    private func setupMemoryPressureSource() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = self.memoryPressureSource?.mask
            if event?.contains(.warning) == true {
                self.handleMemoryPressureEvent(.warning)
            }
            if event?.contains(.critical) == true {
                self.handleMemoryPressureEvent(.critical)
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    private func startPeriodicMemoryCheck() {
        memoryMonitoringTimer?.invalidate()
        
        memoryMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.performMemoryCheck()
        }
    }
    
    private func performMemoryCheck() {
        let usage = getMemoryUsage()
        currentMemoryUsage = usage.current
        
        // Update peak memory
        if usage.current > peakMemoryUsage {
            peakMemoryUsage = usage.current
        }
        
        // Calculate pressure level
        let pressure = calculateMemoryPressure(current: usage.current, available: usage.available)
        let newPressureLevel = determinePressureLevel(pressure: pressure)
        
        // Record snapshot
        let snapshot = MemorySnapshot(
            timestamp: Date(),
            memoryUsage: usage.current,
            pressureLevel: newPressureLevel,
            availableMemory: usage.available,
            memoryPressure: pressure
        )
        
        memoryHistory.append(snapshot)
        if memoryHistory.count > maxHistorySize {
            memoryHistory.removeFirst()
        }
        
        // Handle pressure level changes
        if newPressureLevel != currentPressureLevel {
            handlePressureLevelChange(from: currentPressureLevel, to: newPressureLevel)
        }
    }
    
    private func handlePressureLevelChange(from oldLevel: MemoryPressureLevel, to newLevel: MemoryPressureLevel) {
        currentPressureLevel = newLevel
        
        logger.info("🧠 Memory pressure changed: \(oldLevel.rawValue) → \(newLevel.rawValue)")
        Logger.memory.info("Memory pressure changed: \(oldLevel.rawValue) → \(newLevel.rawValue) (\(self.formatBytes(self.currentMemoryUsage)))")
        
        // Notify all responders
        notifyPressureResponders(newLevel)
    }
    
    private func handleMemoryPressureEvent(_ level: MemoryPressureLevel) {
        memoryWarningCount += 1
        lastMemoryWarning = Date()
        
        logger.warning("🧠 System memory pressure event: \(level.rawValue)")
        Logger.memory.warning("System memory pressure event: \(level.rawValue) - Warning #\(self.memoryWarningCount)")
        
        // Force immediate pressure level update
        if level.rawValue > currentPressureLevel.rawValue {
            handlePressureLevelChange(from: currentPressureLevel, to: level)
        }
    }
    
    @objc private func handleMemoryWarning() {
        handleMemoryPressureEvent(.warning)
    }
    
    private func notifyPressureResponders(_ level: MemoryPressureLevel) {
        cleanupWeakResponders()
        
        for weakResponder in pressureResponders {
            weakResponder.responder?.respondToMemoryPressure(level)
        }
    }
    
    private func cleanupWeakResponders() {
        pressureResponders.removeAll { $0.responder == nil }
    }
    
    private func recordBaselineMemory() {
        let usage = getMemoryUsage()
        baselineMemory = usage.current
        peakMemoryUsage = usage.current
        
        logger.info("🧠 Baseline memory recorded: \(self.formatBytes(self.baselineMemory))")
        Logger.memory.info("Baseline memory recorded: \(self.formatBytes(self.baselineMemory))")
    }
    
    private func getMemoryUsage() -> (current: UInt64, available: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let currentMemory = UInt64(info.resident_size)
            
            // Get available memory
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            let availableMemory = physicalMemory - currentMemory
            
            return (current: currentMemory, available: availableMemory)
        } else {
            logger.error("🧠 Failed to get memory usage: \(kerr)")
            return (current: 0, available: 0)
        }
    }
    
    private func calculateMemoryPressure(current: UInt64, available: UInt64) -> Double {
        let total = current + available
        guard total > 0 else { return 0.0 }
        
        return Double(current) / Double(total)
    }
    
    private func determinePressureLevel(pressure: Double) -> MemoryPressureLevel {
        switch pressure {
        case 0.0..<0.7:
            return .normal
        case 0.7..<0.85:
            return .warning
        case 0.85..<0.95:
            return .critical
        default:
            return .emergency
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Cleanup
    deinit {
        // Inline cleanup to avoid actor isolation call issues in deinit
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        memoryMonitoringTimer?.invalidate()
        memoryMonitoringTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types
struct MemoryUsage {
    let current: UInt64
    let peak: UInt64
    let available: UInt64
    let pressure: Double // 0.0-1.0
}

protocol MemoryPressureResponderProtocol: AnyObject {
    func respondToMemoryPressure(_ level: MemoryPressureMonitor.MemoryPressureLevel)
}

private class WeakMemoryPressureResponder {
    weak var responder: MemoryPressureResponderProtocol?
    
    init(_ responder: MemoryPressureResponderProtocol) {
        self.responder = responder
    }
}