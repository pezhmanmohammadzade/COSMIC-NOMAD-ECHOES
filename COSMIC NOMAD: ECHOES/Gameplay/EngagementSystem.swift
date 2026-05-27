//
//  EngagementSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Central engagement hub: combo/streak system, signal strength indicator,
//  oxygen caches, rare fragments, ambient events, and fragment teasers.
//  These are the "one more turn" hooks that make the game addictive.
//

import simd
import Foundation

// MARK: - Combo System

enum ComboTier: Int {
    case none = 0
    case x2 = 2
    case x3 = 3
    case x5 = 5
    
    var displayText: String {
        switch self {
        case .none: return ""
        case .x2: return "SIGNAL CHAIN ×2"
        case .x3: return "SIGNAL CHAIN ×3"
        case .x5: return "SIGNAL CHAIN ×5"
        }
    }
}

// MARK: - Oxygen Cache

struct OxygenCache {
    let position: SIMD3<Float>
    var isCollected: Bool = false
    let oxygenAmount: Float  // How much O₂ to refill
}

// MARK: - Ambient Event

enum AmbientEventType: String {
    case shootingStar = "☄️ Shooting star spotted!"
    case creatureRoar = "🔊 Distant creature roar echoes..."
    case groundTremor = "🌋 Ground tremor detected nearby"
    case lightPillar  = "✨ Mysterious light pillar appears"
}

struct AmbientEvent {
    let type: AmbientEventType
    let timestamp: Float
}

// MARK: - Engagement System

@MainActor
final class EngagementSystem {
    
    // MARK: - Combo Streak
    
    private(set) var currentComboTier: ComboTier = .none
    private(set) var comboTimer: Float = 0         // Time remaining for next combo
    private(set) var comboWindowActive: Bool = false
    private(set) var lastComboText: String = ""
    private(set) var comboJustTriggered: Bool = false  // One-frame flag for HUD
    
    private let comboWindow_x2: Float = 60.0  // seconds
    private let comboWindow_x3: Float = 30.0
    private let comboWindow_x5: Float = 15.0
    
    private var timeSinceLastDiscovery: Float = 999
    
    // MARK: - Signal Strength
    
    /// 0.0 = no signal, 1.0 = very close. Used by HUD for pulse rate.
    private(set) var signalStrength: Float = 0
    private(set) var nearestFragmentDistance: Float = 999
    
    // MARK: - Fragment Teaser
    
    /// Cryptic preview of nearby fragment title (within 25m)
    private(set) var fragmentTeaser: String? = nil
    
    // MARK: - Oxygen Caches
    
    private(set) var oxygenCaches: [OxygenCache] = []
    private(set) var lastCollectedCacheIndex: Int? = nil  // One-frame flag
    private let cacheCollectionRadius: Float = 3.5
    
    // MARK: - Ambient Events
    
    private(set) var currentAmbientEvent: AmbientEvent? = nil
    private var ambientEventTimer: Float = 0
    private var nextEventInterval: Float = 120  // seconds
    private var ambientEventDisplayTimer: Float = 0
    private let ambientEventDisplayDuration: Float = 4.0
    
    // MARK: - Legendary Tracking
    
    private(set) var lastDiscoveryWasLegendary: Bool = false
    
    // MARK: - Generation
    
    func generate(seed: UInt64, playerPosition: SIMD3<Float>, level: Int) {
        var rng = SeededRNG(seed: seed &+ 55555)
        
        // Reset combo
        currentComboTier = .none
        comboTimer = 0
        comboWindowActive = false
        timeSinceLastDiscovery = 999
        lastDiscoveryWasLegendary = false
        
        // Generate oxygen caches (6-10 per planet)
        oxygenCaches.removeAll()
        let cacheCount = 6 + Int(rng.nextFloatRange(0, 5))
        for _ in 0..<cacheCount {
            let angle = rng.nextFloatRange(0, .pi * 2)
            let dist = rng.nextFloatRange(25, 200)
            let pos = SIMD3<Float>(
                playerPosition.x + cos(angle) * dist,
                0,  // Will be at terrain height
                playerPosition.z + sin(angle) * dist
            )
            let amount = rng.nextFloatRange(20, 35)
            oxygenCaches.append(OxygenCache(position: pos, oxygenAmount: amount))
        }
        
        // Reset ambient events
        ambientEventTimer = 0
        nextEventInterval = rng.nextFloatRange(60, 180)
        currentAmbientEvent = nil
    }
    
    // MARK: - Update (called every frame)
    
    func update(
        deltaTime: Float,
        playerPosition: SIMD3<Float>,
        fragments: [MemoryFragment],
        totalTime: Float
    ) {
        // --- Combo Timer ---
        timeSinceLastDiscovery += deltaTime
        comboJustTriggered = false
        
        if comboWindowActive {
            comboTimer -= deltaTime
            if comboTimer <= 0 {
                comboWindowActive = false
                currentComboTier = .none
            }
        }
        
        // --- Signal Strength ---
        updateSignalStrength(playerPosition: playerPosition, fragments: fragments)
        
        // --- Fragment Teaser ---
        updateFragmentTeaser(playerPosition: playerPosition, fragments: fragments)
        
        // --- Oxygen Cache Proximity ---
        lastCollectedCacheIndex = nil
        // (Actual collection handled by GameEngine which has access to SurvivalSystem)
        
        // --- Ambient Events ---
        updateAmbientEvents(deltaTime: deltaTime, totalTime: totalTime)
    }
    
    // MARK: - Fragment Discovery Callback
    
