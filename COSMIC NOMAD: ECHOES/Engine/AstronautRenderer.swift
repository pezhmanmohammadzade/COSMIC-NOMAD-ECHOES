//
//  AstronautRenderer.swift
//  COSMIC NOMAD: ECHOES
//
//  AAA-quality procedural astronaut built from shaped cube instances.
//  Features anatomically proportioned body, detailed EVA suit with
//  layered armor plating, rounded helmet with gold visor, life support
//  backpack, articulated gloves, heavy-duty boots, and comm antenna.
//  Smooth IK-style walk animation with natural arm/leg swing.
//

import Metal
import simd

@MainActor
final class AstronautRenderer {
    let device: MTLDevice
    
    // OBJ model mesh (nil if not loaded → falls back to procedural)
    private var objMesh: OBJMesh?
    private var useOBJModel: Bool = false
    
    // Instance buffer for OBJ rendering
    private var objInstanceBuffer: MTLBuffer?
    
    // --- AAA Procedural Astronaut ---
    private let partCount = 72
    private var instanceBuffer: MTLBuffer?
    
    // Walk animation phase
    private var walkPhase: Float = 0
    
    // OBJ model transform settings
    private let modelScale: Float = 1.0
    private let modelYOffset: Float = 0.5
    private let targetHeight: Float = 2.5
    
    // Breathing animation
    private var breathPhase: Float = 0
    
    // Eye blink animation
    private var blinkTimer: Float = 0
    private var blinkCooldown: Float = 3.0
    private var isBlinking: Bool = false
    private var blinkDuration: Float = 0.12
    
    init(device: MTLDevice) {
        self.device = device
        
        // Try to load the OBJ model
        if let mesh = OBJLoader.load(filename: "astronaut", device: device) {
            self.objMesh = mesh
            self.useOBJModel = true
            
            let centerX = (mesh.boundingBoxMin.x + mesh.boundingBoxMax.x) * 0.5
            let centerZ = (mesh.boundingBoxMin.z + mesh.boundingBoxMax.z) * 0.5
            let bottomY = mesh.boundingBoxMin.y
            let height = mesh.boundingBoxMax.y - mesh.boundingBoxMin.y
            let normalizeScale: Float = height > 0 ? 1.0 / height : 1.0
            
            let vertPtr = mesh.vertexBuffer.contents().bindMemory(to: EntityVertex.self, capacity: mesh.vertexCount)
            for i in 0..<mesh.vertexCount {
                vertPtr[i].position.x = (vertPtr[i].position.x - centerX) * normalizeScale
                vertPtr[i].position.y = (vertPtr[i].position.y - bottomY) * normalizeScale
                vertPtr[i].position.z = (vertPtr[i].position.z - centerZ) * normalizeScale
            }
            
            self.objInstanceBuffer = device.makeBuffer(
                length: MemoryLayout<EntityInstance>.stride,
                options: .storageModeShared
            )
            objInstanceBuffer?.label = "Astronaut OBJ Instance Buffer"
            
            print("🧑‍🚀 AstronautRenderer: Using custom OBJ model (normalized to height=1.0)")
            print("   Original bounds: \(mesh.boundingBoxMin) → \(mesh.boundingBoxMax)")
        } else {
            print("🧑‍🚀 AstronautRenderer: Using AAA procedural astronaut (\(partCount) parts)")
        }
        
        // Always prepare the procedural buffer
        self.instanceBuffer = device.makeBuffer(
            length: MemoryLayout<EntityInstance>.stride * partCount,
            options: .storageModeShared
        )
        instanceBuffer?.label = "Astronaut Instance Buffer"
    }
    
    // Animation state
    enum AnimState { case idle, walking, sprinting, flying, landing }
    private var currentState: AnimState = .idle
    private var stateBlend: Float = 0
    private var landingTimer: Float = 0
    
