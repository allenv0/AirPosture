import Foundation

// MARK: - AirPostureConfiguration
public struct AirPostureConfiguration: Codable, Equatable {
    public var poorPostureThreshold: Double
    public var normalAirPodsOffset: Double
    public var lowPassFilterFactor: Double
    public var pitchHistorySize: Int
    public var uiSnapshotCoalescingInterval: TimeInterval
    public var healthCheckInterval: TimeInterval
    public var motionSilenceThreshold: TimeInterval
    public var connectionTimeoutInterval: TimeInterval

    public static let `default` = AirPostureConfiguration(
        poorPostureThreshold: -22.0,
        normalAirPodsOffset: 0.0,
        lowPassFilterFactor: 0.4,
        pitchHistorySize: 50,
        uiSnapshotCoalescingInterval: 1.0 / 15.0,
        healthCheckInterval: 2.0,
        motionSilenceThreshold: 10.0,
        connectionTimeoutInterval: 5.0
    )

    public init(
        poorPostureThreshold: Double = -22.0,
        normalAirPodsOffset: Double = 0.0,
        lowPassFilterFactor: Double = 0.4,
        pitchHistorySize: Int = 50,
        uiSnapshotCoalescingInterval: TimeInterval = 1.0 / 15.0,
        healthCheckInterval: TimeInterval = 2.0,
        motionSilenceThreshold: TimeInterval = 10.0,
        connectionTimeoutInterval: TimeInterval = 5.0
    ) {
        self.poorPostureThreshold = poorPostureThreshold
        self.normalAirPodsOffset = normalAirPodsOffset
        self.lowPassFilterFactor = lowPassFilterFactor
        self.pitchHistorySize = pitchHistorySize
        self.uiSnapshotCoalescingInterval = uiSnapshotCoalescingInterval
        self.healthCheckInterval = healthCheckInterval
        self.motionSilenceThreshold = motionSilenceThreshold
        self.connectionTimeoutInterval = connectionTimeoutInterval
    }
}

// MARK: - AirPostureSample
public struct AirPostureSample: Codable, Equatable {
    public let pitch: Double
    public let roll: Double
    public let yaw: Double
    public let timestamp: Date

    public init(pitch: Double, roll: Double, yaw: Double, timestamp: Date = Date()) {
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.timestamp = timestamp
    }
}

// MARK: - AirPostureConnectionState
public enum AirPostureConnectionState: String, Codable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error
}

// MARK: - AirPostureQuality
public enum AirPostureQuality: String, Codable, Equatable {
    case good
    case poor
}

// MARK: - AirPostureSessionSnapshot
public struct AirPostureSessionSnapshot: Codable, Equatable {
    public let startTime: Date
    public let isPaused: Bool
    public let totalDuration: TimeInterval
    public let poorPostureDuration: TimeInterval
    public let goodPosturePercent: Double

    public init(
        startTime: Date,
        isPaused: Bool,
        totalDuration: TimeInterval,
        poorPostureDuration: TimeInterval,
        goodPosturePercent: Double
    ) {
        self.startTime = startTime
        self.isPaused = isPaused
        self.totalDuration = totalDuration
        self.poorPostureDuration = poorPostureDuration
        self.goodPosturePercent = goodPosturePercent
    }
}

// MARK: - AirPostureSessionSummary
public struct AirPostureSessionSummary: Codable, Equatable {
    public let startTime: Date
    public let endTime: Date
    public let totalDuration: TimeInterval
    public let poorPostureDuration: TimeInterval
    public let goodPosturePercent: Double

    public init(
        startTime: Date,
        endTime: Date,
        totalDuration: TimeInterval,
        poorPostureDuration: TimeInterval,
        goodPosturePercent: Double
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.totalDuration = totalDuration
        self.poorPostureDuration = poorPostureDuration
        self.goodPosturePercent = goodPosturePercent
    }
}

// MARK: - AirPostureCalibrationState
public enum AirPostureCalibrationState: Codable, Equatable {
    case idle
    case recordingGoodPosture(progress: Double)
    case transition(progress: Double)
    case recordingBadPosture(progress: Double)
    case complete(goodPostureAverage: Double, badPostureAverage: Double, calculatedThreshold: Double)

    private enum CodingKeys: String, CodingKey {
        case type
        case progress
        case goodPostureAverage
        case badPostureAverage
        case calculatedThreshold
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "idle":
            self = .idle
        case "recordingGoodPosture":
            let progress = try container.decode(Double.self, forKey: .progress)
            self = .recordingGoodPosture(progress: progress)
        case "transition":
            let progress = try container.decode(Double.self, forKey: .progress)
            self = .transition(progress: progress)
        case "recordingBadPosture":
            let progress = try container.decode(Double.self, forKey: .progress)
            self = .recordingBadPosture(progress: progress)
        case "complete":
            let goodAvg = try container.decode(Double.self, forKey: .goodPostureAverage)
            let badAvg = try container.decode(Double.self, forKey: .badPostureAverage)
            let threshold = try container.decode(Double.self, forKey: .calculatedThreshold)
            self = .complete(goodPostureAverage: goodAvg, badPostureAverage: badAvg, calculatedThreshold: threshold)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown calibration state type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle:
            try container.encode("idle", forKey: .type)
        case .recordingGoodPosture(let progress):
            try container.encode("recordingGoodPosture", forKey: .type)
            try container.encode(progress, forKey: .progress)
        case .transition(let progress):
            try container.encode("transition", forKey: .type)
            try container.encode(progress, forKey: .progress)
        case .recordingBadPosture(let progress):
            try container.encode("recordingBadPosture", forKey: .type)
            try container.encode(progress, forKey: .progress)
        case .complete(let goodAvg, let badAvg, let threshold):
            try container.encode("complete", forKey: .type)
            try container.encode(goodAvg, forKey: .goodPostureAverage)
            try container.encode(badAvg, forKey: .badPostureAverage)
            try container.encode(threshold, forKey: .calculatedThreshold)
        }
    }
}

// MARK: - AirPostureSnapshot
public struct AirPostureSnapshot: Codable, Equatable {
    public let sample: AirPostureSample?
    public let adjustedPitchDegrees: Double
    public let quality: AirPostureQuality
    public let goodPosturePercent: Double
    public let connectionState: AirPostureConnectionState
    public let pitchHistory: [Double]
    public let sessionSnapshot: AirPostureSessionSnapshot?
    public let calibrationState: AirPostureCalibrationState

    public static let initial = AirPostureSnapshot(
        sample: nil,
        adjustedPitchDegrees: 0.0,
        quality: .good,
        goodPosturePercent: 100.0,
        connectionState: .disconnected,
        pitchHistory: [],
        sessionSnapshot: nil,
        calibrationState: .idle
    )

    public init(
        sample: AirPostureSample?,
        adjustedPitchDegrees: Double,
        quality: AirPostureQuality,
        goodPosturePercent: Double,
        connectionState: AirPostureConnectionState,
        pitchHistory: [Double],
        sessionSnapshot: AirPostureSessionSnapshot?,
        calibrationState: AirPostureCalibrationState
    ) {
        self.sample = sample
        self.adjustedPitchDegrees = adjustedPitchDegrees
        self.quality = quality
        self.goodPosturePercent = goodPosturePercent
        self.connectionState = connectionState
        self.pitchHistory = pitchHistory
        self.sessionSnapshot = sessionSnapshot
        self.calibrationState = calibrationState
    }
}
