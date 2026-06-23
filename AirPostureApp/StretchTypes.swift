import Foundation

enum StretchType: String, CaseIterable, Codable, Identifiable {
    case toeTouch = "Toe Touch"
    case sideBendLeft = "Side Bend (L)"
    case sideBendRight = "Side Bend (R)"
    case forwardFold = "Forward Fold"
    case neckStretchLeft = "Neck Stretch (L)"
    case neckStretchRight = "Neck Stretch (R)"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .toeTouch:
            return "figure.flexibility"
        case .sideBendLeft, .sideBendRight:
            return "figure.lateral-raise"
        case .forwardFold:
            return "figure.bend.down"
        case .neckStretchLeft, .neckStretchRight:
            return "figure.stand"
        }
    }
    
    var shortName: String {
        switch self {
        case .toeTouch:
            return "Toe Touch"
        case .sideBendLeft:
            return "Side Bend L"
        case .sideBendRight:
            return "Side Bend R"
        case .forwardFold:
            return "Fwd Fold"
        case .neckStretchLeft:
            return "Neck L"
        case .neckStretchRight:
            return "Neck R"
        }
    }
    
    var primarySource: TrackingSource {
        switch self {
        case .neckStretchLeft, .neckStretchRight:
            return .airPods
        case .toeTouch, .sideBendLeft, .sideBendRight, .forwardFold:
            return .arkit
        }
    }
    
    var targetAngle: Float {
        switch self {
        case .toeTouch:
            return 70.0
        case .sideBendLeft:
            return -30.0
        case .sideBendRight:
            return 30.0
        case .forwardFold:
            return 80.0
        case .neckStretchLeft:
            return -25.0
        case .neckStretchRight:
            return 25.0
        }
    }
    
    var angleRange: ClosedRange<Float> {
        switch self {
        case .toeTouch:
            return 60.0...80.0
        case .sideBendLeft:
            return -40.0...(-20.0)
        case .sideBendRight:
            return 20.0...40.0
        case .forwardFold:
            return 70.0...90.0
        case .neckStretchLeft:
            return -35.0...(-15.0)
        case .neckStretchRight:
            return 15.0...35.0
        }
    }
    
    var description: String {
        switch self {
        case .toeTouch:
            return "Bend forward to touch your toes"
        case .sideBendLeft:
            return "Bend sideways to the left"
        case .sideBendRight:
            return "Bend sideways to the right"
        case .forwardFold:
            return "Fold forward deeply"
        case .neckStretchLeft:
            return "Turn head to the left"
        case .neckStretchRight:
            return "Turn head to the right"
        }
    }
}

enum TrackingSource {
    case airPods
    case arkit
    case hybrid
}

enum StretchPhase {
    case idle
    case entering
    case holding
    case completing
    case recovering
}

struct StretchState {
    var type: StretchType
    var phase: StretchPhase = .idle
    var currentAngle: Float = 0
    var holdProgress: Double = 0
    var repCount: Int = 0
    var isInPosition: Bool = false
    
    var feedbackMessage: String {
        switch phase {
        case .idle:
            return "Get ready..."
        case .entering:
            return "Almost there..."
        case .holding:
            if holdProgress < 0.5 {
                return "Hold it!"
            } else if holdProgress < 0.8 {
                return "Great! Keep holding!"
            } else {
                return "Almost done!"
            }
        case .completing:
            return "Great job!"
        case .recovering:
            return "Good! Rest..."
        }
    }
}
