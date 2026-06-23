import Foundation
import ARKit
import Combine
import simd
import os

@MainActor
class StretchTracker: ObservableObject {
    static let shared = StretchTracker()
    
    @Published var isActive: Bool = false
    @Published var currentStretch: StretchType = .toeTouch
    @Published var stretchState: StretchState
    @Published var isBodyDetected: Bool = false
    @Published var trackingStatus: String = "Ready"
    @Published var currentAngle: Float = 0
    @Published var showBodyWarning: Bool = false
    
    let poseProcessor = BodyPoseProcessor()
    let repCounter = RepCounter()
    let voiceEngine = BearVoiceEngine.shared
    let hapticEngine = StretchHapticEngine.shared
    
    let settings = StretchSettingsManager.shared
    
    var bearAvatar: BearAvatar?
    
    private var cancellables = Set<AnyCancellable>()
    private let motionManager = HeadphoneMotionManager.shared
    
    private init() {
        stretchState = StretchState(type: .toeTouch)
        setupBindings()
    }
    
    private func setupBindings() {
        repCounter.$holdProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.stretchState.holdProgress = progress
            }
            .store(in: &cancellables)
        
        repCounter.$currentReps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reps in
                self?.stretchState.repCount = reps
            }
            .store(in: &cancellables)
    }
    
    func start() {
        guard ARSessionManager.isSupported else {
            trackingStatus = "AR Body Tracking not supported"
            isActive = false
            return
        }
        
        isActive = true
        repCounter.reset()
        repCounter.setStretch(currentStretch)
        
        AnalyticsManager.shared.logEvent("stretch_tracking_started", parameters: [
            "stretch_type": currentStretch.shortName
        ])
        
        voiceEngine.speakGetReady(currentStretch.shortName)
        hapticEngine.onTransition()
        
        trackingStatus = "Starting..."
    }
    
    func stop() {
        AnalyticsManager.shared.logEvent("stretch_tracking_stopped", parameters: [
            "stretch_type": currentStretch.shortName,
            "reps_completed": repCounter.currentReps
        ])
        
        isActive = false
        isBodyDetected = false
        trackingStatus = "Stopped"
        showBodyWarning = false
        currentAngle = 0
        voiceEngine.stop()
        bearAvatar = nil
        Logger.motion.info("StretchTracker: Stopped and reset")
    }
    
    func switchStretch(_ stretch: StretchType) {
        currentStretch = stretch
        stretchState.type = stretch
        repCounter.setStretch(stretch)
        repCounter.reset()
        
        voiceEngine.speakGetReady(stretch.shortName)
        hapticEngine.onTransition()
    }
    
    func processFrame(_ bodyAnchor: ARBodyAnchor) {
        guard isActive else { return }
        
        isBodyDetected = bodyAnchor.isTracked
        
        if !bodyAnchor.isTracked {
            showBodyWarning = true
            trackingStatus = "Step into frame"
            return
        }
        
        showBodyWarning = false
        trackingStatus = "Tracking"
        
        let joints = poseProcessor.extractJoints(from: bodyAnchor)
        
        let airPodsPitch = motionManager.pitch
        let airPodsYaw = motionManager.yaw
        
        currentAngle = poseProcessor.calculateAngle(
            for: currentStretch,
            joints: joints,
            airPodsPitch: airPodsPitch,
            airPodsYaw: airPodsYaw
        )
        
        stretchState.currentAngle = currentAngle
        stretchState.isInPosition = poseProcessor.isInPosition(
            angle: currentAngle,
            for: currentStretch,
            tolerance: Float(settings.settings.tolerance(for: currentStretch))
        )
        
        repCounter.updateWithAngle(angle: currentAngle)
        
        updateBearAvatar(joints: joints, rootTransform: bodyAnchor.transform, bodyAnchor: bodyAnchor)
        
        updateStretchPhase()
    }
    
    private func updateBearAvatar(joints: [String: BodyPoseProcessor.JointData], rootTransform: simd_float4x4, bodyAnchor: ARBodyAnchor) {
        guard let avatar = bearAvatar else { return }
        
        let bodyScale = poseProcessor.getBodyScale(joints: joints)
        
        avatar.updatePose(
            joints: joints,
            rootTransform: rootTransform,
            bodyScale: bodyScale
        )
        
        if stretchState.isInPosition {
            if repCounter.holdProgress > 0.8 {
                avatar.playExpression(.thinking)
            } else if repCounter.holdProgress > 0.5 {
                avatar.playExpression(.happy)
            } else {
                avatar.playExpression(.idle)
            }
        } else if repCounter.currentReps > 0 && repCounter.isRecovering {
            avatar.playExpression(.celebrating)
        } else {
            avatar.playExpression(.idle)
        }
    }
    
    private func updateStretchPhase() {
        if showBodyWarning {
            stretchState.phase = .idle
        } else if repCounter.isHolding {
            stretchState.phase = .holding
        } else if stretchState.isInPosition && !repCounter.isHolding {
            stretchState.phase = .entering
        } else if repCounter.isRecovering {
            stretchState.phase = .recovering
        } else {
            stretchState.phase = .idle
        }
    }
}
