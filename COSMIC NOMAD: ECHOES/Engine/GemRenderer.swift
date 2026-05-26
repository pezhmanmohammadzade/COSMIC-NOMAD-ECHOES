//
//  GemRenderer.swift
//  COSMIC NOMAD: ECHOES
//
//  Renders a shining 3D gem (faceted diamond/octahedron) at each
//  undiscovered memory fragment (unknown signal) location.
//  The gem floats above the terrain, slowly rotates, and pulses with light.
//

import Metal
import simd

@MainActor
final class GemRenderer {
    let device: MTLDevice
    
    // Gem mesh buffers
    private var gemVertexBuffer: MTLBuffer!
    private var gemIndexBuffer: MTLBuffer!
    private var gemIndexCount: Int = 0
    
    // Instance buffer (max 20 fragments per planet)
    private let maxInstances = 20
    private var instanceBuffer: MTLBuffer!
    
    // Animation
    private var rotationPhase: Float = 0
    
    init(device: MTLDevice) {
        self.device = device
        buildGemMesh()
        
        instanceBuffer = device.makeBuffer(
            length: MemoryLayout<EntityInstance>.stride * maxInstances,
            options: .storageModeShared
        )
        instanceBuffer.label = "Gem Instance Buffer"
        
        print("💎 GemRenderer: Initialized with faceted gem mesh")
    }
    
    // MARK: - Gem Geometry
    
    /// Build a faceted diamond/octahedron gem with multiple facets for sparkle
    private func buildGemMesh() {
        // A gem shape: elongated octahedron with a wider middle band
        // Top point, bottom point, and a ring of vertices around the equator
        let topY: Float = 1.0       // Top apex
        let bottomY: Float = -0.6   // Bottom apex (shorter, like a real gem)
        let midY: Float = 0.15      // Equator slightly above center for gem look
        let radius: Float = 0.5     // Equator radius
        let facets = 8              // Number of facets around the circumference
        
        var vertices: [EntityVertex] = []
        var indices: [UInt16] = []
        
        // Generate equator ring vertices
        var equatorPositions: [SIMD3<Float>] = []
        for i in 0..<facets {
            let angle = Float(i) / Float(facets) * .pi * 2.0
            let x = cos(angle) * radius
            let z = sin(angle) * radius
            equatorPositions.append(SIMD3<Float>(x, midY, z))
        }
        
        let topPos = SIMD3<Float>(0, topY, 0)
        let bottomPos = SIMD3<Float>(0, bottomY, 0)
        
        // Build triangles with flat shading (each triangle gets its own vertices with face normal)
        for i in 0..<facets {
            let next = (i + 1) % facets
            let eq0 = equatorPositions[i]
            let eq1 = equatorPositions[next]
            
            // --- Upper facet: top → eq0 → eq1 ---
            let upperNormal = normalize(cross(eq0 - topPos, eq1 - topPos))
            let baseIdx = UInt16(vertices.count)
            vertices.append(EntityVertex(position: topPos, normal: upperNormal, texCoord: SIMD2<Float>(0.5, 0)))
            vertices.append(EntityVertex(position: eq0, normal: upperNormal, texCoord: SIMD2<Float>(0, 1)))
            vertices.append(EntityVertex(position: eq1, normal: upperNormal, texCoord: SIMD2<Float>(1, 1)))
            indices.append(contentsOf: [baseIdx, baseIdx + 1, baseIdx + 2])
            
            // --- Lower facet: bottom → eq1 → eq0 ---
            let lowerNormal = normalize(cross(eq1 - bottomPos, eq0 - bottomPos))
            let baseIdx2 = UInt16(vertices.count)
            vertices.append(EntityVertex(position: bottomPos, normal: lowerNormal, texCoord: SIMD2<Float>(0.5, 1)))
            vertices.append(EntityVertex(position: eq1, normal: lowerNormal, texCoord: SIMD2<Float>(0, 0)))
            vertices.append(EntityVertex(position: eq0, normal: lowerNormal, texCoord: SIMD2<Float>(1, 0)))
            indices.append(contentsOf: [baseIdx2, baseIdx2 + 1, baseIdx2 + 2])
        }
        
        // Add a secondary inner ring for extra faceting (crown facets)
        let crownY: Float = midY + (topY - midY) * 0.5  // Halfway between equator and top
        let crownRadius: Float = radius * 0.7
        
        var crownPositions: [SIMD3<Float>] = []
        for i in 0..<facets {
            let angle = (Float(i) + 0.5) / Float(facets) * .pi * 2.0  // Offset by half facet
            let x = cos(angle) * crownRadius
            let z = sin(angle) * crownRadius
            crownPositions.append(SIMD3<Float>(x, crownY, z))
        }
        
        // Crown triangles: eq0 → crown_i → eq1, and crown_i → top → crown_next
        for i in 0..<facets {
            let next = (i + 1) % facets
            let eq0 = equatorPositions[i]
            let eq1 = equatorPositions[next]
            let cr = crownPositions[i]
            
            // Lower crown facet: eq0 → cr → eq1
            let n1 = normalize(cross(cr - eq0, eq1 - eq0))
            let b1 = UInt16(vertices.count)
            vertices.append(EntityVertex(position: eq0, normal: n1, texCoord: SIMD2<Float>(0, 0)))
            vertices.append(EntityVertex(position: cr, normal: n1, texCoord: SIMD2<Float>(0.5, 0.5)))
            vertices.append(EntityVertex(position: eq1, normal: n1, texCoord: SIMD2<Float>(1, 0)))
            indices.append(contentsOf: [b1, b1 + 1, b1 + 2])
            
            // Upper crown facet: cr → top → crown_next
            let crNext = crownPositions[next]
            let n2 = normalize(cross(topPos - cr, crNext - cr))
            let b2 = UInt16(vertices.count)
            vertices.append(EntityVertex(position: cr, normal: n2, texCoord: SIMD2<Float>(0, 1)))
            vertices.append(EntityVertex(position: topPos, normal: n2, texCoord: SIMD2<Float>(0.5, 0)))
            vertices.append(EntityVertex(position: crNext, normal: n2, texCoord: SIMD2<Float>(1, 1)))
            indices.append(contentsOf: [b2, b2 + 1, b2 + 2])
        }
        
        gemVertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<EntityVertex>.stride,
            options: .storageModeShared
        )
        gemVertexBuffer.label = "Gem Vertices"
        
