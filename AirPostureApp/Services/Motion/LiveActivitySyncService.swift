import Combine
import Foundation
import os

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
protocol LiveActivitySessionSyncing: AnyObject {
    func startActivity(sessionId: UUID, avatarAssetName: String, sessionStartTime: Date)
    func updateActivity(sessionId: UUID, scorePercent: Int, status: PostureStatus, calibratedTilt: Double, lean: Double, elapsedSeconds: Int, isPaused: Bool, force: Bool)
    func endActivity(immediate: Bool)
    func startUpdateTimer(interval: TimeInterval, onUpdate: @escaping () -> Void)
    func stopUpdateTimer()
}

@MainActor
final class LiveActivitySyncService: LiveActivitySessionSyncing {
    private let isEnabled = true
    private var updateTimer: AnyCancellable?

    func startActivity(sessionId: UUID, avatarAssetName: String, sessionStartTime: Date) {
        guard isEnabled else { return }

        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            LiveActivityController.shared.start(
                sessionId: sessionId,
                avatarAssetName: avatarAssetName,
                sessionStartTime: sessionStartTime
            )
        }
        #endif
    }

    func updateActivity(sessionId: UUID, scorePercent: Int, status: PostureStatus, calibratedTilt: Double, lean: Double, elapsedSeconds: Int, isPaused: Bool, force: Bool) {
        guard isEnabled else { return }

        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            LiveActivityController.shared.update(
                sessionId: sessionId,
                sessionScorePercent: scorePercent,
                status: status,
                calibratedTilt: calibratedTilt,
                lean: lean,
                elapsedSeconds: elapsedSeconds,
                isPaused: isPaused,
                force: force
            )
        }
        #endif
    }

    func endActivity(immediate: Bool) {
        guard isEnabled else { return }

        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            LiveActivityController.shared.end(immediate: immediate)
        }
        #endif
    }

    func startUpdateTimer(interval: TimeInterval = 1.0, onUpdate: @escaping () -> Void) {
        updateTimer?.cancel()
        updateTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                onUpdate()
            }
    }

    func stopUpdateTimer() {
        updateTimer?.cancel()
        updateTimer = nil
    }
}
