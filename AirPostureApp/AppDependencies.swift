import SwiftUI

@MainActor
final class AppDependencies: ObservableObject {
    let motionTracker: HeadphoneMotionManager
    let sessionStore: SessionStore
    let hapticManager: HapticManager
    let notificationManager: NotificationManager
    let themeManager: ThemeManager
    let avatarManager: AvatarManager
    let backgroundCoordinator: UnifiedBackgroundCoordinator

    init() {
        let store = SessionStore.shared
        let theme = ThemeManager.shared
        let avatar = AvatarManager.shared
        let notification = NotificationManager.shared
        let haptic = HapticManager.shared
        let motion = HeadphoneMotionManager.shared
        let coordinator = UnifiedBackgroundCoordinator.shared

        self.sessionStore = store
        self.themeManager = theme
        self.avatarManager = avatar
        self.notificationManager = notification
        self.hapticManager = haptic
        self.motionTracker = motion
        self.backgroundCoordinator = coordinator
    }
}
