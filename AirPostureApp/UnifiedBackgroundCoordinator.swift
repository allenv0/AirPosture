import os
import Foundation
import AVFoundation
import UserNotifications
import BackgroundTasks
import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
typealias PlatformBackgroundTaskIdentifier = UIBackgroundTaskIdentifier
#else
typealias PlatformBackgroundTaskIdentifier = String
#endif

@MainActor
protocol BackgroundMotionProvider: AnyObject {
    var isPaused: Bool { get }
    var sessionPaused: Bool { get }
    var isDeviceConnected: Bool { get }
    var hasActiveSession: Bool { get }
    func performBackgroundUpdate()
    func handleCoordinatorDidEnterBackground()
    func handleCoordinatorWillEnterForeground()
}

actor BackgroundResourcePool {
    private let maxConcurrentTasks: Int
    private let maxTasksPerSession: Int

    private var activeTasks: Set<PlatformBackgroundTaskIdentifier> = []
    private var tasksCreatedThisSession: Int = 0
    private var isPoolActive: Bool = false

    private var totalTasksCreated: Int = 0
    private var totalTasksExpired: Int = 0

    init(maxConcurrentTasks: Int = 2, maxTasksPerSession: Int = 50) {
        self.maxConcurrentTasks = maxConcurrentTasks
        self.maxTasksPerSession = maxTasksPerSession
    }

    func canCreateTask() -> Bool {
        return activeTasks.count < maxConcurrentTasks &&
               tasksCreatedThisSession < maxTasksPerSession &&
               isPoolActive
    }

    #if os(iOS)
    func addTask(_ taskId: PlatformBackgroundTaskIdentifier) -> Bool {
        guard canCreateTask() else {
            Logger.background.warning("ResourcePool: Cannot add task - limits reached (active: \(self.activeTasks.count), session: \(self.tasksCreatedThisSession))")
            return false
        }

        activeTasks.insert(taskId)
        tasksCreatedThisSession += 1
        totalTasksCreated += 1

        Logger.background.debug("ResourcePool: Added task \(taskId.rawValue) (active: \(self.activeTasks.count)/\(self.maxConcurrentTasks), session: \(self.tasksCreatedThisSession)/\(self.maxTasksPerSession))")
        return true
    }
    #else
    func addTask(_ taskId: PlatformBackgroundTaskIdentifier) -> Bool {
        guard canCreateTask() else {
            Logger.background.warning("ResourcePool: Cannot add task - limits reached (active: \(self.activeTasks.count), session: \(self.tasksCreatedThisSession))")
            return false
        }

        activeTasks.insert(taskId)
        tasksCreatedThisSession += 1
        totalTasksCreated += 1

        Logger.background.debug("ResourcePool: Added task \(String(taskId.suffix(8))) (active: \(self.activeTasks.count)/\(self.maxConcurrentTasks), session: \(self.tasksCreatedThisSession)/\(self.maxTasksPerSession))")
        return true
    }
    #endif

    func removeTask(_ taskId: PlatformBackgroundTaskIdentifier) {
        activeTasks.remove(taskId)
        totalTasksExpired += 1
        #if os(iOS)
        Logger.background.debug("ResourcePool: Removed task \(taskId.rawValue) (active: \(self.activeTasks.count))")
        #else
        Logger.background.debug("ResourcePool: Removed task \(String(taskId.suffix(8))) (active: \(self.activeTasks.count))")
        #endif
    }

    func activate() {
        isPoolActive = true
        tasksCreatedThisSession = 0
        Logger.background.info("ResourcePool: Activated for new session")
    }

    func deactivate() {
        isPoolActive = false
        Logger.background.info("ResourcePool: Deactivated")
    }

    func getAllActiveTasks() -> Set<PlatformBackgroundTaskIdentifier> {
        return activeTasks
    }

    func getStatistics() -> (active: Int, sessionTotal: Int, totalCreated: Int, totalExpired: Int) {
        return (active: activeTasks.count, sessionTotal: tasksCreatedThisSession, totalCreated: totalTasksCreated, totalExpired: totalTasksExpired)
    }

    #if os(iOS)
    func cleanupAllTasks() {
        let tasksToCleanup = Array(activeTasks)
        activeTasks.removeAll()

        for taskId in tasksToCleanup {
            UIApplication.shared.endBackgroundTask(taskId)
        }

        Logger.background.debug("ResourcePool: Cleaned up \(tasksToCleanup.count) tasks")
    }
    #else
    func cleanupAllTasks() {
        let tasksToCleanup = Array(activeTasks)
        activeTasks.removeAll()

        Logger.background.debug("ResourcePool: Cleaned up \(tasksToCleanup.count) tasks")
    }
    #endif
}

