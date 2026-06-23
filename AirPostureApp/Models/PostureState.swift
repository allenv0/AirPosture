import Foundation

enum PostureState: Equatable {
    case good(postureDuration: TimeInterval)
    case warning(pitch: Double, timeAboveThreshold: TimeInterval)
    case alert(pitch: Double, duration: TimeInterval)

    var lastGoodStateTime: Date {
        switch self {
        case .good(let duration):
            return Date().addingTimeInterval(-duration)
        default:
            return Date()
        }
    }

    var shouldTriggerHaptic: Bool {
        if case .alert = self {
            return true
        }
        return false
    }

    var isGood: Bool {
        if case .good = self { return true }
        return false
    }

    var isWarning: Bool {
        if case .warning = self { return true }
        return false
    }

    var isAlert: Bool {
        if case .alert = self { return true }
        return false
    }
}
