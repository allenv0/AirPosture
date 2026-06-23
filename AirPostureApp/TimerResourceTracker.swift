import Foundation
import os.log

/// Tracks timer lifecycle and detects potential timer leaks
@MainActor
class TimerResourceTracker: ObservableObject {
    static let shared = TimerResourceTracker()
    
    // MARK: - Published Properties
    @Published private(set) var activeTimerCount: Int = 0
    @Published private(set) var totalTimersCreated: Int = 0
    @Published private(set) var suspectedLeaks: [TimerLeak] = []
    @Published private(set) var estimatedMemoryUsage: UInt64 = 0
    
    // MARK: - Private Properties
    private var activeTimers: [String: TimerResource] = [:]
    private var timerHistory: [TimerEvent] = []
    private let maxHistorySize = 1000
    private let logger = Logger(subsystem: "com.example.airposture", category: "TimerTracker")
    
    // Leak detection thresholds
    private let maxTimerAge: TimeInterval = 300 // 5 minutes
    private let maxActiveTimers = 15
    private let memoryPerTimer: UInt64 = 1024 // Estimated 1KB per timer
    
    // MARK: - Timer Resource
    struct TimerResource {
        let name: String
        let creationTime: Date
        let interval: TimeInterval
        let isRepeating: Bool
        var lastFireTime: Date?
        var fireCount: Int
        var estimatedMemoryUsage: UInt64
        let creationContext: String
        
        var age: TimeInterval {
            Date().timeIntervalSince(creationTime)
        }
        
        var isStale: Bool {
            age > 300 // 5 minutes
        }
    }
    
    // MARK: - Timer Event
    struct TimerEvent {
        let timestamp: Date
        let timerName: String
        let eventType: EventType
        let context: String
        
        enum EventType {
            case created
            case fired
            case invalidated
            case leaked
        }
    }
    
    // MARK: - Timer Leak
    struct TimerLeak {
        let timerName: String
        let age: TimeInterval
        let fireCount: Int
        let estimatedMemoryImpact: UInt64
        let creationContext: String
        let detectionTime: Date
        