@MainActor
class UnifiedBackgroundCoordinator: ObservableObject {
    static let shared = UnifiedBackgroundCoordinator()

    @Published private(set) var isTrackingActive: Bool = false
    @Published private(set) var activeTaskCount: Int = 0
    @Published private(set) var connectionStatus: String = "Ready"
    @Published private(set) var sessionStatistics: String = "No session"

    private let resourcePool = BackgroundResourcePool()
    private let audioSessionManager = AudioSessionManager()
    private let crashDetector = CrashDetector()

    private var currentAppLifecycleState: AppLifecycleState = .foreground
    private var sessionStartTime: Date?
    private var lastMaintenanceTime: Date?

    private weak var motionProvider: BackgroundMotionProvider?

    private var maintenanceTimer: Timer?
    private let maintenanceInterval: TimeInterval = 15.0

    private init() {
        setupNotificationObservers()
        Task {
            await crashDetector.enable()
        }
    }

    func configure(with provider: BackgroundMotionProvider) {
        self.motionProvider = provider
        Task {
            await audioSessionManager.configure()
        }
        Logger.background.info("UnifiedBackgroundCoordinator configured with typed provider")
    }

    var appLifecycleState: AppLifecycleState {
        currentAppLifecycleState
    }

    func startBackgroundTracking() async {
        guard !isTrackingActive else {
            Logger.background.warning("Background tracking already active")
            return
        }

        guard await validateTrackingPreconditions() else {
            Logger.background.warning("Precondition validation failed - not starting background tracking")
            return
        }

        Logger.background.info("Starting background tracking")

        await resourcePool.activate()
        await audioSessionManager.enableBackgroundAudio()

        isTrackingActive = true
        sessionStartTime = Date()
        lastMaintenanceTime = Date()

        startMaintenanceCycle()
        await createInitialBackgroundTasks()
        await updateTrackingStatus()

        let stats = await resourcePool.getStatistics()
        Logger.background.info("Background tracking started - Pool active: \(stats.active), session: \(stats.sessionTotal)")
    }

    func stopBackgroundTracking() async {
        guard isTrackingActive else {
            Logger.background.warning("Background tracking not active")
            return
        }

        Logger.background.info("Stopping background tracking")

        isTrackingActive = false

        maintenanceTimer?.invalidate()
        maintenanceTimer = nil

        await audioSessionManager.disableBackgroundAudio()
        await performImmediateCleanup()
        await updateTrackingStatus()

        Logger.background.info("Background tracking stopped")
    }

    #if os(iOS)
    @objc private func handleAppBackground() async {
        let transitionStartTime = Date()
        Logger.background.info("App entering background - coordinator handling")

        currentAppLifecycleState = .background

        if shouldEnableBackgroundTracking() {
            await startBackgroundTracking()
        } else {
            Logger.background.info("Background tracking not needed - staying in low power mode")
            await stopBackgroundTracking()
        }

        motionProvider?.handleCoordinatorDidEnterBackground()

        let transitionTime = Date().timeIntervalSince(transitionStartTime) * 1000
        Logger.background.debug("Background transition completed in \(String(format: "%.1f", transitionTime))ms")
    }

    @objc private func handleAppForeground() async {
        let transitionStartTime = Date()
        Logger.background.info("App entering foreground - immediate transition")

        currentAppLifecycleState = .foreground

        motionProvider?.handleCoordinatorWillEnterForeground()

        await stopBackgroundTracking()

        Task.detached(priority: .utility) { [weak self] in
            await self?.performBackgroundCleanup()
        }

        let transitionTime = Date().timeIntervalSince(transitionStartTime) * 1000
        Logger.background.debug("Foreground transition completed in \(String(format: "%.1f", transitionTime))ms")
    }
    #else
    private func handleAppBackground() async {
        Logger.background.info("macOS app entering background")
        currentAppLifecycleState = .background

        if shouldEnableBackgroundTracking() {
            await startBackgroundTracking()
        } else {
            await stopBackgroundTracking()
        }

        motionProvider?.handleCoordinatorDidEnterBackground()
    }

    private func handleAppForeground() async {
        Logger.background.info("macOS app entering foreground")
        currentAppLifecycleState = .foreground

        motionProvider?.handleCoordinatorWillEnterForeground()

        await stopBackgroundTracking()

        Task.detached(priority: .utility) { [weak self] in
            await self?.performBackgroundCleanup()
        }
    }
    #endif

