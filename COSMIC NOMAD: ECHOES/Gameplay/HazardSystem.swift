//
//  HazardSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Procedurally places hazard zones (toxic, radiation, unstable, lava)
//  based on planet mood. Checks player proximity and applies damage.
//

import simd

enum HazardType: String {
    case toxic      // Drains oxygen
    case radiation  // Drains suit power
    case unstable   // Periodic damage bursts
    case lava       // Continuous health damage
}

struct HazardZone {
    let position: SIMD3<Float>
    let radius: Float
    let type: HazardType
    let intensity: Float // 0-1 danger level
    
    func playerFactor(at playerPos: SIMD3<Float>) -> Float {
        let dx = playerPos.x - position.x
        let dz = playerPos.z - position.z
        let dist = sqrt(dx * dx + dz * dz)
        if dist > radius { return 0 }
        // Stronger effect closer to center
        return (1.0 - dist / radius) * intensity
    }
}

final class HazardSystem {
    private(set) var zones: [HazardZone] = []
    private(set) var activeHazardType: HazardType? = nil
    private(set) var activeIntensity: Float = 0
    
    var isPlayerInHazardZone: Bool {
        return activeHazardType != nil
    }
    
    // Pulse timer for unstable zones
    private var unstablePulseTimer: Float = 0
    private var unstablePulseActive: Bool = false
    
    func generate(around center: SIMD3<Float>, mood: PlanetMood, seed: UInt64) {
        var rng = SeededRNG(seed: seed &+ 9999)
        zones.removeAll()
        
        let count: Int
        let types: [HazardType]
        
        switch mood {
        case .hostile:
            count = Int(rng.nextFloatRange(6, 10))
            types = [.lava, .radiation, .toxic]
        case .decayed:
            count = Int(rng.nextFloatRange(4, 7))
            types = [.toxic, .unstable]
        case .surreal:
            count = Int(rng.nextFloatRange(3, 6))
            types = [.radiation, .unstable]
        case .lonely:
            count = Int(rng.nextFloatRange(2, 4))
            types = [.radiation]
        case .serene:
            count = Int(rng.nextFloatRange(1, 3))
            types = [.toxic]
        }
        
        for _ in 0..<count {
            let angle = rng.nextFloatRange(0, .pi * 2)
            let dist = rng.nextFloatRange(40, 250)
            let pos = SIMD3<Float>(
                center.x + cos(angle) * dist,
                0,
                center.z + sin(angle) * dist
            )
            let radius = rng.nextFloatRange(15, 45)
            let type = types[Int(rng.next() % UInt64(types.count))]
            let intensity = rng.nextFloatRange(0.3, 1.0)
            
            zones.append(HazardZone(position: pos, radius: radius, type: type, intensity: intensity))
        }
    }
    
    func update(playerPosition: SIMD3<Float>, survival: SurvivalSystem, deltaTime: Float) {
        var maxFactor: Float = 0
        var dominantType: HazardType? = nil
        
        for zone in zones {
            let factor = zone.playerFactor(at: playerPosition)
            if factor > maxFactor {
                maxFactor = factor
                dominantType = zone.type
            }
        }
        
        activeHazardType = maxFactor > 0.01 ? dominantType : nil
        activeIntensity = maxFactor
        
        guard let type = dominantType, maxFactor > 0.01 else {
            unstablePulseTimer = 0
            return
        }
        
        switch type {
        case .toxic:
            // Drain oxygen
            survival.applyHazardDamage(oxygenDrain: maxFactor * 8.0 * deltaTime, powerDrain: 0, healthDamage: 0)
        case .radiation:
            // Drain suit power
            survival.applyHazardDamage(oxygenDrain: 0, powerDrain: maxFactor * 6.0 * deltaTime, healthDamage: 0)
        case .lava:
            // Direct health damage
            survival.applyHazardDamage(oxygenDrain: 0, powerDrain: 0, healthDamage: maxFactor * 15.0 * deltaTime)
        case .unstable:
            // Periodic damage bursts
            unstablePulseTimer += deltaTime
            if unstablePulseTimer > 3.0 {
                unstablePulseTimer = 0
                survival.applyHazardDamage(oxygenDrain: maxFactor * 10.0, powerDrain: maxFactor * 5.0, healthDamage: 0)
                unstablePulseActive = true
            } else {
                unstablePulseActive = false
            }
        }
    }
    
    var warningText: String? {
        guard let type = activeHazardType else { return nil }
        switch type {
        case .toxic:      return "⚠️ TOXIC ZONE"
        case .radiation:  return "☢️ RADIATION ZONE"
        case .unstable:   return "⚡ UNSTABLE GROUND"
        case .lava:       return "🔥 LAVA ZONE"
        }
    }
}
