enum StartButtonState {
    case idle
    case connecting
    case success
    case error
    case retrying

    var title: String {
        switch self {
        case .idle, .success:
            return "Start"
        case .connecting:
            return "Connecting..."
        case .error:
            return "Finding AirPods"
        case .retrying:
            return "Retrying..."
        }
    }

    var accessibilityValue: String {
        switch self {
        case .idle:
            return "Ready to start posture tracking."
        case .connecting:
            return "Checking for compatible AirPods."
        case .success:
            return "AirPods connected. Starting posture tracking."
        case .error:
            return "AirPods were not found. Connection help is open."
        case .retrying:
            return "Retrying AirPods connection."
        }
    }

    var isInteractionBlocked: Bool {
        switch self {
        case .idle, .success:
            return false
        case .connecting, .error, .retrying:
            return true
        }
    }
}
