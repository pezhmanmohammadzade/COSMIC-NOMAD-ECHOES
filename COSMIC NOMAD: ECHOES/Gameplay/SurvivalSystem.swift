//
//  SurvivalSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Manages player survival resources: Oxygen, Suit Power, Temperature.
//  Resources drain based on planet mood, weather, and player actions.
//

import Foundation
import simd

@MainActor
final class SurvivalSystem {
    
    // MARK: - Resources
    
    private(set) var oxygen: Float = 100.0        // 0–100
    private(set) var suitPower: Float = 100.0     // 0–100
    private(set) var temperature: Float = 25.0    // Celsius (comfort: 18–32)
    
    // Capacities (modified by upgrades)
    var maxOxygen: Float = 100.0
    var maxSuitPower: Float = 100.0
    
    // Upgrade bonuses applied from UpgradeSystem
    var jetpackFuelBonus: Float = 0    // reduces jetpack power drain
    var sprintSpeedBonus: Float = 0    // not used here, used in PlayerController
    
    // MARK: - Drain Rates (per second)
    
    private let baseOxygenDrain: Float = 0.2        // ~8 min on a serene planet
    private let basePowerRechargeRate: Float = 3.0   // recharge when idle
    private let sprintPowerDrain: Float = 1.5        // drain when sprinting
    private let jetpackPowerDrain: Float = 3.0       // drain when jetpacking
    private let scanPowerDrain: Float = 1.0          // drain when scanning
    
    // MARK: - Temperature Targets by Mood
    
    private let temperatureTargets: [PlanetMood: Float] = [
        .serene:  24.0,   // Comfortable
        .lonely:  -15.0,  // Freezing
        .decayed: 38.0,   // Warm
        .hostile: 55.0,   // Scorching
        .surreal: 10.0    // Cool
    ]
    
    // MARK: - State
    
    private(set) var isBlackedOut: Bool = false
    private var blackoutTimer: Float = 0
    private let blackoutDuration: Float = 3.0 // seconds of blackout before respawn
    
    var onBlackout: (() -> Void)?   // Callback to respawn player
    
    // Weather multipliers
    private var weatherOxygenMultiplier: Float = 1.0
    private var weatherTempOffset: Float = 0.0
    
    // MARK: - Update
    
    func update(
        deltaTime: Float,
        mood: PlanetMood,
        weatherType: WeatherType,
        weatherIntensity: Float,
        isMoving: Bool,
        isSprinting: Bool,
        isJetpacking: Bool,
        isScanning: Bool
    ) {
        guard !isBlackedOut else {
            blackoutTimer += deltaTime
            if blackoutTimer >= blackoutDuration {
                respawnFromBlackout()
            }
            return
        }
        
        // --- Weather Effects ---
        updateWeatherEffects(weatherType: weatherType, intensity: weatherIntensity)
        
        // --- Oxygen ---
        var oxygenDrain = baseOxygenDrain * weatherOxygenMultiplier
        
        // Mood multiplier
        switch mood {
        case .hostile:  oxygenDrain *= 1.5
        case .decayed:  oxygenDrain *= 1.2
        case .surreal:  oxygenDrain *= 1.05
        case .lonely:   oxygenDrain *= 1.1
        case .serene:   oxygenDrain *= 0.7
        }
        
        // Sprint increases oxygen drain slightly
        if isSprinting { oxygenDrain *= 1.2 }
        if isJetpacking { oxygenDrain *= 1.4 }
        
        // Temperature stress increases oxygen drain
        let tempStress = temperatureStress()
        oxygenDrain += tempStress * 0.5
        
        oxygen = max(0, oxygen - oxygenDrain * deltaTime)
        
        // --- Suit Power ---
        // Apply jetpack fuel upgrade bonus as drain reduction
        let jetpackDrainReduction = max(0, 1.0 - jetpackFuelBonus)
        
        if isSprinting {
            suitPower = max(0, suitPower - sprintPowerDrain * deltaTime)
        } else if isJetpacking {
            suitPower = max(0, suitPower - jetpackPowerDrain * jetpackDrainReduction * deltaTime)
        } else if isScanning {
            suitPower = max(0, suitPower - scanPowerDrain * deltaTime)
        } else {
            // Passive recharge when not using power
            suitPower = min(maxSuitPower, suitPower + basePowerRechargeRate * deltaTime)
        }
        
        // --- Temperature ---
        let targetTemp = (temperatureTargets[mood] ?? 24.0) + weatherTempOffset
        // Temperature drifts toward target
        temperature = Interpolation.expDecay(
            current: temperature,
            target: targetTemp,
            rate: 0.3,
            deltaTime: deltaTime
        )
        
        // --- Blackout Check ---
        if oxygen <= 0 {
            triggerBlackout()
        }
    }
    
