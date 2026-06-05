import Foundation

@MainActor
public final class AirPostureTracker: ObservableObject {
    // MARK: - Public Properties
    @Published public private(set) var snapshot: AirPostureSnapshot
    public var configuration: AirPostureConfiguration
    public var isDeviceMotionAvailable: Bool { provider.isDeviceMotionAvailable }
    public var isDeviceMotionActive: Bool { provider.isDeviceMotionActive }

    // MARK: - Private Properties
    private let provider: HeadphoneMotionProvider
    private let motionProcessingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.airposture.core.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()

    // Core tracking state
    private var currentPitch: Double = 0.0
    private var currentRoll: Double = 0.0
    private var currentYaw: Double = 0.0
    private var latestSample: AirPostureSample?
    private var pitchHistory: [Double] = []
    private var connectionState: AirPostureConnectionState = .disconnected
    private var lastMotionTime: Date = Date.distantPast
    private var lastSuccessfulMotionTime: Date = Date.distantPast

    // Session state
    private var initialSessionStartTime: Date?
    private var currentSessionIntervalStartTime: Date?
    private var isSessionPaused: Bool = false
    private var accumulatedSessionDuration: TimeInterval = 0.0
    private var poorPostureStartTime: Date?
    private var accumulatedPoorPostureDuration: TimeInterval = 0.0

    // Calibration state
    private var calibrationState: AirPostureCalibrationState = .idle
    private var calibrationTimer: Timer?
    private var calibrationData: [Double] = []
    private var goodPostureAverage: Double = 0.0
    private var badPostureAverage: Double = 0.0
    private var calculatedThreshold: Double = 0.0
    private let calibrationDuration: TimeInterval = 5.0
    private let transitionDuration: TimeInterval = 3.0

    // Timers
    private var uiCoalescingTimer: DispatchSourceTimer?
    private var healthCheckTimer: DispatchSourceTimer?

    // MARK: - Initialization
    public init(
        configuration: AirPostureConfiguration = .default,
        provider: HeadphoneMotionProvider = CMHeadphoneMotionProvider()
    ) {
        self.configuration = configuration
        self.provider = provider
        self.snapshot = .initial
        self.provider.delegate = self
    }

    deinit {
        // Safe timer cancellation on MainActor in deinit is done by invalidating timers
        // and sources on background thread if needed, or keeping it clean.
        // We'll invalidate timers immediately when stopMotionUpdates is called.
    }

    // MARK: - Public API

    public func startMotionUpdates() {
        guard !provider.isDeviceMotionActive else { return }

        // Start with connecting state unless we're already connected
        if connectionState != .connected {
            connectionState = .connecting
        }

        // Reset tracking timestamps
        lastMotionTime = Date()
        lastSuccessfulMotionTime = Date()

        // Start core motion provider
        provider.startDeviceMotionUpdates(to: motionProcessingQueue)

        // Start snapshot coalescing timer (15Hz)
        startUICoalescingTimer()

        // Start health check timer (2s)
        startHealthCheckTimer()

        updateSnapshot()
    }

    public func stopMotionUpdates() {
        provider.stopDeviceMotionUpdates()
        stopAllTimers()
        connectionState = .disconnected
        updateSnapshot()
    }

    public func startSession(at date: Date = Date()) {
        initialSessionStartTime = date
        currentSessionIntervalStartTime = date
        isSessionPaused = false
        accumulatedSessionDuration = 0.0
        poorPostureStartTime = nil
        accumulatedPoorPostureDuration = 0.0
        updateSnapshot()
    }

    public func pauseSession(at date: Date = Date()) {
        guard initialSessionStartTime != nil, !isSessionPaused else { return }

        // Accumulate active session duration
        if let intervalStart = currentSessionIntervalStartTime {
            accumulatedSessionDuration += date.timeIntervalSince(intervalStart)
        }
        currentSessionIntervalStartTime = nil

        // Accumulate poor posture duration if currently in poor posture
        if let poorStart = poorPostureStartTime {
            accumulatedPoorPostureDuration += date.timeIntervalSince(poorStart)
            poorPostureStartTime = nil
        }

        isSessionPaused = true
        updateSnapshot()
    }

    public func resumeSession(at date: Date = Date()) {
        guard initialSessionStartTime != nil, isSessionPaused else { return }

        currentSessionIntervalStartTime = date
        isSessionPaused = false
        updateSnapshot()
    }

    public func endSession(at date: Date = Date()) -> AirPostureSessionSummary? {
        guard let sessionStart = initialSessionStartTime else { return nil }

        // Finalize durations
        var finalDuration = accumulatedSessionDuration
        if !isSessionPaused, let intervalStart = currentSessionIntervalStartTime {
            finalDuration += date.timeIntervalSince(intervalStart)
        }

        var finalPoorDuration = accumulatedPoorPostureDuration
        if !isSessionPaused, let poorStart = poorPostureStartTime {
            finalPoorDuration += date.timeIntervalSince(poorStart)
        }

        let goodPercent =
            finalDuration > 0
            ? max(0.0, min(100.0, ((finalDuration - finalPoorDuration) / finalDuration) * 100.0))
            : 100.0

        let summary = AirPostureSessionSummary(
            startTime: sessionStart,
            endTime: date,
            totalDuration: finalDuration,
            poorPostureDuration: finalPoorDuration,
            goodPosturePercent: goodPercent
        )

        // Reset session state
        initialSessionStartTime = nil
        currentSessionIntervalStartTime = nil
        isSessionPaused = false
        accumulatedSessionDuration = 0.0
        poorPostureStartTime = nil
        accumulatedPoorPostureDuration = 0.0

        updateSnapshot()
        return summary
    }

