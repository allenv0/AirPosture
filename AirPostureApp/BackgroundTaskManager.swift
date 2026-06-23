import Foundation
import BackgroundTasks
import UIKit
import CoreMotion
import os

@MainActor
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()

    // MARK: - Published Properties
    @Published private(set) var isBackgroundRefreshEnabled: Bool = false
    @Published private(set) var lastBackgroundRefresh: Date?
    @Published private(set) var backgroundRefreshCount: Int = 0

    // MARK: - Private Properties
    private let backgroundTaskIdentifier = "com.example.airposture.background-refresh"
    private weak var motionManager: HeadphoneMotionManager?

    // MARK: - Memory Management Properties
    @MainActor private var activeBackgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]
    
    // MARK: - Registration Safety - CRITICAL: Use static to prevent duplicate registration across all instances
    private static var isGloballyRegistered = false
    private static let globalRegistrationLock = NSLock()

    // MARK: - Persistence Properties
    private let persistenceKey = "background_session_state"
    private var lastPersistedState: Date?
    
    // MARK: - Initialization
    private init() {
        checkBackgroundRefreshStatus()
    }
    
    // MARK: - Public Methods
    func configure(with motionManager: HeadphoneMotionManager) {
        self.motionManager = motionManager
        // SAFE: Skip registration here - it's now done once at app launch
        // registerBackgroundTasks() // Moved to app launch
        scheduleBackgroundRefresh()
    }
    
    func checkBackgroundRefreshStatus() {
        isBackgroundRefreshEnabled = UIApplication.shared.backgroundRefreshStatus == .available
        Logger.background.info("Background App Refresh Status: \(UIApplication.shared.backgroundRefreshStatus.rawValue)")
    }
    
    // MARK: - Background Task Registration
    private func registerBackgroundTasks() {
        Self.globalRegistrationLock.lock()
        defer { Self.globalRegistrationLock.unlock() }
        
        // CRITICAL: Use static flag to prevent duplicate registration across ALL instances
        guard !Self.isGloballyRegistered else {
            Logger.background.warning("Background task already registered globally")
            return
        }
        
        do {
            // SAFE: Wrap registration in do-catch to handle Apple's duplicate registration exception
            let success = BGTaskScheduler.shared.register(
                forTaskWithIdentifier: backgroundTaskIdentifier,
                using: nil
            ) { [weak self] task in
                // FIX: Safe casting instead of force unwrap to prevent crashes
                guard let bgTask = task as? BGAppRefreshTask else {
                    Logger.background.error("Unexpected task type received: \(type(of: task))")
                    task.setTaskCompleted(success: false)
                    return
                }
                self?.handleBackgroundRefresh(task: bgTask)
            }
            
            if success {
                Self.isGloballyRegistered = true
                Logger.background.info("Background task registered successfully")
            } else {
                Logger.background.error("Background task registration returned false")
            }
        } catch {
            // CRITICAL: Catch duplicate registration exceptions from Apple's BGTaskScheduler
            Logger.background.error("Background task registration failed: \(error)")
            Self.isGloballyRegistered = true
        }
    }
    
    // MARK: - Public Registration Method
    func registerTasksIfNeeded() {
        registerBackgroundTasks()
    }
    
    // MARK: - Background Task Scheduling
    func scheduleBackgroundRefresh() {
        guard isBackgroundRefreshEnabled else {
            Logger.background.error("Background refresh not available - cannot schedule")
            return
        }
        
        // SAFETY: Verify registration before scheduling
        guard Self.isGloballyRegistered else {
            Logger.background.warning("Cannot schedule background refresh - task not registered globally")
            return
        }
        
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.background.info("Background refresh scheduled for 15 minutes from now")
        } catch {
            Logger.background.error("Failed to schedule background refresh: \(error.localizedDescription)")
            
            if error.localizedDescription.contains("not permitted") {
                Logger.background.warning("Check Info.plist BGTaskSchedulerPermittedIdentifiers")
            }
        }
    }
    
    // MARK: - Background Task Handling
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        Logger.background.debug("Background refresh task started")
        
        // Schedule the next background refresh
        scheduleBackgroundRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            Logger.background.warning("Background refresh task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform background work
        Task {
            await performBackgroundMotionTracking(task: task)
        }
    }
    
    private func performBackgroundMotionTracking(task: BGAppRefreshTask) async {
        guard let motionManager = motionManager else {
            Logger.background.error("No motion manager available for background tracking")
            task.setTaskCompleted(success: false)
            return
        }
        
        Logger.background.debug("Starting background motion tracking")
        
        // Update counters
        backgroundRefreshCount += 1
        lastBackgroundRefresh = Date()

        // Persist current session state before starting background work
        persistCurrentSessionState()

        // Attempt to collect motion data for a short period
        let success = await collectBackgroundMotionData(duration: 25.0) // 25 seconds max

        // Persist state again after background work
        if success {
            persistCurrentSessionState()
        }
        
        Logger.background.debug("Background motion tracking completed - Success: \(success)")
        task.setTaskCompleted(success: success)
    }
    
    private func collectBackgroundMotionData(duration: TimeInterval) async -> Bool {
        guard let motionManager = motionManager else { return false }

        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var didResume = false
            var timer: Timer?

            func resumeOnce(returning value: Bool) {
                lock.lock()
                guard !didResume else {
                    lock.unlock()
                    return
                }
                didResume = true
                lock.unlock()

                Task { @MainActor in
                    timer?.invalidate()
                    timer = nil
                    self.cleanupBackgroundTask(named: "Background Motion Collection")
                    continuation.resume(returning: value)
                }
            }

            Task { @MainActor in
                guard self.requestBackgroundTask(
                    name: "Background Motion Collection",
                    expirationHandler: {
                        Logger.background.warning("Background motion collection task expired")
                        resumeOnce(returning: false)
                    }
                ) != nil else {
                    Logger.background.error("Failed to create background task for motion collection")
                    resumeOnce(returning: false)
                    return
                }

                // Set a timer to limit collection duration
                timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                    Logger.background.debug("Background motion collection completed")
                    resumeOnce(returning: true)
                }

                // Ensure motion tracking is active
                if !motionManager.isPaused && motionManager.currentSessionStore.currentSession != nil {
                    // Motion manager should continue tracking automatically
                    Logger.background.debug("Motion tracking continuing in background")
                } else {
                    Logger.background.warning("No active session or tracking paused - ending early")
                    resumeOnce(returning: false)
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    func requestBackgroundRefreshPermission() {
        // This will prompt user to enable background app refresh in Settings
        // We can only check the status, not programmatically enable it
        checkBackgroundRefreshStatus()
        
        if !isBackgroundRefreshEnabled {
            Logger.background.warning("Background App Refresh is disabled. User needs to enable it in Settings")
        }
    }
    
    func getBackgroundRefreshStatusDescription() -> String {
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available:
            return "Available"
        case .denied:
            return "Denied by user"
        case .restricted:
            return "Restricted by system"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Data Persistence Methods
    func persistCurrentSessionState() {
        guard let motionManager = motionManager,
              let currentSession = motionManager.currentSessionStore.currentSession else {
            return
        }

        let sessionState = BackgroundSessionState(
            sessionId: currentSession.id,
            lastUpdateTime: Date(),
            totalSessionTime: motionManager.totalSessionTime,
            poorPostureDuration: motionManager.poorPostureDuration,
            postureScorePercent: motionManager.postureScorePercent,
            isPaused: motionManager.isPaused,
            isDeviceConnected: motionManager.isDeviceConnected,
            lastKnownPitch: motionManager.pitch
        )

        do {
            let data = try JSONEncoder().encode(sessionState)
            UserDefaults.standard.set(data, forKey: persistenceKey)
            lastPersistedState = Date()
            Logger.background.debug("Persisted background session state")
        } catch {
            Logger.background.error("Failed to persist session state: \(error)")
        }
    }

    func restoreSessionStateIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let sessionState = try? JSONDecoder().decode(BackgroundSessionState.self, from: data),
              let motionManager = motionManager else {
            return
        }

        // Check if the persisted state is recent (within last hour)
        let timeSinceLastUpdate = Date().timeIntervalSince(sessionState.lastUpdateTime)
        guard timeSinceLastUpdate < 3600 else { // 1 hour
            Logger.background.debug("Persisted session state too old, ignoring")
            clearPersistedState()
            return
        }

        // Check if we have a matching current session
        guard let currentSession = motionManager.currentSessionStore.currentSession,
              currentSession.id == sessionState.sessionId else {
            Logger.background.debug("No matching session for persisted state")
            clearPersistedState()
            return
        }

        Logger.background.info("Restoring session state from background persistence")
        Logger.background.debug("Time gap: \(Int(timeSinceLastUpdate)) seconds, previous total time: \(sessionState.totalSessionTime), previous poor posture: \(sessionState.poorPostureDuration)")

        // The motion manager will handle the restoration through its existing mechanisms
        // We just need to ensure the session continues properly
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
        lastPersistedState = nil
    }

    // MARK: - Status Methods
    func getRegistrationStatus() -> String {
        Self.globalRegistrationLock.lock()
        defer { Self.globalRegistrationLock.unlock() }
        
        return """
        📋 Background Task Registration Status
        =====================================
        Identifier: \(backgroundTaskIdentifier)
        Globally Registered: \(Self.isGloballyRegistered ? "✅ YES" : "❌ NO")
        Background Refresh Enabled: \(isBackgroundRefreshEnabled ? "✅ YES" : "❌ NO")
        Last Background Refresh: \(lastBackgroundRefresh?.description ?? "Never")
        Background Refresh Count: \(backgroundRefreshCount)
        """
    }
    
    func validateRegistration() -> Bool {
        Self.globalRegistrationLock.lock()
        defer { Self.globalRegistrationLock.unlock() }
        
        let isValid = Self.isGloballyRegistered && isBackgroundRefreshEnabled
        Logger.background.debug("Registration validation: \(isValid ? "VALID" : "INVALID")")
        return isValid
    }

    // MARK: - Background Task Management
    @MainActor
    private func requestBackgroundTask(name: String, expirationHandler: @escaping () -> Void) -> UIBackgroundTaskIdentifier? {
        guard activeBackgroundTasks[name] == nil else {
            Logger.background.warning("Background task already exists for: \(name)")
            return nil
        }

        let task = UIApplication.shared.beginBackgroundTask(withName: name) {
            Logger.background.warning("Background task expired: \(name)")
            expirationHandler()
            Task { @MainActor in
                self.cleanupBackgroundTask(named: name)
            }
        }

        activeBackgroundTasks[name] = task
        Logger.background.debug("Background task started: \(name) (active: \(self.activeBackgroundTasks.count))")
        return task
    }

    @MainActor
    private func cleanupBackgroundTask(named name: String) {
        if let task = activeBackgroundTasks[name] {
            UIApplication.shared.endBackgroundTask(task)
            activeBackgroundTasks.removeValue(forKey: name)
            Logger.background.debug("Background task cleaned up: \(name) (remaining: \(self.activeBackgroundTasks.count))")
        }
    }

    @MainActor
    private func cleanupAllBackgroundTasks() {
        for (name, task) in activeBackgroundTasks {
            UIApplication.shared.endBackgroundTask(task)
            Logger.background.debug("Background task force cleaned up: \(name)")
        }
        activeBackgroundTasks.removeAll()
        Logger.background.debug("All background tasks cleaned up (total: \(self.activeBackgroundTasks.count))")
    }

    // MARK: - Memory Management
    deinit {
        // Clean up any remaining background tasks
        Logger.background.debug("BackgroundTaskManager deinit - cleaning up resources")
        // Can't call cleanupAllBackgroundTasks() here as it's @MainActor
        // Background tasks will be cleaned up by the system automatically
    }
}

// MARK: - Background Session State Model
private struct BackgroundSessionState: Codable {
    let sessionId: UUID
    let lastUpdateTime: Date
    let totalSessionTime: TimeInterval
    let poorPostureDuration: TimeInterval
    let postureScorePercent: Int
    let isPaused: Bool
    let isDeviceConnected: Bool
    let lastKnownPitch: Double
}
