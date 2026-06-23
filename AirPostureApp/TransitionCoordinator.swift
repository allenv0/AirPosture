import Foundation
import SwiftUI
import BackgroundTasks
import os
#if os(iOS)
import UIKit
#endif

enum AppState: String, CaseIterable {
    case foreground = "foreground"
    case background = "background"
    case transitioning = "transitioning"
    
    var isBackground: Bool {
        return self == .background
    }
    
    var isForeground: Bool {
        return self == .foreground
    }
}

struct TransitionResult {
    let from: AppState?
    let to: AppState?
    let success: Bool
    let reason: String?
    let duration: TimeInterval?
    
    static func completed(from: AppState, to: AppState, duration: TimeInterval) -> TransitionResult {
        return TransitionResult(
            from: from,
            to: to,
            success: true,
            reason: nil,
            duration: duration
        )
    }
    
    static func denied(reason: String) -> TransitionResult {
        return TransitionResult(
            from: nil,
            to: nil,
            success: false,
            reason: reason,
            duration: nil
        )
    }
    
    static var noChange: TransitionResult {
        return TransitionResult(
            from: nil,
            to: nil,
            success: true,
            reason: "No change needed",
            duration: 0
        )
    }
}

struct TrackingState {
    let isTracking: Bool
    let isBackgroundMode: Bool
    let isSessionActive: Bool
    
    var shouldTrackInBackground: Bool {
        return isTracking && isBackgroundMode && isSessionActive
    }
}

enum StateValidation {
    case valid
    case invalid(issues: [String])
}

actor AppStateManager {
    private var currentAppState: AppState = .foreground
    private var previousAppState: AppState = .foreground
    private var stateTransitionHistory: [(AppState, Date)] = []
    private var isTransitioning: Bool = false
    private var transitionLock: Date?
    
    private let maxTransitionHistory = 50
    private let transitionCooldown: TimeInterval = 0.1
    private let maxTransitionDuration: TimeInterval = 5.0
    
    private var trackingEnabled: Bool = false
    private var backgroundModeEnabled: Bool = false
    private var sessionActive: Bool = false
    
    init() {
        Logger.background.debug("AppStateManager: Initialized")
    }
    
    func requestStateTransition(to newState: AppState) async -> TransitionResult {
        let now = Date()
        
        if isTransitioning {
            return TransitionResult.denied(reason: "Already transitioning")
        }
        
        if let lastLock = transitionLock, now.timeIntervalSince(lastLock) < transitionCooldown {
            return TransitionResult.denied(reason: "Transition too frequent")
        }
        
        if newState == currentAppState {
            return TransitionResult.noChange
        }
        
        guard await validateTransition(from: currentAppState, to: newState) else {
            return TransitionResult.denied(reason: "Invalid transition")
        }
        
        isTransitioning = true
        transitionLock = now
        
        let transitionStart = Date()
        
        let previousState = currentAppState
        currentAppState = newState
        
        recordStateTransition(from: previousState, to: newState, at: transitionStart)
        
        Logger.background.info("AppState: \(String(describing: previousState)) → \(String(describing: newState))")
        
        isTransitioning = false
        
        return TransitionResult.completed(
            from: previousState,
            to: newState,
            duration: Date().timeIntervalSince(transitionStart)
        )
    }
    
    func getCurrentState() -> AppState {
        return currentAppState
    }
    
    func getPreviousState() -> AppState {
        return previousAppState
    }
    
    func isCurrentlyTransitioning() -> Bool {
        return isTransitioning
    }
    
    func enableTracking() async {
        trackingEnabled = true
        sessionActive = true
        Logger.motion.info("AppState: Tracking enabled")
    }
    
    func disableTracking() async {
        trackingEnabled = false
        sessionActive = false
        backgroundModeEnabled = false
        Logger.motion.info("AppState: Tracking disabled")
    }
    
    func enableBackgroundMode() async {
        backgroundModeEnabled = true
        Logger.background.info("AppState: Background mode enabled")
    }
    
    func disableBackgroundMode() async {
        backgroundModeEnabled = false
        Logger.background.info("AppState: Background mode disabled")
    }
    
    func getTrackingState() -> TrackingState {
        return TrackingState(
            isTracking: trackingEnabled,
            isBackgroundMode: backgroundModeEnabled,
            isSessionActive: sessionActive
        )
    }
    
    func getStateHistory(limit: Int = 10) -> [(AppState, Date)] {
        return Array(stateTransitionHistory.suffix(limit))
    }
    
    func validateCurrentState() async -> StateValidation {
        if isTransitioning {
            if let lockStart = transitionLock, Date().timeIntervalSince(lockStart) > maxTransitionDuration {
                return StateValidation.invalid(issues: ["Transition stuck for too long"])
            }
        }
        
        if stateTransitionHistory.count > maxTransitionHistory {
            return StateValidation.invalid(issues: ["State history too large"])
        }
        
        return StateValidation.valid
    }
    
    private func validateTransition(from: AppState, to: AppState) async -> Bool {
        let validTransitions: [AppState: Set<AppState>] = [
            .foreground: [.background, .transitioning],
            .background: [.foreground, .transitioning],
            .transitioning: [.foreground, .background]
        ]
        
        return validTransitions[from]?.contains(to) ?? false
    }
    
    private func recordStateTransition(from: AppState, to: AppState, at date: Date) {
        previousAppState = from
        stateTransitionHistory.append((to, date))
        
        if stateTransitionHistory.count > maxTransitionHistory {
            stateTransitionHistory.removeFirst()
        }
    }
}

