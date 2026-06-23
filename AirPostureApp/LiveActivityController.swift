import ActivityKit
import Foundation
import os
#if os(iOS)
    import UIKit
#endif

@available(iOS 16.1, *)
@MainActor
public final class LiveActivityController {
    enum LiveActivityPushMode: Equatable {
        case localOnly
        case pushToken

        var logDescription: String {
            switch self {
            case .localOnly:
                return "local-only"
            case .pushToken:
                return "push-token"
            }
        }
    }

    static let shared = LiveActivityController()
    private var currentActivity: Activity<AirPostureActivityAttributes>?
    private var currentSessionId: UUID?
    private var pushTokenObservationTask: Task<Void, Never>?
    private var activityStateObservationTask: Task<Void, Never>?
    private var lastSentScore: Int = -1
    private var lastSentStatus: PostureStatus = .unknown
    private var lastSentTilt: Double = .greatestFiniteMagnitude
    private var lastSentLean: Double = .greatestFiniteMagnitude
    private var lastSentElapsedSeconds: Int = -1
    private var lastSentPaused: Bool = false
    private var lastSentAt: Date = .distantPast
    private var lastSuppressedUpdateLogAt: Date = .distantPast
    private var lastLocalUpdateAt: Date?
    private var lastRelaySyncAt: Date?
    private var lastRelayStatusCode: Int?
    private var lastRelayResponseSummary: String = "none"
    private var lastRelayRoute: String = "none"
    private var lastUpdateSkipReason: String = "none"
    private var lastActivityStateDescription: String = "not-started"
    private var hasLoggedMissingRelayConfiguration = false

    private enum UpdatePolicy {
        static let activeStaleInterval: TimeInterval = 5 * 60
        static let pausedStaleInterval: TimeInterval = 30 * 60
        static let passiveContentUpdateInterval: TimeInterval = 5
        static let passiveHeartbeatInterval: TimeInterval = 30
        static let suppressedLogInterval: TimeInterval = 30
        static let motionTiltDelta: Double = 2
        static let motionLeanDelta: Double = 3
        static let passivePriority = 5
        static let urgentPriority = 10
    }

    private enum RelayConfiguration {
        static let baseURLInfoKey = "LiveActivityRelayBaseURL"
        static let apiKeyInfoKey = "LiveActivityRelayAPIKey"
        static let registerRoute = "api/live-activity/register"
        static let updateRoute = "api/live-activity/update"
        static let endRoute = "api/live-activity/end"
        static let requestTimeout: TimeInterval = 8
    }

    private init() {}

    func restoreOrphanedActivitiesIfNeeded() {
        let allActivities = Activity<AirPostureActivityAttributes>.activities
        Logger.liveActivity.debug("Checking for orphaned Live Activities on app launch")
        Logger.liveActivity.debug("Total activities found: \(allActivities.count)")
        
        if allActivities.isEmpty {
            Logger.liveActivity.debug("No orphaned activities found")
            return
        }
        
        for activity in allActivities {
            Logger.liveActivity.debug("Found activity: \(activity.id.prefix(8)) state: \(String(describing: activity.activityState))")
            
            if isUsableActivity(activity) {
                Logger.liveActivity.warning("Orphaned Live Activity detected, restoring reference")
                currentActivity = activity
                currentSessionId = activity.attributes.sessionId
                recordLastSentState(activity.content.state, sentAt: activity.content.state.lastUpdate)
                observeActivityStateUpdates(for: activity)
                
                if Self.pushMode(relayBaseURLString: configuredRelayBaseURLString()) == .pushToken {
                    observePushTokenUpdates(
                        for: activity,
                        sessionId: activity.attributes.sessionId,
                        attributes: activity.attributes
                    )
                }
                return
            }
        }
        
        Logger.liveActivity.debug("No usable orphaned activities found")
    }

    func cleanupAllActivities() {
        Logger.liveActivity.info("Cleaning up all Live Activities")
        for activity in Activity<AirPostureActivityAttributes>.activities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        resetActivityState()
        Logger.liveActivity.debug("Cleanup initiated")
    }

    // Simple test method to verify class accessibility
    static func test() {
        Logger.liveActivity.debug("LiveActivityController is accessible")
    }

