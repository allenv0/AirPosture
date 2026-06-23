import Foundation

enum BackgroundConstants {
    static let backgroundRefreshIdentifier = "com.example.airposture.background-refresh"
    static let backgroundRefreshInterval: TimeInterval = 15 * 60
    static let taskDuration: TimeInterval = 25.0
    static let maxTotalTasks = 10
    static let maxConcurrentTasks = 1
    static let appStateCheckInterval: TimeInterval = 2.0
    static let minimumTaskCreationInterval: TimeInterval = 2.0
    static let maxConcurrentActiveTasks = 3
    static let cleanupTimeout: TimeInterval = 1.0
    static let coordinationResetDelay: TimeInterval = 0.1
}
