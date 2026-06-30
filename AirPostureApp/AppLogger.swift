import os
import Foundation

/// Production-ready logging subsystem for AirPosture.
/// Replace `print("...")` calls with the appropriate category logger.
///
/// Usage:
///   Logger.motion.info("Motion tracking started")
///   Logger.session.error("Failed to save session: \(error)")
///   Logger.background.warning("Background task expired")
///
/// Log levels:
///   .info     – expected lifecycle / status events
///   .warning  – recoverable abnormal state
///   .error    – failed operation / unrecoverable error
///   .debug    – verbose tracing (only in debug builds)
///   .notice   – significant events that deserve attention
extension Logger {
    /// The reverse-DNS subsystem identifier used by all AirPosture loggers.
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.allenleee.AirPosturePro"

    /// Motion tracking lifecycle and sensor data.
    static let motion = Logger(subsystem: subsystem, category: "MotionTracking")

    /// Session start, stop, pause, resume, and persistence.
    static let session = Logger(subsystem: subsystem, category: "Session")

    /// Background task management and lifecycle.
    static let background = Logger(subsystem: subsystem, category: "Background")

    /// Live Activity start, update, and end operations.
    static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")

    /// Bluetooth discovery, connection, and disconnection events.
    static let bluetooth = Logger(subsystem: subsystem, category: "Bluetooth")

    /// Haptic feedback start, stop, and countdown events.
    static let haptics = Logger(subsystem: subsystem, category: "Haptics")

    /// Memory pressure and resource usage events.
    static let memory = Logger(subsystem: subsystem, category: "Memory")

    /// UI rendering, transitions, and component lifecycle.
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Notification permission and delivery events.
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")

    /// Calendar/Analytics and other general events.
    static let general = Logger(subsystem: subsystem, category: "General")
}
