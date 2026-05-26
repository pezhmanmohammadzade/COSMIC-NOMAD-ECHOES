//
//  NPCSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Procedural alien creature system. Spawns ambient alien life
//  per-chunk based on planet mood. Creatures can be scanned for data cores.
//  Creatures have collision that damages the player.
//

import simd

enum CreatureType: String {
    case floatingJellyfish  // Surreal/Serene: floats up and down
    case groundCrawler      // Decayed/Hostile: patrols on ground
    case skyWhale           // Lonely: slow high-altitude circles
}

struct AlienCreature {
    var position: SIMD3<Float>
    var spawnPosition: SIMD3<Float>
    let type: CreatureType
    var animationPhase: Float
    let animationSpeed: Float
    let size: Float
    var isScanned: Bool = false
    
    // Colors
    let primaryColor: SIMD4<Float>
    let emissiveColor: SIMD4<Float>
    
    // Collision radius based on creature size and type
    var collisionRadius: Float {
        switch type {
        case .floatingJellyfish: return size * 1.5
        case .groundCrawler:    return size * 1.8
        case .skyWhale:         return size * 4.0
        }
    }
}

@MainActor
final class NPCSystem {
    private(set) var creatures: [AlienCreature] = []
    
    private let maxCreatures = 80
    
    // Data reward for scanning
    let scanReward: Int = 3
    
    // NPC collision damage (per tick)
    let npcDamageOxygen: Float = 3.0
    let npcDamagePower: Float = 2.0
    let npcDamageHealth: Float = 15.0
    private var npcDamageCooldown: Float = 0
    private let npcDamageInterval: Float = 1.0 // seconds between damage ticks
    
    func generate(around center: SIMD3<Float>, mood: PlanetMood, terrainHeight: Float, seed: UInt64) {
        var rng = SeededRNG(seed: seed &+ 77777)
        creatures.removeAll()
        
        let count: Int
        let types: [CreatureType]
        
        switch mood {
        case .surreal:
            count = Int(rng.nextFloatRange(20, 40))
            types = [.floatingJellyfish, .skyWhale]
        case .serene:
            count = Int(rng.nextFloatRange(15, 30))
            types = [.floatingJellyfish, .groundCrawler]
        case .decayed:
            count = Int(rng.nextFloatRange(12, 25))
            types = [.groundCrawler]
        case .hostile:
            count = Int(rng.nextFloatRange(8, 20))
            types = [.groundCrawler]
        case .lonely:
            count = Int(rng.nextFloatRange(5, 15))
            types = [.skyWhale]
        }
        
        let finalCount = min(count, maxCreatures)
        
        for _ in 0..<finalCount {
            let angle = rng.nextFloatRange(0, .pi * 2)
            let dist = rng.nextFloatRange(30, 200)
            let type = types[Int(rng.next() % UInt64(types.count))]
            
            let baseY: Float
            switch type {
            case .floatingJellyfish: baseY = terrainHeight + rng.nextFloatRange(5, 20)
            case .groundCrawler:     baseY = terrainHeight + 1.5
            case .skyWhale:          baseY = terrainHeight + rng.nextFloatRange(30, 60)
            }
            
            let pos = SIMD3<Float>(
                center.x + cos(angle) * dist,
                baseY,
                center.z + sin(angle) * dist
            )
            
            // Bigger creatures (1.5–4.0 instead of 0.8–2.5)
            let creatureSize = rng.nextFloatRange(1.5, 4.0)
            
            let (primary, emissive) = creatureColors(type: type, mood: mood, rng: &rng)
            
            creatures.append(AlienCreature(
                position: pos,
                spawnPosition: pos,
                type: type,
                animationPhase: rng.nextFloatRange(0, .pi * 2),
                animationSpeed: rng.nextFloatRange(0.5, 2.0),
                size: creatureSize,
                primaryColor: primary,
                emissiveColor: emissive
            ))
        }
    }
    
