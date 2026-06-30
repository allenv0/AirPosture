#if os(iOS)
import UIKit
#endif
import Foundation
import os
import UserNotifications
import AudioToolbox

enum NotificationMode: String, CaseIterable {
    case realTime = "Real-time"
    case sessionSummary = "Session Summary Only"

    var description: String {
        switch self {
        case .realTime:
            return "Get notifications during sessions for posture warnings and feedback"
        case .sessionSummary:
            return "Only receive a summary notification when your session ends"
        }
    }
}

enum AudioCueStyle: String, CaseIterable {
    case alert = "1304"
    case pop = "1054"
    case chime = "1057"
    case glass = "1109"
    case pulse = "1306"

    var displayName: String {
        switch self {
        case .alert: return "Alert"
        case .pop: return "Pop"
        case .chime: return "Chime"
        case .glass: return "Glass"
        case .pulse: return "Pulse"
        }
    }

    var description: String {
        switch self {
        case .alert: return "Sharp alert tone"
        case .pop: return "Quick pop sound"
        case .chime: return "Soft notification chime"
        case .glass: return "Light glass ping"
        case .pulse: return "Subtle pulse tone"
        }
    }

    var soundID: SystemSoundID {
        UInt32(rawValue) ?? 1304
    }

    static let `default`: AudioCueStyle = .alert
}

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isNotificationEnabled: Bool = false
    @Published var notificationMode: NotificationMode {
        didSet {
            UserDefaults.standard.set(notificationMode.rawValue, forKey: UserDefaultsKeys.notificationMode)
        }
    }
    @Published var audioCueStyle: AudioCueStyle {
        didSet {
            UserDefaults.standard.set(audioCueStyle.rawValue, forKey: UserDefaultsKeys.audioCueStyle)
        }
    }
    private init() {
        let savedMode = UserDefaults.standard.string(forKey: UserDefaultsKeys.notificationMode) ?? NotificationMode.sessionSummary.rawValue
        self.notificationMode = NotificationMode(rawValue: savedMode) ?? .sessionSummary
        let savedCue = UserDefaults.standard.string(forKey: UserDefaultsKeys.audioCueStyle) ?? AudioCueStyle.default.rawValue
        self.audioCueStyle = AudioCueStyle(rawValue: savedCue) ?? .default
        checkNotificationPermission()
    }

    private func updateNotificationStatus(_ enabled: Bool) {
        isNotificationEnabled = enabled
    }
    
    // MARK: - Permission Management
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            updateNotificationStatus(granted)
            Logger.notifications.info("Notification permission granted: \(granted)")

            if granted {
                await setupNotificationDelegate()
            }

            return granted
        } catch {
            Logger.notifications.error("Failed to request notification permission: \(error)")
            updateNotificationStatus(false)
            return false
        }
    }

    @MainActor
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let isAuthorized = settings.authorizationStatus == .authorized

            Task { @MainActor in
                self?.updateNotificationStatus(isAuthorized)
                Logger.notifications.debug("Notification permission status: \(settings.authorizationStatus.rawValue) - isEnabled: \(isAuthorized)")

                if isAuthorized {
                    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                }
            }
        }
    }

    func logNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Logger.notifications.debug("Current notification settings - Authorization: \(settings.authorizationStatus.rawValue), Alert: \(settings.alertSetting.rawValue), Sound: \(settings.soundSetting.rawValue), Badge: \(settings.badgeSetting.rawValue)")
        }
    }

    func forceRefreshPermissionStatus() {
        Logger.notifications.debug("Force refreshing notification permission status")
        checkNotificationPermission()
    }
    
    // MARK: - Posture Notifications
    func sendPostureWarningNotification() {
        Logger.notifications.debug("Attempting to send posture warning notification - isEnabled: \(self.isNotificationEnabled), mode: \(String(describing: self.notificationMode))")
        
        // Play audio cue immediately — AudioServicesPlaySystemSound doesn't need
        // notification permission. Don't gate it behind isNotificationEnabled or
        // notificationMode; those only control the UNNotification delivery.
        playAudioCue(soundID: 1304)
        
        guard isNotificationEnabled, notificationMode == .realTime else {
            Logger.notifications.warning("UNNotification not sent - notifications disabled or not in real-time mode (audio cue played)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Poor Posture Detected"
        content.body = "You've been in poor posture for a while. Haptic feedback will start soon."
        content.sound = .default
        content.categoryIdentifier = "POSTURE_WARNING"
        
        let request = UNNotificationRequest(
            identifier: "posture_warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.notifications.error("Failed to send warning notification: \(error)")
            } else {
                Logger.notifications.info("Posture warning notification sent")
            }
        }
    }
    
    func sendHapticStartNotification() {
        Logger.notifications.debug("Attempting to send haptic start notification - isEnabled: \(self.isNotificationEnabled), mode: \(String(describing: self.notificationMode))")
        
        // Play audio cue immediately — AudioServicesPlaySystemSound doesn't need
        // notification permission. Don't gate it behind isNotificationEnabled or
        // notificationMode; those only control the UNNotification delivery.
        playAudioCue(soundID: 1007)
        
        guard isNotificationEnabled, notificationMode == .realTime else {
            Logger.notifications.warning("UNNotification not sent - notifications disabled or not in real-time mode (audio cue played)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Haptic Feedback Started"
        content.body = "Improve your posture to stop the haptic feedback."
        content.sound = .default
        content.categoryIdentifier = "HAPTIC_START"
        
        let request = UNNotificationRequest(
            identifier: "haptic_start_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.notifications.error("Failed to send haptic start notification: \(error)")
            } else {
                Logger.notifications.info("Haptic start notification sent")
            }
        }
    }
    
    // MARK: - Session Notifications
    func sendSessionCompleteNotification(duration: TimeInterval, poorPosturePercentage: Int) {
        Logger.notifications.debug("Attempting to send session complete notification - isEnabled: \(self.isNotificationEnabled), mode: \(String(describing: self.notificationMode)), duration: \(duration), percentage: \(poorPosturePercentage)")

        guard isNotificationEnabled else {
            Logger.notifications.warning("Session notification not sent - notifications disabled")
            return
        }

        let minutes = Int(duration / 60)

        let content = UNMutableNotificationContent()
        content.title = "✅ Complete"
        content.body = "\(minutes) min session • \(poorPosturePercentage)% Good Posture"
        content.sound = .default
        content.categoryIdentifier = "SESSION_COMPLETE"
        
        let request = UNNotificationRequest(
            identifier: "session_complete_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.notifications.error("Failed to send session complete notification: \(error)")
            } else {
                Logger.notifications.info("Session complete notification sent")
            }
        }
    }
    
    // MARK: - Connection Notifications
    func sendConnectionLostNotification() {
        Logger.notifications.debug("Attempting to send connection lost notification - isEnabled: \(self.isNotificationEnabled)")
        guard isNotificationEnabled else {
            Logger.notifications.warning("Connection lost notification not sent - notifications disabled")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "AirPods Disconnected"
        content.body = "Posture tracking paused. Reconnect your AirPods to continue."
        content.sound = .default
        content.categoryIdentifier = "CONNECTION_LOST"
        
        let request = UNNotificationRequest(
            identifier: "connection_lost_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.notifications.error("Failed to send connection lost notification: \(error)")
            } else {
                Logger.notifications.info("Connection lost notification sent")
            }
        }
    }
    
    // MARK: - Test Methods
    func sendTestNotification() {
        Logger.notifications.debug("Sending test notification - isEnabled: \(self.isNotificationEnabled)")

        guard isNotificationEnabled else {
            Logger.notifications.warning("Test notification not sent - notifications disabled")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from AirPosture"
        content.sound = .default
        content.categoryIdentifier = "TEST"

        let request = UNNotificationRequest(
            identifier: "test_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.notifications.error("Failed to send test notification: \(error)")
            } else {
                Logger.notifications.info("Test notification sent successfully")
            }
        }
    }

    func sendForceTestNotification() {
        Logger.notifications.debug("Force sending test notification - bypassing permission check")

        let content = UNMutableNotificationContent()
        content.title = "FORCE Test Notification"
        content.body = "This is a FORCE test notification from AirPosture (bypassing permission check)"
        content.sound = .default
        content.categoryIdentifier = "FORCE_TEST"

        let request = UNNotificationRequest(
            identifier: "force_test_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.notifications.error("Failed to send force test notification: \(error)")
            } else {
                Logger.notifications.info("Force test notification sent successfully")
            }
        }

        logNotificationStatus()
    }

    // MARK: - Utility Methods
    private func playAudioCue(soundID: SystemSoundID) {
        guard HeadphoneMotionManager.shared.isHapticFeedbackEnabled else { return }
        AudioServicesPlaySystemSound(audioCueStyle.soundID)
    }

    func previewAudioCue() {
        AudioServicesPlaySystemSound(audioCueStyle.soundID)
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        Logger.notifications.info("All notifications cleared")
    }
    
    func openNotificationSettings() {
        #if os(iOS)
        guard let settingsUrl = URL(string: UIApplication.openNotificationSettingsURLString) else { return }

        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
        #endif
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {
        super.init()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.notifications.debug("Notification will present: \(notification.request.content.title)")
        completionHandler([.alert, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Logger.notifications.debug("Notification tapped: \(response.notification.request.content.title)")
        completionHandler()
    }
}
