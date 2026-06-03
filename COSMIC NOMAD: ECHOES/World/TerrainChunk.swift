//
//  TerrainChunk.swift
//  COSMIC NOMAD: ECHOES
//
//  Single terrain chunk data container with Metal vertex/index buffers,
//  LOD tracking, and bounding box for frustum culling.
//

import Metal
import simd

// MARK: - LOD Level

enum LODLevel: Int, CaseIterable, Comparable {
    case full = 0       // 65×65 = 4225 verts
    case half = 1       // 33×33 = 1089 verts
    case quarter = 2    // 17×17 = 289 verts
    case eighth = 3     // 9×9 = 81 verts
    
    var resolution: Int {
        switch self {
        case .full: return 65
        case .half: return 33
        case .quarter: return 17
        case .eighth: return 9
        }
    }
    
    var maxDistance: Float {
        switch self {
        case .full: return 50
        case .half: return 150
        case .quarter: return 400
        case .eighth: return Float.infinity
        }
    }
    
    static func forDistance(_ distance: Float) -> LODLevel {
        for level in LODLevel.allCases {
            if distance <= level.maxDistance {
                return level
            }
        }
        return .eighth
    }
    
    static func < (lhs: LODLevel, rhs: LODLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Terrain Chunk

@MainActor
final class TerrainChunk {
    
    // Chunk identity
    let chunkX: Int
    let chunkZ: Int
    let worldOriginX: Float
    let worldOriginZ: Float
    let chunkSize: Float
    
    // LOD
    private(set) var lodLevel: LODLevel = .full
    
    // Metal buffers
    private(set) var vertexBuffer: MTLBuffer?
    private(set) var indexBuffer: MTLBuffer?
    private(set) var vertexCount: Int = 0
    private(set) var indexCount: Int = 0
    
    // Bounding box
    private(set) var boundingBoxMin: SIMD3<Float> = .zero
    private(set) var boundingBoxMax: SIMD3<Float> = .zero
    
    // State
    private(set) var isReady: Bool = false
    private(set) var isGenerating: Bool = false
    
    // Heightfield data (kept for collision queries)
    private(set) var heightfield: [[Float]] = []
    private(set) var heightfieldResolution: Int = 0
    
    // Entities
    var entities: [EntityInstance] = []
    private(set) var entityInstanceBuffer: MTLBuffer?
    
    // Building collision AABBs
    var buildingColliders: [BuildingAABB] = []
    
    init(chunkX: Int, chunkZ: Int, chunkSize: Float) {
        self.chunkX = chunkX
        self.chunkZ = chunkZ
        self.chunkSize = chunkSize
        self.worldOriginX = Float(chunkX) * chunkSize
        self.worldOriginZ = Float(chunkZ) * chunkSize
    }
    
    // MARK: - Build Mesh
    
    /// Generate mesh from heightfield data and upload to Metal buffers
    func buildMesh(heightfield: [[Float]], lodLevel: LODLevel, device: MTLDevice, heightScale: Float) {
        self.heightfield = heightfield
        self.heightfieldResolution = heightfield.count
        self.lodLevel = lodLevel
        
        let resolution = lodLevel.resolution
        let step = max(1, (heightfield.count - 1) / (resolution - 1))
        let actualRes = (heightfield.count - 1) / step + 1
        
        // Generate vertices
        var vertices: [TerrainVertex] = []
        vertices.reserveCapacity(actualRes * actualRes)
        
        var minY: Float = .greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        
        for iz in 0..<actualRes {
            for ix in 0..<actualRes {
                let hx = min(ix * step, heightfield.count - 1)
                let hz = min(iz * step, heightfield.count - 1)
                
                let u = Float(ix) / Float(actualRes - 1)
                let v = Float(iz) / Float(actualRes - 1)
                
                let worldX = worldOriginX + u * chunkSize
                let worldZ = worldOriginZ + v * chunkSize
                let height = heightfield[hz][hx] * heightScale
                
                minY = min(minY, height)
                maxY = max(maxY, height)
                
                // Compute normal from neighboring heights
                let left = hx > 0 ? heightfield[hz][hx - 1] * heightScale : height
                let right = hx < heightfield.count - 1 ? heightfield[hz][hx + 1] * heightScale : height
                let down = hz > 0 ? heightfield[hz - 1][hx] * heightScale : height
                let up = hz < heightfield.count - 1 ? heightfield[hz + 1][hx] * heightScale : height
                
                let dx = right - left
                let dz = up - down
                let normal = normalize(SIMD3<Float>(-dx, 2.0 * chunkSize / Float(actualRes), -dz))
                
                // Material weights based on height and slope
                let normalizedHeight = (height / heightScale + 1) * 0.5  // 0-1
                let slope = 1.0 - abs(normal.y)
                
                var weights = SIMD4<Float>.zero
                
                if slope > 0.6 {
                    // Steep = cliff face
                    weights.w = 1.0
                } else if normalizedHeight > 0.7 {
                    // High = mineral
                    weights.z = 1.0
                } else if normalizedHeight > 0.3 {
                    // Mid = rock
                    weights.y = 1.0
                } else {
                    // Low = soil
                    weights.x = 1.0
                }
                
                // Blend between material zones
                if normalizedHeight > 0.25 && normalizedHeight < 0.35 {
                    let t = Interpolation.smoothstep(0.25, 0.35, normalizedHeight)
                    weights = simd_mix(SIMD4<Float>(1, 0, 0, 0), SIMD4<Float>(0, 1, 0, 0), SIMD4<Float>(repeating: t))
                }
                if normalizedHeight > 0.65 && normalizedHeight < 0.75 {
                    let t = Interpolation.smoothstep(0.65, 0.75, normalizedHeight)
                    weights = simd_mix(SIMD4<Float>(0, 1, 0, 0), SIMD4<Float>(0, 0, 1, 0), SIMD4<Float>(repeating: t))
                }
                if slope > 0.4 {
                    let slopeBlend = Interpolation.smoothstep(0.4, 0.7, slope)
                    weights = simd_mix(weights, SIMD4<Float>(0, 0, 0, 1), SIMD4<Float>(repeating: slopeBlend))
                }
                
                let vertex = TerrainVertex(
                    position: SIMD3<Float>(worldX, height, worldZ),
                    normal: normal,
                    texCoord: SIMD2<Float>(u, v),
                    materialWeights: weights
                )
                vertices.append(vertex)
            }
        }
        
        // Generate indices
        var indices: [UInt32] = []
        indices.reserveCapacity((actualRes - 1) * (actualRes - 1) * 6)
        
        for iz in 0..<(actualRes - 1) {
            for ix in 0..<(actualRes - 1) {
                let topLeft = UInt32(iz * actualRes + ix)
                let topRight = topLeft + 1
                let bottomLeft = UInt32((iz + 1) * actualRes + ix)
                let bottomRight = bottomLeft + 1
                
                // Triangle 1
                indices.append(topLeft)
                indices.append(bottomLeft)
                indices.append(topRight)
                
                // Triangle 2
                indices.append(topRight)
                indices.append(bottomLeft)
                indices.append(bottomRight)
            }
        }
        
        // Create Metal buffers
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<TerrainVertex>.stride * vertices.count,
            options: .storageModeShared
        )
        vertexBuffer?.label = "Terrain Chunk (\(chunkX), \(chunkZ)) Vertices"
        
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt32>.stride * indices.count,
            options: .storageModeShared
        )
        indexBuffer?.label = "Terrain Chunk (\(chunkX), \(chunkZ)) Indices"
        
        vertexCount = vertices.count
        indexCount = indices.count
        
        // Bounding box
        boundingBoxMin = SIMD3<Float>(worldOriginX, minY, worldOriginZ)
        boundingBoxMax = SIMD3<Float>(worldOriginX + chunkSize, maxY, worldOriginZ + chunkSize)
        
        isReady = vertexBuffer != nil && indexBuffer != nil
    }
    
