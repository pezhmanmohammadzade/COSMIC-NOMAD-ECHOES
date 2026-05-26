//
//  AstronautRenderer.swift
//  COSMIC NOMAD: ECHOES
//
//  Renders the astronaut character using a custom OBJ model.
//  Falls back to the original cube-based astronaut if the OBJ is not found.
//  The OBJ model is loaded from the app bundle (Models/astronaut.obj).
//

import Metal
import simd

@MainActor
final class AstronautRenderer {
    let device: MTLDevice
    
    // OBJ model mesh (nil if not loaded → falls back to cube)
    private var objMesh: OBJMesh?
    private var useOBJModel: Bool = false
    
    // Instance buffer for OBJ rendering (single instance with transform + color)
    private var objInstanceBuffer: MTLBuffer?
    
    // --- Fallback: cube-based astronaut ---
    private let partCount = 31
    private var instanceBuffer: MTLBuffer?
    
    // Walk animation phase
    private var walkPhase: Float = 0
    
    // Model transform settings (adjust these to fit your OBJ model)
    private let modelScale: Float = 1.0          // Overall scale of the OBJ model
    private let modelYOffset: Float = 0.5         // Vertical offset above terrain surface
    private let targetHeight: Float = 2.5         // Astronaut height in world units
    
    init(device: MTLDevice) {
        self.device = device
        
        // Try to load the OBJ model
        if let mesh = OBJLoader.load(filename: "astronaut", device: device) {
            self.objMesh = mesh
            self.useOBJModel = true
            
            // Normalize OBJ vertices to standard space:
            //   - Centered horizontally (X=0, Z=0)
            //   - Feet at Y=0, head at Y=1.0
            // This lets the vertex shader detect arm/leg regions by position.
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
            
            // Create single-instance buffer for the OBJ model
            self.objInstanceBuffer = device.makeBuffer(
                length: MemoryLayout<EntityInstance>.stride,
                options: .storageModeShared
            )
            objInstanceBuffer?.label = "Astronaut OBJ Instance Buffer"
            
            print("🧑‍🚀 AstronautRenderer: Using custom OBJ model (normalized to height=1.0)")
            print("   Original bounds: \(mesh.boundingBoxMin) → \(mesh.boundingBoxMax)")
        } else {
            print("🧑‍🚀 AstronautRenderer: OBJ not found, using cube-based fallback")
        }
        
        // Always prepare the cube fallback buffer
        self.instanceBuffer = device.makeBuffer(
            length: MemoryLayout<EntityInstance>.stride * partCount,
            options: .storageModeShared
        )
        instanceBuffer?.label = "Astronaut Instance Buffer"
    }
    
    // Animation state
    enum AnimState { case idle, walking, sprinting, flying, landing }
    private var currentState: AnimState = .idle
    private var stateBlend: Float = 0 // 0-1 transition progress
    private var landingTimer: Float = 0
    
    func update(isMoving: Bool, deltaTime: Float, isFlying: Bool = false, isSprinting: Bool = false) {
        // Determine target state
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
        
        // Handle landing timer
        if currentState == .landing {
            landingTimer -= deltaTime
            if landingTimer <= 0 {
                currentState = .idle
            }
        }
        
        // Transition
        if targetState != currentState && currentState != .landing {
            currentState = targetState
            stateBlend = 0
        }
        stateBlend = min(1.0, stateBlend + deltaTime * 4.0)
        
        // Phase progression per state
        switch currentState {
        case .idle:      walkPhase += deltaTime * 0.5
        case .walking:   walkPhase += deltaTime * 9.0
        case .sprinting: walkPhase += deltaTime * 14.0
        case .flying:    walkPhase += deltaTime * 1.5
        case .landing:   walkPhase += deltaTime * 2.0
        }
    }
    
    func draw(player: PlayerController, encoder: MTLRenderCommandEncoder, resources: ResourceManager, pipeline: RenderPipeline, time: Float, isMoving: Bool) {
        // Always use the detailed 31-part procedural model
        drawCubeFallback(player: player, encoder: encoder, resources: resources, pipeline: pipeline, time: time, isMoving: isMoving)
    }
    
