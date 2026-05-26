//
//  ChunkStreamer.swift
//  COSMIC NOMAD: ECHOES
//
//  Chunk-based world streaming: loads/unloads terrain around player,
//  manages LOD transitions, async generation on background threads.
//

import Metal
import simd
import Foundation

@MainActor
final class ChunkStreamer {
    
    let device: MTLDevice
    let terrainGenerator: TerrainGenerator
    let cityGenerator: CityGenerator
    let planetConfig: PlanetConfig
    
    // Active chunks
    private(set) var activeChunks: [ChunkCoord: TerrainChunk] = [:]
    
    // Streaming parameters
    let chunkSize: Float = 64.0
    var loadRadius: Int {
        switch SettingsManager.shared.graphicsQuality {
        case .high: return 4
        case .medium: return 2
        case .low: return 1
        }
    }
    var unloadRadius: Int { return loadRadius + 2 }
    
    // Async generation
    private var generationQueue: [ChunkCoord] = []
    private var generatingChunks: Set<ChunkCoord> = []
    private let maxConcurrentGenerations = 2
    
    // Player tracking
    private var lastPlayerChunkX: Int = Int.min
    private var lastPlayerChunkZ: Int = Int.min
    
    init(device: MTLDevice, terrainGenerator: TerrainGenerator, cityGenerator: CityGenerator, planetConfig: PlanetConfig) {
        self.device = device
        self.terrainGenerator = terrainGenerator
        self.cityGenerator = cityGenerator
        self.planetConfig = planetConfig
    }
    
    // MARK: - Update
    
    func update(playerPosition: SIMD3<Float>, cameraFrustum: Frustum) {
        let playerChunkX = Int(floor(playerPosition.x / chunkSize))
        let playerChunkZ = Int(floor(playerPosition.z / chunkSize))
        
        // Only re-evaluate if player moved to a different chunk
        if playerChunkX != lastPlayerChunkX || playerChunkZ != lastPlayerChunkZ {
            lastPlayerChunkX = playerChunkX
            lastPlayerChunkZ = playerChunkZ
            
            // Queue new chunks
            queueChunksAroundPlayer(chunkX: playerChunkX, chunkZ: playerChunkZ)
            
            // Unload distant chunks
            unloadDistantChunks(playerChunkX: playerChunkX, playerChunkZ: playerChunkZ)
        }
        
        // Update LOD levels based on distance
        updateLODLevels(playerPosition: playerPosition)
        
        // Process generation queue
        processGenerationQueue()
    }
    
    // MARK: - Chunk Loading
    
    private func queueChunksAroundPlayer(chunkX: Int, chunkZ: Int) {
        var newCoords: [(ChunkCoord, Float)] = []
        
        for dz in -loadRadius...loadRadius {
            for dx in -loadRadius...loadRadius {
                let coord = ChunkCoord(x: chunkX + dx, z: chunkZ + dz)
                
                // Skip if already loaded or being generated
                if activeChunks[coord] != nil || generatingChunks.contains(coord) { continue }
                
                // Priority based on distance to player
                let distance = sqrt(Float(dx * dx + dz * dz))
                newCoords.append((coord, distance))
            }
        }
        
        // Sort by distance (closest first)
        newCoords.sort { $0.1 < $1.1 }
        
        for (coord, _) in newCoords {
            if !generationQueue.contains(coord) {
                generationQueue.append(coord)
            }
        }
    }
    
    private func unloadDistantChunks(playerChunkX: Int, playerChunkZ: Int) {
        let toRemove = activeChunks.filter { (coord, _) in
            let dx = abs(coord.x - playerChunkX)
            let dz = abs(coord.z - playerChunkZ)
            return dx > unloadRadius || dz > unloadRadius
        }
        
        for (coord, chunk) in toRemove {
            chunk.release()
            activeChunks.removeValue(forKey: coord)
        }
    }
    
    // MARK: - Async Generation
    