    public func beginCalibration() {
        calibrationData.removeAll()
        goodPostureAverage = 0.0
        badPostureAverage = 0.0
        calculatedThreshold = 0.0
        calibrationState = .recordingGoodPosture(progress: 0.0)

        // Ensure motion updates are active during calibration
        startMotionUpdates()
        startCalibrationStep()
        updateSnapshot()
    }

    public func cancelCalibration() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        calibrationState = .idle
        updateSnapshot()
    }

    public func saveCalibrationResult() -> AirPostureConfiguration? {
        if case .complete(_, _, let threshold) = calibrationState {
            configuration.poorPostureThreshold = threshold
            calibrationState = .idle
            updateSnapshot()
            return configuration
        }
        return nil
    }

    // MARK: - Private Engine Calculations

    private func processAttitudeSample(_ sample: HeadphoneMotionAttitudeSample) {
        let pitch = sample.pitchRadians
        let roll = sample.rollRadians
        let yaw = sample.yawRadians
        let timestamp = sample.timestamp

        // 1. Validate sample
        guard validateAttitude(pitch: pitch, roll: roll, yaw: yaw) else {
            return
        }

        let pitchDeg = pitch * 180.0 / .pi
        let rollDeg = roll * 180.0 / .pi
        let yawDeg = yaw * 180.0 / .pi

        // 2. Low-pass filter (on pitch)
        let filteredPitch = lowPassFilter(current: pitchDeg, previous: currentPitch)

        currentPitch = filteredPitch
        currentRoll = rollDeg
        currentYaw = yawDeg

        let sample = AirPostureSample(
            pitch: currentPitch, roll: currentRoll, yaw: currentYaw, timestamp: timestamp)
        latestSample = sample

        // Update timestamps
        lastMotionTime = timestamp
        lastSuccessfulMotionTime = timestamp

        // Transition to connected if not already
        if connectionState != .connected {
            connectionState = .connected
        }

        // Update pitch history
        updatePitchHistory(filteredPitch)

        // Update active session metrics
        updateActiveSessionMetrics(at: timestamp)

        // Update the snapshot immediately on sample processing
        updateSnapshot()
    }

    private func validateAttitude(pitch: Double, roll: Double, yaw: Double) -> Bool {
        // Rejects NaN, infinity, and outside -pi...pi range
        guard !pitch.isNaN && !roll.isNaN && !yaw.isNaN else { return false }
        guard !pitch.isInfinite && !roll.isInfinite && !yaw.isInfinite else { return false }
        let validRange = -Double.pi...Double.pi
        guard validRange.contains(pitch) && validRange.contains(roll) && validRange.contains(yaw)
        else { return false }
        return true
    }

    private func lowPassFilter(current: Double, previous: Double) -> Double {
        return previous * (1.0 - configuration.lowPassFilterFactor) + current
            * configuration.lowPassFilterFactor
    }

    private func updatePitchHistory(_ newPitch: Double) {
        pitchHistory.append(newPitch)
        if pitchHistory.count > configuration.pitchHistorySize {
            pitchHistory.removeFirst()
        }
    }

    private func updateActiveSessionMetrics(at date: Date) {
        guard initialSessionStartTime != nil, !isSessionPaused else { return }

        let adjustedPitch = currentPitch - configuration.normalAirPodsOffset
        let isPoor = adjustedPitch < configuration.poorPostureThreshold

        if isPoor {
            if poorPostureStartTime == nil {
                poorPostureStartTime = date
            }
        } else {
            if let poorStart = poorPostureStartTime {
                accumulatedPoorPostureDuration += date.timeIntervalSince(poorStart)
                poorPostureStartTime = nil
            }
        }
    }

    private func calculateAverage(_ data: [Double]) -> Double {
        guard !data.isEmpty else { return 0.0 }
        return data.reduce(0.0, +) / Double(data.count)
    }

    private func startCalibrationStep() {
        calibrationData.removeAll()
        let duration: TimeInterval
        switch calibrationState {
        case .recordingGoodPosture:
            duration = calibrationDuration
        case .transition:
            duration = transitionDuration
        case .recordingBadPosture:
            duration = calibrationDuration
        default:
            return
        }

        var elapsed: TimeInterval = 0.0
        calibrationTimer?.invalidate()
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                elapsed += 0.1
                let progress = min(1.0, elapsed / duration)

                switch self.calibrationState {
                case .recordingGoodPosture:
                    if let currentPitch = self.latestSample?.pitch {
                        self.calibrationData.append(currentPitch)
                    }
                    self.calibrationState = .recordingGoodPosture(progress: progress)
                    if progress >= 1.0 {
                        self.goodPostureAverage = self.calculateAverage(self.calibrationData)
                        self.calibrationState = .transition(progress: 0.0)
                        self.startCalibrationStep()
                    }
                case .transition:
                    self.calibrationState = .transition(progress: progress)
                    if progress >= 1.0 {
                        self.calibrationState = .recordingBadPosture(progress: 0.0)
                        self.startCalibrationStep()
                    }
                case .recordingBadPosture:
                    if let currentPitch = self.latestSample?.pitch {
                        self.calibrationData.append(currentPitch)
                    }
                    self.calibrationState = .recordingBadPosture(progress: progress)
                    if progress >= 1.0 {
                        self.badPostureAverage = self.calculateAverage(self.calibrationData)
                        let rawThreshold = (self.goodPostureAverage + self.badPostureAverage) / 2.0
                        let safeThreshold = max(-35.0, min(-5.0, rawThreshold))
                        self.calculatedThreshold = safeThreshold
                        self.calibrationTimer?.invalidate()
                        self.calibrationTimer = nil
                        self.calibrationState = .complete(
                            goodPostureAverage: self.goodPostureAverage,
                            badPostureAverage: self.badPostureAverage,
                            calculatedThreshold: safeThreshold
                        )
                    }
                default:
                    self.calibrationTimer?.invalidate()
                    self.calibrationTimer = nil
                }
                self.updateSnapshot()
            }
        }
    }

    // MARK: - Coalescing & Timer Systems

    private func startUICoalescingTimer() {
        uiCoalescingTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: configuration.uiSnapshotCoalescingInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.updateSnapshot()
        }
        uiCoalescingTimer = timer
        timer.resume()
    }

    private func startHealthCheckTimer() {
        healthCheckTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(
            deadline: .now() + configuration.healthCheckInterval,
            repeating: configuration.healthCheckInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.performHealthCheck()
        }
        healthCheckTimer = timer
        timer.resume()
    }

    private func performHealthCheck() {
        let now = Date()
        let timeSinceLastMotion = now.timeIntervalSince(lastSuccessfulMotionTime)

        if timeSinceLastMotion >= configuration.motionSilenceThreshold {
            // Motion silence after 10s: Disconnected
            connectionState = .disconnected
        } else if timeSinceLastMotion >= configuration.connectionTimeoutInterval {
            // Connection timeout after 5s: Reconnecting
            connectionState = .reconnecting
        }

        updateSnapshot()
    }

    private func stopAllTimers() {
        uiCoalescingTimer?.cancel()
        uiCoalescingTimer = nil
        healthCheckTimer?.cancel()
        healthCheckTimer = nil
        calibrationTimer?.invalidate()
        calibrationTimer = nil
    }

    private func updateSnapshot() {
        let now = Date()
        let adjustedPitch = currentPitch - configuration.normalAirPodsOffset
        let quality: AirPostureQuality =
            adjustedPitch < configuration.poorPostureThreshold ? .poor : .good

        // Resolve current session snapshot
        var sessionSnap: AirPostureSessionSnapshot?
        if let sessionStart = initialSessionStartTime {
            var currentDuration = accumulatedSessionDuration
            if !isSessionPaused, let intervalStart = currentSessionIntervalStartTime {
                currentDuration += now.timeIntervalSince(intervalStart)
            }

            var currentPoorDuration = accumulatedPoorPostureDuration
            if !isSessionPaused, let poorStart = poorPostureStartTime {
                currentPoorDuration += now.timeIntervalSince(poorStart)
            }

            let goodPercent =
                currentDuration > 0
                ? max(
                    0.0,
                    min(100.0, ((currentDuration - currentPoorDuration) / currentDuration) * 100.0))
                : 100.0

            sessionSnap = AirPostureSessionSnapshot(
                startTime: sessionStart,
                isPaused: isSessionPaused,
                totalDuration: currentDuration,
                poorPostureDuration: currentPoorDuration,
                goodPosturePercent: goodPercent
            )
        }

        let goodPosturePercent = sessionSnap?.goodPosturePercent ?? 100.0

        snapshot = AirPostureSnapshot(
            sample: latestSample,
            adjustedPitchDegrees: adjustedPitch,
            quality: quality,
            goodPosturePercent: goodPosturePercent,
            connectionState: connectionState,
            pitchHistory: pitchHistory,
            sessionSnapshot: sessionSnap,
            calibrationState: calibrationState
        )
    }
}

// MARK: - HeadphoneMotionProviderDelegate Implementation

extension AirPostureTracker: HeadphoneMotionProviderDelegate {
    public nonisolated func headphoneMotionProvider(
        _ provider: HeadphoneMotionProvider, didUpdate sample: HeadphoneMotionAttitudeSample
    ) {
        Task { @MainActor in
            self.processAttitudeSample(sample)
        }
    }

    public nonisolated func headphoneMotionProvider(
        _ provider: HeadphoneMotionProvider, didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.connectionState = .error
            self.updateSnapshot()
        }
    }
}
