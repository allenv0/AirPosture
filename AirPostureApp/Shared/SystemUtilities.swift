import Foundation

enum SystemUtilities {
    static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    static func formatBytes(_ bytes: Int64) -> String {
        byteFormatter.string(fromByteCount: bytes)
    }

    #if os(iOS)
    static func getCurrentMemoryUsage() -> (used: UInt64, available: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        let available = UInt64(os_proc_available_memory())
        return (info.resident_size, available)
    }
    #endif

    static func cancelTimerSourceSafely(_ source: inout DispatchSourceTimer?) {
        source?.setEventHandler(handler: {})
        source?.cancel()
        source = nil
    }
}
