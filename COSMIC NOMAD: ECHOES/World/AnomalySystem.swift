//
//  AnomalySystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Spawns environmental hazards and anomalies around the map.
//  Each planet mood generates different types of anomalies.
//

import simd
import Foundation

@MainActor
final class AnomalySystem {
    
    // MARK: - Anomaly Types
    
    enum AnomalyType: String, CaseIterable {
        case geyser = "Geyser"
        case radiationZone = "Radiation Zone"
        case icePatch = "Ice Patch"
        case energyVortex = "Energy Vortex"
        
        var effectRadius: Float {
            switch self {
            case .geyser:        return 6.0
            case .radiationZone: return 12.0
            case .icePatch:      return 10.0
            case .energyVortex:  return 8.0
            }
        }
        
        var icon: String {
            switch self {
            case .geyser:        return "flame.fill"
            case .radiationZone: return "radiation"
            case .icePatch:      return "snowflake"
            case .energyVortex:  return "tornado"
            }
        }
    }
    
    // MARK: - Anomaly Instance
    
    struct Anomaly {
        let id: Int
        let type: AnomalyType
        let worldPosition: SIMD3<Float>
        let effectRadius: Float
        var isCollected: Bool = false    // For energy vortexes
        
        // Geyser-specific
        var eruptionTimer: Float = 0
        var isErupting: Bool = false
        let eruptionInterval: Float     // seconds between eruptions
        let eruptionDuration: Float     // seconds eruption lasts
    }
    
    // MARK: - Properties
    
    private(set) var anomalies: [Anomaly] = []
    private var activeEffects: Set<Int> = []  // IDs of anomalies currently affecting player
    
    // MARK: - Generation
    
    func generate(seed: UInt64, mood: PlanetMood) {
        anomalies = []
        var rng = SeededRNG(seed: seed &+ 9999)
        
        let anomalyTypes = typesForMood(mood)
        let count = Int(rng.nextFloatRange(4, 10))
        
        for i in 0..<count {
            let type = anomalyTypes[Int(rng.next() % UInt64(anomalyTypes.count))]
            let x = rng.nextFloatRange(-200, 200)
            let z = rng.nextFloatRange(-200, 200)
            
            // Don't place too close to spawn point
            if abs(x) < 30 && abs(z) < 30 { continue }
            
            let anomaly = Anomaly(
                id: i,
                type: type,
                worldPosition: SIMD3<Float>(x, 0, z),
                effectRadius: type.effectRadius * rng.nextFloatRange(0.8, 1.3),
                eruptionTimer: rng.nextFloatRange(0, 15),
                eruptionInterval: rng.nextFloatRange(8, 20),
                eruptionDuration: rng.nextFloatRange(2, 5)
            )
            anomalies.append(anomaly)
        }
    }
    
    // MARK: - Types by Mood
    
    private func typesForMood(_ mood: PlanetMood) -> [AnomalyType] {
        switch mood {
        case .hostile:
            return [.geyser, .geyser, .radiationZone]
        case .decayed:
            return [.radiationZone, .radiationZone, .geyser]
        case .lonely:
            return [.icePatch, .icePatch, .energyVortex]
        case .serene:
            return [.energyVortex, .energyVortex, .icePatch]
        case .surreal:
            return [.energyVortex, .geyser, .icePatch, .radiationZone]
        }
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        for i in 0..<anomalies.count {
            guard anomalies[i].type == .geyser else { continue }
            
            anomalies[i].eruptionTimer += deltaTime
            
            if anomalies[i].isErupting {
                if anomalies[i].eruptionTimer >= anomalies[i].eruptionDuration {
                    anomalies[i].isErupting = false
                    anomalies[i].eruptionTimer = 0
                }
            } else {
                if anomalies[i].eruptionTimer >= anomalies[i].eruptionInterval {
                    anomalies[i].isErupting = true
                    anomalies[i].eruptionTimer = 0
                }
            }
        }
    }
    
    // MARK: - Proximity Check
    
    struct AnomalyEffect {
        var oxygenDrain: Float = 0
        var powerDrain: Float = 0
        var temperatureOffset: Float = 0
        var pushDirection: SIMD3<Float>? = nil
        var pushStrength: Float = 0
        var speedMultiplier: Float = 1.0
        var dataCoreReward: Int = 0
        var activeAnomalyType: AnomalyType? = nil
    }
    
    func checkProximity(playerPosition: SIMD3<Float>) -> AnomalyEffect {
        var effect = AnomalyEffect()
        
        for i in 0..<anomalies.count {
            let anomaly = anomalies[i]
            let dx = playerPosition.x - anomaly.worldPosition.x
            let dz = playerPosition.z - anomaly.worldPosition.z
            let dist = sqrt(dx * dx + dz * dz)
            
            guard dist < anomaly.effectRadius else { continue }
            
            let intensity = 1.0 - (dist / anomaly.effectRadius)
            
            switch anomaly.type {
            case .geyser:
                if anomaly.isErupting {
                    effect.oxygenDrain += 8.0 * intensity
                    effect.temperatureOffset += 20.0 * intensity
                    // Push away from geyser
                    if dist > 0.01 {
                        let pushDir = normalize(SIMD3<Float>(dx, 0.5, dz))
                        effect.pushDirection = pushDir
                        effect.pushStrength = 15.0 * intensity
                    }
                    effect.activeAnomalyType = .geyser
                }
                
            case .radiationZone:
                effect.powerDrain += 10.0 * intensity
                effect.oxygenDrain += 3.0 * intensity
                effect.activeAnomalyType = .radiationZone
                
            case .icePatch:
                effect.speedMultiplier *= (1.0 - 0.6 * intensity) // Slippery
                effect.temperatureOffset -= 15.0 * intensity
                effect.activeAnomalyType = .icePatch
                
            case .energyVortex:
                if !anomaly.isCollected {
                    // Pull player toward vortex
                    if dist > 0.01 {
                        let pullDir = normalize(SIMD3<Float>(-dx, 0, -dz))
                        effect.pushDirection = pullDir
                        effect.pushStrength = 5.0 * intensity
                    }
                    
                    // If very close, collect it
                    if dist < 3.0 {
                        anomalies[i].isCollected = true
                        effect.dataCoreReward = 2
                        effect.activeAnomalyType = .energyVortex
                    }
                }
            }
        }
        
        return effect
    }
    
    // MARK: - Query
    
    var activeAnomalies: [Anomaly] {
        anomalies.filter { !$0.isCollected }
    }
}
