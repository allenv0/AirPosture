import Foundation
import Combine
@preconcurrency import CoreMotion

@MainActor
final class HeadphoneMotionManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var pitch: Double = 0.0
    @Published private(set) var roll: Double = 0.0
    @Published private(set) var yaw: Double = 0.0
    @Published private(set) var isDeviceConnected: Bool = false
    @Published private(set) var connectionStatus: String = "Not started"
    @Published private(set) var postureState: PostureState = .good(postureDuration: 0)
    @Published private(set) var pitchHistory: [Double] = []
    @Published private(set) var poorPostureDuration: TimeInterval = 0
    @Published private(set) var poorPosturePercentage: Int = 0
    
    // MARK: - Private Properties
    private let motionManager = CMHeadphoneMotionManager()
    private var cancellables = Set<AnyCancellable>()
    private var poorPostureStartTime: Date?
    private var sessionStartTime: Date = Date()
    @Published private var totalSessionTime: TimeInterval = 0
    private let maxDataPoints = 100
    private let updateQueue = DispatchQueue(label: "com.necksync.motionUpdates", qos: .userInteractive)
    private let motionUpdateInterval: TimeInterval = 1.0/60.0 // 60 FPS
    
    // MARK: - Constants
    private enum Constants {
        static let poorPostureThreshold: Double = -22.0
        static let warningThreshold: Double = 20.0
        static let lowPassFilterFactor: Double = 0.2
    }
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    deinit {
        Task { @MainActor in
            stop()
        }
    }
    
    // MARK: - Public Methods
    @MainActor
    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            connectionStatus = "Device motion not available"
            return
        }
        
        connectionStatus = "Starting motion updates"
        
        // Start device motion updates
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            if let error = error {
                self?.connectionStatus = "Error: \(error.localizedDescription)"
                self?.isDeviceConnected = false
                return
            }
            
            guard let motion = motion else { return }
            self?.processMotionData(motion)
        }
        
        // Setup periodic updates
        Timer.publish(every: motionUpdateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkDeviceStatus()
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func stop() {
        motionManager.stopDeviceMotionUpdates()
        cancellables.removeAll()
        connectionStatus = "Stopped"
        isDeviceConnected = false
    }
    
    @MainActor
    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.start()
        }
    }
    
    @MainActor
    func resetSession() {
        pitchHistory.removeAll()
        poorPostureDuration = 0
        poorPostureStartTime = nil
        sessionStartTime = Date()
        totalSessionTime = 0
        poorPosturePercentage = 0
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Update poor posture percentage when duration changes
        $poorPostureDuration
            .combineLatest($totalSessionTime)
            .map { duration, totalTime in
                totalTime > 0 ? Int((duration / totalTime) * 100) : 0
            }
            .assign(to: \.poorPosturePercentage, on: self)
            .store(in: &cancellables)
    }
    
    private func processMotionData(_ motion: CMDeviceMotion) {
        // Update motion data on background thread
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Convert to degrees and apply low-pass filter
            let newPitch = self.lowPassFilter(
                current: motion.attitude.pitch * 180 / .pi,
                previous: self.pitch
            )
            
            DispatchQueue.main.async {
                self.pitch = newPitch
                self.roll = motion.attitude.roll * 180 / .pi
                self.yaw = motion.attitude.yaw * 180 / .pi
                self.isDeviceConnected = true
                self.connectionStatus = "Connected"
                
                self.updatePitchHistory(newPitch)
                self.updatePostureState(newPitch: newPitch)
                self.updateSessionTimers(newPitch: newPitch)
            }
        }
    }
    
    private func updatePitchHistory(_ newPitch: Double) {
        pitchHistory.append(newPitch)
        if pitchHistory.count > maxDataPoints {
            pitchHistory.removeFirst()
        }
    }
    
    private func updatePostureState(newPitch: Double) {
        let currentTime = Date()
        
        if newPitch > Constants.warningThreshold {
            let duration = postureState.lastGoodStateTime.distance(to: currentTime)
            postureState = duration > 2.0 ? 
                .alert(pitch: newPitch, duration: duration) : 
                .warning(pitch: newPitch, timeAboveThreshold: duration)
        } else {
            let duration = currentTime.timeIntervalSince(sessionStartTime)
            postureState = .good(postureDuration: duration)
        }
    }
    
    private func updateSessionTimers(newPitch: Double) {
        let currentTime = Date()
        let timeSinceLastUpdate = currentTime.timeIntervalSince(sessionStartTime)
        totalSessionTime += timeSinceLastUpdate
        sessionStartTime = currentTime
        
        if newPitch < Constants.poorPostureThreshold {
            if poorPostureStartTime == nil {
                poorPostureStartTime = currentTime
            }
            poorPostureDuration += timeSinceLastUpdate
        } else {
            poorPostureStartTime = nil
        }
    }
    
    private func checkDeviceStatus() {
        if !motionManager.isDeviceMotionAvailable && isDeviceConnected {
            connectionStatus = "Device disconnected"
            isDeviceConnected = false
        }
    }
    
    private func lowPassFilter(current: Double, previous: Double) -> Double {
        return previous * (1.0 - Constants.lowPassFilterFactor) + current * Constants.lowPassFilterFactor
    }
}

// MARK: - PostureState
enum PostureState {
    case good(postureDuration: TimeInterval)
    case warning(pitch: Double, timeAboveThreshold: TimeInterval)
    case alert(pitch: Double, duration: TimeInterval)
    
    var lastGoodStateTime: Date {
        switch self {
        case .good(let duration):
            return Date().addingTimeInterval(-duration)
        default:
            return Date()
        }
    }
    
    var shouldTriggerHaptic: Bool {
        if case .alert = self {
            return true
        }
        return false
    }
}
