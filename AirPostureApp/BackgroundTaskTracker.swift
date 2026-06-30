import Foundation
import UIKit
import os.log

/// Tracks background task lifecycle and detects potential task leaks
@MainActor
class BackgroundTaskTracker: ObservableObject {
    static let shared = BackgroundTaskTracker()
    
    // MARK: - Published Properties
    @Published private(set) var activeTaskCount: Int = 0
    @Published private(set) var totalTasksCreated: Int = 0
    @Published private(set) var suspectedLeaks: [BackgroundTaskLeak] = []
    @Published private(set) var estimatedMemoryUsage: UInt64 = 0
    @Published private(set) var backgroundTimeRemaining: TimeInterval = 0
    
    // MARK: - Private Properties
    private var activeTasks: [UIBackgroundTaskIdentifier: BackgroundTaskResource] = [:]
    private var taskHistory: [BackgroundTaskEvent] = []
    private let maxHistorySize = 500
    private let logger = Logger(subsystem: "com.allenleee.AirPosture", category: "BackgroundTaskTracker")
    
    // Leak detection thresholds
    private let maxTaskAge: TimeInterval = 30 // 30 seconds (iOS background limit)
    private let maxActiveTasks = 10
    private let memoryPerTask: UInt64 = 2048 // Estimated 2KB per background task
    
    // Monitoring timer
    private var monitoringTimer: Timer?
    
    // MARK: - Background Task Resource
    struct BackgroundTaskResource {
        let identifier: UIBackgroundTaskIdentifier
        let name: String
        let creationTime: Date
        let estimatedDuration: TimeInterval
        var actualDuration: TimeInterval?
        var memoryAtCreation: UInt64
        var memoryAtCompletion: UInt64?
        let creationContext: String
        
        var age: TimeInterval {
            Date().timeIntervalSince(creationTime)
        }
        
        var isStale: Bool {
            age > 25 // 25 seconds (close to iOS 30s limit)
        }
        
        var isExpired: Bool {
            age > 30 // 30 seconds (iOS background limit)
        }
    }
    
    // MARK: - Background Task Event
    struct BackgroundTaskEvent {
        let timestamp: Date
        let taskId: UIBackgroundTaskIdentifier
        let taskName: String
        let eventType: EventType
        let context: String
        
        enum EventType {
            case created
            case expired
            case completed
            case leaked
        }
    }
    
    // MARK: - Background Task Leak
    struct BackgroundTaskLeak {
        let taskId: UIBackgroundTaskIdentifier
        let taskName: String
        let age: TimeInterval
        let estimatedMemoryImpact: UInt64
        let creationContext: String
        let detectionTime: Date
        
        var severity: LeakSeverity {
            switch age {
            case 0..<20: return .minor
            case 20..<25: return .moderate
            case 25..<30: return .major
            default: return .critical
            }
        }
        
        enum LeakSeverity: String {
            case minor = "Minor"
            case moderate = "Moderate"
            case major = "Major"
            case critical = "Critical"
        }
    }
    
    // MARK: - Initialization
    private init() {
        startMonitoring()
        setupBackgroundTimeTracking()
    }
    
    // MARK: - Public Methods
    func trackTaskCreation(_ id: UIBackgroundTaskIdentifier, name: String, estimatedDuration: TimeInterval = 30.0) {
        guard id != .invalid else {
            logger.warning("⚠️ Attempted to track invalid background task")
            return
        }
        
        let memoryUsage = getCurrentMemoryUsage()
        let resource = BackgroundTaskResource(
            identifier: id,
            name: name,
            creationTime: Date(),
            estimatedDuration: estimatedDuration,
            actualDuration: nil,
            memoryAtCreation: memoryUsage,
            memoryAtCompletion: nil,
            creationContext: getCreationContext()
        )
        
        activeTasks[id] = resource
        totalTasksCreated += 1
        updateMetrics()
        
        recordEvent(.created, taskId: id, taskName: name, context: "Estimated: \(estimatedDuration)s")
        
        logger.info("🔄 Background task created: \(name) (\(id.rawValue))")
        Logger.background.info("Background task created: \(name) - Total active: \(self.activeTaskCount)")
        
        // Check for potential issues
        if activeTaskCount > maxActiveTasks {
            logger.warning("⚠️ High background task count: \(self.activeTaskCount) active tasks")
            Logger.background.warning("High background task count: \(self.activeTaskCount) active tasks")
        }
    }
    