    private func shouldEnableBackgroundTracking() -> Bool {
        guard let provider = motionProvider else { return false }
        return provider.hasActiveSession && !provider.isPaused && !provider.sessionPaused
    }

    private func createInitialBackgroundTasks() async {
        let taskCount = min(2, await resourcePool.getStatistics().active + 1)

        for i in 0..<taskCount {
            let delay = Double(i) * 1.0
            Task.detached(priority: .background) { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await self?.createBackgroundTask()
            }
        }
    }

    #if os(iOS)
    private func createBackgroundTask() async {
        guard isTrackingActive else { return }

        guard await resourcePool.canCreateTask() else {
            Logger.background.warning("Cannot create task - resource limits reached")
            return
        }

        var taskId: PlatformBackgroundTaskIdentifier = .invalid
        taskId = UIApplication.shared.beginBackgroundTask(withName: "UnifiedCoordinator Tracking") { [weak self] in
            Task { [weak self] in
                await self?.handleTaskExpiration(taskId: taskId)
            }
        }

        guard taskId != .invalid else {
            Logger.background.error("Failed to create background task")
            return
        }

        guard await resourcePool.addTask(taskId) else {
            UIApplication.shared.endBackgroundTask(taskId)
            return
        }

        await updateTrackingStatus()

        Task.detached(priority: .background) { [weak self] in
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            await self?.renewBackgroundTask(taskId: taskId)
        }
    }
    #else
    private func createBackgroundTask() async {
        guard isTrackingActive else { return }

        guard await resourcePool.canCreateTask() else {
            Logger.background.warning("Cannot create task - resource limits reached")
            return
        }

        let taskId = "background_task_\(UUID().uuidString)"

        guard await resourcePool.addTask(taskId) else {
            return
        }

        await updateTrackingStatus()

        Task.detached(priority: .background) { [weak self] in
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            await self?.renewBackgroundTask(taskId: taskId)
        }
    }
    #endif

    #if os(iOS)
    private func renewBackgroundTask(taskId: PlatformBackgroundTaskIdentifier) async {
        await resourcePool.removeTask(taskId)
        UIApplication.shared.endBackgroundTask(taskId)

        if isTrackingActive {
            await createBackgroundTask()
        }

        await updateTrackingStatus()
    }

    private func handleTaskExpiration(taskId: PlatformBackgroundTaskIdentifier) async {
        Logger.background.warning("Task expiration: \(taskId.rawValue)")
        await crashDetector.recordTaskExpiration()

        await resourcePool.removeTask(taskId)
        UIApplication.shared.endBackgroundTask(taskId)

        if isTrackingActive {
            await createBackgroundTask()
        }

        await updateTrackingStatus()
    }
    #else
    private func renewBackgroundTask(taskId: PlatformBackgroundTaskIdentifier) async {
        await resourcePool.removeTask(taskId)

        if isTrackingActive {
            await createBackgroundTask()
        }

        await updateTrackingStatus()
    }

    private func handleTaskExpiration(taskId: PlatformBackgroundTaskIdentifier) async {
        Logger.background.warning("Task expiration: \(String(taskId.suffix(8)))")
        await crashDetector.recordTaskExpiration()

        await resourcePool.removeTask(taskId)

        if isTrackingActive {
            await createBackgroundTask()
        }

        await updateTrackingStatus()
    }
    #endif