    /// Called when player discovers a fragment. Returns bonus multiplier for Data Cores.
    func onFragmentDiscovered(isLegendary: Bool) -> Int {
        lastDiscoveryWasLegendary = isLegendary
        
        let elapsed = timeSinceLastDiscovery
        timeSinceLastDiscovery = 0
        
        // Determine combo tier based on time since last discovery
        let newTier: ComboTier
        if elapsed <= comboWindow_x5 {
            newTier = .x5
        } else if elapsed <= comboWindow_x3 {
            newTier = .x3
        } else if elapsed <= comboWindow_x2 {
            newTier = .x2
        } else {
            newTier = .none
        }
        
        if newTier != .none {
            currentComboTier = newTier
            lastComboText = newTier.displayText
            comboJustTriggered = true
            StatisticsManager.shared.recordCombo(multiplier: newTier.rawValue)
        } else {
            currentComboTier = .none
        }
        
        // Start combo window for next discovery
        comboWindowActive = true
        comboTimer = comboWindow_x2  // Max window
        
        // Calculate base + legendary + combo multiplier
        let baseReward = isLegendary ? 5 : 1
        let comboMultiplier = max(1, currentComboTier.rawValue)
        
        return baseReward * comboMultiplier
    }
    
    // MARK: - Oxygen Cache Collection
    
    /// Check proximity to oxygen caches and return the amount to refill (if any).
    func checkOxygenCaches(playerPosition: SIMD3<Float>) -> Float {
        for i in 0..<oxygenCaches.count {
            guard !oxygenCaches[i].isCollected else { continue }
            
            let dx = oxygenCaches[i].position.x - playerPosition.x
            let dz = oxygenCaches[i].position.z - playerPosition.z
            let dist = sqrt(dx * dx + dz * dz)
            
            if dist < cacheCollectionRadius {
                oxygenCaches[i].isCollected = true
                lastCollectedCacheIndex = i
                StatisticsManager.shared.recordOxygenCacheCollected()
                return oxygenCaches[i].oxygenAmount
            }
        }
        return 0
    }
    
    // MARK: - Signal Strength
    
    private func updateSignalStrength(playerPosition: SIMD3<Float>, fragments: [MemoryFragment]) {
        var minDist: Float = 999
        
        for frag in fragments where !frag.isDiscovered {
            let dx = frag.worldPosition.x - playerPosition.x
            let dz = frag.worldPosition.z - playerPosition.z
            let dist = sqrt(dx * dx + dz * dz)
            if dist < minDist {
                minDist = dist
            }
        }
        
        nearestFragmentDistance = minDist
        
        // Signal strength: 1.0 at 8m (discovery radius), 0.0 at 100m+
        let maxDetectionRange: Float = 100.0
        if minDist < maxDetectionRange {
            signalStrength = 1.0 - (minDist / maxDetectionRange)
            signalStrength = signalStrength * signalStrength  // Quadratic curve for dramatic close-range spike
        } else {
            signalStrength = 0
        }
    }
    
    // MARK: - Fragment Teaser
    
    private let teaserRange: Float = 25.0
    
    private func updateFragmentTeaser(playerPosition: SIMD3<Float>, fragments: [MemoryFragment]) {
        var nearest: MemoryFragment? = nil
        var minDist: Float = teaserRange
        
        for frag in fragments where !frag.isDiscovered {
            let dx = frag.worldPosition.x - playerPosition.x
            let dz = frag.worldPosition.z - playerPosition.z
            let dist = sqrt(dx * dx + dz * dz)
            if dist < minDist {
                minDist = dist
                nearest = frag
            }
        }
        
        if let frag = nearest {
            // Create cryptic teaser from title
            let words = frag.title.split(separator: " ")
            if words.count >= 2 {
                // Show 1-2 words with ellipsis
                _ = words[words.count / 2]
                fragmentTeaser = "...\\(teaserWord.lowercased())..."
            } else {
                fragmentTeaser = "...signal..."
            }
        } else {
            fragmentTeaser = nil
        }
    }
    
    // MARK: - Ambient Events
    
    private func updateAmbientEvents(deltaTime: Float, totalTime: Float) {
        // Tick display timer
        if currentAmbientEvent != nil {
            ambientEventDisplayTimer += deltaTime
            if ambientEventDisplayTimer >= ambientEventDisplayDuration {
                currentAmbientEvent = nil
            }
        }
        
        // Tick event spawn timer
        ambientEventTimer += deltaTime
        if ambientEventTimer >= nextEventInterval {
            ambientEventTimer = 0
            nextEventInterval = Float.random(in: 90...240)
            
            // Pick a random event
            let events: [AmbientEventType] = [.shootingStar, .creatureRoar, .groundTremor, .lightPillar]
            let event = events[Int.random(in: 0..<events.count)]
            currentAmbientEvent = AmbientEvent(type: event, timestamp: totalTime)
            ambientEventDisplayTimer = 0
        }
    }
    
    // MARK: - Nearest Oxygen Cache for HUD
    
    func nearestUncollectedCacheDistance(from playerPosition: SIMD3<Float>) -> Float? {
        var minDist: Float = 30.0  // Only show within 30m
        var found = false
        
        for cache in oxygenCaches where !cache.isCollected {
            let dx = cache.position.x - playerPosition.x
            let dz = cache.position.z - playerPosition.z
            let dist = sqrt(dx * dx + dz * dz)
            if dist < minDist {
                minDist = dist
                found = true
            }
        }
        
        return found ? minDist : nil
    }
}
