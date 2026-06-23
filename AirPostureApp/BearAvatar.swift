import Foundation
import RealityKit
import simd
import UIKit

enum BearExpression: String, CaseIterable {
    case idle
    case happy
    case excited
    case thinking
    case celebrating
    case cheering
    
    var animationDuration: Double {
        switch self {
        case .idle: return 2.0
        case .happy: return 0.5
        case .excited: return 0.3
        case .thinking: return 1.0
        case .celebrating: return 0.8
        case .cheering: return 0.6
        }
    }
}

class BearAvatar {
    let root: Entity
    let head: ModelEntity
    let snout: ModelEntity
    let nose: ModelEntity
    let leftEar: ModelEntity
    let rightEar: ModelEntity
    let leftEye: ModelEntity
    let rightEye: ModelEntity
    let body: ModelEntity
    let leftArm: ModelEntity
    let rightArm: ModelEntity
    let leftLeg: ModelEntity
    let rightLeg: ModelEntity
    let tail: ModelEntity
    
    private var currentExpression: BearExpression = .idle
    private var animationPhase: Float = 0
    
    init() {
        let brownMaterial = SimpleMaterial(color: UIColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1), isMetallic: false)
        let darkBrownMaterial = SimpleMaterial(color: UIColor(red: 0.4, green: 0.26, blue: 0.13, alpha: 1), isMetallic: false)
        let blackMaterial = SimpleMaterial(color: .black, isMetallic: false)
        let whiteMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let pinkMaterial = SimpleMaterial(color: UIColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1), isMetallic: false)
        
        head = ModelEntity(mesh: .generateSphere(radius: 0.08), materials: [brownMaterial])
        snout = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [brownMaterial])
        snout.position = SIMD3(0, -0.02, 0.075)
        
        nose = ModelEntity(mesh: .generateSphere(radius: 0.012), materials: [blackMaterial])
        nose.position = SIMD3(0, 0.005, 0.1)
        
        let snoutHighlight = ModelEntity(mesh: .generateSphere(radius: 0.008), materials: [pinkMaterial])
        snoutHighlight.position = SIMD3(0, 0.008, 0.105)
        
        leftEar = ModelEntity(mesh: .generateSphere(radius: 0.028), materials: [brownMaterial])
        leftEar.position = SIMD3(-0.065, 0.065, 0)
        
        let leftEarInner = ModelEntity(mesh: .generateSphere(radius: 0.015), materials: [pinkMaterial])
        leftEarInner.position = SIMD3(-0.065, 0.065, 0.01)
        
        rightEar = ModelEntity(mesh: .generateSphere(radius: 0.028), materials: [brownMaterial])
        rightEar.position = SIMD3(0.065, 0.065, 0)
        
        let rightEarInner = ModelEntity(mesh: .generateSphere(radius: 0.015), materials: [pinkMaterial])
        rightEarInner.position = SIMD3(0.065, 0.065, 0.01)
        
        leftEye = ModelEntity(mesh: .generateSphere(radius: 0.012), materials: [blackMaterial])
        leftEye.position = SIMD3(-0.03, 0.02, 0.065)
        
        let leftEyeHighlight = ModelEntity(mesh: .generateSphere(radius: 0.004), materials: [whiteMaterial])
        leftEyeHighlight.position = SIMD3(-0.028, 0.024, 0.075)
        
        rightEye = ModelEntity(mesh: .generateSphere(radius: 0.012), materials: [blackMaterial])
        rightEye.position = SIMD3(0.03, 0.02, 0.065)
        
        let rightEyeHighlight = ModelEntity(mesh: .generateSphere(radius: 0.004), materials: [whiteMaterial])
        rightEyeHighlight.position = SIMD3(0.028, 0.024, 0.075)
        
        body = ModelEntity(mesh: .generateBox(size: [0.14, 0.18, 0.1]), materials: [brownMaterial])
        body.position = SIMD3(0, -0.16, 0)
        
        let belly = ModelEntity(mesh: .generateBox(size: [0.08, 0.12, 0.04]), materials: [darkBrownMaterial])
        belly.position = SIMD3(0, -0.16, 0.04)
        
        leftArm = ModelEntity(mesh: .generateCylinder(height: 0.12, radius: 0.028), materials: [brownMaterial])
        leftArm.position = SIMD3(-0.1, -0.12, 0)
        leftArm.orientation = simd_quatf(angle: .pi / 6, axis: [0, 0, 1])
        
        rightArm = ModelEntity(mesh: .generateCylinder(height: 0.12, radius: 0.028), materials: [brownMaterial])
        rightArm.position = SIMD3(0.1, -0.12, 0)
        rightArm.orientation = simd_quatf(angle: -.pi / 6, axis: [0, 0, 1])
        
        leftLeg = ModelEntity(mesh: .generateCylinder(height: 0.14, radius: 0.032), materials: [brownMaterial])
        leftLeg.position = SIMD3(-0.045, -0.3, 0)
        
        rightLeg = ModelEntity(mesh: .generateCylinder(height: 0.14, radius: 0.032), materials: [brownMaterial])
        rightLeg.position = SIMD3(0.045, -0.3, 0)
        
        tail = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [brownMaterial])
        tail.position = SIMD3(0, -0.22, -0.08)
        
        root = Entity()
        root.addChild(head)
        root.addChild(snout)
        root.addChild(nose)
        root.addChild(snoutHighlight)
        root.addChild(leftEar)
        root.addChild(leftEarInner)
        root.addChild(rightEar)
        root.addChild(rightEarInner)
        root.addChild(leftEye)
        root.addChild(leftEyeHighlight)
        root.addChild(rightEye)
        root.addChild(rightEyeHighlight)
        root.addChild(body)
        root.addChild(belly)
        root.addChild(leftArm)
        root.addChild(rightArm)
        root.addChild(leftLeg)
        root.addChild(rightLeg)
        root.addChild(tail)
    }
    
    func updatePose(joints: [String: BodyPoseProcessor.JointData], rootTransform: simd_float4x4, bodyScale: Float) {
        let scaleFactor = bodyScale * 0.5
        
        if let headJoint = joints["head"] {
            let worldPos = rootTransform * SIMD4<Float>(headJoint.position, 1)
            head.position = SIMD3(worldPos.x, worldPos.y, worldPos.z)
            head.orientation = headJoint.rotation
            
            snout.position = head.position + SIMD3(0, -0.02 * scaleFactor, 0.075 * scaleFactor)
            nose.position = head.position + SIMD3(0, 0.005 * scaleFactor, 0.1 * scaleFactor)
            leftEar.position = head.position + SIMD3(-0.065 * scaleFactor, 0.065 * scaleFactor, 0)
            rightEar.position = head.position + SIMD3(0.065 * scaleFactor, 0.065 * scaleFactor, 0)
            leftEye.position = head.position + SIMD3(-0.03 * scaleFactor, 0.02 * scaleFactor, 0.065 * scaleFactor)
            rightEye.position = head.position + SIMD3(0.03 * scaleFactor, 0.02 * scaleFactor, 0.065 * scaleFactor)
        }
        
        if let neckJoint = joints["neck"] {
            let neckWorldPos = rootTransform * SIMD4<Float>(neckJoint.position, 1)
            body.position = SIMD3(neckWorldPos.x, neckWorldPos.y - 0.08 * scaleFactor, neckWorldPos.z)
            body.orientation = neckJoint.rotation
        }
        
        if let lShoulder = joints["leftShoulder"], let rShoulder = joints["rightShoulder"] {
            let lWorld = rootTransform * SIMD4<Float>(lShoulder.position, 1)
            let rWorld = rootTransform * SIMD4<Float>(rShoulder.position, 1)
            
            leftArm.position = SIMD3(lWorld.x, lWorld.y, lWorld.z)
            rightArm.position = SIMD3(rWorld.x, rWorld.y, rWorld.z)
        }
        
        if let lHip = joints["leftHip"], let rHip = joints["rightHip"] {
            let lWorld = rootTransform * SIMD4<Float>(lHip.position, 1)
            let rWorld = rootTransform * SIMD4<Float>(rHip.position, 1)
            
            leftLeg.position = SIMD3(lWorld.x, lWorld.y, lWorld.z)
            rightLeg.position = SIMD3(rWorld.x, rWorld.y, rWorld.z)
        }
        
        applyExpression(currentExpression, deltaTime: 0.016)
    }
    
    func playExpression(_ expression: BearExpression) {
        currentExpression = expression
        animationPhase = 0
    }
    
    private func applyExpression(_ expression: BearExpression, deltaTime: Float) {
        animationPhase += deltaTime
        
        switch expression {
        case .idle:
            let breathe = sin(animationPhase * .pi) * 0.01
            head.position.y += breathe
            
        case .happy:
            let bounce = abs(sin(animationPhase * .pi * 2)) * 0.02
            root.position.y += bounce
            
        case .excited:
            let jump = abs(sin(animationPhase * .pi * 3)) * 0.05
            root.position.y += jump
            
        case .thinking:
            let tilt = sin(animationPhase * .pi) * 0.15
            head.orientation *= simd_quatf(angle: tilt, axis: [0, 0, 1])
            
        case .celebrating:
            let armUp = -Float.pi / 2
            leftArm.orientation = simd_quatf(angle: armUp, axis: [1, 0, 0])
            rightArm.orientation = simd_quatf(angle: armUp, axis: [1, 0, 0])
            
            let spin = animationPhase * .pi * 2
            root.orientation = simd_quatf(angle: spin, axis: [0, 1, 0])
            
        case .cheering:
            let wave = sin(animationPhase * .pi * 4) * 0.3
            leftArm.orientation = simd_quatf(angle: Float(wave) - .pi / 2, axis: [1, 0, 0])
            rightArm.orientation = simd_quatf(angle: Float(-wave) - .pi / 2, axis: [1, 0, 0])
            
            let bounce = abs(sin(animationPhase * .pi * 2)) * 0.03
            root.position.y += bounce
        }
    }
    
    func resetPose() {
        playExpression(.idle)
    }
}