        gemIndexBuffer = device.makeBuffer(
            bytes: indices,
            length: indices.count * MemoryLayout<UInt16>.stride,
            options: .storageModeShared
        )
        gemIndexBuffer.label = "Gem Indices"
        
        gemIndexCount = indices.count
    }
    
    // MARK: - Draw
    
    func draw(
        fragments: [MemoryFragment],
        world: WorldGenerator,
        encoder: MTLRenderCommandEncoder,
        resources: ResourceManager,
        pipeline: RenderPipeline,
        time: Float
    ) {
        // Advance rotation
        rotationPhase = time * 1.5  // Slow continuous rotation
        
        // Collect undiscovered fragments
        var instanceCount = 0
        let pointer = instanceBuffer.contents().bindMemory(to: EntityInstance.self, capacity: maxInstances)
        
        for frag in fragments {
            guard !frag.isDiscovered else { continue }
            guard instanceCount < maxInstances else { break }
            
            let fragPos = frag.worldPosition
            
            // Get terrain height at fragment position
            let terrainY = world.heightAt(worldX: fragPos.x, worldZ: fragPos.z) ?? 0
            
            // Float above terrain with gentle bobbing
            let floatHeight: Float = 3.5
            let bob = sin(time * 2.0 + fragPos.x * 0.5) * 0.4
            let gemY = terrainY + floatHeight + bob
            
            // Rotation (each gem has slightly different phase based on position)
            let uniquePhase = rotationPhase + fragPos.x * 0.3 + fragPos.z * 0.7
            let yawRot = MatrixUtil.rotation(pitch: 0, yaw: uniquePhase, roll: 0)
            // Slight tilt for visual interest
            let tiltRot = MatrixUtil.rotation(pitch: sin(time * 0.8 + fragPos.z) * 0.15, yaw: 0, roll: 0)
            
            // Scale: gem is about 1.5 units tall, pulses slightly
            let pulseScale = 1.0 + sin(time * 3.0 + fragPos.x) * 0.08
            let gemScale: Float = 1.5 * Float(pulseScale)
            
            // Build model matrix
            let translation = MatrixUtil.translation(SIMD3<Float>(fragPos.x, gemY, fragPos.z))
            let scale = MatrixUtil.scale(SIMD3<Float>(gemScale, gemScale * 1.2, gemScale))  // Taller than wide
            let modelMatrix = translation * yawRot * tiltRot * scale
            
            // Color: glowing cyan/teal with emissive material (type 3 = Memory Fragment)
            let colorAndMat = SIMD4<Float>(0.2, 0.85, 1.0, 3.0)
            
            pointer[instanceCount] = EntityInstance(
                modelMatrix: modelMatrix,
                colorAndMaterial: colorAndMat
            )
            instanceCount += 1
        }
        
        guard instanceCount > 0 else { return }
        
        // Draw all gem instances
        encoder.setRenderPipelineState(pipeline.entityPipeline)
        encoder.setVertexBuffer(gemVertexBuffer, offset: 0, index: BufferIndex.vertices.rawValue)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: BufferIndex.instanceData.rawValue)
        
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: gemIndexCount,
            indexType: .uint16,
            indexBuffer: gemIndexBuffer,
            indexBufferOffset: 0,
            instanceCount: instanceCount
        )
    }
}
