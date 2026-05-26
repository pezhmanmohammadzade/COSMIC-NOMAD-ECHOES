//
//  PlayerController.swift
//  COSMIC NOMAD: ECHOES
//
//  Player position, movement, terrain alignment,
//  jetpack mode, sprinting, and interaction with world systems.
//

import simd
import Foundation

@MainActor
final class PlayerController {
    
    // Position & orientation
    private(set) var position: SIMD3<Float> = SIMD3<Float>(0, 10, 0)
    private(set) var forward: SIMD3<Float> = SIMD3<Float>(0, 0, -1)
    private(set) var yaw: Float = 0
    
    // Movement
    var baseSpeed: Float = 7.0
    var sprintMultiplier: Float = 1.6
    var acceleration: Float = 25.0
    var groundFriction: Float = 4.0
    var airFriction: Float = 0.5
    
    private(set) var velocity: SIMD3<Float> = .zero
    
    // Sprint
    private(set) var isSprinting: Bool = false
    
    // Jetpack mode
    private(set) var isJetpacking: Bool = false
    private(set) var isAirborne: Bool = false
    
    // Jetpack altitude — configurable (20, 30, or 50 meters)
    var jetpackAltitude: Float = 20.0
    
    private let ascentSpeed: Float = 25.0
    private let descentSpeed: Float = 15.0
    private let gravity: Float = -16.0
    
    // Terrain following
    private(set) var groundHeight: Float = 0
    let playerHeight: Float = 1.8
    
    // Impacts
    private(set) var lastImpactVelocity: Float = 0
    
    // Speed modifiers
    var weatherSpeedModifier: Float = 1.0
    var slopeSpeedModifier: Float = 1.0
    
    // MARK: - Update
    