    func start(
        sessionId: UUID,
        avatarAssetName: String,
        userDisplayName: String? = nil,
        sessionStartTime: Date = Date()
    ) {
        Logger.liveActivity.info("Live Activity start requested")
        Logger.liveActivity.debug("Session: \(sessionId.uuidString.prefix(8)), avatar: \(avatarAssetName), hasDisplayName: \(userDisplayName != nil)")

        let authInfo = ActivityAuthorizationInfo()
        let relayBaseURLString = configuredRelayBaseURLString()
        let preferredPushMode = Self.pushMode(relayBaseURLString: relayBaseURLString)
        Logger.liveActivity.debug("Authorization: enabled=\(authInfo.areActivitiesEnabled), frequentPushes=\(self.frequentPushesEnabledDescription(authInfo)), relayConfigured=\(relayBaseURLString != nil), pushMode=\(preferredPushMode.logDescription)")
        logDiagnostics(context: "start-request")

        guard authInfo.areActivitiesEnabled else {
            Logger.liveActivity.error("Live Activities not enabled in system settings")
            return
        }

        let attributes = AirPostureActivityAttributes(
            sessionId: sessionId,
            avatarAssetName: avatarAssetName,
            userDisplayName: userDisplayName,
            sessionStartTime: sessionStartTime
        )

        let initial = AirPostureActivityAttributes.ContentState(
            postureStatus: .unknown,
            sessionScorePercent: 100,
            lastUpdate: Date(),
            tiltDegrees: 0,
            leanDegrees: 0,
            elapsedSeconds: 0,
            isSessionPaused: false
        )

        if let existingActivity = currentActivity {
            Task {
                await existingActivity.end(dismissalPolicy: .immediate)
            }
            resetActivityState()
        }
        endDetachedActivities(exceptSessionId: sessionId)

        do {
            let requestResult = try requestActivity(
                attributes: attributes,
                initial: initial,
                preferredPushMode: preferredPushMode
            )
            currentActivity = requestResult.activity
            Logger.liveActivity.info("Live Activity started successfully")
            guard let activity = currentActivity else {
                Logger.liveActivity.error("Live Activity was created as nil unexpectedly")
                return
            }
            Logger.liveActivity.debug("Activity: \(activity.id.prefix(8)), pushMode: \(requestResult.effectivePushMode.logDescription)")
            lastActivityStateDescription = "active"
            currentSessionId = sessionId
            lastSentScore = initial.sessionScorePercent
            lastSentStatus = .unknown
            lastSentTilt = initial.tiltDegrees
            lastSentLean = initial.leanDegrees
            lastSentElapsedSeconds = initial.elapsedSeconds
            lastSentPaused = initial.isSessionPaused
            lastSentAt = Date()
            lastLocalUpdateAt = initial.lastUpdate
            observeActivityStateUpdates(for: activity)
            if requestResult.effectivePushMode == .pushToken {
                observePushTokenUpdates(
                    for: activity,
                    sessionId: sessionId,
                    attributes: attributes
                )
            } else {
                Logger.liveActivity.info("Live Activity started without push-token updates")
            }
            Task { [weak self] in
                await self?.postStateToRelay(
                    activityId: activity.id,
                    sessionId: sessionId,
                    state: initial,
                    apnsPriority: UpdatePolicy.urgentPriority
                )
            }
        } catch {
            let nsError = error as NSError
            Logger.liveActivity.error("Failed to start Live Activity: \(error.localizedDescription) [\(nsError.domain)/\(nsError.code)]")
        }
    }

    func update(
        sessionId: UUID? = nil,
        sessionScorePercent: Int,
        status: PostureStatus,
        calibratedTilt: Double = 0,
        lean: Double = 0,
        elapsedSeconds: Int,
        isPaused: Bool,
        force: Bool = false
    ) {
        if let sessionId {
            currentSessionId = sessionId
        }

        guard let activity = currentActivity ?? restoreExistingActivity(sessionId: sessionId ?? currentSessionId) else {
            Logger.liveActivity.error("Live Activity update failed: no current activity")
            return
        }

        let clampedScore = max(0, min(100, sessionScorePercent))
        let clampedElapsedSeconds = max(0, elapsedSeconds)
        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastSentAt)