    func update(isMoving: Bool, deltaTime: Float, isFlying: Bool = false, isSprinting: Bool = false) {
        let targetState: AnimState
        if isFlying {
            targetState = .flying
        } else if isSprinting && isMoving {
            targetState = .sprinting
        } else if isMoving {
            targetState = .walking
        } else if currentState == .flying {
            targetState = .landing
            landingTimer = 0.5
        } else {
            targetState = .idle
        }
        
        if currentState == .landing {
            landingTimer -= deltaTime
            if landingTimer <= 0 {
                currentState = .idle
            }
        }
        
        if targetState != currentState && currentState != .landing {
            currentState = targetState
            stateBlend = 0
        }
        stateBlend = min(1.0, stateBlend + deltaTime * 4.0)
        
        switch currentState {
        case .idle:      walkPhase += deltaTime * 0.5
        case .walking:   walkPhase += deltaTime * 9.0
        case .sprinting: walkPhase += deltaTime * 14.0
        case .flying:    walkPhase += deltaTime * 1.5
        case .landing:   walkPhase += deltaTime * 2.0
        }
        
        breathPhase += deltaTime * 1.2
        
        // Eye blink animation
        blinkTimer -= deltaTime
        if blinkTimer <= 0 {
            if isBlinking {
                isBlinking = false
                blinkCooldown = Float.random(in: 2.0...5.0)
                blinkTimer = blinkCooldown
            } else {
                isBlinking = true
                blinkTimer = blinkDuration
            }
        }
    }
    
    func draw(player: PlayerController, encoder: MTLRenderCommandEncoder, resources: ResourceManager, pipeline: RenderPipeline, time: Float, isMoving: Bool) {
        drawCubeFallback(player: player, encoder: encoder, resources: resources, pipeline: pipeline, time: time, isMoving: isMoving)
    }
    
    // MARK: - OBJ Model Rendering
    
