import CoreMotion
import Foundation

public struct HeadphoneMotionAttitudeSample: Equatable, Sendable {
    public let pitchRadians: Double
    public let rollRadians: Double
    public let yawRadians: Double
    public let timestamp: Date

    public init(
        pitchRadians: Double,
        rollRadians: Double,
        yawRadians: Double,
        timestamp: Date = Date()
    ) {
        self.pitchRadians = pitchRadians
        self.rollRadians = rollRadians
        self.yawRadians = yawRadians
        self.timestamp = timestamp
    }
}

/// Protocol defining the interface for a headphone motion provider, enabling robust mocking in test targets.
public protocol HeadphoneMotionProviderDelegate: AnyObject {
    func headphoneMotionProvider(
        _ provider: HeadphoneMotionProvider, didUpdate sample: HeadphoneMotionAttitudeSample)
    func headphoneMotionProvider(_ provider: HeadphoneMotionProvider, didFailWithError error: Error)
}

public protocol HeadphoneMotionProvider: AnyObject {
    var isDeviceMotionAvailable: Bool { get }
    var isDeviceMotionActive: Bool { get }
    var delegate: HeadphoneMotionProviderDelegate? { get set }

    func startDeviceMotionUpdates(to queue: OperationQueue)
    func stopDeviceMotionUpdates()
}

/// A standard implementation of `HeadphoneMotionProvider` wrapping Apple's `CMHeadphoneMotionManager`.
public final class CMHeadphoneMotionProvider: HeadphoneMotionProvider, @unchecked Sendable {
    private let motionManager: CMHeadphoneMotionManager
    public weak var delegate: HeadphoneMotionProviderDelegate?

    public var isDeviceMotionAvailable: Bool {
        return motionManager.isDeviceMotionAvailable
    }

    public var isDeviceMotionActive: Bool {
        return motionManager.isDeviceMotionActive
    }

    public init(motionManager: CMHeadphoneMotionManager = CMHeadphoneMotionManager()) {
        self.motionManager = motionManager
    }

    public func startDeviceMotionUpdates(to queue: OperationQueue) {
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self = self else { return }
            if let error = error {
                self.delegate?.headphoneMotionProvider(self, didFailWithError: error)
            } else if let motion = motion {
                let sample = HeadphoneMotionAttitudeSample(
                    pitchRadians: motion.attitude.pitch,
                    rollRadians: motion.attitude.roll,
                    yawRadians: motion.attitude.yaw,
                    timestamp: Date()
                )
                self.delegate?.headphoneMotionProvider(self, didUpdate: sample)
            }
        }
    }

    public func stopDeviceMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}

public final class MockHeadphoneMotionProvider: HeadphoneMotionProvider, @unchecked Sendable {
    public var isDeviceMotionAvailable: Bool
    public private(set) var isDeviceMotionActive: Bool = false
    public weak var delegate: HeadphoneMotionProviderDelegate?

    public init(isDeviceMotionAvailable: Bool = true) {
        self.isDeviceMotionAvailable = isDeviceMotionAvailable
    }

    public func startDeviceMotionUpdates(to queue: OperationQueue) {
        isDeviceMotionActive = isDeviceMotionAvailable
    }

    public func stopDeviceMotionUpdates() {
        isDeviceMotionActive = false
    }

    public func emit(
        pitchRadians: Double,
        rollRadians: Double = 0.0,
        yawRadians: Double = 0.0,
        timestamp: Date = Date()
    ) {
        guard isDeviceMotionActive else { return }
        let sample = HeadphoneMotionAttitudeSample(
            pitchRadians: pitchRadians,
            rollRadians: rollRadians,
            yawRadians: yawRadians,
            timestamp: timestamp
        )
        delegate?.headphoneMotionProvider(self, didUpdate: sample)
    }

    public func emit(error: Error) {
        delegate?.headphoneMotionProvider(self, didFailWithError: error)
    }
}