    func update(deltaTime: Float, time: Float, playerPosition: SIMD3<Float>) {
        npcDamageCooldown = max(0, npcDamageCooldown - deltaTime)
        
        for i in 0..<creatures.count {
            creatures[i].animationPhase += deltaTime * creatures[i].animationSpeed
            
            let phase = creatures[i].animationPhase
            
            switch creatures[i].type {
            case .floatingJellyfish:
                let dx = playerPosition.x - creatures[i].position.x
                let dz = playerPosition.z - creatures[i].position.z
                let distToPlayer = sqrt(dx*dx + dz*dz)
                
                if distToPlayer < 20.0 {
                    // Drift towards player
                    let moveSpeed: Float = 2.0
                    if distToPlayer > 0.1 {
                        creatures[i].spawnPosition.x += (dx / distToPlayer) * moveSpeed * deltaTime
                        creatures[i].spawnPosition.z += (dz / distToPlayer) * moveSpeed * deltaTime
                    }
                }
                
                // Float up and down, gentle horizontal drift
                creatures[i].position.y = creatures[i].spawnPosition.y + sin(phase) * 3.0
                creatures[i].position.x = creatures[i].spawnPosition.x + sin(phase * 0.3) * 5.0
                creatures[i].position.z = creatures[i].spawnPosition.z + cos(phase * 0.4) * 5.0
                
            case .groundCrawler:
                let dx = playerPosition.x - creatures[i].position.x
                let dy = playerPosition.y - creatures[i].position.y
                let dz = playerPosition.z - creatures[i].position.z
                let distToPlayer = sqrt(dx*dx + dy*dy + dz*dz)
                
                let radius: Float = 10.0
                
                if distToPlayer < 25.0 {
                    let moveSpeed: Float = 6.0
                    let hDist = sqrt(dx*dx + dz*dz)
                    if hDist > 0.1 {
                        creatures[i].position.x += (dx / hDist) * moveSpeed * deltaTime
                        creatures[i].position.z += (dz / hDist) * moveSpeed * deltaTime
                        
                        // Keep spawnPosition synced so it doesn't snap when leaving aggro
                        creatures[i].spawnPosition.x = creatures[i].position.x - cos(phase * 0.5) * radius
                        creatures[i].spawnPosition.z = creatures[i].position.z - sin(phase * 0.5) * radius
                    }
                } else {
                    // Patrol in a circle
                    creatures[i].position.x = creatures[i].spawnPosition.x + cos(phase * 0.5) * radius
                    creatures[i].position.z = creatures[i].spawnPosition.z + sin(phase * 0.5) * radius
                }
                
            case .skyWhale:
                let radius: Float = 40.0
                
                let dx = playerPosition.x - creatures[i].spawnPosition.x
                let dz = playerPosition.z - creatures[i].spawnPosition.z
                let distToPlayer = sqrt(dx*dx + dz*dz)
                
                if distToPlayer < 100.0 {
                    let moveSpeed: Float = 5.0
                    if distToPlayer > 0.1 {
                        creatures[i].spawnPosition.x += (dx / distToPlayer) * moveSpeed * deltaTime
                        creatures[i].spawnPosition.z += (dz / distToPlayer) * moveSpeed * deltaTime
                    }
                }
                
                // Slow wide circles at high altitude
                creatures[i].position.x = creatures[i].spawnPosition.x + cos(phase * 0.15) * radius
                creatures[i].position.z = creatures[i].spawnPosition.z + sin(phase * 0.15) * radius
                creatures[i].position.y = creatures[i].spawnPosition.y + sin(phase * 0.3) * 5.0
            }
        }
    }
    
    /// Check if player can scan any creature (returns index if scannable)
    func nearestScannableCreature(at playerPos: SIMD3<Float>, scanRange: Float = 15.0) -> Int? {
        var bestDist: Float = scanRange
        var bestIdx: Int? = nil
        
        for (i, creature) in creatures.enumerated() {
            if creature.isScanned { continue }
            let dx = creature.position.x - playerPos.x
            let dy = creature.position.y - playerPos.y
            let dz = creature.position.z - playerPos.z
            let dist = sqrt(dx*dx + dy*dy + dz*dz)
            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }
        return bestIdx
    }
    
    /// Scan a creature (mark as scanned, return type name)
    func scanCreature(at index: Int) -> String {
        guard index < creatures.count else { return "Unknown" }
        creatures[index].isScanned = true
        
        switch creatures[index].type {
        case .floatingJellyfish: return "Luminous Drifter"
        case .groundCrawler:     return "Husk Crawler"
        case .skyWhale:          return "Void Leviathan"
        }
    }
    
    /// Check if player is colliding with any NPC — returns true and applies damage if so
    func checkCollision(playerPosition: SIMD3<Float>, survival: SurvivalSystem, deltaTime: Float) -> Bool {
        // Only damage on cooldown ticks
        guard npcDamageCooldown <= 0 else { return false }
        
        for creature in creatures {
            let dx = creature.position.x - playerPosition.x
            let dy = creature.position.y - playerPosition.y
            let dz = creature.position.z - playerPosition.z
            let dist = sqrt(dx*dx + dy*dy + dz*dz)
            
            // Add 0.6 to collisionRadius to account for the player's 0.5 physical radius push-out
            if dist <= creature.collisionRadius + 0.6 {
                survival.applyHazardDamage(
                    oxygenDrain: npcDamageOxygen,
                    powerDrain: npcDamagePower,
                    healthDamage: npcDamageHealth
                )
                npcDamageCooldown = npcDamageInterval
                return true
            }
        }
        return false
    }
    