    private func processGenerationQueue() {
        while !generationQueue.isEmpty && generatingChunks.count < maxConcurrentGenerations {
            let coord = generationQueue.removeFirst()
            
            // Don't regenerate
            guard activeChunks[coord] == nil else { continue }
            
            generatingChunks.insert(coord)
            
            let generator = terrainGenerator
            let chunkSize = self.chunkSize
            let heightScale = planetConfig.terrainHeightScale
            let device = self.device
            
            // Generate heightfield on background thread
            Task.detached(priority: .userInitiated) { [weak self] in
                let heightfield = generator.generateHeightfield(
                    chunkX: coord.x,
                    chunkZ: coord.z,
                    resolution: 65
                )
                
                // Build mesh on main thread (requires Metal device)
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    let chunk = TerrainChunk(chunkX: coord.x, chunkZ: coord.z, chunkSize: chunkSize)
                    
                    // Determine LOD based on distance to player
                    let playerWorldX = Float(self.lastPlayerChunkX) * chunkSize + chunkSize * 0.5
                    let playerWorldZ = Float(self.lastPlayerChunkZ) * chunkSize + chunkSize * 0.5
                    let chunkCenterX = Float(coord.x) * chunkSize + chunkSize * 0.5
                    let chunkCenterZ = Float(coord.z) * chunkSize + chunkSize * 0.5
                    let distance = sqrt(
                        (chunkCenterX - playerWorldX) * (chunkCenterX - playerWorldX) +
                        (chunkCenterZ - playerWorldZ) * (chunkCenterZ - playerWorldZ)
                    )
                    let lod = LODLevel.forDistance(distance)
                    
                    chunk.buildMesh(heightfield: heightfield, lodLevel: lod, device: device, heightScale: heightScale)
                    
                    // Generate entities and collision data
                    let result = self.cityGenerator.generateEntitiesAndCollision(forChunkX: coord.x, chunkZ: coord.z, chunkSize: chunkSize, terrainGen: generator)
                    chunk.entities = result.entities
                    chunk.buildingColliders = result.colliders
                    chunk.buildEntityBuffer(device: device)
                    
                    self.activeChunks[coord] = chunk
                    self.generatingChunks.remove(coord)
                }
            }
        }
    }
    
    // MARK: - LOD Updates
    
    private func updateLODLevels(playerPosition: SIMD3<Float>) {
        for (coord, chunk) in activeChunks {
            let chunkCenterX = Float(coord.x) * chunkSize + chunkSize * 0.5
            let chunkCenterZ = Float(coord.z) * chunkSize + chunkSize * 0.5
            let distance = sqrt(
                (chunkCenterX - playerPosition.x) * (chunkCenterX - playerPosition.x) +
                (chunkCenterZ - playerPosition.z) * (chunkCenterZ - playerPosition.z)
            )
            
            let desiredLOD = LODLevel.forDistance(distance)
            
            // Only rebuild if LOD needs to change significantly
            if desiredLOD != chunk.lodLevel && chunk.isReady {
                // Re-queue for regeneration at new LOD
                // For now, we keep the current LOD to avoid frame drops
                // A more sophisticated system would do incremental LOD transitions
            }
        }
    }
    
    // MARK: - Terrain Queries
    
    /// Get terrain height at world position
    func heightAt(worldX: Float, worldZ: Float) -> Float? {
        let chunkX = Int(floor(worldX / chunkSize))
        let chunkZ = Int(floor(worldZ / chunkSize))
        let coord = ChunkCoord(x: chunkX, z: chunkZ)
        
        return activeChunks[coord]?.heightAt(
            worldX: worldX, worldZ: worldZ,
            heightScale: planetConfig.terrainHeightScale
        )
    }
    
    /// Check if a world position collides with any building
    func buildingCollisionAt(worldX: Float, worldY: Float, worldZ: Float) -> Bool {
        let chunkX = Int(floor(worldX / chunkSize))
        let chunkZ = Int(floor(worldZ / chunkSize))
        
        // Check the current chunk and adjacent chunks (buildings near edges)
        for dz in -1...1 {
            for dx in -1...1 {
                let coord = ChunkCoord(x: chunkX + dx, z: chunkZ + dz)
                guard let chunk = activeChunks[coord] else { continue }
                for collider in chunk.buildingColliders {
                    if collider.intersectsXZ(x: worldX, z: worldZ, margin: 1.2) &&
                       worldY >= collider.minY && worldY <= collider.maxY {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    // MARK: - Render Data
    
    /// Get all ready chunks for rendering
    func readyChunks() -> [TerrainChunk] {
        return activeChunks.values.filter { $0.isReady }
    }
    
    /// Generate terrain params for all ready chunks
    func terrainParams() -> [TerrainParams] {
        return readyChunks().map { chunk in
            var params = TerrainParams()
            params.modelMatrix = matrix_identity_float4x4
            params.chunkWorldPosition = SIMD2<Float>(chunk.worldOriginX, chunk.worldOriginZ)
            params.chunkSize = chunk.chunkSize
            params.lodLevel = Float(chunk.lodLevel.rawValue)
            params.heightScale = planetConfig.terrainHeightScale
            params.textureScale = 4.0
            return params
        }
    }
    
    // MARK: - Cleanup
    
    func unloadAll() {
        for (_, chunk) in activeChunks {
            chunk.release()
        }
        activeChunks.removeAll()
        generationQueue.removeAll()
        generatingChunks.removeAll()
    }
}

// MARK: - Chunk Coordinate

struct ChunkCoord: Hashable, Equatable {
    let x: Int
    let z: Int
}
