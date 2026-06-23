import Foundation
import AVFoundation
import UIKit
import os

@MainActor
class AudioBackgroundManager: ObservableObject {
    static let shared = AudioBackgroundManager()
    
    // MARK: - Published Properties
    @Published private(set) var isAudioSessionActive: Bool = false
    @Published private(set) var audioSessionError: String?
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var isBackgroundAudioEnabled: Bool = false
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    func enableBackgroundAudio() {
        guard !isBackgroundAudioEnabled else { return }

        // 🚨 CRITICAL: Only enable if there's an ACTIVE session
        let motionManager = HeadphoneMotionManager.shared
        guard let currentSession = motionManager.currentSessionStore.currentSession,
              !motionManager.isPaused && !motionManager.sessionPaused else {
            Logger.background.info("No active posture session - skipping background audio to save battery")
            return
        }

        Logger.background.info("Active session detected - enabling background audio")
        isBackgroundAudioEnabled = true
        startSilentAudio()
    }
    
    func disableBackgroundAudio() {
        guard isBackgroundAudioEnabled else { return }
        
        Logger.background.info("Disabling background audio")
        isBackgroundAudioEnabled = false
        stopSilentAudio()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Configure audio session for background playback with audio mixing
            // This allows AirPosture to run in background while other apps (Spotify, etc.) play audio
            // FIXED: Removed .duckOthers to prevent volume reduction of other apps
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowAirPlay, .allowBluetoothA2DP]
            )

            // Activate the audio session
            try audioSession.setActive(true)

            isAudioSessionActive = true
            audioSessionError = nil
            Logger.background.info("Audio session configured successfully")

        } catch {
            isAudioSessionActive = false
            audioSessionError = error.localizedDescription
            Logger.background.error("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Silent Audio Playback
    private func startSilentAudio() {
        // Create a silent audio file in memory
        let silentAudioData = createSilentAudioData()
        
        do {
            // Create audio player with silent audio
            audioPlayer = try AVAudioPlayer(data: silentAudioData)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.0 // Silent
            audioPlayer?.prepareToPlay()
            
            // Start playing silent audio
            let success = audioPlayer?.play() ?? false
            
            if success {
                Logger.background.info("Silent audio started for background tracking")
            } else {
                Logger.background.error("Failed to start silent audio")
            }
            
        } catch {
            Logger.background.error("Failed to create audio player: \(error)")
            audioSessionError = error.localizedDescription
        }
    }
    
    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        Logger.background.info("Silent audio stopped")
    }
    
    private func createSilentAudioData() -> Data {
        return SilentAudioGenerator.createSilentWAVData()
    }
    
    // MARK: - Notification Handling
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            Logger.background.info("Audio session interrupted")
            // Audio was interrupted, but we'll resume when possible
            
        case .ended:
            Logger.background.info("Audio session interruption ended")
            if isBackgroundAudioEnabled {
                // Resume silent audio if we were using it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startSilentAudio()
                }
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        // Handle audio route changes (e.g., headphones connected/disconnected)
        Logger.background.debug("Audio route changed")
    }
    
    @objc private func handleAppBackground() {
        // App is going to background - ensure audio continues if enabled
        if isBackgroundAudioEnabled && audioPlayer?.isPlaying != true {
            startSilentAudio()
        }
    }
    
    @objc private func handleAppForeground() {
        // App is coming to foreground - audio session should still be active
        Logger.background.debug("App returning to foreground - audio session active: \(self.isAudioSessionActive)")
    }
    
    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