@MainActor
class TransitionCoordinator: ObservableObject {
    static let shared = TransitionCoordinator()
    
    @Published private(set) var currentPhase: TransitionPhase = .idle
    @Published private(set) var isTransitioning: Bool = false
    @Published private(set) var lastTransition: Date?
    
    private let stateManager = AppStateManager()
    private var backgroundCoordinator: AnyObject?
    private var activeTransitions: Set<TransitionType> = []
    private let transitionTimeout: TimeInterval = 10.0
    
    private init() {
        setupNotificationObservers()
    }
    
    func requestTransition(type: TransitionType, to state: AppState) async -> TransitionResult {
        guard !activeTransitions.contains(type) else {
            return TransitionResult.denied(reason: "Transition \(type) already in progress")
        }
        
        guard !isTransitioning else {
            return TransitionResult.denied(reason: "Another transition is in progress")
        }
        
        isTransitioning = true
        activeTransitions.insert(type)
        currentPhase = .starting
        
        let transitionStart = Date()
        
        Logger.background.info("TransitionCoordinator: Starting \(String(describing: type)) → \(String(describing: state))")
        
        let result = await performTransition(type: type, to: state)
        
        let duration = Date().timeIntervalSince(transitionStart)
        lastTransition = Date()
        
        isTransitioning = false
        activeTransitions.remove(type)
        currentPhase = .completed
        
        Logger.background.info("TransitionCoordinator: Completed \(String(describing: type)) in \(String(format: "%.2f", duration))s")
        
        if result.success {
            await onTransitionCompleted(type: type, from: result.from, to: result.to, duration: duration)
        }
        
        return result
    }
    
    func requestBackgroundTrackingStart() async -> TransitionResult {
        guard !activeTransitions.contains(.backgroundTracking) else {
            return TransitionResult.denied(reason: "Background tracking already starting")
        }
        
        return await requestTransition(type: .backgroundTracking, to: .background)
    }
    
    func requestBackgroundTrackingStop() async -> TransitionResult {
        guard !activeTransitions.contains(.backgroundTrackingStop) else {
            return TransitionResult.denied(reason: "Background tracking already stopping")
        }
        
        return await requestTransition(type: .backgroundTrackingStop, to: .foreground)
    }
    
    func forceEmergencyStop() async {
        Logger.background.error("TransitionCoordinator: Emergency stop requested")
        
        isTransitioning = false
        currentPhase = .emergency
        
        await stateManager.disableTracking()
        
        activeTransitions.removeAll()
        
        currentPhase = .idle
        Logger.background.info("TransitionCoordinator: Emergency stop completed")
    }
    
    func getCurrentState() async -> AppState {
        return await stateManager.getCurrentState()
    }
    
