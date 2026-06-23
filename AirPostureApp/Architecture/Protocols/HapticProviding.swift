import Foundation

enum HapticFeedbackStyle: Int {
    case light = 0
    case medium = 1
    case heavy = 2
    case soft = 3
    case rigid = 4
}

@MainActor
protocol HapticProviding: AnyObject {
    func impact(style: HapticFeedbackStyle)
}