    func trackTaskCompletion(_ id: UIBackgroundTaskIdentifier) {
        guard var resource = activeTasks.removeValue(forKey: id) else {
            logger.warning("⚠️ Attempted to complete unknown background task: \(id.rawValue)")
            return
        }
        
        resource.actualDuration = resource.age
        resource.memoryAtCompletion = getCurrentMemoryUsage()
        updateMetrics()
        
        recordEvent(.completed, taskId: id, taskName: resource.name, context: "Duration: \(String(format: "%.1f", resource.actualDuration!))s")
        
        logger.info("✅ Background task completed: \(resource.name) (\(id.rawValue)) after \(String(format: "%.1f", resource.actualDuration!))s")
        Logger.background.info("Background task completed: \(resource.name) - Total active: \(self.activeTaskCount)")
        
        // Remove from suspected leaks if present
        suspectedLeaks.removeAll { $0.taskId == id }
    }
    
    func trackTaskExpiration(_ id: UIBackgroundTaskIdentifier) {
        guard let resource = activeTasks[id] else {
            logger.warning("⚠️ Attempted to expire unknown background task: \(id.rawValue)")
            return
        }
        
        recordEvent(.expired, taskId: id, taskName: resource.name, context: "Age: \(String(format: "%.1f", resource.age))s")
        
        logger.warning("⏰ Background task expired: \(resource.name) (\(id.rawValue)) after \(String(format: "%.1f", resource.age))s")
        Logger.background.warning("Background task expired: \(resource.name)")
        
        // Don't remove from activeTasks yet - let trackTaskCompletion handle it
    }
    
    func detectTaskLeaks() -> [BackgroundTaskLeak] {
        var leaks: [BackgroundTaskLeak] = []
        let now = Date()
        
        for (id, resource) in activeTasks {
            // Check for stale or expired tasks
            if resource.isStale {
                let leak = BackgroundTaskLeak(
                    taskId: id,
                    taskName: resource.name,
                    age: resource.age,
                    estimatedMemoryImpact: resource.memoryAtCreation,
                    creationContext: resource.creationContext,
                    detectionTime: now
                )
                
                leaks.append(leak)
                recordEvent(.leaked, taskId: id, taskName: resource.name, context: "Age: \(String(format: "%.1f", resource.age))s")
            }
        }
        
        suspectedLeaks = leaks
        
        if !leaks.isEmpty {
            logger.warning("🚨 Background task leaks detected: \(leaks.count) suspected leaks")
            Logger.background.warning("Background task leaks detected: \(leaks.count) suspected leaks")
            for leak in leaks {
                Logger.background.debug("Leak: \(leak.taskName): \(String(format: "%.1f", leak.age))s old (\(leak.severity.rawValue))")
            }
        }
        
        return leaks
    }
    
    func getTaskMemoryImpact() -> BackgroundTaskMemoryReport {
        let totalMemoryAtCreation = activeTasks.values.reduce(0) { $0 + $1.memoryAtCreation }
        let currentMemory = getCurrentMemoryUsage()
        let estimatedTaskMemory = UInt64(activeTaskCount) * memoryPerTask
        
        return BackgroundTaskMemoryReport(
            activeTaskCount: activeTaskCount,
            totalMemoryAtCreation: totalMemoryAtCreation,
            currentMemory: currentMemory,
            estimatedTaskMemory: estimatedTaskMemory,
            memoryGrowthSinceCreation: currentMemory > totalMemoryAtCreation ? currentMemory - totalMemoryAtCreation : 0
        )
    }
    
