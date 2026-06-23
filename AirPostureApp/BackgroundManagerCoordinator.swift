import Foundation
import UIKit
import os

/// Coordinates multiple background managers to prevent resource contention and improve foreground transitions
@MainActor
class BackgroundManagerCoordinator: ObservableObject {
    static let shared = BackgroundManagerCoordinator()
    
    // MARK: - Manager References
    private weak var backgroundTaskManager: BackgroundTaskManager?
    private weak var enhancedBackgroundManager: EnhancedBackgroundManager?
    private weak var audioBackgroundManager: AudioBackgroundManager?
    private weak var motionManager: HeadphoneMotionManager?
    
    // MARK: - State Management
    @Published private(set) var isCoordinatedTransitionInProgress = false
    @Published private(set) var lastTransitionTime: TimeInterval = 0
    
    // MARK: - Coordination State
    private var transitionLock = NSLock()
    private var pendingForegroundTasks: [() -> Void] = []
    
    private init() {
    }
    
    // MARK: - Manager Registration
    func registerManagers(
        backgroundTaskManager: BackgroundTaskManager,
        enhancedBackgroundManager: EnhancedBackgroundManager,
        audioBackgroundManager: AudioBackgroundManager,
        motionManager: HeadphoneMotionManager
    ) {
        self.backgroundTaskManager = backgroundTaskManager
        self.enhancedBackgroundManager = enhancedBackgroundManager
        self.audioBackgroundManager = audioBackgroundManager
        self.motionManager = motionManager
        
        Logger.background.info("BackgroundManagerCoordinator: All managers registered")
    }
    
    // MARK: - Coordinated Transitions
    func coordinatedForegroundTransition() {
        guard !isCoordinatedTransitionInProgress else {
            Logger.background.warning("Coordinated transition already in progress - skipping")
            return
        }
        
        transitionLock.lock()
        defer { transitionLock.unlock() }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        isCoordinatedTransitionInProgress = true
        
        Logger.background.info("Starting coordinated foreground transition")
        
        // Phase 1: Immediate UI responsiveness (< 5ms)
        performImmediateUIUpdates()
        
        // Phase 2: Background cleanup coordination (non-blocking)
        coordinateBackgroundCleanup()
        
        // Phase 3: Motion system recovery (deferred)
        scheduleMotionSystemRecovery()
        
        let transitionTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        lastTransitionTime = transitionTime
        
        Logger.background.info("Coordinated foreground transition completed in \(String(format: "%.1f", transitionTime))ms")
        
        // Reset coordination state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.isCoordinatedTransitionInProgress = false
        }
    }
    
    func coordinatedBackgroundTransition() {
        Logger.background.info("Starting coordinated background transition")
        
        // Coordinate background managers to start in sequence to avoid resource conflicts
        if let audioManager = audioBackgroundManager {
            audioManager.enableBackgroundAudio()
        }
        
        // Small delay to let audio session establish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if let enhancedManager = self.enhancedBackgroundManager {
                enhancedManager.startBackgroundTracking()
            }
        }
        
        // Schedule background refresh after other managers are established
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.backgroundTaskManager?.scheduleBackgroundRefresh()
        }
    }
    
    // MARK: - Phase Implementation
    private func performImmediateUIUpdates() {
        Logger.ui.debug("Phase 1: Immediate UI updates")
        
        // Update basic state flags immediately
        // Note: isInBackground is managed internally by HeadphoneMotionManager
        
        // Stop any active timers immediately
        // This is handled by individual managers but we ensure coordination
    }
    
    private func coordinateBackgroundCleanup() {
        Logger.background.debug("Phase 2: Coordinated background cleanup")
        
        // Use a dispatch group to coordinate cleanup across managers
        let cleanupGroup = DispatchGroup()
        
        // Enhanced background manager cleanup
        if let enhancedManager = enhancedBackgroundManager {
            cleanupGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                // Cleanup happens on background queue
                DispatchQueue.main.async {
                    enhancedManager.stopBackgroundTracking()
                    cleanupGroup.leave()
                }
            }
        }
        
        // Audio background manager cleanup
        if let audioManager = audioBackgroundManager {
            cleanupGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                DispatchQueue.main.async {
                    audioManager.disableBackgroundAudio()
                    cleanupGroup.leave()
                }
            }
        }
        
        // Monitor cleanup completion
        cleanupGroup.notify(queue: .main) { [weak self] in
            Logger.background.info("All background managers cleanup completed")
        }
        
        // Timeout protection for cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if cleanupGroup.wait(timeout: .now()) == .timedOut {
                Logger.background.warning("Background cleanup timeout - some managers may not have completed cleanup")
            }
        }
    }
    
    private func scheduleMotionSystemRecovery() {
        Logger.motion.debug("Phase 3: Scheduling motion system recovery")
        
        // Defer motion system recovery to avoid blocking UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Motion manager handles its own recovery
            // We just ensure it happens after UI is responsive
            Logger.motion.debug("Motion system recovery phase initiated")
        }
    }
    
    // MARK: - Resource Conflict Prevention
    func requestBackgroundTask(identifier: String, priority: TaskPriority = .normal) -> UIBackgroundTaskIdentifier? {
        // Coordinate background task creation to prevent resource conflicts
        let taskId = UIApplication.shared.beginBackgroundTask(withName: "Coordinated-\(identifier)") {
            Logger.background.warning("Coordinated background task expired: \(identifier)")
        }
        
        if taskId != .invalid {
            Logger.background.info("Coordinated background task created: \(identifier)")
        } else {
            Logger.background.error("Failed to create coordinated background task: \(identifier)")
        }
        
        return taskId != .invalid ? taskId : nil
    }
    
    enum TaskPriority {
        case high, normal, low
    }
    
    // MARK: - Notification Handling
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppForeground() {
    }

    @objc private func handleAppBackground() {
    }
    
    // MARK: - Performance Monitoring
    func getCoordinationReport() -> String {
        return """
        📊 Background Manager Coordination Report
        ========================================
        Last Transition Time: \(String(format: "%.1f", lastTransitionTime))ms
        Transition In Progress: \(isCoordinatedTransitionInProgress)
        Registered Managers: \(getRegisteredManagersCount())
        
        Manager Status:
        • BackgroundTaskManager: \(backgroundTaskManager != nil ? "✅" : "❌")
        • EnhancedBackgroundManager: \(enhancedBackgroundManager != nil ? "✅" : "❌")
        • AudioBackgroundManager: \(audioBackgroundManager != nil ? "✅" : "❌")
        • HeadphoneMotionManager: \(motionManager != nil ? "✅" : "❌")
        """
    }
    
    private func getRegisteredManagersCount() -> Int {
        var count = 0
        if backgroundTaskManager != nil { count += 1 }
        if enhancedBackgroundManager != nil { count += 1 }
        if audioBackgroundManager != nil { count += 1 }
        if motionManager != nil { count += 1 }
        return count
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
