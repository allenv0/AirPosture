#if os(iOS)
import UIKit

@MainActor
class StretchHapticEngine {
    static let shared = StretchHapticEngine()
    
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {
        impactGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    func onRepComplete() {
        guard StretchSettingsManager.shared.hapticEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }
    
    func onAlmostThere() {
        guard StretchSettingsManager.shared.hapticEnabled else { return }
        impactGenerator.impactOccurred(intensity: 0.5)
    }
    
    func onHoldProgress(_ progress: Double) {
        guard StretchSettingsManager.shared.hapticEnabled else { return }
        if progress > 0.8 {
            impactGenerator.impactOccurred(intensity: 0.3)
        }
    }
    
    func onStretchComplete() {
        guard StretchSettingsManager.shared.hapticEnabled else { return }
        impactGenerator.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impactGenerator.impactOccurred(intensity: 1.0)
        }
    }
    
    func onNewRecord() {
        guard StretchSettingsManager.shared.hapticEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.notificationGenerator.notificationOccurred(.success)
        }
    }
    
    func onTransition() {
        guard StretchSettingsManager.shared.hapticEnabled else { return }
        selectionGenerator.selectionChanged()
    }
    
    func onWarning() {
        guard StretchSettingsManager.shared.hapticEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }
    
    func prepare() {
        impactGenerator.prepare()
        notificationGenerator.prepare()
    }
}
#endif