    func buildEntityBuffer(device: MTLDevice) {
        guard !entities.isEmpty else { return }
        entityInstanceBuffer = device.makeBuffer(
            bytes: entities,
            length: MemoryLayout<EntityInstance>.stride * entities.count,
            options: .storageModeShared
        )
        entityInstanceBuffer?.label = "Entity Instances Chunk (\(chunkX), \(chunkZ))"
    }
    
    // MARK: - Terrain Queries
    
    /// Get height at world position (bilinear interpolation)
    func heightAt(worldX: Float, worldZ: Float, heightScale: Float) -> Float? {
        guard !heightfield.isEmpty else { return nil }
        
        let localX = (worldX - worldOriginX) / chunkSize
        let localZ = (worldZ - worldOriginZ) / chunkSize
        
        guard localX >= 0 && localX <= 1 && localZ >= 0 && localZ <= 1 else { return nil }
        
        let gridX = localX * Float(heightfieldResolution - 1)
        let gridZ = localZ * Float(heightfieldResolution - 1)
        
        let ix = Int(gridX)
        let iz = Int(gridZ)
        let fx = gridX - Float(ix)
        let fz = gridZ - Float(iz)
        
        let ix1 = min(ix + 1, heightfieldResolution - 1)
        let iz1 = min(iz + 1, heightfieldResolution - 1)
        
        let h00 = heightfield[iz][ix]
        let h10 = heightfield[iz][ix1]
        let h01 = heightfield[iz1][ix]
        let h11 = heightfield[iz1][ix1]
        
        let h = (h00 * (1 - fx) * (1 - fz) +
                 h10 * fx * (1 - fz) +
                 h01 * (1 - fx) * fz +
                 h11 * fx * fz) * heightScale
        
        return h
    }
    
    // MARK: - Cleanup
    
    func release() {
        vertexBuffer = nil
        indexBuffer = nil
        entityInstanceBuffer = nil
        entities = []
        buildingColliders = []
        heightfield = []
        isReady = false
    }
}