        let scoreDelta = abs(clampedScore - lastSentScore)
        let statusChanged = status != lastSentStatus
        let tiltDelta = abs(calibratedTilt - lastSentTilt)
        let leanDelta = abs(lean - lastSentLean)
        let elapsedChanged = clampedElapsedSeconds != lastSentElapsedSeconds
        let pauseChanged = isPaused != lastSentPaused
        let motionChanged = tiltDelta >= UpdatePolicy.motionTiltDelta
            || leanDelta >= UpdatePolicy.motionLeanDelta
        let heartbeatDue = !isPaused && timeSinceLast >= UpdatePolicy.passiveHeartbeatInterval
        let urgentUpdate = pauseChanged || statusChanged
        let scoreChanged = scoreDelta >= 1
        let passiveContentChanged = scoreChanged || motionChanged
        let passiveWindowOpen = timeSinceLast >= UpdatePolicy.passiveContentUpdateInterval
        let shouldSend = force || urgentUpdate || (passiveContentChanged && passiveWindowOpen) || heartbeatDue

        guard shouldSend else {
            lastUpdateSkipReason = skippedUpdateReason(
                elapsedChanged: elapsedChanged,
                passiveContentChanged: passiveContentChanged,
                passiveWindowOpen: passiveWindowOpen,
                timeSinceLast: timeSinceLast
            )
            logSuppressedUpdateIfNeeded(
                elapsedChanged: elapsedChanged,
                clampedElapsedSeconds: clampedElapsedSeconds,
                timeSinceLast: timeSinceLast
            )
            return
        }

        Logger.liveActivity.debug("Sending update: score=\(clampedScore)% (\(String(describing: status))), elapsed=\(clampedElapsedSeconds)s, paused=\(isPaused)")
        Logger.liveActivity.debug("Update reasons: force=\(force) urgent=\(urgentUpdate) score=\(scoreChanged) motion=\(motionChanged) passiveWindow=\(passiveWindowOpen) heartbeat=\(heartbeatDue)")

        let state = AirPostureActivityAttributes.ContentState(
            postureStatus: status,
            sessionScorePercent: clampedScore,
            lastUpdate: now,
            tiltDegrees: calibratedTilt,
            leanDegrees: lean,
            elapsedSeconds: clampedElapsedSeconds,
            isSessionPaused: isPaused
        )
        lastSentScore = clampedScore
        lastSentStatus = status
        lastSentTilt = calibratedTilt
        lastSentLean = lean
        lastSentElapsedSeconds = clampedElapsedSeconds
        lastSentPaused = isPaused
        lastSentAt = now
        lastUpdateSkipReason = "none"

        let activityId = activity.id
        let relaySessionId = currentSessionId ?? activity.attributes.sessionId
        let priority = relayPriority(
            force: force,
            urgentUpdate: urgentUpdate
        )

