//
//  CityGenerator.swift
//  COSMIC NOMAD: ECHOES
//
//  Generates procedural cities and structures on planetary surfaces.
//  Outputs arrays of EntityInstance for instanced rendering.
//  Also generates AABB collision data for solid buildings.
//

import simd
import Foundation

/// Axis-aligned bounding box for building collision
struct BuildingAABB {
    let minX: Float
    let minY: Float
    let minZ: Float
    let maxX: Float
    let maxY: Float
    let maxZ: Float
    
    func contains(x: Float, y: Float, z: Float) -> Bool {
        return x >= minX && x <= maxX &&
               y >= minY && y <= maxY &&
               z >= minZ && z <= maxZ
    }
    
    func intersectsXZ(x: Float, z: Float, margin: Float = 1.0) -> Bool {
        return x >= (minX - margin) && x <= (maxX + margin) &&
               z >= (minZ - margin) && z <= (maxZ + margin)
    }
}

@MainActor
final class CityGenerator {
    
    let planetConfig: PlanetConfig
    private let baseSeed: UInt64
    
    // City parameters — lowered threshold for many more cities
    let cityFrequency: Float = 0.03
    let cityRadius: Float = 200.0
    let buildingCountPerCity: Int = 150
    
    init(planetConfig: PlanetConfig) {
        self.planetConfig = planetConfig
        self.baseSeed = planetConfig.seed &+ 0x12345678
    }
    
    // MARK: - Generation
    
