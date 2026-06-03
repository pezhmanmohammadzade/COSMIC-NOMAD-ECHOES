//
//  WorldGenerator.swift
//  COSMIC NOMAD: ECHOES
//
//  Top-level world coordinator: manages planet generation,
//  chunk streaming, atmosphere, and weather subsystems.
//

import Metal
import simd
import Foundation

@MainActor
final class WorldGenerator {
    
    let device: MTLDevice
    
    // Current planet
    private(set) var planetConfig: PlanetConfig
    private(set) var terrainGenerator: TerrainGenerator
    private(set) var cityGenerator: CityGenerator
    private(set) var chunkStreamer: ChunkStreamer
    private(set) var atmosphereSystem: AtmosphereSystem
    private(set) var weatherSystem: WeatherSystem
    private(set) var memoryFragmentSystem: MemoryFragmentSystem
    private(set) var anomalySystem: AnomalySystem
    
    // World state
    private(set) var isReady: Bool = false
    
    init(device: MTLDevice, seed: UInt64, level: Int, restoredFactIds: [Int]? = nil) {
        self.device = device
        
        // Generate planet from seed
        self.planetConfig = PlanetConfig.generate(seed: seed)
        self.terrainGenerator = TerrainGenerator(planetConfig: planetConfig)
        self.cityGenerator = CityGenerator(planetConfig: planetConfig)
        self.chunkStreamer = ChunkStreamer(device: device, terrainGenerator: terrainGenerator, cityGenerator: cityGenerator, planetConfig: planetConfig)
        self.atmosphereSystem = AtmosphereSystem(planetConfig: planetConfig)
        self.weatherSystem = WeatherSystem(planetConfig: planetConfig)
        self.memoryFragmentSystem = MemoryFragmentSystem()
        self.anomalySystem = AnomalySystem()
        self.memoryFragmentSystem.generate(seed: seed, planetName: self.planetConfig.name, mood: self.planetConfig.mood, level: level, restoredFactIds: restoredFactIds)
        self.anomalySystem.generate(seed: seed, mood: self.planetConfig.mood)
        
        print("🌍 World Generated: \(planetConfig.name)")
        print("   Mood: \(planetConfig.mood.rawValue)")
        print("   Seed: \(planetConfig.seed)")
        print("   Terrain Height: \(planetConfig.terrainHeightScale)m")
        print("   Anomalies: \(anomalySystem.anomalies.count)")
        
        isReady = true
    }
    
    // MARK: - Update
    
    func update(playerPosition: SIMD3<Float>, cameraFrustum: Frustum, deltaTime: Float, totalTime: Float) {
        // Update weather
        weatherSystem.update(deltaTime: deltaTime)
        
        // Update atmosphere with weather influence
        atmosphereSystem.update(
            deltaTime: deltaTime,
            totalTime: totalTime,
            weatherVisibility: weatherSystem.visibility
        )
        
        // Update anomalies
        anomalySystem.update(deltaTime: deltaTime)
        
        // Update chunk streaming
        chunkStreamer.update(playerPosition: playerPosition, cameraFrustum: cameraFrustum)
    }
    
    // MARK: - Render Data
    
    var atmosphereParams: AtmosphereParams {
        var params = atmosphereSystem.currentParams
        params.fogDensityBase *= weatherSystem.fogMultiplier
        return params
    }
    
    var sunDirection: SIMD3<Float> {
        atmosphereSystem.sunDirection
    }
    
    var sunColor: SIMD3<Float> {
        atmosphereSystem.sunColor * weatherSystem.lightMultiplier
    }
    
    var sunIntensity: Float {
        atmosphereSystem.sunIntensity * weatherSystem.lightMultiplier
    }
    
    var readyChunks: [TerrainChunk] {
        chunkStreamer.readyChunks()
    }
    
    var terrainParams: [TerrainParams] {
        chunkStreamer.terrainParams()
    }
    
    // MARK: - Terrain Queries
    
    func heightAt(worldX: Float, worldZ: Float) -> Float? {
        chunkStreamer.heightAt(worldX: worldX, worldZ: worldZ)
    }
    
    /// Check if a world position collides with a building
    func buildingCollisionAt(worldX: Float, worldY: Float, worldZ: Float) -> Bool {
        chunkStreamer.buildingCollisionAt(worldX: worldX, worldY: worldY, worldZ: worldZ)
    }
    
    // MARK: - Planet Change
    
    func changePlanet(seed: UInt64, restoredFactIds: [Int]? = nil) {
        chunkStreamer.unloadAll()
        
        let newConfig = PlanetConfig.generate(seed: seed)
        let newTerrainGen = TerrainGenerator(planetConfig: newConfig)
        let newCityGen = CityGenerator(planetConfig: newConfig)
        
        self.planetConfig = newConfig
        self.terrainGenerator = newTerrainGen
        self.cityGenerator = newCityGen
        self.chunkStreamer = ChunkStreamer(device: device, terrainGenerator: newTerrainGen, cityGenerator: newCityGen, planetConfig: newConfig)
        self.atmosphereSystem = AtmosphereSystem(planetConfig: newConfig)
        self.weatherSystem = WeatherSystem(planetConfig: newConfig)
        self.memoryFragmentSystem.generate(seed: seed, planetName: newConfig.name, mood: newConfig.mood, level: SaveManager.shared.getPlanetsCompleted() + 1, restoredFactIds: restoredFactIds)
        self.anomalySystem.generate(seed: seed, mood: newConfig.mood)
        
        print("🌍 Planet Changed: \(newConfig.name) (Mood: \(newConfig.mood.rawValue))")
    }
}
