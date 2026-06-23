import Foundation

struct RepCountingSettings: Codable {
    var holdDurationSeconds: Double
    var recoveryDelaySeconds: Double
    var angleToleranceDegrees: Double
    
    var stretchSpecificHoldDuration: [String: Double]?
    var stretchSpecificTolerance: [String: Double]?
    
    static let `default` = RepCountingSettings(
        holdDurationSeconds: 2.0,
        recoveryDelaySeconds: 1.0,
        angleToleranceDegrees: 10.0
    )
    
    func holdDuration(for stretch: StretchType) -> Double {
        if let specific = stretchSpecificHoldDuration?[stretch.rawValue] {
            return specific
        }
        return holdDurationSeconds
    }
    
    func tolerance(for stretch: StretchType) -> Double {
        if let specific = stretchSpecificTolerance?[stretch.rawValue] {
            return specific
        }
        return angleToleranceDegrees
    }
}

@MainActor
class StretchSettingsManager: ObservableObject {
    static let shared = StretchSettingsManager()
    
    @Published var settings: RepCountingSettings {
        didSet {
            save()
        }
    }
    
    @Published var voiceEnabled: Bool {
        didSet {
            UserDefaults.standard.set(voiceEnabled, forKey: UserDefaultsKeys.stretchVoiceEnabled)
        }
    }
    
    @Published var hapticEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticEnabled, forKey: UserDefaultsKeys.stretchHapticEnabled)
        }
    }
    
    @Published var showRepCount: Bool {
        didSet {
            UserDefaults.standard.set(showRepCount, forKey: UserDefaultsKeys.stretchShowRepCount)
        }
    }
    
    @Published var targetReps: Int {
        didSet {
            UserDefaults.standard.set(targetReps, forKey: UserDefaultsKeys.stretchTargetReps)
        }
    }
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.repCountingSettings),
           let decoded = try? JSONDecoder().decode(RepCountingSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
        
        self.voiceEnabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.stretchVoiceEnabled) as? Bool ?? true
        self.hapticEnabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.stretchHapticEnabled) as? Bool ?? true
        self.showRepCount = UserDefaults.standard.object(forKey: UserDefaultsKeys.stretchShowRepCount) as? Bool ?? true
        self.targetReps = UserDefaults.standard.object(forKey: UserDefaultsKeys.stretchTargetReps) as? Int ?? 10
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: UserDefaultsKeys.repCountingSettings)
        }
    }
    
    func updateHoldDuration(_ value: Double) {
        settings.holdDurationSeconds = value
    }
    
    func updateRecoveryDelay(_ value: Double) {
        settings.recoveryDelaySeconds = value
    }
    
    func updateAngleTolerance(_ value: Double) {
        settings.angleToleranceDegrees = value
    }
    
    func updateSpecificHoldDuration(_ stretch: StretchType, _ value: Double) {
        if settings.stretchSpecificHoldDuration == nil {
            settings.stretchSpecificHoldDuration = [:]
        }
        settings.stretchSpecificHoldDuration?[stretch.rawValue] = value
    }
    
    func updateSpecificTolerance(_ stretch: StretchType, _ value: Double) {
        if settings.stretchSpecificTolerance == nil {
            settings.stretchSpecificTolerance = [:]
        }
        settings.stretchSpecificTolerance?[stretch.rawValue] = value
    }
    
    func resetToDefaults() {
        settings = .default
    }
}
