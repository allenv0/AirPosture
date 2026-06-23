import Foundation
import Combine

@MainActor
class RepCounter: ObservableObject {
    @Published var currentReps: Int = 0
    @Published var isHolding: Bool = false
    @Published var holdProgress: Double = 0.0
    @Published var isRecovering: Bool = false
    @Published var totalSessionReps: Int = 0
    
    private var settings: RepCountingSettings
    private var holdStartTime: Date?
    private var lastRepTime: Date?
    private var recoveryEndTime: Date?
    private var lastProgressUpdate: Double = -1
    
    private let voiceEngine = BearVoiceEngine.shared
    private let hapticEngine = StretchHapticEngine.shared
    
    private var currentStretch: StretchType = .toeTouch
    private var maxRepsThisSession: Int = 0
    
    private var allTimeBestReps: Int = 0

    init(settings: RepCountingSettings = .default) {
        self.settings = settings
    }
    
    func setStretch(_ stretch: StretchType) {
        currentStretch = stretch
    }
    
    func updateSettings(_ newSettings: RepCountingSettings) {
        settings = newSettings
    }
    
    func update(poseAngle: Float, targetAngle: Float) {
        let tolerance = Float(settings.tolerance(for: currentStretch))
        let isInPose = abs(poseAngle - targetAngle) < tolerance
        
        let holdDuration = settings.holdDuration(for: currentStretch)
        let recoveryDelay = settings.recoveryDelaySeconds
        
        if isRecovering {
            if let endTime = recoveryEndTime, Date() >= endTime {
                isRecovering = false
                recoveryEndTime = nil
            }
            return
        }
        
        if isInPose && !isHolding {
            isHolding = true
            holdStartTime = Date()
            holdProgress = 0.0
            
        } else if isInPose && isHolding {
            guard let startTime = holdStartTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            holdProgress = min(elapsed / holdDuration, 1.0)
            
            if holdProgress >= 1.0 {
                completeRep()
            } else if holdProgress >= 0.8 && lastProgressUpdate < 0.8 {
                voiceEngine.speakGreatKeepGoing()
                hapticEngine.onAlmostThere()
            } else if holdProgress >= 0.5 && lastProgressUpdate < 0.5 {
                voiceEngine.speakHoldIt()
            }
            
            lastProgressUpdate = holdProgress
            
        } else if !isInPose && isHolding {
            resetHold()
        }
    }
    
    func updateWithAngle(angle: Float) {
        update(poseAngle: angle, targetAngle: currentStretch.targetAngle)
    }
    
    private func completeRep() {
        let now = Date()
        
        if let lastRep = lastRepTime, now.timeIntervalSince(lastRep) < settings.recoveryDelaySeconds {
            resetHold()
            return
        }
        
        currentReps += 1
        totalSessionReps += 1
        lastRepTime = now
        maxRepsThisSession = max(maxRepsThisSession, currentReps)
        
        voiceEngine.speakRepComplete(currentReps)
        hapticEngine.onRepComplete()
        
        if currentReps > 1 {
            if currentReps > allTimeBestReps {
                allTimeBestReps = currentReps
                voiceEngine.speakNewRecord(currentReps)
                hapticEngine.onNewRecord()
            }
            if currentReps == StretchSettingsManager.shared.targetReps {
                voiceEngine.speakStretchComplete(currentStretch.shortName)
                hapticEngine.onStretchComplete()
            }
        }
        
        isRecovering = true
        recoveryEndTime = now.addingTimeInterval(settings.recoveryDelaySeconds)
        
        resetHold()
    }
    
    private func resetHold() {
        isHolding = false
        holdProgress = 0.0
        holdStartTime = nil
        lastProgressUpdate = -1
    }
    
    func reset() {
        currentReps = 0
        totalSessionReps = 0
        maxRepsThisSession = 0
        allTimeBestReps = 0
        resetHold()
        isRecovering = false
        recoveryEndTime = nil
    }
    
    func setTargetReps(_ target: Int) {
        // This will be handled by StretchSettingsManager
    }
}