    func getTaskReport() -> String {
        let leaks = detectTaskLeaks()
        let memoryReport = getTaskMemoryImpact()
        
        var report = """
        🔄 Background Task Tracker Report
        ================================
        Active Tasks: \(activeTaskCount)
        Total Created: \(totalTasksCreated)
        Background Time Remaining: \(String(format: "%.1f", backgroundTimeRemaining))s
        Estimated Memory: \(formatBytes(estimatedMemoryUsage))
        Suspected Leaks: \(leaks.count)
        
        Active Tasks:
        """
        
        for (id, resource) in activeTasks.sorted(by: { $0.value.age > $1.value.age }) {
            let ageString = String(format: "%.1f", resource.age)
            let memoryString = formatBytes(resource.memoryAtCreation)
            report += "\n  • \(resource.name) (\(id.rawValue)): \(ageString)s old, \(memoryString)"
        }
        
        if !leaks.isEmpty {
            report += "\n\nSuspected Leaks:"
            for leak in leaks {
                report += "\n  🚨 \(leak.taskName) (\(leak.taskId.rawValue)): \(leak.severity.rawValue) (\(String(format: "%.1f", leak.age))s old)"
            }
        }
        
        report += "\n\nMemory Impact:"
        report += "\n  Current Memory: \(formatBytes(memoryReport.currentMemory))"
        report += "\n  Estimated Task Memory: \(formatBytes(memoryReport.estimatedTaskMemory))"
        report += "\n  Memory Growth: \(formatBytes(memoryReport.memoryGrowthSinceCreation))"
        
        return report
    }
    
    func performCleanup() {
        let leaks = detectTaskLeaks()
        
        if !leaks.isEmpty {
            logger.info("🧹 Performing background task cleanup - \(leaks.count) potential leaks identified")
            Logger.background.info("Background task cleanup identified \(leaks.count) potential leaks")
            
            // For critical leaks (expired tasks), we could force cleanup
            let criticalLeaks = leaks.filter { $0.severity == .critical }
            if !criticalLeaks.isEmpty {
                logger.warning("🚨 Critical background task leaks detected - consider force cleanup")
                Logger.background.error("\(criticalLeaks.count) critical background task leaks detected")
            }
        }
    }
    
    // MARK: - Private Implementation
    private func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performMonitoring()
        }
    }
    
    private func performMonitoring() {
        updateBackgroundTimeRemaining()
        let _ = detectTaskLeaks()
        
        // Clean up old history
        let cutoffTime = Date().addingTimeInterval(-1800) // Keep 30 minutes of history
        taskHistory.removeAll { $0.timestamp < cutoffTime }
    }
    
    private func setupBackgroundTimeTracking() {
        // Update background time remaining periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateBackgroundTimeRemaining()
        }
    }
    
    private func updateBackgroundTimeRemaining() {
        backgroundTimeRemaining = UIApplication.shared.backgroundTimeRemaining
    }
    
    private func updateMetrics() {
        activeTaskCount = activeTasks.count
        estimatedMemoryUsage = UInt64(activeTaskCount) * memoryPerTask
    }
    
    private func recordEvent(_ eventType: BackgroundTaskEvent.EventType, taskId: UIBackgroundTaskIdentifier, taskName: String, context: String) {
        let event = BackgroundTaskEvent(
            timestamp: Date(),
            taskId: taskId,
            taskName: taskName,
            eventType: eventType,
            context: context
        )
        
        taskHistory.append(event)
        
        // Limit history size
        if taskHistory.count > maxHistorySize {
            taskHistory.removeFirst()
        }
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
    
    private func getCreationContext() -> String {
        let stackTrace = Thread.callStackSymbols
        if stackTrace.count > 2 {
            let caller = stackTrace[2]
            if let range = caller.range(of: " ") {
                let afterSpace = caller[range.upperBound...]
                if let nextSpace = afterSpace.firstIndex(of: " ") {
                    return String(afterSpace[..<nextSpace])
                }
            }
        }
        return "Unknown"
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Cleanup
    deinit {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
}

// MARK: - Supporting Types
struct BackgroundTaskMemoryReport {
    let activeTaskCount: Int
    let totalMemoryAtCreation: UInt64
    let currentMemory: UInt64
    let estimatedTaskMemory: UInt64
    let memoryGrowthSinceCreation: UInt64
}