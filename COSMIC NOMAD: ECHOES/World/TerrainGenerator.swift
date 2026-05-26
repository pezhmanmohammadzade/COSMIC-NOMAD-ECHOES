//
//  TerrainGenerator.swift
//  COSMIC NOMAD: ECHOES
//
//  Procedural terrain: multi-octave noise heightfield generation,
//  simplified erosion simulation, normal and material computation.
//

import simd
import Foundation

@MainActor
final class TerrainGenerator {
    
    let planetConfig: PlanetConfig
    private let baseSeed: UInt64
    
    // Generation settings
    let heightfieldResolution: Int = 65  // Per chunk (LOD 0)
    
    init(planetConfig: PlanetConfig) {
        self.planetConfig = planetConfig
        self.baseSeed = planetConfig.seed
    }
    
    // MARK: - Heightfield Generation
    
    /// Generate heightfield for a chunk at given grid coordinates
    /// Returns a 2D array of normalized heights [0, 1]
    nonisolated func generateHeightfield(chunkX: Int, chunkZ: Int, resolution: Int) -> [[Float]] {
        let chunkSeed = SeededRNG.seedFromCoords(chunkX, chunkZ, baseSeed: baseSeed)
        var rng = SeededRNG(seed: chunkSeed)
        
        let config = planetConfig
        let scale = config.terrainScale
        
        var heightfield = [[Float]](repeating: [Float](repeating: 0, count: resolution), count: resolution)
        
        let worldOriginX = Float(chunkX) * 64.0  // chunk size in world units
        let worldOriginZ = Float(chunkZ) * 64.0
        
        for iz in 0..<resolution {
            for ix in 0..<resolution {
                let u = Float(ix) / Float(resolution - 1)
                let v = Float(iz) / Float(resolution - 1)
                
                let worldX = (worldOriginX + u * 64.0) * scale
                let worldZ = (worldOriginZ + v * 64.0) * scale
                
                // Base terrain: FBM noise
                var height = Noise.fbm(worldX, worldZ,
                                       octaves: config.terrainOctaves,
                                       lacunarity: config.terrainLacunarity,
                                       persistence: config.terrainPersistence)
                
                // Ridge noise for mountains
                if config.terrainRidgeFactor > 0.01 {
                    let ridge = Noise.ridged(worldX, worldZ,
                                             octaves: max(config.terrainOctaves - 1, 3),
                                             lacunarity: config.terrainLacunarity,
                                             persistence: config.terrainPersistence * 0.8)
                    height = height * (1 - config.terrainRidgeFactor) + ridge * config.terrainRidgeFactor
                }
                
                // Domain warping for alien feel
                if config.terrainWarpStrength > 0.01 {
                    let warped = Noise.domainWarped(worldX, worldZ, warpStrength: config.terrainWarpStrength)
                    height = height * 0.7 + warped * 0.3
                }
                
                // Normalize to [0, 1] range (noise returns roughly [-1, 1])
                height = (height + 1.0) * 0.5
                height = simd_clamp(height, 0, 1)
                
                heightfield[iz][ix] = height
            }
        }
        
        // Apply erosion simulation
        if config.terrainErosionPasses > 0 {
            heightfield = applyErosion(heightfield, passes: config.terrainErosionPasses, rng: &rng)
        }
        
        return heightfield
    }
    
    // MARK: - Erosion Simulation
    
    /// Simplified thermal + hydraulic erosion
    private nonisolated func applyErosion(_ input: [[Float]], passes: Int, rng: inout SeededRNG) -> [[Float]] {
        var heightfield = input
        let resolution = heightfield.count
        
        for _ in 0..<passes {
            // Thermal erosion: material slides from steep slopes
            var newField = heightfield
            let talusAngle: Float = 0.05  // Threshold slope
            
            for iz in 1..<(resolution - 1) {
                for ix in 1..<(resolution - 1) {
                    let h = heightfield[iz][ix]
                    
                    // Check 4 neighbors
                    let neighbors = [
                        (ix - 1, iz), (ix + 1, iz),
                        (ix, iz - 1), (ix, iz + 1)
                    ]
                    
                    var maxDiff: Float = 0
                    var totalDiff: Float = 0
                    var diffs: [Float] = []
                    
                    for (nx, nz) in neighbors {
                        let diff = h - heightfield[nz][nx]
                        diffs.append(diff)
                        if diff > talusAngle {
                            totalDiff += diff
                            maxDiff = max(maxDiff, diff)
                        }
                    }
                    
                    if totalDiff > 0 {
                        let redistribute = maxDiff * 0.2
                        newField[iz][ix] -= redistribute
                        
                        for (i, (nx, nz)) in neighbors.enumerated() {
                            if diffs[i] > talusAngle {
                                newField[nz][nx] += redistribute * (diffs[i] / totalDiff)
                            }
                        }
                    }
                }
            }
            
            heightfield = newField
            
            // Hydraulic erosion: simplified droplet simulation
            let numDroplets = resolution * 2
            for _ in 0..<numDroplets {
                var dx = Int(rng.next() % UInt64(resolution - 2)) + 1
                var dz = Int(rng.next() % UInt64(resolution - 2)) + 1
                var water: Float = 1.0
                var sediment: Float = 0.0
                let erosionRate: Float = 0.01
                let depositionRate: Float = 0.01
                
                for _ in 0..<20 {
                    let h = heightfield[dz][dx]
                    
                    // Find steepest descent
                    var bestDx = dx, bestDz = dz
                    var bestDiff: Float = 0
                    
                    let checkNeighbors = [
                        (dx - 1, dz), (dx + 1, dz),
                        (dx, dz - 1), (dx, dz + 1)
                    ]
                    
                    for (nx, nz) in checkNeighbors {
                        guard nx >= 0 && nx < resolution && nz >= 0 && nz < resolution else { continue }
                        let diff = h - heightfield[nz][nx]
                        if diff > bestDiff {
                            bestDiff = diff
                            bestDx = nx
                            bestDz = nz
                        }
                    }
                    
                    if bestDiff <= 0 {
                        // Deposit sediment
                        heightfield[dz][dx] += sediment * depositionRate
                        break
                    }
                    
                    // Erode and carry
                    let erosionAmount = min(bestDiff * erosionRate, water * erosionRate)
                    heightfield[dz][dx] -= erosionAmount
                    sediment += erosionAmount
                    
                    // Move droplet
                    dx = bestDx
                    dz = bestDz
                    water *= 0.95  // Evaporation
                    
                    // Deposit some sediment
                    let deposit = sediment * depositionRate * 0.3
                    heightfield[dz][dx] += deposit
                    sediment -= deposit
                }
            }
        }
        
        return heightfield
    }
}
