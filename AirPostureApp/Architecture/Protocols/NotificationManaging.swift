import Foundation

@MainActor
protocol NotificationManaging: AnyObject {
    var isNotificationEnabled: Bool { get }
    var notificationMode: NotificationMode { get set }

    func requestNotificationPermission() async -> Bool
    func sendPostureWarningNotification()
    func sendHapticStartNotification()
    func sendSessionCompleteNotification(duration: TimeInterval, poorPosturePercentage: Int)
    func sendConnectionLostNotification()
    func clearAllNotifications()
}