    private func creatureColors(type: CreatureType, mood: PlanetMood, rng: inout SeededRNG) -> (SIMD4<Float>, SIMD4<Float>) {
        let variant = rng.nextFloatRange(0, 1)
        
        switch type {
        case .floatingJellyfish:
            // Diverse jellyfish colors by mood
            switch mood {
            case .surreal:
                if variant < 0.33 {
                    return (SIMD4<Float>(0.7, 0.2, 0.9, 0.0), SIMD4<Float>(0.9, 0.3, 1.0, 1.0))  // Neon purple
                } else if variant < 0.66 {
                    return (SIMD4<Float>(0.1, 0.8, 0.5, 0.0), SIMD4<Float>(0.2, 1.0, 0.6, 1.0))  // Electric green
                } else {
                    return (SIMD4<Float>(0.9, 0.1, 0.5, 0.0), SIMD4<Float>(1.0, 0.2, 0.6, 1.0))  // Hot pink
                }
            case .serene:
                if variant < 0.33 {
                    return (SIMD4<Float>(0.2, 0.7, 0.9, 0.0), SIMD4<Float>(0.3, 0.9, 1.0, 1.0))  // Sky blue
                } else if variant < 0.66 {
                    return (SIMD4<Float>(0.4, 0.9, 0.7, 0.0), SIMD4<Float>(0.5, 1.0, 0.8, 1.0))  // Mint
                } else {
                    return (SIMD4<Float>(0.8, 0.8, 0.3, 0.0), SIMD4<Float>(1.0, 1.0, 0.4, 1.0))  // Golden
                }
            default:
                if variant < 0.5 {
                    return (SIMD4<Float>(0.3, 0.5, 0.8, 0.0), SIMD4<Float>(0.2, 0.8, 1.0, 1.0))  // Classic blue
                } else {
                    return (SIMD4<Float>(0.6, 0.3, 0.7, 0.0), SIMD4<Float>(0.8, 0.4, 0.9, 1.0))  // Lavender
                }
            }
            
        case .groundCrawler:
            // Diverse crawler colors by mood
            switch mood {
            case .hostile:
                if variant < 0.33 {
                    return (SIMD4<Float>(0.7, 0.15, 0.1, 0.0), SIMD4<Float>(1.0, 0.3, 0.1, 1.0))  // Blood red
                } else if variant < 0.66 {
                    return (SIMD4<Float>(0.3, 0.1, 0.3, 0.0), SIMD4<Float>(0.6, 0.1, 0.5, 1.0))  // Dark magenta
                } else {
                    return (SIMD4<Float>(0.2, 0.2, 0.2, 0.0), SIMD4<Float>(0.9, 0.6, 0.1, 1.0))  // Dark body, orange eyes
                }
            case .decayed:
                if variant < 0.33 {
                    return (SIMD4<Float>(0.5, 0.35, 0.2, 0.0), SIMD4<Float>(0.8, 0.4, 0.1, 1.0))  // Earthy brown
                } else if variant < 0.66 {
                    return (SIMD4<Float>(0.3, 0.5, 0.2, 0.0), SIMD4<Float>(0.5, 0.9, 0.2, 1.0))  // Mossy green
                } else {
                    return (SIMD4<Float>(0.6, 0.4, 0.3, 0.0), SIMD4<Float>(0.9, 0.7, 0.2, 1.0))  // Sand with amber eyes
                }
            case .serene:
                if variant < 0.5 {
                    return (SIMD4<Float>(0.4, 0.6, 0.5, 0.0), SIMD4<Float>(0.5, 0.9, 0.7, 1.0))  // Jade
                } else {
                    return (SIMD4<Float>(0.5, 0.5, 0.7, 0.0), SIMD4<Float>(0.6, 0.6, 1.0, 1.0))  // Periwinkle
                }
            default:
                return (SIMD4<Float>(0.5, 0.35, 0.2, 0.0), SIMD4<Float>(0.8, 0.4, 0.1, 1.0))  // Default earthy
            }
            
        case .skyWhale:
            // Diverse whale colors by mood
            switch mood {
            case .lonely:
                if variant < 0.33 {
                    return (SIMD4<Float>(0.15, 0.2, 0.5, 0.0), SIMD4<Float>(0.3, 0.5, 1.0, 1.0))  // Deep blue
                } else if variant < 0.66 {
                    return (SIMD4<Float>(0.3, 0.15, 0.4, 0.0), SIMD4<Float>(0.5, 0.3, 0.8, 1.0))  // Violet
                } else {
                    return (SIMD4<Float>(0.1, 0.3, 0.3, 0.0), SIMD4<Float>(0.2, 0.6, 0.6, 1.0))  // Deep teal
                }
            case .surreal:
                if variant < 0.5 {
                    return (SIMD4<Float>(0.4, 0.1, 0.6, 0.0), SIMD4<Float>(0.7, 0.2, 1.0, 1.0))  // Purple whale
                } else {
                    return (SIMD4<Float>(0.1, 0.5, 0.5, 0.0), SIMD4<Float>(0.2, 0.9, 0.8, 1.0))  // Cyan whale
                }
            default:
                return (SIMD4<Float>(0.2, 0.25, 0.4, 0.0), SIMD4<Float>(0.4, 0.6, 0.9, 1.0))  // Default blue-grey
            }
        }
    }
}
