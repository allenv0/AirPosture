import Foundation

@MainActor
protocol ConnectionMonitoring: AnyObject {
    var isDeviceConnected: Bool { get }
    var connectionStatus: String { get }
    var connectedDeviceName: String { get }

    func checkForAirPodsImmediate() -> Bool
    func checkConnectionStatusForUI()
    func forceCheckAirPodsConnection()
}
