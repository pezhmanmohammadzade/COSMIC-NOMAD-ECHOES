//
//  BountySystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Planet-specific challenges that reward bonus Data Cores.
//  Each planet mood generates unique bounties for variety.
//

import Foundation
import simd

// MARK: - Bounty Definition

enum BountyType: String {
    case noBlackout       = "Iron Suit"
    case speedRun         = "Speed Decoder"
    case hazardDiscovery  = "Danger Seeker"
    case creatureScan     = "Xenobiologist"
    case marathonWalk     = "Long March"
    case comboMaster      = "Chain Lightning"
    
    var icon: String {
        switch self {
        case .noBlackout:      return "shield.checkered"
        case .speedRun:        return "timer"
        case .hazardDiscovery: return "flame.fill"
        case .creatureScan:    return "eye.fill"
        case .marathonWalk:    return "figure.walk"
        case .comboMaster:     return "bolt.horizontal.fill"
        }
    }
    
    var description: String {
        switch self {
        case .noBlackout:      return "Complete planet without a blackout"
        case .speedRun:        return "Decode all signals within the time limit"
        case .hazardDiscovery: return "Discover fragments while in hazard zones"
        case .creatureScan:    return "Scan the required number of creatures"
        case .marathonWalk:    return "Walk the required distance on this planet"
        case .comboMaster:     return "Achieve signal chain combos"
        }
    }
}

struct Bounty: Identifiable {
    let id = UUID()
    let type: BountyType
    let targetValue: Int       // Target to reach
    var currentValue: Int = 0  // Current progress
    let reward: Int            // Data Cores reward
    var isCompleted: Bool = false
    
    var progress: Float {
        guard targetValue > 0 else { return 0 }
        return min(1.0, Float(currentValue) / Float(targetValue))
    }
    
    var progressText: String {
        switch type {
        case .noBlackout:
            return isCompleted ? "✓ No blackouts!" : "0 blackouts so far"
        case .speedRun:
            return "\(currentValue)/\(targetValue) signals"
        case .hazardDiscovery:
            return "\(currentValue)/\(targetValue) in hazard"
        case .creatureScan:
            return "\(currentValue)/\(targetValue) scanned"
        case .marathonWalk:
            return "\(currentValue)/\(targetValue)m walked"
        case .comboMaster:
            return "\(currentValue)/\(targetValue) combos"
        }
    }
}

// MARK: - Bounty System

@MainActor
final class BountySystem {
    
    private(set) var activeBounties: [Bounty] = []
    private(set) var completedBountyNames: [String] = []
    
    // Tracking state
    private var hasBlackedOut: Bool = false
    private var distanceOnPlanet: Float = 0
    private var lastPosition: SIMD3<Float>?
    
    // MARK: - Generation
    
    func generate(mood: PlanetMood, level: Int, seed: UInt64) {
        var rng = SeededRNG(seed: seed &+ 33333)
        activeBounties.removeAll()
        completedBountyNames.removeAll()
        hasBlackedOut = false
        distanceOnPlanet = 0
        lastPosition = nil
        
        // Each planet gets 2 bounties based on mood
        let bountyPool: [(BountyType, Int, Int)]  // (type, target, reward)
        
        switch mood {
        case .hostile:
            bountyPool = [
                (.noBlackout, 1, 10),
                (.hazardDiscovery, 3, 8),
                (.comboMaster, 2, 7),
            ]
        case .decayed:
            bountyPool = [
                (.hazardDiscovery, 2, 6),
                (.marathonWalk, 500, 5),
                (.creatureScan, 3, 6),
            ]
        case .serene:
            bountyPool = [
                (.creatureScan, 5, 6),
                (.comboMaster, 3, 7),
                (.marathonWalk, 400, 5),
            ]
        case .lonely:
            bountyPool = [
                (.marathonWalk, 600, 5),
                (.noBlackout, 1, 8),
                (.speedRun, 10, 7),
            ]
        case .surreal:
            bountyPool = [
                (.comboMaster, 3, 7),
                (.creatureScan, 4, 6),
                (.speedRun, 8, 8),
            ]
        }
        
        // Pick 2 unique bounties
        var indices = Array(0..<bountyPool.count)
        let count = min(2, indices.count)
        for _ in 0..<count {
            let idx = Int(rng.next() % UInt64(indices.count))
            let picked = bountyPool[indices[idx]]
            activeBounties.append(Bounty(
                type: picked.0,
                targetValue: picked.1,
                reward: picked.2
            ))
            indices.remove(at: idx)
        }
    }
    
    // MARK: - Update
    
    func update(
        deltaTime: Float,
        playerPosition: SIMD3<Float>,
        fragmentsDiscovered: Int,
        creaturesScanned: Int,
        combosAchieved: Int,
        isInHazardZone: Bool,
        hazardFragmentsFound: Int
    ) {
        // Track distance
        if let last = lastPosition {
            let dx = playerPosition.x - last.x
            let dz = playerPosition.z - last.z
            let dist = sqrt(dx * dx + dz * dz)
            if dist < 50 { distanceOnPlanet += dist }
        }
        lastPosition = playerPosition
        
        // Update each bounty
        for i in 0..<activeBounties.count {
            guard !activeBounties[i].isCompleted else { continue }
            
            switch activeBounties[i].type {
            case .noBlackout:
                // Completed when planet is decoded AND no blackouts occurred
                activeBounties[i].currentValue = hasBlackedOut ? 0 : 1
                // This one is checked at planet completion
                
            case .speedRun:
                activeBounties[i].currentValue = fragmentsDiscovered
                
            case .hazardDiscovery:
                activeBounties[i].currentValue = hazardFragmentsFound
                
            case .creatureScan:
                activeBounties[i].currentValue = creaturesScanned
                
            case .marathonWalk:
                activeBounties[i].currentValue = Int(distanceOnPlanet)
                
            case .comboMaster:
                activeBounties[i].currentValue = combosAchieved
            }
            
            // Check completion (except noBlackout which is checked at end)
            if activeBounties[i].type != .noBlackout {
                if activeBounties[i].currentValue >= activeBounties[i].targetValue {
                    activeBounties[i].isCompleted = true
                    completedBountyNames.append(activeBounties[i].type.rawValue)
                }
            }
        }
    }
    
    // MARK: - Event Callbacks
    
    func onBlackout() {
        hasBlackedOut = true
    }
    
    /// Called when planet is fully decoded. Returns total bounty rewards to award.
    func onPlanetCompleted() -> Int {
        var totalReward = 0
        
        // Check noBlackout bounty
        for i in 0..<activeBounties.count {
            if activeBounties[i].type == .noBlackout && !hasBlackedOut && !activeBounties[i].isCompleted {
                activeBounties[i].isCompleted = true
                completedBountyNames.append(activeBounties[i].type.rawValue)
            }
            
            if activeBounties[i].isCompleted {
                totalReward += activeBounties[i].reward
                StatisticsManager.shared.recordBountyCompleted()
            }
        }
        
        return totalReward
    }
    
    // MARK: - Accessors
    
    var hasActiveBounties: Bool { !activeBounties.isEmpty }
    
    var anyCompleted: Bool { activeBounties.contains { $0.isCompleted } }
}