    // MARK: - OBJ Model Rendering
    
    private func drawOBJModel(player: PlayerController, encoder: MTLRenderCommandEncoder, resources: ResourceManager, pipeline: RenderPipeline, time: Float, isMoving: Bool) {
        guard let mesh = objMesh, let instanceBuf = objInstanceBuffer else { return }
        
        let p = player.position
        let fwd = player.forward
        
        // Build rotation from player facing direction
        // Flip 180° so model faces forward (negate right + forward columns)
        let right = normalize(cross(fwd, SIMD3<Float>(0, 1, 0)))
        let up = SIMD3<Float>(0, 1, 0)
        
        let rot = float4x4(
            SIMD4<Float>(-right.x, -right.y, -right.z, 0),
            SIMD4<Float>(up.x, up.y, up.z, 0),
            SIMD4<Float>(fwd.x, fwd.y, fwd.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        
        // Vertices are pre-normalized (height=1.0, centered) so just scale to target height
        let finalScale = targetHeight * modelScale
        
        // Subtle body bob when walking
        let bodyBob: Float = isMoving ? abs(sin(walkPhase * 2)) * 0.06 : 0.0
        
        // Build final model matrix:
        // 1. Scale from normalized (height=1) to world size
        // 2. Rotate to match player facing
        // 3. Translate to player world position
        // Use the raw terrain height (not the smoothed player.position.y which lags on slopes)
        // This places the astronaut's feet directly on the actual terrain surface.
        let feetY = player.groundHeight
        let scaleMatrix = MatrixUtil.scale(finalScale)
        let worldTranslation = MatrixUtil.translation(SIMD3<Float>(p.x, feetY + modelYOffset + bodyBob, p.z))
        
        let modelMatrix = worldTranslation * rot * scaleMatrix
        
        // === ARM SWING ANIMATION ===
        // Compute arm swing value and encode it in material type 4.x
        // The vertex shader will use this to animate arm/leg vertices
        let armSwingValue: Float = isMoving ? sin(walkPhase) * 0.55 : sin(walkPhase) * 0.03
        let normalizedSwing = (armSwingValue + 0.55) / 1.1  // Map [-0.55, 0.55] → [0, 1]
        let materialType: Float = 4.0 + normalizedSwing * 0.99  // Encode in [4.0, 4.99]
        
        // Soft green suit color (material type 4.x = animated astronaut)
        let suitColor = SIMD4<Float>(0.45, 0.78, 0.48, materialType)
        
        // Write instance data
        let pointer = instanceBuf.contents().bindMemory(to: EntityInstance.self, capacity: 1)
        pointer[0] = EntityInstance(
            modelMatrix: modelMatrix,
            colorAndMaterial: suitColor
        )
        
        // Draw using the entity pipeline with the OBJ mesh buffers
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
    
    // MARK: - Cube Fallback (original implementation)
    
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
        
        // Colors
        let suitColor = SIMD4<Float>(0.6, 0.9, 0.65, 4.0) // Soft green suit, material 4.0
        let darkGreyJoints = SIMD4<Float>(0.2, 0.2, 0.25, 4.0) // material 4.0
        let goldVisor = SIMD4<Float>(1.0, 0.8, 0.2, 1.0) // 1.0 = Glass
        let blackEquipment = SIMD4<Float>(0.08, 0.08, 0.1, 4.0) // material 4.0
        let metallicAccent = SIMD4<Float>(0.5, 0.55, 0.6, 0.0) // 0.0 = Metal
        let neonBlueDisplay = SIMD4<Float>(0.0, 0.8, 1.0, 1.0) // 1.0 = Emissive
        
        let armSwing: Float = isMoving ? sin(walkPhase) * 0.6 : sin(walkPhase) * 0.05
        let legSwing: Float = isMoving ? sin(walkPhase) * 0.5 : 0.0
        let bodyBob: Float = isMoving ? abs(sin(walkPhase * 2)) * 0.08 : 0.0
        let headTilt: Float = isMoving ? sin(walkPhase * 0.5) * 0.04 : 0.0
        
        let pointer = instanceBuffer.contents().bindMemory(to: EntityInstance.self, capacity: partCount)
        
        // Base position (feet are at camera position minus player height)
        let feetY = player.position.y - player.playerHeight
        let bodyMatrix = MatrixUtil.translation(SIMD3<Float>(p.x, feetY + bodyBob, p.z)) * rot
        
        // --- Pivots ---
        let headPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(0, 1.65, 0)) * MatrixUtil.rotation(pitch: headTilt, yaw: 0, roll: 0)
        
        let lShoulderPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(-0.4, 1.55, 0)) * MatrixUtil.rotation(pitch: armSwing, yaw: 0, roll: 0)
        let rShoulderPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(0.4, 1.55, 0)) * MatrixUtil.rotation(pitch: -armSwing, yaw: 0, roll: 0)
        
