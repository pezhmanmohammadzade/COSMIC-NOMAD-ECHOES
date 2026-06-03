//
//  NPCRenderer.swift
//  COSMIC NOMAD: ECHOES
//
//  Renders alien creatures as instanced cube-based models.
//  Each creature type has a distinct detailed shape and emissive glow.
//  Enhanced with multi-part anatomical detail for all creature types.
//

import Metal
import simd

@MainActor
final class NPCRenderer {
    let device: MTLDevice
    private var instanceBuffer: MTLBuffer?
    private var instanceCount: Int = 0
    
    // Max parts per creature × max creatures
    private let maxInstances = 1600 // ~18 parts × 80 creatures + buffer
    
    init(device: MTLDevice) {
        self.device = device
        self.instanceBuffer = device.makeBuffer(
            length: MemoryLayout<EntityInstance>.stride * maxInstances,
            options: .storageModeShared
        )
        instanceBuffer?.label = "NPC Instance Buffer"
    }
    
    func draw(creatures: [AlienCreature], encoder: MTLRenderCommandEncoder, resources: ResourceManager, pipeline: RenderPipeline, time: Float) {
        guard let instanceBuffer = instanceBuffer else { return }
        
        let pointer = instanceBuffer.contents().bindMemory(to: EntityInstance.self, capacity: maxInstances)
        var idx = 0
        
        for creature in creatures {
            let p = creature.position
            let phase = creature.animationPhase
            let s = creature.size
            
            switch creature.type {
            case .floatingJellyfish:
                // === ENHANCED JELLYFISH (14 parts) ===
                
                // 1. Outer dome (translucent shell)
                let domeColor = SIMD4<Float>(creature.primaryColor.x * 0.8, creature.primaryColor.y * 0.8, creature.primaryColor.z * 0.8, 0.0)
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p) * MatrixUtil.scale(SIMD3<Float>(s * 0.85, s * 0.52, s * 0.85)),
                    colorAndMaterial: domeColor
                )
                idx += 1
                
                // 2. Inner membrane (slightly smaller, brighter)
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, -0.02, 0)) * MatrixUtil.scale(SIMD3<Float>(s * 0.7, s * 0.42, s * 0.7)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
                
                // 3. Brain core (pulsing glow)
                let glowPulse = (sin(phase * 3.0) + 1.0) * 0.5
                var coreColor = creature.emissiveColor
                coreColor.x *= (0.5 + glowPulse * 0.5)
                coreColor.y *= (0.5 + glowPulse * 0.5)
                coreColor.z *= (0.5 + glowPulse * 0.5)
                coreColor.w = 1.0
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, s * 0.05, 0)) * MatrixUtil.scale(SIMD3<Float>(s * 0.25, s * 0.2, s * 0.25)),
                    colorAndMaterial: coreColor
                )
                idx += 1
                
                // 4. Dome fringe ring (bottom edge detail)
                let fringeWobble = sin(phase * 2.5) * 0.05
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, -s * 0.22, 0)) * MatrixUtil.scale(SIMD3<Float>(s * 0.88 + fringeWobble, s * 0.06, s * 0.88 + fringeWobble)),
                    colorAndMaterial: creature.emissiveColor
                )
                idx += 1
                
                // 5-7. Bioluminescent spots on dome (3 spots)
                for spot in 0..<3 {
                    let spotAngle = Float(spot) * (.pi * 2.0 / 3.0) + phase * 0.2
                    let spotX = cos(spotAngle) * s * 0.35
                    let spotZ = sin(spotAngle) * s * 0.35
                    let spotPulse = (sin(phase * 4.0 + Float(spot) * 2.1) + 1.0) * 0.5
                    var spotColor = creature.emissiveColor
                    spotColor.x *= spotPulse
                    spotColor.y *= spotPulse
                    spotColor.z *= spotPulse
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(spotX, s * 0.1, spotZ)) * MatrixUtil.scale(SIMD3<Float>(s * 0.06, s * 0.06, s * 0.06)),
                        colorAndMaterial: spotColor
                    )
                    idx += 1
                }
                
                // 8-13. Tentacles (6 hanging down with curving sway)
                for t in 0..<6 {
                    let tAngle = Float(t) * (.pi * 2.0 / 6.0) + phase * 0.3
                    let tX = cos(tAngle) * s * 0.32
                    let tZ = sin(tAngle) * s * 0.32
                    let tSway = sin(phase * 2.5 + Float(t) * 1.05) * 0.25
                    let tDroop = cos(phase * 1.8 + Float(t) * 0.7) * 0.15
                    let tentLen = s * (0.5 + sin(phase * 1.5 + Float(t)) * 0.15)
                    
                    // Alternating thin/thick tentacles
                    let thickness = (t % 2 == 0) ? s * 0.06 : s * 0.04
                    
                    var tentColor = creature.emissiveColor
                    tentColor.w = (t % 2 == 0) ? 1.0 : 0.0  // Alternate emissive/matte
                    
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(tX + tSway, -s * 0.25 - tentLen * 0.5 + tDroop, tZ)) * MatrixUtil.scale(SIMD3<Float>(thickness, tentLen, thickness)),
                        colorAndMaterial: tentColor
                    )
                    idx += 1
                }
                
                // 14. Oral arms (central short tentacle cluster)
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, -s * 0.35, 0)) * MatrixUtil.scale(SIMD3<Float>(s * 0.12, s * 0.2, s * 0.12)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
                
            case .groundCrawler:
                // === ENHANCED CRAWLER (18 parts) ===
                
                // Movement direction for facing
                let crawlPhase = phase * 0.5
                _ = SIMD3<Float>(cos(crawlPhase), 0, sin(crawlPhase))
                
                // 1. Head segment (rounded, slightly raised)
                let headBob = sin(phase * 4.0) * s * 0.03
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, s * 0.2 + headBob, -s * 0.5)) * MatrixUtil.scale(SIMD3<Float>(s * 0.38, s * 0.32, s * 0.35)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
                
                // 2-3. Eye stalks (raised, emissive)
                let eyeGlow = creature.emissiveColor
                for side: Float in [-1.0, 1.0] {
                    let eyeWobble = sin(phase * 3.0 + side * 2.0) * 0.02
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(side * s * 0.14, s * 0.35 + eyeWobble, -s * 0.65)) * MatrixUtil.scale(SIMD3<Float>(s * 0.07, s * 0.12, s * 0.07)),
                        colorAndMaterial: eyeGlow
                    )
                    idx += 1
                }
                
                // 4-5. Mandibles/pincers
                let mandibleOpen = sin(phase * 2.0) * 0.08
                for side: Float in [-1.0, 1.0] {
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(side * (s * 0.18 + mandibleOpen), s * 0.1, -s * 0.72)) * MatrixUtil.scale(SIMD3<Float>(s * 0.06, s * 0.06, s * 0.14)),
                        colorAndMaterial: creature.primaryColor
                    )
                    idx += 1
                }
                
                // 6-8. Body segments (3 segments tapering toward rear)
                let segmentWidths: [Float] = [0.55, 0.48, 0.38]
                let segmentPositions: [Float] = [-0.15, 0.15, 0.42]
                for seg in 0..<3 {
                    let segBob = sin(phase * 4.0 + Float(seg) * 0.8) * s * 0.015
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, s * 0.12 + segBob, s * segmentPositions[seg])) * MatrixUtil.scale(SIMD3<Float>(s * segmentWidths[seg], s * 0.22, s * 0.28)),
                        colorAndMaterial: seg == 1 ? creature.primaryColor : SIMD4<Float>(creature.primaryColor.x * 0.85, creature.primaryColor.y * 0.85, creature.primaryColor.z * 0.85, creature.primaryColor.w)
                    )
                    idx += 1
                }
                
                // 9-11. Dorsal ridge/spines (3 plates along back)
                for spine in 0..<3 {
                    let spinePos = -0.2 + Float(spine) * 0.28
                    let spineHeight = s * (0.08 - Float(spine) * 0.015)
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, s * 0.28, s * spinePos)) * MatrixUtil.scale(SIMD3<Float>(s * 0.04, spineHeight, s * 0.1)),
                        colorAndMaterial: creature.emissiveColor
                    )
                    idx += 1
                }
                
                // 12-17. Legs (6, arthropod gait with alternating tripod)
                for leg in 0..<6 {
                    let side: Float = leg < 3 ? -1.0 : 1.0
                    let legIdx = leg % 3  // 0=front, 1=mid, 2=rear
                    let legZ: Float = -0.3 + Float(legIdx) * 0.3
                    
                    // Alternating tripod gait: legs 0,2,4 vs 1,3,5
                    let gaitOffset: Float = (leg % 2 == 0) ? 0.0 : .pi
                    let legPhase = phase * 5.0 + gaitOffset
                    let legLift = max(0, sin(legPhase)) * s * 0.1
                    let legReach = sin(legPhase) * s * 0.06
                    
                    // Upper leg segment angled outward
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(side * s * 0.32, -s * 0.02 + legLift, s * legZ + legReach)) * MatrixUtil.scale(SIMD3<Float>(s * 0.06, s * 0.18, s * 0.06)),
                        colorAndMaterial: creature.primaryColor
                    )
                    idx += 1
                }
                
                // 18. Tail/stinger
                let tailSway = sin(phase * 3.0) * s * 0.1
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(tailSway, s * 0.15, s * 0.65)) * MatrixUtil.scale(SIMD3<Float>(s * 0.04, s * 0.04, s * 0.22)),
                    colorAndMaterial: creature.emissiveColor
                )
                idx += 1
                
            case .skyWhale:
                // === ENHANCED SKY WHALE (14 parts) ===
                
                // 1. Head section (rounded front)
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, 0, -s * 1.8)) * MatrixUtil.scale(SIMD3<Float>(s * 1.3, s * 0.9, s * 1.2)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
                
                // 2. Main body (largest section)
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p) * MatrixUtil.scale(SIMD3<Float>(s * 1.5, s * 0.85, s * 2.4)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
                
                // 3. Rear body (tapering toward tail)
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, 0, s * 1.6)) * MatrixUtil.scale(SIMD3<Float>(s * 1.0, s * 0.6, s * 1.4)),
                    colorAndMaterial: SIMD4<Float>(creature.primaryColor.x * 0.9, creature.primaryColor.y * 0.9, creature.primaryColor.z * 0.9, creature.primaryColor.w)
                )
                idx += 1
                
                // 4-5. Side fins (with flapping animation)
                _ = sin(phase * 1.2) * 0.3
                for side: Float in [-1.0, 1.0] {
                    let finFlap = sin(phase * 1.2 + side * 0.5) * s * 0.3
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(side * (s * 1.2 + abs(finFlap)), finFlap * 0.3, -s * 0.3)) * MatrixUtil.scale(SIMD3<Float>(s * 0.7, s * 0.12, s * 1.0)),
                        colorAndMaterial: creature.primaryColor
                    )
                    idx += 1
                }
                
                // 6-8. Dorsal ridge (3 spine segments along the back)
                for ridge in 0..<3 {
                    let ridgeZ = -s * 1.0 + Float(ridge) * s * 1.0
                    let ridgeHeight = s * (0.25 - Float(ridge) * 0.05)
                    let ridgeWobble = sin(phase * 0.8 + Float(ridge) * 1.5) * s * 0.03
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, s * 0.42 + ridgeWobble, ridgeZ)) * MatrixUtil.scale(SIMD3<Float>(s * 0.08, ridgeHeight, s * 0.35)),
                        colorAndMaterial: creature.primaryColor
                    )
                    idx += 1
                }
                
                // 9-11. Belly bioluminescence (3 glowing panels)
                for panel in 0..<3 {
                    let panelZ = -s * 0.8 + Float(panel) * s * 0.8
                    let panelPulse = (sin(phase * 2.0 + Float(panel) * 2.1) + 1.0) * 0.5
                    var bellyColor = creature.emissiveColor
                    bellyColor.x *= (0.4 + panelPulse * 0.6)
                    bellyColor.y *= (0.4 + panelPulse * 0.6)
                    bellyColor.z *= (0.4 + panelPulse * 0.6)
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, -s * 0.35, panelZ)) * MatrixUtil.scale(SIMD3<Float>(s * 0.6, s * 0.08, s * 0.6)),
                        colorAndMaterial: bellyColor
                    )
                    idx += 1
                }
                
                // 12-13. Eye spots (two large, ancient-looking eyes on head)
                for side: Float in [-1.0, 1.0] {
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(side * s * 0.5, s * 0.15, -s * 2.2)) * MatrixUtil.scale(SIMD3<Float>(s * 0.15, s * 0.12, s * 0.08)),
                        colorAndMaterial: creature.emissiveColor
                    )
                    idx += 1
                }
                
                // 14. Tail flukes (horizontal, swaying)
                let tailSway = sin(phase * 1.5) * s * 0.6
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(tailSway, 0, s * 2.5)) * MatrixUtil.scale(SIMD3<Float>(s * 1.0, s * 0.15, s * 0.4)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
            }
            
            if idx >= maxInstances - 20 { break } // Safety
        }
        
        instanceCount = idx
        guard instanceCount > 0 else { return }
        
        encoder.setRenderPipelineState(pipeline.entityPipeline)
        encoder.setVertexBuffer(resources.cubeVertexBuffer, offset: 0, index: BufferIndex.vertices.rawValue)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: BufferIndex.instanceData.rawValue)
        
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: resources.cubeIndexCount,
            indexType: .uint16,
            indexBuffer: resources.cubeIndexBuffer,
            indexBufferOffset: 0,
            instanceCount: instanceCount
        )
    }
}
