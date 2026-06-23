import SwiftUI
import RealityKit
import ARKit
import os

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var tracker: StretchTracker
    
    func makeUIView(context: Context) -> ARView {
        Logger.ui.debug("ARViewContainer: Creating AR View...")
        
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        
        do {
            if ARBodyTrackingConfiguration.isSupported {
                Logger.ui.debug("ARViewContainer: AR Body Tracking IS supported")
                let configuration = ARBodyTrackingConfiguration()
                configuration.automaticSkeletonScaleEstimationEnabled = true
                configuration.isAutoFocusEnabled = true
                arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                let avatar = BearAvatar()
                let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -1))
                anchor.addChild(avatar.root)
                arView.scene.addAnchor(anchor)
                tracker.bearAvatar = avatar
                
                Logger.ui.info("ARViewContainer: AR Body Tracking initialized with BearAvatar")
            } else {
                Logger.ui.warning("ARViewContainer: AR Body Tracking NOT supported - showing placeholder")
            }
        } catch {
            Logger.ui.error("ARViewContainer: Failed to configure AR session: \(error.localizedDescription)")
        }
        
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        Logger.ui.debug("ARViewContainer: Cleaning up AR session")
        uiView.session.pause()
        uiView.scene.anchors.removeAll()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(tracker: tracker)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let tracker: StretchTracker
        
        init(tracker: StretchTracker) {
            self.tracker = tracker
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            let bodyAnchors = anchors.compactMap { $0 as? ARBodyAnchor }
            if let bodyAnchor = bodyAnchors.first {
                Task { @MainActor in
                    tracker.processFrame(bodyAnchor)
                }
            }
        }
    }
}
