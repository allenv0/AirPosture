import ActivityKit
import Foundation

// MARK: - Live Activity Data Model

@available(iOS 16.1, *)
public struct AirPostureActivityAttributes: ActivityAttributes {
    @available(iOS 16.1, *)
    public struct ContentState: Codable, Hashable {
        private enum CodingKeys: String, CodingKey {
            case postureStatus
            case sessionScorePercent
            case lastUpdate
            case tiltDegrees
            case leanDegrees
            case elapsedSeconds
            case isSessionPaused
        }

        public var postureStatus: PostureStatus
        public var sessionScorePercent: Int
        public var lastUpdate: Date
        public var tiltDegrees: Double
        public var leanDegrees: Double
        public var elapsedSeconds: Int
        public var isSessionPaused: Bool

        public init(
            postureStatus: PostureStatus,
            sessionScorePercent: Int,
            lastUpdate: Date,
            tiltDegrees: Double = 0,
            leanDegrees: Double = 0,
            elapsedSeconds: Int = 0,
            isSessionPaused: Bool = false
        ) {
            self.postureStatus = postureStatus
            self.sessionScorePercent = max(0, min(100, sessionScorePercent))
            self.lastUpdate = lastUpdate
            self.tiltDegrees = tiltDegrees
            self.leanDegrees = leanDegrees
            self.elapsedSeconds = max(0, elapsedSeconds)
            self.isSessionPaused = isSessionPaused
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            postureStatus = try container.decodeIfPresent(PostureStatus.self, forKey: .postureStatus) ?? .unknown
            sessionScorePercent = max(
                0,
                min(
                    100,
                    try container.decodeIfPresent(Int.self, forKey: .sessionScorePercent) ?? 100
                )
            )
            lastUpdate = try container.decodeIfPresent(Date.self, forKey: .lastUpdate) ?? Date()
            tiltDegrees = try container.decodeIfPresent(Double.self, forKey: .tiltDegrees) ?? 0
            leanDegrees = try container.decodeIfPresent(Double.self, forKey: .leanDegrees) ?? 0
            elapsedSeconds = max(0, try container.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0)
            isSessionPaused = try container.decodeIfPresent(Bool.self, forKey: .isSessionPaused) ?? false
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(postureStatus, forKey: .postureStatus)
            try container.encode(sessionScorePercent, forKey: .sessionScorePercent)
            try container.encode(lastUpdate, forKey: .lastUpdate)
            try container.encode(tiltDegrees, forKey: .tiltDegrees)
            try container.encode(leanDegrees, forKey: .leanDegrees)
            try container.encode(elapsedSeconds, forKey: .elapsedSeconds)
            try container.encode(isSessionPaused, forKey: .isSessionPaused)
        }

        public var poorPosturePercent: Int {
            max(0, 100 - sessionScorePercent)
        }
    }

    public var sessionId: UUID
    public var avatarAssetName: String
    public var userDisplayName: String?
    public var sessionStartTime: Date

    public init(
        sessionId: UUID,
        avatarAssetName: String,
        userDisplayName: String? = nil,
        sessionStartTime: Date = Date()
    ) {
        self.sessionId = sessionId
        self.avatarAssetName = avatarAssetName
        self.userDisplayName = userDisplayName
        self.sessionStartTime = sessionStartTime
    }
}

@available(iOS 16.1, *)
public enum PostureStatus: String, Codable, Hashable {
    case good
    case poor
    case unknown
}