    func getTrackingState() async -> TrackingState {
        return await stateManager.getTrackingState()
    }
    
    func getTransitionStatus() -> TransitionStatus {
        return TransitionStatus(
            isTransitioning: isTransitioning,
            currentPhase: currentPhase,
            activeTransitions: Array(activeTransitions),
            lastTransition: lastTransition
        )
    }
    
    private func performTransition(type: TransitionType, to state: AppState) async -> TransitionResult {
        currentPhase = .validating
        
        let stateResult = await stateManager.requestStateTransition(to: state)
        guard stateResult.success else {
            currentPhase = .failed
            return TransitionResult.denied(reason: stateResult.reason ?? "State transition failed")
        }
        
        currentPhase = .executing
        
        switch type {
        case .backgroundTracking:
            await stateManager.enableBackgroundMode()
            await stateManager.enableTracking()
            
        case .backgroundTrackingStop:
            await stateManager.disableBackgroundMode()
            
        case .emergency:
            await stateManager.disableTracking()
            
        default:
            break
        }
        
        return TransitionResult.completed(
            from: stateResult.from ?? .foreground,
            to: state,
            duration: stateResult.duration ?? 0
        )
    }
    
    private func onTransitionCompleted(type: TransitionType, from: AppState?, to: AppState?, duration: TimeInterval) async {
        let trackingState = await getTrackingState()
        
        if trackingState.shouldTrackInBackground && to == .background {
            Logger.background.info("Background tracking successfully activated")
        } else if !trackingState.shouldTrackInBackground && to == .foreground {
            Logger.background.info("Foreground mode successfully activated")
        }
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appTerminationNotification),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        #endif
    }
    
    #if os(iOS)
    @objc private func appBackgroundNotification() {
        Task {
            await requestBackgroundTrackingStart()
        }
    }
    
    @objc private func appForegroundNotification() {
        Task {
            await requestBackgroundTrackingStop()
        }
    }
    
    @objc private func appTerminationNotification() {
        Task {
            await forceEmergencyStop()
        }
    }
    #endif
    
    func validateCurrentState() async -> StateValidation {
        let stateValidation = await stateManager.validateCurrentState()
        let transitionValidation = validateTransitionSystem()
        
        switch (stateValidation, transitionValidation) {
        case (.valid, .valid):
            return .valid
        case let (.invalid(issues), .valid), let (.valid, .invalid(issues)):
            return .invalid(issues: issues)
        case let (.invalid(stateIssues), .invalid(transitionIssues)):
            return .invalid(issues: stateIssues + transitionIssues)
        }
    }
    
    private func validateTransitionSystem() -> StateValidation {
        var issues: [String] = []
        
        if isTransitioning {
            if let lastTransition = lastTransition, 
               Date().timeIntervalSince(lastTransition) > transitionTimeout {
                issues.append("Transition stuck for too long")
            }
        }
        
        if activeTransitions.isEmpty && isTransitioning {
            issues.append("Inconsistent transition state")
        }
        
        return issues.isEmpty ? .valid : .invalid(issues: issues)
    }
    
    deinit {
        Logger.background.debug("TransitionCoordinator deinit")
        
        NotificationCenter.default.removeObserver(self)
        Task {
            await forceEmergencyStop()
        }
    }
}

enum TransitionType: String, CaseIterable {
    case backgroundTracking = "backgroundTracking"
    case backgroundTrackingStop = "backgroundTrackingStop"
    case emergency = "emergency"
    case custom = "custom"
}

enum TransitionPhase: String, CaseIterable {
    case idle = "idle"
    case starting = "starting"
    case validating = "validating"
    case executing = "executing"
    case completed = "completed"
    case failed = "failed"
    case emergency = "emergency"
}

struct TransitionStatus {
    let isTransitioning: Bool
    let currentPhase: TransitionPhase
    let activeTransitions: [TransitionType]
    let lastTransition: Date?
    
    var formattedStatus: String {
        return """
        Transition Status:
        - Phase: \(currentPhase.rawValue)
        - Transitioning: \(isTransitioning)
        - Active: \(activeTransitions.map(\.rawValue).joined(separator: ", "))
        - Last: \(lastTransition?.description ?? "Never")
        """
    }
}