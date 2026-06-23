import Foundation
import simd
import ARKit

class BodyPoseProcessor {
    
    struct JointData {
        let name: String
        let position: SIMD3<Float>
        let rotation: simd_quatf
        let isTracked: Bool
    }
    
    private let jointNames: [String] = [
        "head", "neck", "spine7", "spine4", "spine3", "hips",
        "leftShoulder", "rightShoulder",
        "leftElbow", "rightElbow",
        "leftWrist", "rightWrist",
        "leftHand", "rightHand",
        "leftHip", "rightHip",
        "leftKnee", "rightKnee",
        "leftAnkle", "rightAnkle",
        "leftFoot", "rightFoot"
    ]
    
    func extractJoints(from bodyAnchor: ARBodyAnchor) -> [String: JointData] {
        var joints: [String: JointData] = [:]
        
        let skeleton = bodyAnchor.skeleton
        
        for jointName in jointNames {
            let jointIndex = ARSkeleton.JointName(rawValue: jointName)
            if let jointTransform = skeleton.modelTransform(for: jointIndex) {
                let position = SIMD3<Float>(jointTransform.columns.3.x, jointTransform.columns.3.y, jointTransform.columns.3.z)
                let rotation = simd_quatf(jointTransform)
                
                joints[jointName] = JointData(
                    name: jointName,
                    position: position,
                    rotation: rotation,
                    isTracked: true
                )
            }
        }
        
        return joints
    }
    
    func spineForwardBend(joints: [String: JointData]) -> Float? {
        guard let hips = joints["hips"],
              let spine7 = joints["spine7"],
              let shoulder = joints["leftShoulder"] ?? joints["rightShoulder"] else {
            return nil
        }
        
        let spineVector = spine7.position - hips.position
        let verticalVector = SIMD3<Float>(0, 1, 0)
        
        let normalizedSpine = normalize(spineVector)
        let cosAngle = dot(normalizedSpine, verticalVector)
        let clampedCos = min(max(cosAngle, -1), 1)
        let angle = acos(clampedCos)
        
        return toDegrees(angle) - 90
    }
    
    func lateralBend(joints: [String: JointData]) -> Float? {
        guard let hips = joints["hips"],
              let spine7 = joints["spine7"] else {
            return nil
        }
        
        let lateralVector = spine7.position - hips.position
        return toDegrees(atan2(lateralVector.x, lateralVector.y))
    }
    
    func shoulderTilt(joints: [String: JointData]) -> Float? {
        guard let leftShoulder = joints["leftShoulder"],
              let rightShoulder = joints["rightShoulder"],
              let hips = joints["hips"] else {
            return nil
        }
        
        let midShoulder = (leftShoulder.position + rightShoulder.position) / 2
        let tiltVector = midShoulder - hips.position
        
        return toDegrees(atan2(tiltVector.x, tiltVector.y))
    }
    
    func calculateAngle(for stretch: StretchType, joints: [String: JointData], airPodsPitch: Double = 0, airPodsYaw: Double = 0) -> Float {
        switch stretch {
        case .toeTouch, .forwardFold:
            if let forwardBend = spineForwardBend(joints: joints) {
                return forwardBend
            }
            return 0
            
        case .sideBendLeft, .sideBendRight:
            if let lateral = lateralBend(joints: joints) {
                return lateral
            }
            return 0
            
        case .neckStretchLeft, .neckStretchRight:
            return Float(airPodsYaw)
        }
    }
    
    func isInPosition(angle: Float, for stretch: StretchType, tolerance: Float) -> Bool {
        let target = stretch.targetAngle
        let range = stretch.angleRange
        let adjustedTolerance = tolerance
        
        return angle >= (range.lowerBound - adjustedTolerance) && 
               angle <= (range.upperBound + adjustedTolerance)
    }
    
    private func toDegrees(_ radians: Float) -> Float {
        return radians * 180.0 / .pi
    }
    
    func getBodyCenter(joints: [String: JointData]) -> SIMD3<Float>? {
        guard let hips = joints["hips"],
              let spine7 = joints["spine7"] else {
            return nil
        }
        return (hips.position + spine7.position) / 2
    }
    
    func getBodyScale(joints: [String: JointData]) -> Float {
        guard let head = joints["head"],
              let hips = joints["hips"] else {
            return 1.0
        }
        
        let bodyHeight = distance(head.position, hips.position)
        return bodyHeight > 0 ? bodyHeight : 1.0
    }
}
