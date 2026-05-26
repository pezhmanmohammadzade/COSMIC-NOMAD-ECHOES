//
//  WeatherSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Dynamic weather state machine: manages weather transitions,
//  affects visibility, lighting, audio, and mood.
//

import simd
import Foundation

@MainActor
final class WeatherSystem {
    
    let planetConfig: PlanetConfig
    
    // Current state
    private(set) var currentWeather: WeatherType = .clear
    private(set) var nextWeather: WeatherType = .clear
    private(set) var transitionProgress: Float = 1.0  // 0 = current, 1 = fully transitioned
    
    // Timing
    private var timeSinceLastChange: Float = 0
    private var currentInterval: Float = 120
    private var transitionDuration: Float = 30  // seconds to transition between weather states
    
    // Weather effects
    private(set) var visibility: Float = 1.0      // 0 = zero visibility, 1 = clear
    private(set) var fogMultiplier: Float = 1.0
    private(set) var lightMultiplier: Float = 1.0
    private(set) var windStrength: Float = 0.0
    
    // RNG
    private var rng: SeededRNG
    
    init(planetConfig: PlanetConfig) {
        self.planetConfig = planetConfig
        self.rng = SeededRNG(seed: planetConfig.seed &+ 777)
        self.currentInterval = planetConfig.weatherChangeInterval
        
        // Start with the most probable weather
        currentWeather = selectWeather()
        nextWeather = currentWeather
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        timeSinceLastChange += deltaTime
        
        if transitionProgress < 1.0 {
            // Transitioning between weather states
            transitionProgress += deltaTime / transitionDuration
            
            if transitionProgress >= 1.0 {
                transitionProgress = 1.0
                currentWeather = nextWeather
            }
        } else if timeSinceLastChange >= currentInterval {
            // Time for a new weather state
            timeSinceLastChange = 0
            currentInterval = planetConfig.weatherChangeInterval + rng.nextFloatRange(-30, 30)
            
            let newWeather = selectWeather()
            if newWeather != currentWeather {
                nextWeather = newWeather
                transitionProgress = 0
                transitionDuration = rng.nextFloatRange(15, 45)
            }
        }
        
        // Interpolate weather effects
        let currentEffects = weatherEffects(for: currentWeather)
        let nextEffects = weatherEffects(for: nextWeather)
        let t = Interpolation.smootherstep(0, 1, transitionProgress)
        
        visibility = currentEffects.visibility * (1 - t) + nextEffects.visibility * t
        fogMultiplier = currentEffects.fogMult * (1 - t) + nextEffects.fogMult * t
        lightMultiplier = currentEffects.lightMult * (1 - t) + nextEffects.lightMult * t
        windStrength = currentEffects.wind * (1 - t) + nextEffects.wind * t
    }
    
    // MARK: - Weather Selection
    
    private func selectWeather() -> WeatherType {
        let roll = rng.nextFloat()
        var cumulative: Float = 0
        
        for (weather, probability) in planetConfig.weatherProbabilities {
            cumulative += probability
            if roll <= cumulative {
                return weather
            }
        }
        
        return .clear
    }
    
    // MARK: - Weather Effects
    
    private struct WeatherEffects {
        var visibility: Float
        var fogMult: Float
        var lightMult: Float
        var wind: Float
    }
    
    private func weatherEffects(for weather: WeatherType) -> WeatherEffects {
        switch weather {
        case .clear:
            return WeatherEffects(visibility: 1.0, fogMult: 1.0, lightMult: 1.0, wind: 0.1)
        case .foggy:
            return WeatherEffects(visibility: 0.3, fogMult: 5.0, lightMult: 0.6, wind: 0.05)
        case .dustStorm:
            return WeatherEffects(visibility: 0.15, fogMult: 8.0, lightMult: 0.4, wind: 0.9)
        case .alienRain:
            return WeatherEffects(visibility: 0.6, fogMult: 2.5, lightMult: 0.5, wind: 0.4)
        case .aurora:
            return WeatherEffects(visibility: 0.9, fogMult: 1.2, lightMult: 0.8, wind: 0.15)
        case .electricStorm:
            return WeatherEffects(visibility: 0.4, fogMult: 3.0, lightMult: 0.3, wind: 0.7)
        }
    }
    
    // MARK: - Query
    
    var isTransitioning: Bool {
        transitionProgress < 1.0
    }
    
    var weatherDescription: String {
        if isTransitioning {
            let pct = Int(transitionProgress * 100)
            return "\(currentWeather.rawValue) → \(nextWeather.rawValue) (\(pct)%)"
        }
        return currentWeather.rawValue
    }
}