    /// Generate building instances AND collision AABBs for a specific terrain chunk
    func generateEntitiesAndCollision(forChunkX chunkX: Int, chunkZ: Int, chunkSize: Float, terrainGen: TerrainGenerator) -> (entities: [EntityInstance], colliders: [BuildingAABB]) {
        var instances: [EntityInstance] = []
        var colliders: [BuildingAABB] = []
        
        let worldOriginX = Float(chunkX) * chunkSize
        let worldOriginZ = Float(chunkZ) * chunkSize
        let chunkCenter = SIMD2<Float>(worldOriginX + chunkSize * 0.5, worldOriginZ + chunkSize * 0.5)
        
        // Determine if this chunk contains a city hub
        let cityNoise = Noise.perlin2D(chunkCenter.x * cityFrequency, chunkCenter.y * cityFrequency)
        
        // Much lower threshold = cities everywhere
        if cityNoise > -0.3 {
            let chunkSeed = SeededRNG.seedFromCoords(chunkX, chunkZ, baseSeed: baseSeed)
            var rng = SeededRNG(seed: chunkSeed)
            
            // More buildings per chunk
            let count = Int(rng.nextFloatRange(25, 80))
            
            for _ in 0..<count {
                // Random position within chunk
                let localX = rng.nextFloatRange(0, chunkSize)
                let localZ = rng.nextFloatRange(0, chunkSize)
                let worldX = worldOriginX + localX
                let worldZ = worldOriginZ + localZ
                
                // Get terrain height
                let scale = planetConfig.terrainScale
                var height = Noise.fbm(worldX * scale, worldZ * scale,
                                       octaves: planetConfig.terrainOctaves,
                                       lacunarity: planetConfig.terrainLacunarity,
                                       persistence: planetConfig.terrainPersistence)
                
                if planetConfig.terrainRidgeFactor > 0.01 {
                    let ridge = Noise.ridged(worldX * scale, worldZ * scale,
                                             octaves: max(planetConfig.terrainOctaves - 1, 3),
                                             lacunarity: planetConfig.terrainLacunarity,
                                             persistence: planetConfig.terrainPersistence * 0.8)
                    height = height * (1 - planetConfig.terrainRidgeFactor) + ridge * planetConfig.terrainRidgeFactor
                }
                
                if planetConfig.terrainWarpStrength > 0.01 {
                    let warped = Noise.domainWarped(worldX * scale, worldZ * scale, warpStrength: planetConfig.terrainWarpStrength)
                    height = height * 0.7 + warped * 0.3
                }
                
                height = (height + 1.0) * 0.5
                height = simd_clamp(height, 0, 1)
                
                let worldY = height * planetConfig.terrainHeightScale
                
                // Skip too steep or too low
                let heightR = Noise.fbm((worldX + 1) * scale, worldZ * scale, octaves: 2)
                let slope = abs(heightR - height) * planetConfig.terrainHeightScale
                if slope > 2.0 { continue }
                if worldY < planetConfig.terrainHeightScale * 0.2 { continue }
                
                // Building dimensions — bigger and more imposing
                let width = rng.nextFloatRange(4.0, 25.0)
                let depth = rng.nextFloatRange(4.0, 25.0)
                let heightBldg = rng.nextFloatRange(15.0, 120.0)
                
                // Transform
                var modelMatrix = matrix_identity_float4x4
                modelMatrix = modelMatrix * MatrixUtil.translation(SIMD3<Float>(worldX, worldY + heightBldg * 0.5 - 2.0, worldZ))
                
                let yaw = rng.nextFloatRange(0, .pi * 2)
                modelMatrix = modelMatrix * MatrixUtil.rotation(pitch: 0, yaw: yaw, roll: 0)
                modelMatrix = modelMatrix * MatrixUtil.scale(SIMD3<Float>(width, heightBldg, depth))
                
                // Material (0=Metal, 1=Glass, 2=Ruin, 3=MemoryFragment)
                var matType: Float = floor(rng.nextFloatRange(0, 2.99))
                var baseColor = SIMD3<Float>(0.5, 0.5, 0.5)
                
                // 5% chance to be a Memory Fragment instead of a building
                if rng.nextFloatRange(0, 1) < 0.05 {
                    matType = 3.0
                    baseColor = SIMD3<Float>(0.2, 0.8, 1.0) // Cyan glowing
                    
                    modelMatrix = matrix_identity_float4x4
                    modelMatrix = modelMatrix * MatrixUtil.translation(SIMD3<Float>(worldX, worldY + 2.0, worldZ))
                    modelMatrix = modelMatrix * MatrixUtil.scale(SIMD3<Float>(2.0, 4.0, 2.0))
                    
                    // Memory fragments don't block player
                } else {
                    // Vivid, mood-specific colors with high variety
                    let colorVariant = rng.nextFloatRange(0, 1)
                    switch planetConfig.mood {
                    case .lonely:
                        if colorVariant < 0.25 {
                            baseColor = SIMD3<Float>(0.3, 0.4, 0.7) // Steel blue
                        } else if colorVariant < 0.5 {
                            baseColor = SIMD3<Float>(0.5, 0.5, 0.6) // Silver grey
                        } else if colorVariant < 0.75 {
                            baseColor = SIMD3<Float>(0.2, 0.5, 0.6) // Teal
                        } else {
                            baseColor = SIMD3<Float>(0.6, 0.4, 0.7) // Dusty purple
                        }
                    case .decayed:
                        if colorVariant < 0.25 {
                            baseColor = SIMD3<Float>(0.8, 0.6, 0.3) // Golden amber
                        } else if colorVariant < 0.5 {
                            baseColor = SIMD3<Float>(0.6, 0.8, 0.4) // Moss green
                        } else if colorVariant < 0.75 {
                            baseColor = SIMD3<Float>(0.9, 0.5, 0.2) // Rust orange
                        } else {
                            baseColor = SIMD3<Float>(0.7, 0.7, 0.5) // Sandstone
                        }
                    case .hostile:
                        if colorVariant < 0.25 {
                            baseColor = SIMD3<Float>(0.9, 0.2, 0.1) // Crimson
                        } else if colorVariant < 0.5 {
                            baseColor = SIMD3<Float>(0.3, 0.1, 0.1) // Dark maroon
                        } else if colorVariant < 0.75 {
                            baseColor = SIMD3<Float>(0.8, 0.5, 0.1) // Lava orange
                        } else {
                            baseColor = SIMD3<Float>(0.4, 0.2, 0.3) // Charred purple
                        }
                    case .serene:
                        if colorVariant < 0.25 {
                            baseColor = SIMD3<Float>(0.4, 0.8, 0.6) // Mint green
                        } else if colorVariant < 0.5 {
                            baseColor = SIMD3<Float>(0.6, 0.7, 0.9) // Sky blue
                        } else if colorVariant < 0.75 {
                            baseColor = SIMD3<Float>(0.8, 0.8, 0.6) // Cream
                        } else {
                            baseColor = SIMD3<Float>(0.5, 0.9, 0.8) // Aqua
                        }
                    case .surreal:
                        if colorVariant < 0.25 {
                            baseColor = SIMD3<Float>(0.7, 0.1, 0.9) // Neon purple
                        } else if colorVariant < 0.5 {
                            baseColor = SIMD3<Float>(0.1, 0.9, 0.7) // Electric teal
                        } else if colorVariant < 0.75 {
                            baseColor = SIMD3<Float>(0.9, 0.3, 0.6) // Hot pink
                        } else {
                            baseColor = SIMD3<Float>(0.3, 0.5, 1.0) // Vivid blue
                        }
                    }
                    
                    // Per-building color variation
                    baseColor.x += rng.nextFloatRange(-0.15, 0.15)
                    baseColor.y += rng.nextFloatRange(-0.15, 0.15)
                    baseColor.z += rng.nextFloatRange(-0.15, 0.15)
                    baseColor = simd_clamp(baseColor, SIMD3<Float>(repeating: 0.05), SIMD3<Float>(repeating: 1.0))
                    
                    // Add collision AABB for solid buildings
                    let halfW = width * 0.5
                    let halfD = depth * 0.5
                    colliders.append(BuildingAABB(
                        minX: worldX - halfW,
                        minY: worldY - 2.0,
                        minZ: worldZ - halfD,
                        maxX: worldX + halfW,
                        maxY: worldY + heightBldg - 2.0,
                        maxZ: worldZ + halfD
                    ))
                }
                
                let colorAndMat = SIMD4<Float>(baseColor.x, baseColor.y, baseColor.z, matType)
                
                instances.append(EntityInstance(modelMatrix: modelMatrix, colorAndMaterial: colorAndMat))
            }
        }
        
        return (instances, colliders)
    }
    
    /// Legacy method — generates entities only (for backward compatibility)
    func generateEntities(forChunkX chunkX: Int, chunkZ: Int, chunkSize: Float, terrainGen: TerrainGenerator) -> [EntityInstance] {
        return generateEntitiesAndCollision(forChunkX: chunkX, chunkZ: chunkZ, chunkSize: chunkSize, terrainGen: terrainGen).entities
    }
}