    // MARK: - Weather Effects
    
    private func updateWeatherEffects(weatherType: WeatherType, intensity: Float) {
        switch weatherType {
        case .clear:
            weatherOxygenMultiplier = 1.0
            weatherTempOffset = 0
        case .foggy:
            weatherOxygenMultiplier = 1.1
            weatherTempOffset = -3
        case .dustStorm:
            weatherOxygenMultiplier = 1.6
            weatherTempOffset = 8
        case .alienRain:
            weatherOxygenMultiplier = 1.2
            weatherTempOffset = -5
        case .aurora:
            weatherOxygenMultiplier = 0.9
            weatherTempOffset = -2
        case .electricStorm:
            weatherOxygenMultiplier = 1.4
            weatherTempOffset = 5
        }
    }
    
    // MARK: - Temperature Stress
    
    /// Returns 0 when comfortable, up to 1.0 when extreme
    func temperatureStress() -> Float {
        if temperature < 18 {
            return min(1.0, (18 - temperature) / 40.0)
        } else if temperature > 32 {
            return min(1.0, (temperature - 32) / 30.0)
        }
        return 0
    }
    
    /// Temperature classification for UI display
    var temperatureState: TemperatureState {
        if temperature < 5 { return .freezing }
        if temperature < 18 { return .cold }
        if temperature <= 32 { return .comfortable }
        if temperature <= 45 { return .hot }
        return .scorching
    }
    
    // MARK: - Blackout
    
    private func triggerBlackout() {
        isBlackedOut = true
        blackoutTimer = 0
    }
    
    private func respawnFromBlackout() {
        isBlackedOut = false
        oxygen = maxOxygen * 0.5
        suitPower = maxSuitPower * 0.3
        temperature = 25.0
        onBlackout?()
    }
    
    // MARK: - Refills
    
    /// Called when player finds an oxygen vent near a signal
    func refillOxygen(amount: Float) {
        oxygen = min(maxOxygen, oxygen + amount)
    }
    
    /// Called when player finds a power cell
    func refillPower(amount: Float) {
        suitPower = min(maxSuitPower, suitPower + amount)
    }
    
    /// Applied by HazardSystem when player is in a hazard zone
    func applyHazardDamage(oxygenDrain: Float, powerDrain: Float, healthDamage: Float) {
        oxygen = max(0, oxygen - oxygenDrain)
        suitPower = max(0, suitPower - powerDrain)
        // Health damage reduces oxygen (no separate health bar)
        oxygen = max(0, oxygen - healthDamage)
    }
    
    // MARK: - Reset
    
    func reset() {
        oxygen = maxOxygen
        suitPower = maxSuitPower
        temperature = 25.0
        isBlackedOut = false
        blackoutTimer = 0
    }
}

// MARK: - Temperature State

enum TemperatureState: String {
    case freezing = "FREEZING"
    case cold = "COLD"
    case comfortable = "NORMAL"
    case hot = "HOT"
    case scorching = "SCORCHING"
    
    var color: String {
        switch self {
        case .freezing:    return "blue"
        case .cold:        return "cyan"
        case .comfortable: return "green"
        case .hot:         return "orange"
        case .scorching:   return "red"
        }
    }
}