    private func drawOBJModel(player: PlayerController, encoder: MTLRenderCommandEncoder, resources: ResourceManager, pipeline: RenderPipeline, time: Float, isMoving: Bool) {
        guard let mesh = objMesh, let instanceBuf = objInstanceBuffer else { return }
        
        let p = player.position
        let fwd = player.forward
        
        let right = normalize(cross(fwd, SIMD3<Float>(0, 1, 0)))
        let up = SIMD3<Float>(0, 1, 0)
        
        let rot = float4x4(
            SIMD4<Float>(-right.x, -right.y, -right.z, 0),
            SIMD4<Float>(up.x, up.y, up.z, 0),
            SIMD4<Float>(fwd.x, fwd.y, fwd.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        
        let finalScale = targetHeight * modelScale
        let bodyBob: Float = isMoving ? abs(sin(walkPhase * 2)) * 0.06 : 0.0
        
        let feetY = player.groundHeight
        let scaleMatrix = MatrixUtil.scale(finalScale)
        let worldTranslation = MatrixUtil.translation(SIMD3<Float>(p.x, feetY + modelYOffset + bodyBob, p.z))
        
        let modelMatrix = worldTranslation * rot * scaleMatrix
        
        let armSwingValue: Float = isMoving ? sin(walkPhase) * 0.55 : sin(walkPhase) * 0.03
        let normalizedSwing = (armSwingValue + 0.55) / 1.1
        let materialType: Float = 4.0 + normalizedSwing * 0.99
        
        let suitColor = SIMD4<Float>(0.45, 0.78, 0.48, materialType)
        
        let pointer = instanceBuf.contents().bindMemory(to: EntityInstance.self, capacity: 1)
        pointer[0] = EntityInstance(
            modelMatrix: modelMatrix,
            colorAndMaterial: suitColor
        )
        
        encoder.setRenderPipelineState(pipeline.entityPipeline)
        encoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: BufferIndex.vertices.rawValue)
        encoder.setVertexBuffer(instanceBuf, offset: 0, index: BufferIndex.instanceData.rawValue)
        
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: mesh.indexCount,
            indexType: .uint32,
            indexBuffer: mesh.indexBuffer,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }
    
    // MARK: - AAA Procedural Astronaut (62 parts)
    
    private func drawCubeFallback(player: PlayerController, encoder: MTLRenderCommandEncoder, resources: ResourceManager, pipeline: RenderPipeline, time: Float, isMoving: Bool) {
        guard let instanceBuffer = instanceBuffer else { return }
        
        let p = player.position
        let fwd = player.forward
        
        let right = normalize(cross(fwd, SIMD3<Float>(0, 1, 0)))
        let up = SIMD3<Float>(0, 1, 0)
        
        let rot = float4x4(
            SIMD4<Float>(right.x, right.y, right.z, 0),
            SIMD4<Float>(up.x, up.y, up.z, 0),
            SIMD4<Float>(-fwd.x, -fwd.y, -fwd.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        
        // === PASTEL MATTE SUIT COLORS ===
        // Primary suit — soft powder blue with slight warmth
        let suitPrimary      = SIMD4<Float>(0.72, 0.82, 0.92, 4.0)
        // Secondary suit — warm cream panels
        let suitSecondary    = SIMD4<Float>(0.90, 0.88, 0.82, 4.0)
        // Joints/flex areas — soft charcoal with blue tint
        let jointColor       = SIMD4<Float>(0.28, 0.30, 0.35, 4.0)
        // Armor plates — slightly darker blue-gray
        let armorPlate       = SIMD4<Float>(0.62, 0.68, 0.76, 4.0)
        // Helmet shell — clean white with slight blue
        let helmetShell      = SIMD4<Float>(0.88, 0.90, 0.94, 4.0)
        // Visor — warm amber-gold reflective
        let visorGold        = SIMD4<Float>(0.95, 0.78, 0.35, 1.0)
        // Visor frame — dark border
        let visorFrame       = SIMD4<Float>(0.15, 0.16, 0.20, 4.0)
        // Backpack — matte dark with subtle color
        let backpackColor    = SIMD4<Float>(0.22, 0.25, 0.30, 4.0)
        // Metallic accents — brushed silver
        let metallicAccent   = SIMD4<Float>(0.65, 0.68, 0.72, 0.0)
        // Life support glow — soft periwinkle
        let lifeSupportGlow  = SIMD4<Float>(0.55, 0.65, 0.92, 1.0)
        // Chest display — soft warm peach HUD light
        let chestDisplay     = SIMD4<Float>(0.92, 0.72, 0.55, 1.0)
        // Boot sole — dark rubber
        let bootSole         = SIMD4<Float>(0.12, 0.12, 0.15, 4.0)
        // Glove palm — grippy dark material
        let glovePalm        = SIMD4<Float>(0.18, 0.20, 0.22, 4.0)
        // Stripe accent — soft coral/peach stripe
        let stripeAccent     = SIMD4<Float>(0.92, 0.68, 0.62, 4.0)
        // Antenna — metallic thin rod
        let antennaColor     = SIMD4<Float>(0.72, 0.74, 0.78, 0.0)
        // Antenna tip — glowing indicator
        let antennaTip       = SIMD4<Float>(0.55, 0.88, 0.72, 1.0)
        
        // === ANIMATION ===
        let armSwing: Float = isMoving ? sin(walkPhase) * 0.55 : sin(walkPhase) * 0.04
        let legSwing: Float = isMoving ? sin(walkPhase) * 0.45 : 0.0
        let bodyBob: Float  = isMoving ? abs(sin(walkPhase * 2)) * 0.06 : 0.0
        let headTilt: Float = isMoving ? sin(walkPhase * 0.5) * 0.03 : 0.0
        let breathScale: Float = 1.0 + sin(breathPhase) * 0.008
        let shoulderRoll: Float = isMoving ? sin(walkPhase) * 0.06 : 0.0
        
        // Face colors
        let skinTone        = SIMD4<Float>(0.85, 0.72, 0.60, 4.0)  // Warm skin behind visor
        let eyeWhite        = SIMD4<Float>(0.95, 0.95, 0.97, 4.0)
        let eyePupil        = SIMD4<Float>(0.15, 0.25, 0.45, 1.0)  // Deep blue iris, slight glow
        let mouthColor      = SIMD4<Float>(0.70, 0.45, 0.42, 4.0)
        _     = SIMD4<Float>(0.75, 0.62, 0.52, 4.0)  // Slightly darker for eyelids
        
        let pointer = instanceBuffer.contents().bindMemory(to: EntityInstance.self, capacity: partCount)
        
        let feetY = player.position.y - player.playerHeight
        let bodyMatrix = MatrixUtil.translation(SIMD3<Float>(p.x, feetY + bodyBob, p.z)) * rot
        
        // === JOINT PIVOTS ===
        let headPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(0, 1.68, 0)) * MatrixUtil.rotation(pitch: headTilt, yaw: 0, roll: 0)
        
        // NOTE: User wants arm movement 180 degrees different
        let lShoulderPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(-0.42, 1.55, 0)) * MatrixUtil.rotation(pitch: armSwing, yaw: 0, roll: shoulderRoll)
        let rShoulderPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(0.42, 1.55, 0)) * MatrixUtil.rotation(pitch: -armSwing, yaw: 0, roll: -shoulderRoll)
        
        // Elbow IK: bend more when arm swings forward, straighten when swinging back
        // Left arm is forward when armSwing < 0 (pitch: armSwing < 0 = forward)
        // Right arm is forward when armSwing > 0 (pitch: -armSwing < 0 = forward)
        let lElbowBend: Float = isMoving ? 0.20 + max(0, -armSwing) * 0.6 : 0.10
        let rElbowBend: Float = isMoving ? 0.20 + max(0, armSwing) * 0.6 : 0.10
        // Negative pitch on elbow = forearm curls forward (natural arm bend)
        let lElbowPivot = lShoulderPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.38, 0)) * MatrixUtil.rotation(pitch: -lElbowBend, yaw: 0, roll: 0)
        let rElbowPivot = rShoulderPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.38, 0)) * MatrixUtil.rotation(pitch: -rElbowBend, yaw: 0, roll: 0)
        
        let lWristPivot = lElbowPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.32, 0))
        let rWristPivot = rElbowPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.32, 0))
        
        // Cross-body: right leg forward when left arm forward
        let lHipPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(-0.20, 0.72, 0)) * MatrixUtil.rotation(pitch: legSwing, yaw: 0, roll: 0)
        let rHipPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(0.20, 0.72, 0)) * MatrixUtil.rotation(pitch: -legSwing, yaw: 0, roll: 0)
        
        // Knee IK: User wants knees to bend FORWARD, not backward
        // Negative pitch = rotates toward -Z (forward)
        let kneeBendL: Float = isMoving ? max(0, -legSwing) * 1.4 + 0.1 : 0.05   // Left bends when going FORWARD (legSwing < 0)
        let kneeBendR: Float = isMoving ? max(0, legSwing) * 1.4 + 0.1 : 0.05    // Right bends when going FORWARD (legSwing > 0)
        let lKneePivot = lHipPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.38, 0)) * MatrixUtil.rotation(pitch: -kneeBendL, yaw: 0, roll: 0)
        let rKneePivot = rHipPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.38, 0)) * MatrixUtil.rotation(pitch: -kneeBendR, yaw: 0, roll: 0)
        
        // Foot toe-off: trailing foot tilts slightly for push-off effect
        // Left foot is trailing when legSwing > 0, right foot when legSwing < 0
        let toeOffL: Float = isMoving ? max(0, legSwing) * 0.2 : 0.0
        let toeOffR: Float = isMoving ? max(0, -legSwing) * 0.2 : 0.0
        let lAnklePivot = lKneePivot * MatrixUtil.translation(SIMD3<Float>(0, -0.35, 0)) * MatrixUtil.rotation(pitch: -toeOffL, yaw: 0, roll: 0)
        let rAnklePivot = rKneePivot * MatrixUtil.translation(SIMD3<Float>(0, -0.35, 0)) * MatrixUtil.rotation(pitch: -toeOffR, yaw: 0, roll: 0)
        
        // Helper
        func makePart(_ index: Int, _ pivot: float4x4, _ offset: SIMD3<Float>, _ scale: SIMD3<Float>, _ color: SIMD4<Float>) {
            let mat = pivot * MatrixUtil.translation(offset) * MatrixUtil.scale(scale)
            pointer[index] = EntityInstance(modelMatrix: mat, colorAndMaterial: color)
        }
        
        var idx = 0
        
        // ===== TORSO (8 parts) =====
        // Upper chest — broad, heroic proportions
        let chestBreath = SIMD3<Float>(0.58 * breathScale, 0.30, 0.38 * breathScale)
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.40, 0), chestBreath, suitPrimary); idx += 1
        // Upper chest armor plate
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.42, -0.20), SIMD3<Float>(0.48, 0.24, 0.05), armorPlate); idx += 1
        // Chest center stripe
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.40, -0.21), SIMD3<Float>(0.08, 0.22, 0.02), stripeAccent); idx += 1
        // Chest display/HUD panel
        makePart(idx, bodyMatrix, SIMD3<Float>(0.12, 1.44, -0.22), SIMD3<Float>(0.10, 0.06, 0.02), chestDisplay); idx += 1
        // Mid torso — slight taper
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.12, 0), SIMD3<Float>(0.50, 0.20, 0.34), suitSecondary); idx += 1
        // Abdomen flex segment
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 0.98, 0), SIMD3<Float>(0.46, 0.14, 0.32), jointColor); idx += 1
        // Pelvis/hip plate
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 0.82, 0), SIMD3<Float>(0.52, 0.16, 0.34), suitPrimary); idx += 1
        // Belt
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 0.76, 0), SIMD3<Float>(0.54, 0.06, 0.36), armorPlate); idx += 1
        
        // ===== COLLAR & NECK (3 parts) =====
        // Neck ring / collar
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.58, 0), SIMD3<Float>(0.38, 0.08, 0.32), jointColor); idx += 1
        // Collar flange (connects helmet to suit)
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.62, 0), SIMD3<Float>(0.44, 0.04, 0.36), metallicAccent); idx += 1
        // Back collar support
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.60, 0.12), SIMD3<Float>(0.30, 0.10, 0.10), armorPlate); idx += 1
        
        // ===== HELMET (6 parts) =====
        // Main helmet dome
        makePart(idx, headPivot, SIMD3<Float>(0, 0.26, 0), SIMD3<Float>(0.52, 0.52, 0.52), helmetShell); idx += 1
        // Helmet top crest
        makePart(idx, headPivot, SIMD3<Float>(0, 0.48, 0), SIMD3<Float>(0.20, 0.08, 0.20), armorPlate); idx += 1
        // Visor (gold reflective, recessed)
        makePart(idx, headPivot, SIMD3<Float>(0, 0.28, -0.22), SIMD3<Float>(0.42, 0.32, 0.12), visorGold); idx += 1
        // Visor border frame
        makePart(idx, headPivot, SIMD3<Float>(0, 0.28, -0.24), SIMD3<Float>(0.46, 0.36, 0.04), visorFrame); idx += 1
        // Left cheek vent
        makePart(idx, headPivot, SIMD3<Float>(-0.25, 0.20, -0.08), SIMD3<Float>(0.06, 0.12, 0.10), metallicAccent); idx += 1
        // Right cheek vent
        makePart(idx, headPivot, SIMD3<Float>(0.25, 0.20, -0.08), SIMD3<Float>(0.06, 0.12, 0.10), metallicAccent); idx += 1
        
        // ===== LEFT ARM (8 parts) =====
        // Shoulder pad (rounded armor)
        makePart(idx, lShoulderPivot, SIMD3<Float>(-0.04, 0.04, 0), SIMD3<Float>(0.24, 0.18, 0.24), armorPlate); idx += 1
        // Shoulder joint ball
        makePart(idx, lShoulderPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.16, 0.16, 0.16), jointColor); idx += 1
        // Upper arm
        makePart(idx, lShoulderPivot, SIMD3<Float>(0, -0.20, 0), SIMD3<Float>(0.16, 0.36, 0.16), suitPrimary); idx += 1
        // Upper arm stripe
        makePart(idx, lShoulderPivot, SIMD3<Float>(0, -0.14, -0.09), SIMD3<Float>(0.04, 0.08, 0.02), stripeAccent); idx += 1
        // Elbow joint
        makePart(idx, lElbowPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.14, 0.14, 0.14), jointColor); idx += 1
        // Forearm
        makePart(idx, lElbowPivot, SIMD3<Float>(0, -0.18, 0), SIMD3<Float>(0.14, 0.30, 0.14), suitSecondary); idx += 1
        // Wrist cuff
        makePart(idx, lWristPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.16, 0.06, 0.16), metallicAccent); idx += 1
        // Glove
        makePart(idx, lWristPivot, SIMD3<Float>(0, -0.08, -0.02), SIMD3<Float>(0.15, 0.14, 0.18), glovePalm); idx += 1
        
        // ===== RIGHT ARM (8 parts) =====
        // Shoulder pad
        makePart(idx, rShoulderPivot, SIMD3<Float>(0.04, 0.04, 0), SIMD3<Float>(0.24, 0.18, 0.24), armorPlate); idx += 1
        // Shoulder joint ball
        makePart(idx, rShoulderPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.16, 0.16, 0.16), jointColor); idx += 1
        // Upper arm
        makePart(idx, rShoulderPivot, SIMD3<Float>(0, -0.20, 0), SIMD3<Float>(0.16, 0.36, 0.16), suitPrimary); idx += 1
        // Upper arm stripe
        makePart(idx, rShoulderPivot, SIMD3<Float>(0, -0.14, -0.09), SIMD3<Float>(0.04, 0.08, 0.02), stripeAccent); idx += 1
        // Elbow joint
        makePart(idx, rElbowPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.14, 0.14, 0.14), jointColor); idx += 1
        // Forearm
        makePart(idx, rElbowPivot, SIMD3<Float>(0, -0.18, 0), SIMD3<Float>(0.14, 0.30, 0.14), suitSecondary); idx += 1
        // Wrist cuff
        makePart(idx, rWristPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.16, 0.06, 0.16), metallicAccent); idx += 1
        // Glove
        makePart(idx, rWristPivot, SIMD3<Float>(0, -0.08, -0.02), SIMD3<Float>(0.15, 0.14, 0.18), glovePalm); idx += 1
        
        // ===== LEFT LEG (8 parts) =====
        // Hip joint
        makePart(idx, lHipPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.18, 0.16, 0.18), jointColor); idx += 1
        // Upper thigh (muscular)
        makePart(idx, lHipPivot, SIMD3<Float>(0, -0.12, 0), SIMD3<Float>(0.22, 0.22, 0.22), suitPrimary); idx += 1
        // Lower thigh
        makePart(idx, lHipPivot, SIMD3<Float>(0, -0.28, 0), SIMD3<Float>(0.20, 0.18, 0.20), suitPrimary); idx += 1
        // Knee pad
        makePart(idx, lKneePivot, SIMD3<Float>(0, 0, -0.04), SIMD3<Float>(0.18, 0.12, 0.18), armorPlate); idx += 1
        // Knee joint
        makePart(idx, lKneePivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.16, 0.14, 0.16), jointColor); idx += 1
        // Shin
        makePart(idx, lKneePivot, SIMD3<Float>(0, -0.18, 0), SIMD3<Float>(0.18, 0.30, 0.18), suitSecondary); idx += 1
        // Boot upper
        makePart(idx, lAnklePivot, SIMD3<Float>(0, -0.02, -0.02), SIMD3<Float>(0.22, 0.14, 0.26), armorPlate); idx += 1
        // Boot sole (thick treaded sole)
        makePart(idx, lAnklePivot, SIMD3<Float>(0, -0.10, -0.02), SIMD3<Float>(0.24, 0.06, 0.30), bootSole); idx += 1
        
        // ===== RIGHT LEG (8 parts) =====
        // Hip joint
        makePart(idx, rHipPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.18, 0.16, 0.18), jointColor); idx += 1
        // Upper thigh
        makePart(idx, rHipPivot, SIMD3<Float>(0, -0.12, 0), SIMD3<Float>(0.22, 0.22, 0.22), suitPrimary); idx += 1
        // Lower thigh
        makePart(idx, rHipPivot, SIMD3<Float>(0, -0.28, 0), SIMD3<Float>(0.20, 0.18, 0.20), suitPrimary); idx += 1
        // Knee pad
        makePart(idx, rKneePivot, SIMD3<Float>(0, 0, -0.04), SIMD3<Float>(0.18, 0.12, 0.18), armorPlate); idx += 1
        // Knee joint
        makePart(idx, rKneePivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.16, 0.14, 0.16), jointColor); idx += 1
        // Shin
        makePart(idx, rKneePivot, SIMD3<Float>(0, -0.18, 0), SIMD3<Float>(0.18, 0.30, 0.18), suitSecondary); idx += 1
        // Boot upper
        makePart(idx, rAnklePivot, SIMD3<Float>(0, -0.02, -0.02), SIMD3<Float>(0.22, 0.14, 0.26), armorPlate); idx += 1
        // Boot sole
        makePart(idx, rAnklePivot, SIMD3<Float>(0, -0.10, -0.02), SIMD3<Float>(0.24, 0.06, 0.30), bootSole); idx += 1
        
        // ===== BACKPACK / LIFE SUPPORT (7 parts) =====
        // Main pack body
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.28, 0.24), SIMD3<Float>(0.44, 0.52, 0.22), backpackColor); idx += 1
        // Pack top cap
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.56, 0.24), SIMD3<Float>(0.38, 0.04, 0.18), metallicAccent); idx += 1
        // Left oxygen tank
        makePart(idx, bodyMatrix, SIMD3<Float>(-0.16, 1.30, 0.38), SIMD3<Float>(0.10, 0.44, 0.10), metallicAccent); idx += 1
        // Right oxygen tank
        makePart(idx, bodyMatrix, SIMD3<Float>(0.16, 1.30, 0.38), SIMD3<Float>(0.10, 0.44, 0.10), metallicAccent); idx += 1
        // Life support indicator (center glow)
        makePart(idx, bodyMatrix, SIMD3<Float>(0, 1.38, 0.36), SIMD3<Float>(0.08, 0.08, 0.04), lifeSupportGlow); idx += 1
        
        // Jetpack thruster nozzles
        let jetPhase = player.isJetpacking ? Float.random(in: 0.8...1.2) : 0.0
        let jetFlame = SIMD4<Float>(0.55 * jetPhase, 0.72 * jetPhase, 0.95 * jetPhase, jetPhase > 0 ? 1.0 : 0.0)
        makePart(idx, bodyMatrix, SIMD3<Float>(-0.14, 0.98, 0.36), SIMD3<Float>(0.08, 0.06, 0.08), jetFlame); idx += 1
        makePart(idx, bodyMatrix, SIMD3<Float>(0.14, 0.98, 0.36), SIMD3<Float>(0.08, 0.06, 0.08), jetFlame); idx += 1
        
        // ===== FACE (behind visor) (10 parts) =====
        let eyebrowColor = SIMD4<Float>(0.15, 0.12, 0.10, 4.0)
        let cheekColor = SIMD4<Float>(0.95, 0.60, 0.55, 4.0)
        
        // Left eye white
        let eyeScale: SIMD3<Float> = isBlinking ? SIMD3<Float>(0.06, 0.01, 0.04) : SIMD3<Float>(0.06, 0.05, 0.04)
        makePart(idx, headPivot, SIMD3<Float>(-0.08, 0.30, -0.18), eyeScale, eyeWhite); idx += 1
        // Right eye white
        makePart(idx, headPivot, SIMD3<Float>(0.08, 0.30, -0.18), eyeScale, eyeWhite); idx += 1
        
        // Left pupil (emissive blue)
        let pupilScale: SIMD3<Float> = isBlinking ? SIMD3<Float>(0.03, 0.005, 0.02) : SIMD3<Float>(0.03, 0.03, 0.02)
        makePart(idx, headPivot, SIMD3<Float>(-0.08, 0.30, -0.20), pupilScale, eyePupil); idx += 1
        // Right pupil
        makePart(idx, headPivot, SIMD3<Float>(0.08, 0.30, -0.20), pupilScale, eyePupil); idx += 1
        
        // Left eyebrow
        makePart(idx, headPivot, SIMD3<Float>(-0.09, 0.36, -0.19), SIMD3<Float>(0.05, 0.015, 0.02), eyebrowColor); idx += 1
        // Right eyebrow
        makePart(idx, headPivot, SIMD3<Float>(0.09, 0.36, -0.19), SIMD3<Float>(0.05, 0.015, 0.02), eyebrowColor); idx += 1
        
        // Left cheek (rosy)
        makePart(idx, headPivot, SIMD3<Float>(-0.12, 0.24, -0.17), SIMD3<Float>(0.04, 0.03, 0.02), cheekColor); idx += 1
        // Right cheek (rosy)
        makePart(idx, headPivot, SIMD3<Float>(0.12, 0.24, -0.17), SIMD3<Float>(0.04, 0.03, 0.02), cheekColor); idx += 1
        
        // Nose bridge (subtle)
        makePart(idx, headPivot, SIMD3<Float>(0, 0.24, -0.19), SIMD3<Float>(0.03, 0.06, 0.03), skinTone); idx += 1
        // Mouth (small subtle line)
        makePart(idx, headPivot, SIMD3<Float>(0, 0.18, -0.19), SIMD3<Float>(0.07, 0.015, 0.02), mouthColor); idx += 1
        
        // ===== ANTENNA (2 parts) =====
        // Antenna rod
        makePart(idx, headPivot, SIMD3<Float>(0.22, 0.50, 0.08), SIMD3<Float>(0.02, 0.20, 0.02), antennaColor); idx += 1
        // Antenna tip (glowing)
        makePart(idx, headPivot, SIMD3<Float>(0.22, 0.62, 0.08), SIMD3<Float>(0.04, 0.04, 0.04), antennaTip); idx += 1
        
        // ===== DRAW =====
        encoder.setRenderPipelineState(pipeline.entityPipeline)
        encoder.setVertexBuffer(resources.cubeVertexBuffer, offset: 0, index: BufferIndex.vertices.rawValue)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: BufferIndex.instanceData.rawValue)
        
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: resources.cubeIndexCount,
            indexType: .uint16,
            indexBuffer: resources.cubeIndexBuffer,
            indexBufferOffset: 0,
            instanceCount: partCount
        )
    }
}