        var severity: LeakSeverity {
            switch age {
            case 0..<300: return .minor
            case 300..<600: return .moderate
            case 600..<1800: return .major
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
        startLeakDetection()
    }
    
    // MARK: - Public Methods
    func registerTimer(_ name: String, timer: Timer, context: String = "") {
        let resource = TimerResource(
            name: name,
            creationTime: Date(),
            interval: timer.timeInterval,
            isRepeating: timer.isValid,
            lastFireTime: nil,
            fireCount: 0,
            estimatedMemoryUsage: memoryPerTimer,
            creationContext: context.isEmpty ? getCreationContext() : context
        )
        
        activeTimers[name] = resource
        totalTimersCreated += 1
        updateMetrics()
        
        recordEvent(.created, timerName: name, context: resource.creationContext)
        
        logger.info("⏰ Timer registered: \(name) (\(resource.interval)s interval)")
        Logger.memory.info("Timer registered: \(name) - Total active: \(self.activeTimerCount)")
        
        // Check for potential issues
        if activeTimerCount > maxActiveTimers {
            logger.warning("⚠️ High timer count detected: \(self.activeTimerCount) active timers")
            Logger.memory.warning("High timer count detected: \(self.activeTimerCount) active timers")
        }
    }
    
    func unregisterTimer(_ name: String) {
        guard let resource = activeTimers.removeValue(forKey: name) else {
            logger.warning("⚠️ Attempted to unregister unknown timer: \(name)")
            return
        }
        
        updateMetrics()
        recordEvent(.invalidated, timerName: name, context: "Age: \(String(format: "%.1f", resource.age))s")
        
        logger.info("⏰ Timer unregistered: \(name) (lived \(String(format: "%.1f", resource.age))s)")
        Logger.memory.info("Timer unregistered: \(name) - Total active: \(self.activeTimerCount)")
        
        // Remove from suspected leaks if present
        suspectedLeaks.removeAll { $0.timerName == name }
    }
    
    func recordTimerFire(_ name: String) {
        guard var resource = activeTimers[name] else { return }
        
        resource.lastFireTime = Date()
        resource.fireCount += 1
        activeTimers[name] = resource
        
        recordEvent(.fired, timerName: name, context: "Fire #\(resource.fireCount)")
    }
    
    func detectTimerLeaks() -> [TimerLeak] {
        var leaks: [TimerLeak] = []
        let now = Date()
        
        for (name, resource) in activeTimers {
            // Check for stale timers
            if resource.isStale {
                let leak = TimerLeak(
                    timerName: name,
                    age: resource.age,
                    fireCount: resource.fireCount,
                    estimatedMemoryImpact: resource.estimatedMemoryUsage,
                    creationContext: resource.creationContext,
                    detectionTime: now
                )
                
                leaks.append(leak)
                recordEvent(.leaked, timerName: name, context: "Age: \(String(format: "%.1f", resource.age))s")
            }
        }
        
        suspectedLeaks = leaks
        
        if !leaks.isEmpty {
            logger.warning("🚨 Timer leaks detected: \(leaks.count) suspected leaks")
            Logger.memory.warning("Timer leaks detected: \(leaks.count) suspected leaks")
            for leak in leaks {
                Logger.memory.debug("Leak: \(leak.timerName): \(String(format: "%.1f", leak.age))s old, \(leak.fireCount) fires")
            }
        }
        
        return leaks
    }
    
    func getTimerReport() -> String {
        let leaks = detectTimerLeaks()
        
        var report = """
        ⏰ Timer Resource Tracker Report
        ===============================
        Active Timers: \(activeTimerCount)
        Total Created: \(totalTimersCreated)
        Estimated Memory: \(formatBytes(estimatedMemoryUsage))
        Suspected Leaks: \(leaks.count)
        
        Active Timers:
        """
        
        for (name, resource) in activeTimers.sorted(by: { $0.value.age > $1.value.age }) {
            let ageString = String(format: "%.1f", resource.age)
            let intervalString = String(format: "%.1f", resource.interval)
            report += "\n  • \(name): \(ageString)s old, \(intervalString)s interval, \(resource.fireCount) fires"
        }
        
        if !leaks.isEmpty {
            report += "\n\nSuspected Leaks:"
            for leak in leaks {
                report += "\n  🚨 \(leak.timerName): \(leak.severity.rawValue) (\(String(format: "%.1f", leak.age))s old)"
            }
        }
        
        return report
    }
    
    func performCleanup() {
        let leaks = detectTimerLeaks()
        
        if !leaks.isEmpty {
            logger.info("🧹 Performing timer cleanup - \(leaks.count) potential leaks identified")
            Logger.memory.info("Timer cleanup identified \(leaks.count) potential leaks")
        }
        
        // Note: We don't automatically invalidate timers as they might be legitimately long-running
        // This is for monitoring and alerting purposes
    }
    
    // MARK: - Private Implementation
    private func startLeakDetection() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.performLeakDetection()
        }
    }
    
    private func performLeakDetection() {
        let _ = detectTimerLeaks()
        
        // Clean up old history
        let cutoffTime = Date().addingTimeInterval(-3600) // Keep 1 hour of history
        timerHistory.removeAll { $0.timestamp < cutoffTime }
    }
    
    private func updateMetrics() {
        activeTimerCount = activeTimers.count
        estimatedMemoryUsage = UInt64(activeTimerCount) * memoryPerTimer
    }
    
    private func recordEvent(_ eventType: TimerEvent.EventType, timerName: String, context: String) {
        let event = TimerEvent(
            timestamp: Date(),
            timerName: timerName,
            eventType: eventType,
            context: context
        )
        
        timerHistory.append(event)
        
        // Limit history size
        if timerHistory.count > maxHistorySize {
            timerHistory.removeFirst()
        }
    }
    
    private func getCreationContext() -> String {
        // Get the calling function context
        let stackTrace = Thread.callStackSymbols
        if stackTrace.count > 2 {
            let caller = stackTrace[2]
            // Extract function name from stack trace
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
}

// MARK: - Managed Timer (RAII Pattern)
class ManagedTimer {
    private let timer: Timer
    private let name: String
    private let tracker = TimerResourceTracker.shared
    
    init(name: String, interval: TimeInterval, repeats: Bool = true, block: @escaping (Timer) -> Void) {
        self.name = name
        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak tracker] timer in
            tracker?.recordTimerFire(name)
            block(timer)
        }
        
        Task { @MainActor in
            tracker.registerTimer(name, timer: timer)
        }
    }
    
    func invalidate() {
        timer.invalidate()
        Task { @MainActor in
            tracker.unregisterTimer(name)
        }
    }
    
    var isValid: Bool {
        return timer.isValid
    }
    
    deinit {
        if timer.isValid {
            timer.invalidate()
            Task { @MainActor in
                tracker.unregisterTimer(name)
            }
        }
    }
}