    private func startMaintenanceCycle() {
        maintenanceTimer?.invalidate()

        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: maintenanceInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performMaintenance()
            }
        }

        Logger.background.debug("Maintenance cycle started (\(self.maintenanceInterval)s interval)")
    }

    private func performMaintenance() async {
        guard isTrackingActive else { return }

        lastMaintenanceTime = Date()

        let stats = await resourcePool.getStatistics()
        if stats.active < 1 {
            Logger.background.warning("No active tasks - creating new task")
            await createBackgroundTask()
        }

        motionProvider?.performBackgroundUpdate()

        await updateTrackingStatus()

        Logger.background.debug("Maintenance completed - Active tasks: \(stats.active)")
    }

    private func performImmediateCleanup() async {
        await resourcePool.deactivate()
        await resourcePool.cleanupAllTasks()
        await updateTrackingStatus()
    }

    private func performBackgroundCleanup() async {
        await resourcePool.cleanupAllTasks()
        await audioSessionManager.performBackgroundCleanup()
    }

    private func validateTrackingPreconditions() async -> Bool {
        guard currentAppLifecycleState == .background else {
            Logger.background.warning("Not in background state")
            return false
        }

        guard motionProvider != nil else {
            Logger.background.warning("No motion provider")
            return false
        }

        let stats = await resourcePool.getStatistics()
        if stats.sessionTotal >= 50 {
            Logger.background.warning("Session task limit reached (\(stats.sessionTotal))")
            return false
        }

        if await crashDetector.shouldPreventTracking() {
            Logger.background.warning("Crash detector preventing tracking")
            return false
        }

        return true
    }

    private func updateTrackingStatus() async {
        let stats = await resourcePool.getStatistics()

        activeTaskCount = stats.active

        if isTrackingActive {
            connectionStatus = "Background tracking active (\(stats.active) tasks)"
            sessionStatistics = "Session: \(stats.sessionTotal)/50, Total: \(stats.totalCreated)"
        } else {
            connectionStatus = currentAppLifecycleState == .background ? "Background ready" : "Foreground mode"
            sessionStatistics = "No active session"
        }
    }

    func getComprehensiveStatus() async -> String {
        let stats = await resourcePool.getStatistics()
        let crashInfo = await crashDetector.getStatus()
        let audioInfo = await audioSessionManager.getStatus()

        return """
        Coordinator Status:
        - State: \(isTrackingActive ? "Active" : "Inactive")
        - App State: \(currentAppLifecycleState)
        - Active Tasks: \(stats.active)/\(stats.sessionTotal)
        - Audio: \(audioInfo)
        - Crash Detection: \(crashInfo)
        """
    }

    private func setupNotificationObservers() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBackgroundNotification),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appForegroundNotification),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }

    #if os(iOS)
    @objc private func appBackgroundNotification() {
        Task {
            await handleAppBackground()
        }
    }

    @objc private func appForegroundNotification() {
        Task {
            await handleAppForeground()
        }
    }
    #endif

    deinit {
        Logger.background.debug("UnifiedBackgroundCoordinator deinit")

        NotificationCenter.default.removeObserver(self)
        maintenanceTimer?.invalidate()

        Task {
            await performImmediateCleanup()
        }
    }
}

actor AudioSessionManager {
    private var audioPlayer: AVAudioPlayer?
    private var isSessionActive: Bool = false

    func configure() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true)
            isSessionActive = true
            Logger.background.info("AudioSession: Configured")
        } catch {
            Logger.background.error("AudioSession: Configuration failed: \(error)")
        }
        #else
        Logger.background.debug("AudioSession: macOS - no configuration needed")
        isSessionActive = true
        #endif
    }

    func enableBackgroundAudio() {
        guard isSessionActive else { return }

        #if os(iOS)
        let silentAudioData = createSilentAudioData()

        do {
            audioPlayer = try AVAudioPlayer(data: silentAudioData)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.0
            audioPlayer?.play()
            Logger.background.info("AudioSession: Background audio enabled")
        } catch {
            Logger.background.error("AudioSession: Failed to enable background audio: \(error)")
        }
        #else
        Logger.background.debug("AudioSession: macOS - background audio not needed")
        #endif
    }

    func disableBackgroundAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        Logger.background.info("AudioSession: Background audio disabled")
    }

    func performBackgroundCleanup() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    func getStatus() -> String {
        return audioPlayer?.isPlaying == true ? "Active" : "Inactive"
    }

    #if os(iOS)
    private func createSilentAudioData() -> Data {
        return SilentAudioGenerator.createSilentWAVData()
    }
    #endif
}

actor CrashDetector {
    private var taskExpirations: [Date] = []
    private var crashDetectionEnabled: Bool = false
    private let maxExpirationsPerMinute = 5
    private let maxCrashScore = 100

    func enable() {
        crashDetectionEnabled = true
        Logger.background.info("CrashDetector: Enabled")
    }

    func recordTaskExpiration() {
        guard crashDetectionEnabled else { return }

        let now = Date()
        taskExpirations.append(now)

        taskExpirations.removeAll { $0.timeIntervalSince(now) > 60 }

        if taskExpirations.count > maxExpirationsPerMinute {
            Logger.background.warning("CrashDetector: High task expiration rate detected (\(self.taskExpirations.count)/min)")
        }
    }

    func shouldPreventTracking() -> Bool {
        guard crashDetectionEnabled else { return false }

        let recentExpirations = taskExpirations.filter {
            $0.timeIntervalSince(Date()) <= 60
        }

        let crashScore = recentExpirations.count * 20

        return crashScore >= maxCrashScore
    }

    func getStatus() -> String {
        let recentExpirations = taskExpirations.filter {
            $0.timeIntervalSince(Date()) <= 60
        }

        return "\(recentExpirations.count)/\(maxExpirationsPerMinute) expirations/min"
    }
}

enum AppLifecycleState {
    case foreground
    case background
    case transitioning
}
