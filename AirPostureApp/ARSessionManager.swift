import Foundation
import ARKit
import Combine

protocol ARCapabilityProviding: Sendable {
    var isBodyTrackingSupported: Bool { get }
}

struct ARProductionCapabilityProvider: ARCapabilityProviding, Sendable {
    let isBodyTrackingSupported: Bool = ARBodyTrackingConfiguration.isSupported
}

class ARSessionManager: NSObject, ObservableObject {
    @Published var isTracking: Bool = false
    @Published var bodyAnchor: ARBodyAnchor?
    @Published var tracking: String = "Not started"
    @Published var isBodyDetected: Bool = false
    
    var onBodyUpdate: ((ARBodyAnchor) -> Void)?
    
    private var session: ARSession?
    
    static let defaultCapabilityProvider: ARCapabilityProviding = ARProductionCapabilityProvider()
    static var capabilityProvider: ARCapabilityProviding = defaultCapabilityProvider
    
    static var isSupported: Bool {
        capabilityProvider.isBodyTrackingSupported
    }
    
    func start() {
        guard ARSessionManager.isSupported else {
            tracking = "Not supported on this device"
            return
        }
        
        let configuration = ARBodyTrackingConfiguration()
        configuration.automaticSkeletonScaleEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        
        session = ARSession()
        session?.delegate = self
        session?.run(configuration)
        
        tracking = "Initializing..."
    }
    
    func stop() {
        session?.pause()
        session = nil
        isTracking = false
        isBodyDetected = false
        bodyAnchor = nil
        tracking = "Stopped"
    }
    
    func pause() {
        session?.pause()
        isTracking = false
        tracking = "Paused"
    }
    
    func resume() {
        guard let session = session else { return }
        
        let configuration = ARBodyTrackingConfiguration()
        configuration.automaticSkeletonScaleEstimationEnabled = true
        session.run(configuration)
        
        isTracking = true
    }
}

extension ARSessionManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.bodyAnchor = bodyAnchor
                    self.isBodyDetected = bodyAnchor.isTracked
                    self.tracking = bodyAnchor.isTracked ? "Tracking" : "Body lost"
                    self.onBodyUpdate?(bodyAnchor)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tracking = "Error: \(error.localizedDescription)"
            self.isTracking = false
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tracking = "Interrupted"
            self.isTracking = false
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.resume()
        }
    }
}
