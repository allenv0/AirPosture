import os
import Foundation
import UIKit
import UserNotifications

// MARK: - UIApplication.State Extension for Better Logging
extension UIApplication.State {
    var description: String {
        switch self {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}

@MainActor
class EnhancedBackgroundManager: ObservableObject {
    static let shared = EnhancedBackgroundManager()
    
    // MARK: - Published Properties
    @Published private(set) var isBackgroundTrackingActive: Bool = false
    @Published private(set) var backgroundTaskCount: Int = 0
    @Published private(set) var lastBackgroundActivity: Date?
    @Published private(set) var totalBackgroundTime: TimeInterval = 0
    
    // MARK: - Private Properties
    private var backgroundTasks: [UIBackgroundTaskIdentifier] = []
    private var backgroundTimer: Timer? // legacy
    private var backgroundSource: DispatchSourceTimer?
    private var backgroundStartTime: Date?
    private weak var motionManager: HeadphoneMotionManager?
    private var isAppInBackground: Bool = false
    private var isForegroundTransitioning: Bool = false
    
    // MARK: - Memory Management Integration (Disabled)
    // Background task tracking disabled - files not in Xcode project
    
    // STABILITY: Additional safety properties
    private var isCleaningUp: Bool = false
    private var cleanupTimer: Timer?
    private var lastAppStateCheck: Date = Date.distantPast
    private let appStateCheckInterval: TimeInterval = 2.0

    // MARK: - Smart Power Saving Properties
    private var backgroundIdleStartTime: Date?
    private var powerSavingModeActive: Bool = false
    private let powerSavingThreshold: TimeInterval = MotionConstants.powerSavingThreshold
    private let deepSleepThreshold: TimeInterval = MotionConstants.deepSleepThreshold
    
    // Safe cancellation utility for DispatchSourceTimer
    private func cancelTimerSourceSafely(_ source: inout DispatchSourceTimer?) {
        SystemUtilities.cancelTimerSourceSafely(&source)
    }
    
    // Background task management - FIXED: Reduced limits to prevent explosion
    private let maxConcurrentTasks = 1 // Reduced from 3 to 1
    private let taskDuration: TimeInterval = 25.0 // 25 seconds per task
    private let taskOverlap: TimeInterval = 5.0   // 5 seconds overlap
    private let maxTotalTasks = 10 // FIXED: Maximum total tasks allowed
    private var totalTasksCreated = 0 // FIXED: Track total tasks created
    
    // Add rate limiting and safety controls
    private var lastTaskCreationTime: Date = Date.distantPast
    private let minimumTaskCreationInterval: TimeInterval = 2.0
    private let maxConcurrentActiveTasks = 3
    
    // MARK: - Initialization
    private init() {
        setupNotifications()
    }
    
    // MARK: - Public Methods
    func configure(with motionManager: HeadphoneMotionManager) {
        self.motionManager = motionManager
    }
    
    func startBackgroundTracking() {
        guard !isBackgroundTrackingActive else { return }

        guard let motionManager = motionManager,
              let currentSession = motionManager.currentSessionStore.currentSession,
              !motionManager.isPaused && !motionManager.sessionPaused else {
            Logger.background.info("No active posture session - skipping background tracking")
            return
        }

        Logger.background.info("Active session detected - starting enhanced background tracking")
        isBackgroundTrackingActive = true
        backgroundStartTime = Date()
        totalTasksCreated = 0 // FIXED: Reset counter

        // Initialize power saving state
        backgroundIdleStartTime = Date()
        powerSavingModeActive = false

        startBackgroundTaskChain()
        setupBackgroundTimer()
    }
    
    func stopBackgroundTracking() {
        guard isBackgroundTrackingActive else { return }

        Logger.background.info("Stopping enhanced background tracking")
        isBackgroundTrackingActive = false

        // Calculate total background time
        if let startTime = backgroundStartTime {
            totalBackgroundTime += Date().timeIntervalSince(startTime)
        }

        // Stop timer immediately
        backgroundTimer?.invalidate()
        backgroundTimer = nil

        // Use graceful cleanup to prevent UI blocking
        cleanupAllBackgroundTasks()

        // Reset task counter after cleanup is scheduled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.totalTasksCreated = 0
        }
    }
    
    // MARK: - Background Task Chain Management
    private func startBackgroundTaskChain() {
        // Start multiple overlapping background tasks
        for i in 0..<maxConcurrentTasks {
            let delay = Double(i) * taskOverlap
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.createBackgroundTask()
            }
        }
    }
    