        Task {
            await activity.update(activityContent(for: state, now: now))
            await MainActor.run {
                self.lastLocalUpdateAt = now
            }
                Logger.liveActivity.debug("Live Activity update sent successfully")
            await self.postStateToRelay(
                activityId: activityId,
                sessionId: relaySessionId,
                state: state,
                apnsPriority: priority
            )
        }
    }

    func end(immediate: Bool = false, sessionId: UUID? = nil) {
        let activity = currentActivity ?? restoreExistingActivity(sessionId: sessionId ?? currentSessionId)
        
        guard let activity else {
            Logger.liveActivity.error("Live Activity end failed: no activity found, hasCurrent=\(self.currentActivity != nil), activities count: \(Activity<AirPostureActivityAttributes>.activities.count)")
            return
        }
        
        let activityId = activity.id
        let relaySessionId = currentSessionId ?? activity.attributes.sessionId
        let finalState = AirPostureActivityAttributes.ContentState(
            postureStatus: lastSentStatus,
            sessionScorePercent: max(0, min(100, lastSentScore >= 0 ? lastSentScore : 100)),
            lastUpdate: Date(),
            tiltDegrees: lastSentTilt.isFinite ? lastSentTilt : 0,
            leanDegrees: lastSentLean.isFinite ? lastSentLean : 0,
            elapsedSeconds: max(0, lastSentElapsedSeconds),
            isSessionPaused: lastSentPaused
        )
        pushTokenObservationTask?.cancel()
        pushTokenObservationTask = nil

        Task {
            let activityToEnd = activity
            let finalContent = self.activityContent(for: finalState, now: finalState.lastUpdate)
            
            Task {
                await self.postEndToRelay(
                    activityId: activityId,
                    sessionId: relaySessionId,
                    finalState: finalState,
                    immediate: immediate
                )
            }
            
            await activityToEnd.end(
                finalContent,
                dismissalPolicy: immediate ? .immediate : .default
            )
            await MainActor.run {
                self.lastActivityStateDescription = "ended"
                self.currentActivity = nil
            }
        }
        resetActivityState()
    }

    func logDiagnostics(context: String) {
        let authInfo = ActivityAuthorizationInfo()
        let relayBaseURLString = configuredRelayBaseURLString()
        let pushMode = Self.pushMode(relayBaseURLString: relayBaseURLString)
        Logger.liveActivity.debug("Diagnostics [\(context)]: pushMode=\(pushMode.logDescription), enabled=\(authInfo.areActivitiesEnabled), frequentPushes=\(self.frequentPushesEnabledDescription(authInfo)), relayConfigured=\(relayBaseURLString != nil), lastLocalUpdate=\(self.dateDescription(self.lastLocalUpdateAt)), lastRelaySync=\(self.dateDescription(self.lastRelaySyncAt)), relayResult: route=\(self.lastRelayRoute) status=\(self.lastRelayStatusCode.map(String.init) ?? "none") response=\(self.lastRelayResponseSummary), skipReason=\(self.lastUpdateSkipReason), activityState=\(self.lastActivityStateDescription)")
        #if os(iOS)
            Logger.liveActivity.debug("Background time remaining: \(String(format: "%.1f", UIApplication.shared.backgroundTimeRemaining))s")
        #endif
    }

    private func observePushTokenUpdates(
        for activity: Activity<AirPostureActivityAttributes>,
        sessionId: UUID,
        attributes: AirPostureActivityAttributes
    ) {
        pushTokenObservationTask?.cancel()
        pushTokenObservationTask = Task { [weak self] in
            guard let self else { return }
            for await tokenData in activity.pushTokenUpdates {
                guard !Task.isCancelled else { return }
                let tokenHex = tokenData.hexString
                Logger.liveActivity.info("Live Activity push token received (\(tokenHex.count) chars)")
                await self.registerTokenWithRelay(
                    activityId: activity.id,
                    sessionId: sessionId,
                    pushTokenHex: tokenHex,
                    attributes: attributes
                )
            }
        }
    }

    private func requestActivity(
        attributes: AirPostureActivityAttributes,
        initial: AirPostureActivityAttributes.ContentState,
        preferredPushMode: LiveActivityPushMode
    ) throws -> (
        activity: Activity<AirPostureActivityAttributes>,
        effectivePushMode: LiveActivityPushMode
    ) {
        do {
            return (
                try requestActivity(attributes: attributes, initial: initial, pushMode: preferredPushMode),
                preferredPushMode
            )
        } catch {
            guard preferredPushMode == .pushToken else {
                throw error
            }

            let nsError = error as NSError
            Logger.liveActivity.warning("Push-token Live Activity request failed [\(nsError.domain)/\(nsError.code)], retrying local-only")
            return (
                try requestActivity(attributes: attributes, initial: initial, pushMode: .localOnly),
                .localOnly
            )
        }
    }

    private func requestActivity(
        attributes: AirPostureActivityAttributes,
        initial: AirPostureActivityAttributes.ContentState,
        pushMode: LiveActivityPushMode
    ) throws -> Activity<AirPostureActivityAttributes> {
        let content = activityContent(for: initial, now: initial.lastUpdate)

        switch pushMode {
        case .localOnly:
            return try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        case .pushToken:
            return try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
        }
    }

    private func activityContent(
        for state: AirPostureActivityAttributes.ContentState,
        now: Date
    ) -> ActivityContent<AirPostureActivityAttributes.ContentState> {
        ActivityContent(
            state: state,
            staleDate: staleDate(for: state, now: now),
            relevanceScore: relevanceScore(for: state)
        )
    }

    private func staleDate(
        for state: AirPostureActivityAttributes.ContentState,
        now: Date
    ) -> Date? {
        let interval = state.isSessionPaused
            ? UpdatePolicy.pausedStaleInterval
            : UpdatePolicy.activeStaleInterval
        return now.addingTimeInterval(interval)
    }

    private func relevanceScore(
        for state: AirPostureActivityAttributes.ContentState
    ) -> Double {
        if state.isSessionPaused {
            return 25
        }

        switch state.postureStatus {
        case .poor:
            return 100
        case .good:
            return 70
        case .unknown:
            return 50
        }
    }

    private func restoreExistingActivity(
        sessionId: UUID?
    ) -> Activity<AirPostureActivityAttributes>? {
        let candidates = Activity<AirPostureActivityAttributes>.activities
            .filter(isUsableActivity)

        let restored = sessionId.flatMap { id in
            candidates.first { $0.attributes.sessionId == id }
        } ?? candidates.sorted {
            $0.attributes.sessionStartTime > $1.attributes.sessionStartTime
        }.first

        guard let restored else {
            return nil
        }

        currentActivity = restored
        currentSessionId = restored.attributes.sessionId
        recordLastSentState(restored.content.state, sentAt: restored.content.state.lastUpdate)
        observeActivityStateUpdates(for: restored)

        if Self.pushMode(relayBaseURLString: configuredRelayBaseURLString()) == .pushToken {
            observePushTokenUpdates(
                for: restored,
                sessionId: restored.attributes.sessionId,
                attributes: restored.attributes
            )
        }

        Logger.liveActivity.info("Restored Live Activity reference: \(restored.id.prefix(8))")
        return restored
    }

    private func recordLastSentState(
        _ state: AirPostureActivityAttributes.ContentState,
        sentAt: Date
    ) {
        lastSentScore = state.sessionScorePercent
        lastSentStatus = state.postureStatus
        lastSentTilt = state.tiltDegrees
        lastSentLean = state.leanDegrees
        lastSentElapsedSeconds = state.elapsedSeconds
        lastSentPaused = state.isSessionPaused
        lastSentAt = sentAt
    }

    private func isUsableActivity(
        _ activity: Activity<AirPostureActivityAttributes>
    ) -> Bool {
        switch activity.activityState {
        case .active, .stale:
            return true
        case .ended, .dismissed:
            return false
        @unknown default:
            return false
        }
    }

    private func observeActivityStateUpdates(
        for activity: Activity<AirPostureActivityAttributes>
    ) {
        activityStateObservationTask?.cancel()
        activityStateObservationTask = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { return }

                switch state {
                case .active:
                    await self?.recordActivityState("active", activityId: activity.id)
                case .stale:
                    await self?.recordActivityState("stale", activityId: activity.id)
                case .ended, .dismissed:
                    await self?.recordActivityState(String(describing: state), activityId: activity.id)
                    await self?.clearActivityIfCurrent(activityId: activity.id)
                    return
                @unknown default:
                    break
                }
            }
        }
    }

    private func clearActivityIfCurrent(activityId: String) {
        guard currentActivity?.id == activityId else { return }
        resetActivityState()
    }

    private func recordActivityState(_ state: String, activityId: String) {
        lastActivityStateDescription = state
        Logger.liveActivity.info("Live Activity state changed: \(activityId.prefix(8)) -> \(state)")
    }

    private func endDetachedActivities(exceptSessionId: UUID) {
        for activity in Activity<AirPostureActivityAttributes>.activities
        where activity.attributes.sessionId != exceptSessionId && isUsableActivity(activity) {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }

    private func relayPriority(
        force: Bool,
        urgentUpdate: Bool
    ) -> Int {
        if force || urgentUpdate {
            return UpdatePolicy.urgentPriority
        }

        return UpdatePolicy.passivePriority
    }

    private func logSuppressedUpdateIfNeeded(
        elapsedChanged: Bool,
        clampedElapsedSeconds: Int,
        timeSinceLast: TimeInterval
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastSuppressedUpdateLogAt) >= UpdatePolicy.suppressedLogInterval else {
            return
        }

        lastSuppressedUpdateLogAt = now
        Logger.liveActivity.debug(
            "Live Activity update skipped: \(self.lastUpdateSkipReason), elapsedChanged=\(elapsedChanged), elapsed=\(clampedElapsedSeconds)s, lastSent=\(String(format: "%.1f", timeSinceLast))s ago"
        )
    }

    private func skippedUpdateReason(
        elapsedChanged: Bool,
        passiveContentChanged: Bool,
        passiveWindowOpen: Bool,
        timeSinceLast: TimeInterval
    ) -> String {
        if elapsedChanged && !passiveContentChanged {
            return "elapsed-only update suppressed"
        }

        if passiveContentChanged && !passiveWindowOpen {
            return "passive content coalesced for \(String(format: "%.1f", max(0, UpdatePolicy.passiveContentUpdateInterval - timeSinceLast)))s"
        }

        return "no meaningful Live Activity content change"
    }

    private func registerTokenWithRelay(
        activityId: String,
        sessionId: UUID,
        pushTokenHex: String,
        attributes: AirPostureActivityAttributes
    ) async {
        let payload = RelayTokenRegistrationPayload(
            activityId: activityId,
            sessionId: sessionId.uuidString,
            pushToken: pushTokenHex,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            avatarAssetName: attributes.avatarAssetName,
            userDisplayName: attributes.userDisplayName,
            sessionStartUnix: Int(attributes.sessionStartTime.timeIntervalSince1970.rounded(.down))
        )
        await sendRelayRequest(route: RelayConfiguration.registerRoute, payload: payload)
    }

    private func postStateToRelay(
        activityId: String,
        sessionId: UUID,
        state: AirPostureActivityAttributes.ContentState,
        apnsPriority: Int
    ) async {
        let payload = RelayStateUpdatePayload(
            activityId: activityId,
            sessionId: sessionId.uuidString,
            sentAtUnix: Int(Date().timeIntervalSince1970.rounded(.down)),
            contentState: RelayContentState(state: state),
            apnsPriority: apnsPriority,
            staleDateUnix: staleDate(for: state, now: state.lastUpdate).map {
                Int($0.timeIntervalSince1970.rounded(.down))
            },
            relevanceScore: relevanceScore(for: state)
        )
        await sendRelayRequest(route: RelayConfiguration.updateRoute, payload: payload)
    }

    private func postEndToRelay(
        activityId: String,
        sessionId: UUID,
        finalState: AirPostureActivityAttributes.ContentState,
        immediate: Bool
    ) async {
        let payload = RelayEndPayload(
            activityId: activityId,
            sessionId: sessionId.uuidString,
            endedAtUnix: Int(Date().timeIntervalSince1970.rounded(.down)),
            immediate: immediate,
            finalState: RelayContentState(state: finalState)
        )
        await sendRelayRequest(route: RelayConfiguration.endRoute, payload: payload)
    }

    private func sendRelayRequest<Payload: Encodable>(
        route: String,
        payload: Payload
    ) async {
        guard let baseURL = relayBaseURL() else { return }
        let endpoint = baseURL.appendingPathComponent(route)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = RelayConfiguration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = relayAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue(apiKey, forHTTPHeaderField: "X-Relay-API-Key")
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            request.httpBody = try encoder.encode(payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                recordRelayResult(route: route, statusCode: nil, responseSummary: "non-http response")
                Logger.liveActivity.warning("Relay request returned non-HTTP response: \(endpoint.absoluteString)")
                return
            }

            let responseSummary = relayResponseSummary(data)
            recordRelayResult(route: route, statusCode: http.statusCode, responseSummary: responseSummary)

            if !(200...299).contains(http.statusCode) {
                Logger.liveActivity.warning("Relay request failed: \(http.statusCode) route=\(route)")
            } else {
                Logger.liveActivity.debug("Relay request succeeded: route=\(route), status=\(http.statusCode)")
            }
        } catch {
            recordRelayResult(route: route, statusCode: nil, responseSummary: error.localizedDescription)
            Logger.liveActivity.warning("Relay request error: route=\(route), \(error.localizedDescription)")
        }
    }

    private func recordRelayResult(
        route: String,
        statusCode: Int?,
        responseSummary: String
    ) {
        lastRelayRoute = route
        lastRelayStatusCode = statusCode
        lastRelayResponseSummary = responseSummary
        lastRelaySyncAt = Date()
    }

    private func relayResponseSummary(_ data: Data) -> String {
        guard !data.isEmpty else {
            return "empty"
        }

        let raw = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
        if raw.count <= 240 {
            return raw
        }

        return "\(raw.prefix(240))..."
    }

    private func configuredRelayBaseURLString() -> String? {
        let configuredValue = (Bundle.main.object(
            forInfoDictionaryKey: RelayConfiguration.baseURLInfoKey
        ) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let configuredValue,
              !configuredValue.isEmpty,
              !configuredValue.hasPrefix("$(")
        else {
            return nil
        }

        return configuredValue
    }

    private func relayBaseURL() -> URL? {
        guard let configuredValue = configuredRelayBaseURLString(),
              let url = URL(string: configuredValue)
        else {
            if !hasLoggedMissingRelayConfiguration {
                hasLoggedMissingRelayConfiguration = true
                Logger.liveActivity.info(
                    "Live Activity relay disabled. Set Info.plist key \(RelayConfiguration.baseURLInfoKey) to enable push-driven updates."
                )
                logDiagnostics(context: "missing-relay-config")
            }
            return nil
        }

        return url
    }

    nonisolated static func pushMode(
        relayBaseURLString: String?
    ) -> LiveActivityPushMode {
        guard let relayBaseURLString,
              !relayBaseURLString.isEmpty
        else {
            return .localOnly
        }

        return .pushToken
    }

    private func relayAPIKey() -> String? {
        let configuredValue = (Bundle.main.object(
            forInfoDictionaryKey: RelayConfiguration.apiKeyInfoKey
        ) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let configuredValue, !configuredValue.hasPrefix("$(") else {
            return nil
        }

        return configuredValue
    }

    private func frequentPushesEnabledDescription(
        _ authInfo: ActivityAuthorizationInfo
    ) -> String {
        if #available(iOS 16.2, *) {
            return authInfo.frequentPushesEnabled ? "true" : "false"
        }

        return "unavailable"
    }

    private func dateDescription(_ date: Date?) -> String {
        guard let date else {
            return "none"
        }

        return ISO8601DateFormatter().string(from: date)
    }

    private func resetActivityState() {
        pushTokenObservationTask?.cancel()
        pushTokenObservationTask = nil
        activityStateObservationTask?.cancel()
        activityStateObservationTask = nil
        currentActivity = nil
        currentSessionId = nil
        lastSentScore = -1
        lastSentStatus = .unknown
        lastSentTilt = .greatestFiniteMagnitude
        lastSentLean = .greatestFiniteMagnitude
        lastSentElapsedSeconds = -1
        lastSentPaused = false
        lastSentAt = .distantPast
        lastSuppressedUpdateLogAt = .distantPast
        lastActivityStateDescription = "not-started"
    }
}

