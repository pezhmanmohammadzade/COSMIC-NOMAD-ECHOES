//
//  NPCRenderer.swift
//  COSMIC NOMAD: ECHOES
//
//  Renders alien creatures as instanced cube-based models.
//  Each creature type has a distinct shape and emissive glow.
//

import Metal
import simd

@MainActor
final class NPCRenderer {
    let device: MTLDevice
    private var instanceBuffer: MTLBuffer?
    private var instanceCount: Int = 0
    
    // Max parts per creature × max creatures
    private let maxInstances = 1000 // 10 parts × 80 creatures + buffer
    
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
                // Dome body
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p) * MatrixUtil.scale(SIMD3<Float>(s * 0.8, s * 0.5, s * 0.8)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
                
                // Inner glow
                let glowPulse = (sin(phase * 3.0) + 1.0) * 0.5
                var glowColor = creature.emissiveColor
                glowColor.w = 1.0 // emissive
                glowColor.x *= glowPulse
                glowColor.y *= glowPulse
                glowColor.z *= glowPulse
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, -0.1, 0)) * MatrixUtil.scale(SIMD3<Float>(s * 0.5, s * 0.3, s * 0.5)),
                    colorAndMaterial: glowColor
                )
                idx += 1
                
                // Tentacles (3 hanging down)
                for t in 0..<3 {
                    let tAngle = Float(t) * (.pi * 2.0 / 3.0) + phase * 0.5
                    let tX = cos(tAngle) * s * 0.3
                    let tZ = sin(tAngle) * s * 0.3
                    let tSway = sin(phase * 2.0 + Float(t)) * 0.3
                    
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(tX + tSway, -s * 0.6, tZ)) * MatrixUtil.scale(SIMD3<Float>(s * 0.08, s * 0.5, s * 0.08)),
                        colorAndMaterial: creature.emissiveColor
                    )
                    idx += 1
                }
                
            case .groundCrawler:
                // Body
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p) * MatrixUtil.scale(SIMD3<Float>(s * 0.6, s * 0.3, s * 1.0)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
                
                // Head
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, s * 0.15, -s * 0.5)) * MatrixUtil.scale(SIMD3<Float>(s * 0.35, s * 0.35, s * 0.35)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
                
                // Eyes (emissive)
                let eyeGlow = creature.emissiveColor
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(-s * 0.12, s * 0.2, -s * 0.7)) * MatrixUtil.scale(SIMD3<Float>(s * 0.06, s * 0.06, s * 0.06)),
                    colorAndMaterial: eyeGlow
                )
                idx += 1
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(s * 0.12, s * 0.2, -s * 0.7)) * MatrixUtil.scale(SIMD3<Float>(s * 0.06, s * 0.06, s * 0.06)),
                    colorAndMaterial: eyeGlow
                )
                idx += 1
                
                // Legs (4, with walk animation)
                for leg in 0..<4 {
                    let side: Float = leg < 2 ? -1.0 : 1.0
                    let front: Float = leg % 2 == 0 ? -0.3 : 0.3
                    let legPhase = phase * 4.0 + Float(leg) * (.pi / 2.0)
                    let legLift = max(0, sin(legPhase)) * s * 0.1
                    
                    pointer[idx] = EntityInstance(
                        modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(side * s * 0.35, -s * 0.1 + legLift, front * s)) * MatrixUtil.scale(SIMD3<Float>(s * 0.08, s * 0.2, s * 0.08)),
                        colorAndMaterial: creature.primaryColor
                    )
                    idx += 1
                }
                
            case .skyWhale:
                // Main body (elongated)
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p) * MatrixUtil.scale(SIMD3<Float>(s * 1.5, s * 0.8, s * 3.0)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
                
                // Belly glow
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(0, -s * 0.3, 0)) * MatrixUtil.scale(SIMD3<Float>(s * 1.0, s * 0.15, s * 2.5)),
                    colorAndMaterial: creature.emissiveColor
                )
                idx += 1
                
                // Tail fin
                let tailSway = sin(phase * 1.5) * s * 0.5
                pointer[idx] = EntityInstance(
                    modelMatrix: MatrixUtil.translation(p + SIMD3<Float>(tailSway, 0, s * 2.0)) * MatrixUtil.scale(SIMD3<Float>(s * 0.8, s * 0.4, s * 0.3)),
                    colorAndMaterial: creature.primaryColor
                )
                idx += 1
            }
            
            if idx >= maxInstances - 10 { break } // Safety
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
