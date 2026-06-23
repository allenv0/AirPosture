#if os(iOS)
import UIKit
#endif

final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}

    #if os(iOS)
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        Task { @MainActor in
            // Check if haptic feedback is enabled globally
            let motionManager = HeadphoneMotionManager.shared
            guard motionManager.isHapticFeedbackEnabled else {
                return
            }

            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }
    #endif
}