@available(iOS 16.1, *)
private struct RelayTokenRegistrationPayload: Encodable {
    let activityId: String
    let sessionId: String
    let pushToken: String
    let bundleId: String
    let avatarAssetName: String
    let userDisplayName: String?
    let sessionStartUnix: Int
}

@available(iOS 16.1, *)
private struct RelayStateUpdatePayload: Encodable {
    let activityId: String
    let sessionId: String
    let sentAtUnix: Int
    let contentState: RelayContentState
    let apnsPriority: Int
    let staleDateUnix: Int?
    let relevanceScore: Double
}

@available(iOS 16.1, *)
private struct RelayEndPayload: Encodable {
    let activityId: String
    let sessionId: String
    let endedAtUnix: Int
    let immediate: Bool
    let finalState: RelayContentState
}

@available(iOS 16.1, *)
private struct RelayContentState: Encodable {
    let postureStatus: String
    let sessionScorePercent: Int
    let tiltDegrees: Double
    let leanDegrees: Double
    let elapsedSeconds: Int
    let isSessionPaused: Bool
    let lastUpdate: Double
    let lastUpdateUnix: Int

    init(state: AirPostureActivityAttributes.ContentState) {
        postureStatus = state.postureStatus.rawValue
        sessionScorePercent = state.sessionScorePercent
        tiltDegrees = state.tiltDegrees
        leanDegrees = state.leanDegrees
        elapsedSeconds = state.elapsedSeconds
        isSessionPaused = state.isSessionPaused
        lastUpdate = state.lastUpdate.timeIntervalSinceReferenceDate
        lastUpdateUnix = Int(state.lastUpdate.timeIntervalSince1970.rounded(.down))
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