        let elbowBend: Float = isMoving ? 0.3 : 0.1
        let lElbowPivot = lShoulderPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.4, 0)) * MatrixUtil.rotation(pitch: -elbowBend, yaw: 0, roll: 0)
        let rElbowPivot = rShoulderPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.4, 0)) * MatrixUtil.rotation(pitch: -elbowBend, yaw: 0, roll: 0)
        
        let lHipPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(-0.22, 0.7, 0)) * MatrixUtil.rotation(pitch: -legSwing, yaw: 0, roll: 0)
        let rHipPivot = bodyMatrix * MatrixUtil.translation(SIMD3<Float>(0.22, 0.7, 0)) * MatrixUtil.rotation(pitch: legSwing, yaw: 0, roll: 0)
        
        let kneeBendL: Float = isMoving ? max(0, legSwing * 1.5) : 0.05
        let kneeBendR: Float = isMoving ? max(0, -legSwing * 1.5) : 0.05
        let lKneePivot = lHipPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.4, 0)) * MatrixUtil.rotation(pitch: kneeBendL, yaw: 0, roll: 0)
        let rKneePivot = rHipPivot * MatrixUtil.translation(SIMD3<Float>(0, -0.4, 0)) * MatrixUtil.rotation(pitch: kneeBendR, yaw: 0, roll: 0)
        
        // Helper
        func makePart(_ index: Int, _ pivot: float4x4, _ offset: SIMD3<Float>, _ scale: SIMD3<Float>, _ color: SIMD4<Float>) {
            let mat = pivot * MatrixUtil.translation(offset) * MatrixUtil.scale(scale)
            pointer[index] = EntityInstance(modelMatrix: mat, colorAndMaterial: color)
        }
        
        // --- Core Body ---
        makePart(0, bodyMatrix, SIMD3<Float>(0, 1.35, 0), SIMD3<Float>(0.6, 0.5, 0.4), suitColor)   // Upper Torso
        makePart(1, bodyMatrix, SIMD3<Float>(0, 0.95, 0), SIMD3<Float>(0.5, 0.3, 0.35), darkGreyJoints)  // Abdomen
        makePart(2, bodyMatrix, SIMD3<Float>(0, 0.7, 0), SIMD3<Float>(0.55, 0.2, 0.35), suitColor)   // Pelvis/Belt
        makePart(3, bodyMatrix, SIMD3<Float>(0, 1.4, -0.21), SIMD3<Float>(0.2, 0.1, 0.05), neonBlueDisplay) // Chest Display
        
        // --- Head ---
        makePart(4, headPivot, SIMD3<Float>(0, 0.25, 0), SIMD3<Float>(0.55, 0.55, 0.55), suitColor) // Helmet
        makePart(5, headPivot, SIMD3<Float>(0, 0.28, -0.23), SIMD3<Float>(0.45, 0.35, 0.15), goldVisor) // Visor
        
        // --- Left Arm ---
        makePart(6, lShoulderPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.2, 0.2, 0.2), darkGreyJoints)
        makePart(7, lShoulderPivot, SIMD3<Float>(0, -0.2, 0), SIMD3<Float>(0.18, 0.4, 0.18), suitColor)
        makePart(8, lElbowPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.16, 0.16, 0.16), darkGreyJoints)
        makePart(9, lElbowPivot, SIMD3<Float>(0, -0.2, 0), SIMD3<Float>(0.15, 0.4, 0.15), suitColor)
        makePart(10, lElbowPivot, SIMD3<Float>(0, -0.45, 0), SIMD3<Float>(0.18, 0.2, 0.18), blackEquipment)
        
        // --- Right Arm ---
        makePart(11, rShoulderPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.2, 0.2, 0.2), darkGreyJoints)
        makePart(12, rShoulderPivot, SIMD3<Float>(0, -0.2, 0), SIMD3<Float>(0.18, 0.4, 0.18), suitColor)
        makePart(13, rElbowPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.16, 0.16, 0.16), darkGreyJoints)
        makePart(14, rElbowPivot, SIMD3<Float>(0, -0.2, 0), SIMD3<Float>(0.15, 0.4, 0.15), suitColor)
        makePart(15, rElbowPivot, SIMD3<Float>(0, -0.45, 0), SIMD3<Float>(0.18, 0.2, 0.18), blackEquipment)
        
        // --- Left Leg ---
        makePart(16, lHipPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.2, 0.2, 0.2), darkGreyJoints)
        makePart(17, lHipPivot, SIMD3<Float>(0, -0.2, 0), SIMD3<Float>(0.22, 0.4, 0.22), suitColor)
        makePart(18, lKneePivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.18, 0.18, 0.18), darkGreyJoints)
        makePart(19, lKneePivot, SIMD3<Float>(0, -0.2, 0), SIMD3<Float>(0.2, 0.4, 0.2), suitColor)
        makePart(20, lKneePivot, SIMD3<Float>(0, -0.45, -0.05), SIMD3<Float>(0.25, 0.15, 0.3), blackEquipment)
        
        // --- Right Leg ---
        makePart(21, rHipPivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.2, 0.2, 0.2), darkGreyJoints)
        makePart(22, rHipPivot, SIMD3<Float>(0, -0.2, 0), SIMD3<Float>(0.22, 0.4, 0.22), suitColor)
        makePart(23, rKneePivot, SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.18, 0.18, 0.18), darkGreyJoints)
        makePart(24, rKneePivot, SIMD3<Float>(0, -0.2, 0), SIMD3<Float>(0.2, 0.4, 0.2), suitColor)
        makePart(25, rKneePivot, SIMD3<Float>(0, -0.45, -0.05), SIMD3<Float>(0.25, 0.15, 0.3), blackEquipment)
        
        // --- Backpack ---
        makePart(26, bodyMatrix, SIMD3<Float>(0, 1.25, 0.25), SIMD3<Float>(0.5, 0.6, 0.25), blackEquipment)
        makePart(27, bodyMatrix, SIMD3<Float>(-0.15, 1.25, 0.4), SIMD3<Float>(0.15, 0.5, 0.15), metallicAccent)
        makePart(28, bodyMatrix, SIMD3<Float>(0.15, 1.25, 0.4), SIMD3<Float>(0.15, 0.5, 0.15), metallicAccent)
        
        let jetPhase = player.isJetpacking ? Float.random(in: 0.8...1.2) : 0.0
        let jetColor = SIMD4<Float>(0.0, 0.5 * jetPhase, 1.0 * jetPhase, jetPhase > 0 ? 1.0 : 0.0)
        makePart(29, bodyMatrix, SIMD3<Float>(-0.15, 0.95, 0.4), SIMD3<Float>(0.1, 0.05, 0.1), jetColor)
        makePart(30, bodyMatrix, SIMD3<Float>(0.15, 0.95, 0.4), SIMD3<Float>(0.1, 0.05, 0.1), jetColor)
        
        // === DRAW ===
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
