import AVFoundation

@MainActor
class BearVoiceEngine: ObservableObject {
    static let shared = BearVoiceEngine()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenTime: Date?
    private let minimumInterval: TimeInterval = 1.5
    
    private init() {}
    
    enum VoiceMessage: String {
        case repComplete = "Good job! That's %d!"
        case almostThere = "Almost there..."
        case stretchComplete = "Great! All done!"
        case keepGoing = "Keep going!"
        case newRecord = "New record: %d reps!"
        case getReady = "Get ready for %s"
        case stretchDone = "Nice! %s complete!"
        case almostThereHold = "Hold it! You can do it!"
        case greatKeepGoing = "Great! Keep holding!"
        
        func formatted(_ args: [Any]) -> String {
            guard let first = args.first else { return rawValue }
            if let intVal = first as? Int {
                return String(format: rawValue, intVal)
            } else if let strVal = first as? String {
                return String(format: rawValue, strVal)
            }
            return rawValue
        }
    }
    
    func speak(_ message: VoiceMessage, _ args: Any...) {
        guard StretchSettingsManager.shared.voiceEnabled else { return }
        
        let now = Date()
        if let lastTime = lastSpokenTime, now.timeIntervalSince(lastTime) < minimumInterval {
            return
        }
        
        lastSpokenTime = now
        
        let text = args.isEmpty ? message.rawValue : message.formatted(args)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.3
        utterance.volume = 0.8
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        synthesizer.speak(utterance)
    }
    
    func speakRepComplete(_ count: Int) {
        speak(.repComplete, count)
    }
    
    func speakAlmostThere() {
        speak(.almostThere)
    }
    
    func speakHoldIt() {
        speak(.almostThereHold)
    }
    
    func speakGreatKeepGoing() {
        speak(.greatKeepGoing)
    }
    
    func speakStretchComplete(_ stretchName: String) {
        speak(.stretchDone, stretchName)
    }
    
    func speakNewRecord(_ count: Int) {
        speak(.newRecord, count)
    }
    
    func speakGetReady(_ stretchName: String) {
        speak(.getReady, stretchName)
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