    private func createBackgroundTask() {
        // CRITICAL: Add proper rate limiting
        guard isBackgroundTrackingActive else { return }
        guard isAppInBackground else { return }
        
        // CRITICAL: Add hard limits with proper enforcement
        guard totalTasksCreated < maxTotalTasks else {
            Logger.background.warning("Maximum background task limit reached (\(self.maxTotalTasks)). Stopping task creation.")
            return
        }
        
        // CRITICAL: Add rate limiting to prevent task explosion
        let now = Date()
        guard now.timeIntervalSince(lastTaskCreationTime) > minimumTaskCreationInterval else {
            Logger.background.debug("Task creation rate limited")
            return
        }
        
        // CRITICAL: Check current active tasks don't exceed system limits
        guard backgroundTasks.count < maxConcurrentActiveTasks else {
            Logger.background.debug("Active task limit reached")
            return
        }
        
        // NOW create the task
        var taskId: UIBackgroundTaskIdentifier = .invalid
        taskId = UIApplication.shared.beginBackgroundTask(withName: "Enhanced Motion Tracking") { [weak self] in
            self?.handleBackgroundTaskExpiration(taskId: taskId)
        }
        
        guard taskId != .invalid else {
            Logger.background.error("Failed to create background task")
            return
        }
        
        backgroundTasks.append(taskId)
        backgroundTaskCount += 1
        totalTasksCreated += 1
        lastTaskCreationTime = now
        lastBackgroundActivity = Date()
        
        Logger.background.debug("Created background task \(self.backgroundTaskCount) (Total: \(self.totalTasksCreated)/\(self.maxTotalTasks))")
        Logger.background.debug("Background time remaining: \(UIApplication.shared.backgroundTimeRemaining) seconds")

        // Schedule task completion and renewal
        DispatchQueue.main.asyncAfter(deadline: .now() + taskDuration) {
            self.renewBackgroundTask(taskId)
        }
    }
    
    private func renewBackgroundTask(_ expiredTaskId: UIBackgroundTaskIdentifier) {
        // Remove expired task
        if let index = backgroundTasks.firstIndex(of: expiredTaskId) {
            backgroundTasks.remove(at: index)
            UIApplication.shared.endBackgroundTask(expiredTaskId)
            Logger.background.debug("Renewed background task")
        }

        // FIXED: Only create new task if app is in background and under limits
        guard UIApplication.shared.applicationState == .background else {
            Logger.background.warning("App not in background during renewal, stopping task creation")
            return
        }
        
        if isBackgroundTrackingActive && isAppInBackground && totalTasksCreated < maxTotalTasks {
            createBackgroundTask()
        } else if totalTasksCreated >= maxTotalTasks {
            Logger.background.warning("Background task limit reached. No more tasks will be created.")
        }
    }
    
    private func handleBackgroundTaskExpiration(taskId: UIBackgroundTaskIdentifier) {
        Logger.background.debug("Background task expiring - attempting renewal")
        
        // Background task expiration tracking disabled

        // FIXED: Only create new task if app is in background and under limits
        guard UIApplication.shared.applicationState == .background else {
            Logger.background.warning("App not in background during expiration, stopping task creation")
            return
        }

        if isBackgroundTrackingActive && isAppInBackground && totalTasksCreated < maxTotalTasks {
            createBackgroundTask()
        } else if totalTasksCreated >= maxTotalTasks {
            Logger.background.warning("Background task limit reached. Stopping background tracking.")
            stopBackgroundTracking()
        }
    }
    