    func update(input: InputState, world: WorldGenerator, npcSystem: NPCSystem, camera: CameraSystem, deltaTime: Float, suitPower: Float) {
        lastImpactVelocity = 0
        
        // Sprint check
        isSprinting = input.moveStrength > 0.85 && suitPower > 0 && !isAirborne
        
        // Jetpack toggle state
        let wantsJetpack = input.isJetpackPressed && suitPower > 5
        isJetpacking = wantsJetpack
        
        // 1. Process horizontal movement input
        var desiredAccel: SIMD3<Float> = .zero
        
        if input.moveStrength > 0.01 {
            let camForwardFlat = normalize(SIMD3<Float>(camera.forward.x, 0, camera.forward.z))
            let camRight = normalize(cross(camForwardFlat, SIMD3<Float>(0, 1, 0)))
            
            let worldDir = camForwardFlat * (-input.moveDirection.y) + camRight * input.moveDirection.x
            
            if length(worldDir) > 0.01 {
                let normalizedDir = normalize(worldDir)
                
                if !isAirborne || length(SIMD2<Float>(velocity.x, velocity.z)) > 2.0 {
                    forward = normalize(simd_mix(forward, normalizedDir, SIMD3<Float>(repeating: 6.0 * deltaTime)))
                    yaw = atan2(forward.x, forward.z)
                }
                
                let upgradeSpeedBonus = UpgradeSystem.shared.sprintSpeedBonus
                let sprintMult: Float = isSprinting ? (sprintMultiplier + upgradeSpeedBonus) : 1.0
                // In jetpack, move a bit faster horizontally
                let flightSpeedBoost: Float = isAirborne ? 1.5 : 1.0
                
                let targetSpeed = baseSpeed * input.moveStrength * weatherSpeedModifier * slopeSpeedModifier * sprintMult * flightSpeedBoost
                let requiredAccel = targetSpeed * groundFriction
                desiredAccel = normalizedDir * requiredAccel
            }
        }
        
        // 2. Terrain height (Sample center and 4 corners to prevent side-clipping on steep slopes)
        var terrainHeight: Float = 0
        if let h = world.heightAt(worldX: position.x, worldZ: position.z) {
            terrainHeight = h
            
            let r: Float = 0.4 // Collision radius
            if let h1 = world.heightAt(worldX: position.x + r, worldZ: position.z), h1 > terrainHeight { terrainHeight = h1 }
            if let h2 = world.heightAt(worldX: position.x - r, worldZ: position.z), h2 > terrainHeight { terrainHeight = h2 }
            if let h3 = world.heightAt(worldX: position.x, worldZ: position.z + r), h3 > terrainHeight { terrainHeight = h3 }
            if let h4 = world.heightAt(worldX: position.x, worldZ: position.z - r), h4 > terrainHeight { terrainHeight = h4 }
        }
        
        let targetGroundY = terrainHeight + playerHeight
        
        // 3. Vertical movement — jetpack mode or gravity
        if wantsJetpack {
            // Target altitude: hover exactly at configured jetpackAltitude above terrain
            let targetFlightY = terrainHeight + jetpackAltitude
            let diff = targetFlightY - position.y
            
            if diff > 0.5 {
                // Ascending
                velocity.y = ascentSpeed * simd_clamp(diff / 5.0, 0.2, 1.0)
            } else if diff < -0.5 {
                // Too high (terrain dropped), descend gently
                velocity.y = -descentSpeed * 0.5
            } else {
                // At target altitude, hover exactly
                velocity.y = diff * 4.0 // Strong spring to lock onto altitude
            }
            isAirborne = true
        } else {
            // Not flying — apply gravity
            velocity.y += gravity * deltaTime
            
            // Jump logic
            if input.isJumpPressed && !isAirborne {
                velocity.y = 8.5 // Smoother, slightly floatier jump arc
                isAirborne = true
            }
        }
        
        // 4. Ground collision
        if position.y + velocity.y * deltaTime <= targetGroundY && velocity.y <= 0 {
            if isAirborne {
                lastImpactVelocity = -velocity.y
            }
            position.y = targetGroundY
            velocity.y = 0
            isAirborne = false
        } else {
            isAirborne = true
        }
        
        // Slope speed modifier (only on ground)
        if !isAirborne {
            let slope = abs(terrainHeight - groundHeight) / max(length(SIMD2<Float>(velocity.x, velocity.z)) * deltaTime, 0.01)
            slopeSpeedModifier = simd_clamp(1.0 - slope * 0.4, 0.2, 1.0)
        } else {
            slopeSpeedModifier = 1.0
        }
        
        groundHeight = terrainHeight
        
        // 5. Apply horizontal forces and friction
        let friction = isAirborne ? airFriction : groundFriction
        velocity.x -= velocity.x * friction * deltaTime
        velocity.z -= velocity.z * friction * deltaTime
        
        let accelMult: Float = isAirborne ? 0.6 : 1.0
        velocity.x += desiredAccel.x * accelMult * deltaTime
        velocity.z += desiredAccel.z * accelMult * deltaTime
        
        // 6. Compute candidate position
        var candidatePosition = position + velocity * deltaTime
        
        // 7. Building collision check — prevent passing through buildings
        if world.buildingCollisionAt(worldX: candidatePosition.x, worldY: candidatePosition.y, worldZ: candidatePosition.z) {
            // Block horizontal movement, keep vertical
            velocity.x = 0
            velocity.z = 0
            // Recompute candidate position without horizontal movement
            candidatePosition = position + SIMD3<Float>(0, velocity.y * deltaTime, 0)
        }
        
        // 8. NPC Collision (Push out)
        let playerRadius: Float = 0.5
        for creature in npcSystem.creatures {
            let dx = candidatePosition.x - creature.position.x
            let dz = candidatePosition.z - creature.position.z
            let hDist = sqrt(dx*dx + dz*dz)
            
            let dy = candidatePosition.y - creature.position.y
            if abs(dy) < creature.collisionRadius + playerHeight {
                let minDist = creature.collisionRadius + playerRadius
                if hDist > 0 && hDist < minDist {
                    let overlap = minDist - hDist
                    candidatePosition.x += (dx / hDist) * overlap
                    candidatePosition.z += (dz / hDist) * overlap
                }
            }
        }
        
        position = candidatePosition
        
        // Camera orbit from input (always allow 360 rotation)
        if abs(input.lookDelta.x) > 0.1 || abs(input.lookDelta.y) > 0.1 {
            camera.rotateOrbit(deltaYaw: -input.lookDelta.x, deltaPitch: input.lookDelta.y)
        }
        
        // Camera zoom from pinch
        if abs(input.zoomDelta) > 0.01 {
            camera.zoom(delta: input.zoomDelta)
        }
    }
    
    // MARK: - Teleport
    
    func teleportTo(_ pos: SIMD3<Float>) {
        position = pos
        velocity = .zero
        isAirborne = false
        isJetpacking = false
        lastImpactVelocity = 0
    }
    
    // MARK: - Movement State
    
    var isMoving: Bool {
        length(SIMD2<Float>(velocity.x, velocity.z)) > 1.0
    }
    
    var speedNormalized: Float {
        length(SIMD2<Float>(velocity.x, velocity.z)) / (baseSpeed * sprintMultiplier)
    }
}