    private func cleanupAllBackgroundTasks() {
        // STABILITY: Prevent multiple cleanup operations
        guard !isCleaningUp else {
            Logger.background.debug("Cleanup already in progress, skipping")
            return
        }
        
        guard !backgroundTasks.isEmpty else {
            Logger.background.debug("No background tasks to clean up")
            return
        }
        
        isCleaningUp = true
        Logger.background.info("Starting graceful cleanup of \(self.backgroundTasks.count) background tasks")
        
        // Create a copy of the tasks array to avoid modification during iteration
        let tasksToCleanup = backgroundTasks
        backgroundTasks.removeAll() // Clear the array immediately to prevent new operations
        
        // STABILITY: Use background queue for cleanup to prevent main thread blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Cleanup tasks with staggered delays
            for (index, taskId) in tasksToCleanup.enumerated() {
                let delay = Double(index) * 0.05 // Reduced to 50ms delay for faster cleanup
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    UIApplication.shared.endBackgroundTask(taskId)
                    Logger.background.debug("Cleaned up background task \(index + 1)/\(tasksToCleanup.count)")
                }
            }
            
            // Mark cleanup as complete
            let totalDelay = Double(tasksToCleanup.count) * 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay + 0.1) { [weak self] in
                self?.isCleaningUp = false
                Logger.background.info("Graceful cleanup completed for all \(tasksToCleanup.count) background tasks")
            }
        }
    }
    
    // MARK: - Immediate Cleanup (Non-blocking)
    private func performImmediateBackgroundCleanup() {
        let cleanupStartTime = Date()
        
        // Batch terminate all tasks immediately (no staggered delays)
        let tasksToCleanup = Array(backgroundTasks)
        
        // Clear collections immediately
        DispatchQueue.main.async { [weak self] in
            self?.backgroundTasks.removeAll()
        }
        
        Logger.background.info("Starting immediate batch cleanup of \(tasksToCleanup.count) background tasks")
        
        // Terminate all tasks in parallel using concurrent dispatch
        if !tasksToCleanup.isEmpty {
            DispatchQueue.concurrentPerform(iterations: tasksToCleanup.count) { [weak self] index in
                let taskId = tasksToCleanup[index]
                
                // Background task completion tracking disabled
                
                UIApplication.shared.endBackgroundTask(taskId)
                Logger.background.debug("Terminated task \(index + 1)/\(tasksToCleanup.count)")
            }
        }
        
        // Single callback to main thread when complete
        DispatchQueue.main.async { [weak self] in
            self?.isCleaningUp = false
            self?.totalTasksCreated = 0
            
            let cleanupDuration = Date().timeIntervalSince(cleanupStartTime) * 1000 // Convert to ms
            Logger.background.info("Immediate batch cleanup completed in \(String(format: "%.1f", cleanupDuration))ms")
        }
    }
    
    // MARK: - Background Timer
    private func setupBackgroundTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        cancelTimerSourceSafely(&backgroundSource)
        let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        source.schedule(deadline: .now() + 10.0, repeating: 10.0)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.performBackgroundMaintenance()
            }
        }
        backgroundSource = source
        source.resume()
    }
    
    private func performBackgroundMaintenance() {
        guard isBackgroundTrackingActive && isAppInBackground && !isForegroundTransitioning else { return }

        // Check if we should apply power saving
        checkAndApplyPowerSaving()

        // If in deep sleep mode, skip maintenance
        if let idleStart = backgroundIdleStartTime,
           Date().timeIntervalSince(idleStart) >= deepSleepThreshold {
            Logger.background.debug("Deep sleep mode active - skipping background maintenance")
            return
        }

        // STABILITY: Perform health check to detect app state mismatches
        performAppStateHealthCheck()

        // FIXED: Additional check to ensure app is still in background
        guard UIApplication.shared.applicationState == .background else {
            Logger.background.debug("App not in background during maintenance, skipping")
            return
        }

        // STABILITY: Don't perform maintenance if we're cleaning up
        guard !isCleaningUp else {
            Logger.background.debug("Cleanup in progress, skipping maintenance")
            return
        }

        lastBackgroundActivity = Date()

        // Ensure we have active background tasks
        if backgroundTasks.isEmpty {
            Logger.background.debug("No active background tasks - creating new ones")
            startBackgroundTaskChain()
        }

        // Update motion manager if available
        if let motionManager = motionManager {
            // Trigger a background update in the motion manager
            motionManager.performBackgroundUpdate()
        }

        Logger.background.debug("Background maintenance - Active tasks: \(self.backgroundTasks.count)")
    }

    // MARK: - Smart Power Saving
    private func checkAndApplyPowerSaving() {
        guard isBackgroundTrackingActive else { return }

        let now = Date()

        // Track idle time
        if backgroundIdleStartTime == nil {
            backgroundIdleStartTime = now
            return
        }

        guard let idleStart = backgroundIdleStartTime else {
            backgroundIdleStartTime = now
            return
        }
        let idleTime = now.timeIntervalSince(idleStart)

        if idleTime > deepSleepThreshold && !powerSavingModeActive {
            enterDeepSleepMode()
        } else if idleTime > powerSavingThreshold && !powerSavingModeActive {
            enterPowerSavingMode()
        }
    }

    private func enterPowerSavingMode() {
        Logger.background.info("Entering power saving mode - reducing background activity")
        powerSavingModeActive = true

        // Reduce timer frequency from 10s to 30s
        backgroundTimer?.invalidate()
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performBackgroundMaintenance()
        }
    }

    private func enterDeepSleepMode() {
        Logger.background.info("Entering deep sleep mode - minimal background activity")

        // Stop maintenance timer completely
        backgroundTimer?.invalidate()
        backgroundTimer = nil

        // Let background tasks expire naturally, don't renew them
        Logger.background.info("Allowing background tasks to expire naturally")
    }

    // MARK: - Notification Handling
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppTermination),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func handleAppBackground() {
        Logger.background.info("App entering background - checking session state")
        isAppInBackground = true

        if let motionManager = motionManager,
           let currentSession = motionManager.currentSessionStore.currentSession,
           !motionManager.isPaused && !motionManager.sessionPaused {
            Logger.background.info("Active session found - starting background tracking")
            startBackgroundTracking()
        } else {
            Logger.background.info("No active session - staying in low-power mode")
            stopBackgroundTracking()
        }
    }
    
    @objc private func handleAppForeground() {
        // MONITORING: Start transition tracking
        let tracker = ForegroundTransitionMonitor.shared.startTransition(identifier: "EnhancedBackgroundManager")

        Logger.background.info("App entering foreground - immediate transition starting")
        Logger.background.info("Final background stats - Tasks created: \(self.totalTasksCreated), Active tasks: \(self.backgroundTasks.count)")

        // IMMEDIATE: Update flags (< 1ms) - NO DELAYS
        isAppInBackground = false
        isBackgroundTrackingActive = false
        isForegroundTransitioning = true

        backgroundIdleStartTime = nil
        powerSavingModeActive = false

        Logger.background.info("Power saving reset - returning to normal mode")

        tracker.recordComponent("State Flags Update")

        // IMMEDIATE: Stop all timers without delays
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        cancelTimerSourceSafely(&backgroundSource)
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        tracker.recordComponent("Timer Cleanup")

        // IMMEDIATE: Calculate total background time
        if let startTime = backgroundStartTime {
            totalBackgroundTime += Date().timeIntervalSince(startTime)
        }
        tracker.recordComponent("Background Time Calculation")

        // TIMEOUT PROTECTION: Set up timeout for cleanup operations
        let cleanupTimeoutTask = DispatchWorkItem { [weak self] in
            Logger.background.warning("Background cleanup timeout (1000ms) - forcing completion")
            self?.forceCleanupCompletion()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: cleanupTimeoutTask)

        // NON-BLOCKING: Dispatch cleanup to background queue immediately, avoid main actor during cleanup
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performImmediateBackgroundCleanup()
            DispatchQueue.main.async {
                cleanupTimeoutTask.cancel() // Cancel timeout if cleanup completes normally
                tracker.recordComponent("Background Task Cleanup")
            }
        }

        // IMMEDIATE: Update UI state synchronously
        updateUIStateImmediately()
        tracker.recordComponent("UI State Update")

        // Clear transition guard shortly after UI is responsive
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isForegroundTransitioning = false
            tracker.complete()
        }
    }
    
    @objc private func handleAppBecameActive() {
        Logger.background.debug("App became active")
        // STABILITY: Ensure we're not in background mode when app becomes active
        if isAppInBackground {
            Logger.background.warning("App became active but internal state was background - correcting")
            isAppInBackground = false
            isBackgroundTrackingActive = false
            cleanupAllBackgroundTasks()
        }
    }
    
    @objc private func handleAppResignActive() {
        Logger.background.debug("App will resign active")
        // This happens before going to background, but also during interruptions
        // Don't take action here, wait for actual background notification
    }
    
    @objc private func handleAppTermination() {
        Logger.background.info("App terminating - emergency cleanup")
        
        // Use Task to handle main actor isolation
        Task { @MainActor in
            // Force immediate cleanup without delays
            isBackgroundTrackingActive = false
            isAppInBackground = false
            
            backgroundTimer?.invalidate()
            backgroundTimer = nil
            cleanupTimer?.invalidate()
            cleanupTimer = nil
            
            // Force cleanup all tasks immediately
            for taskId in backgroundTasks {
                UIApplication.shared.endBackgroundTask(taskId)
            }
            backgroundTasks.removeAll()
            
            Logger.background.info("App termination cleanup completed")
        }
    }
    
    // MARK: - Safety Methods
    private func forceCleanupIfNeeded() {
        guard !backgroundTasks.isEmpty else { return }
        
        Logger.background.warning("Force cleanup triggered - cleaning up \(self.backgroundTasks.count) remaining tasks")
        
        // Force cleanup any remaining tasks immediately
        for taskId in backgroundTasks {
            UIApplication.shared.endBackgroundTask(taskId)
            Logger.background.debug("Force cleaned task")
        }
        backgroundTasks.removeAll()
        
        Logger.background.info("Force cleanup completed")
    }
    
    private func performAppStateHealthCheck() {
        let now = Date()
        guard now.timeIntervalSince(lastAppStateCheck) >= appStateCheckInterval else { return }
        
        lastAppStateCheck = now
        let currentState = UIApplication.shared.applicationState
        
        // If we think we're in background but iOS says we're not, stop everything
        if isAppInBackground && currentState != .background {
            Logger.background.warning("App state mismatch detected! Internal: background, iOS: \(currentState.description)")
            Logger.background.warning("Performing emergency shutdown")
            
            isAppInBackground = false
            isBackgroundTrackingActive = false
            
            backgroundTimer?.invalidate()
            backgroundTimer = nil
            
            cleanupAllBackgroundTasks()
        }
    }
    
    // MARK: - Immediate UI State Update
    @MainActor
    private func updateUIStateImmediately() {
        // This method is called immediately during foreground transition
        // to ensure UI responsiveness

        // Update published properties immediately
        backgroundTaskCount = 0
        lastBackgroundActivity = Date()

        // Notify motion manager of foreground transition
        if let motionManager = motionManager {
            // The motion manager will handle its own UI state updates
            // We just need to ensure it knows we're in foreground mode
            Logger.background.debug("Notifying motion manager of foreground transition")
        }

        Logger.background.debug("UI state updated immediately for foreground transition")
    }

    // MARK: - Timeout Protection
    @MainActor
    private func forceCleanupCompletion() {
        Logger.background.warning("Forcing background cleanup completion due to timeout")

        // Force cleanup any remaining tasks immediately
        let remainingTasks = backgroundTasks
        backgroundTasks.removeAll()
        backgroundTaskCount = 0

        // End remaining tasks on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .utility).async {
            for taskId in remainingTasks {
                UIApplication.shared.endBackgroundTask(taskId)
            }

            DispatchQueue.main.async {
                Logger.background.info("Force cleanup completed - ended \(remainingTasks.count) remaining tasks")
            }
        }

        // Ensure UI state is consistent
        isBackgroundTrackingActive = false
        isAppInBackground = false

        // Force UI update
        objectWillChange.send()
    }
    
    // MARK: - Status Methods
    func getBackgroundStatus() -> String {
        if isBackgroundTrackingActive {
            return "Enhanced tracking active (\(backgroundTasks.count) tasks)"
        } else {
            return "Foreground mode"
        }
    }
    
    func getBackgroundTimeRemaining() -> TimeInterval {
        return UIApplication.shared.backgroundTimeRemaining
    }
    
    // MARK: - Cleanup
    deinit {
        Logger.background.debug("EnhancedBackgroundManager deinit - performing final cleanup")
        
        NotificationCenter.default.removeObserver(self)
        
        // Stop all timers
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        
        // Force cleanup all background tasks immediately in deinit
        for taskId in backgroundTasks {
            UIApplication.shared.endBackgroundTask(taskId)
        }
        backgroundTasks.removeAll()
        
        Logger.background.debug("EnhancedBackgroundManager deinit completed")
    }
}
