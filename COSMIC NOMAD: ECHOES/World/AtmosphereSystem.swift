//
//  AtmosphereSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Per-planet atmosphere: sky color evolution, fog management,
//  atmosphere uniform updates, drives shader parameters.
//

import simd
import Foundation

@MainActor
final class AtmosphereSystem {
    
    let planetConfig: PlanetConfig
    
    // Current atmosphere state
    private(set) var currentParams: AtmosphereParams
    
    // Time-of-day simulation
    private var timeOfDay: Float = 0.5  // 0 = midnight, 0.5 = noon, 1 = midnight
    private var dayDuration: Float = 600  // 10 minutes per day cycle
    
    // Sun position evolves over time
    private var baseSunDirection: SIMD3<Float>
    
    init(planetConfig: PlanetConfig) {
        self.planetConfig = planetConfig
        self.baseSunDirection = planetConfig.sunDirection
        self.currentParams = planetConfig.toAtmosphereParams()
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float, totalTime: Float, weatherVisibility: Float) {
        // Evolve time of day
        timeOfDay += deltaTime / dayDuration
        if timeOfDay > 1.0 { timeOfDay -= 1.0 }
        
        // Update sun direction based on time of day
        let sunAngle = (timeOfDay - 0.25) * .pi * 2  // Peak at noon (timeOfDay = 0.5)
        let sunElevation = sin(sunAngle)
        let sunAzimuth = atan2(baseSunDirection.z, baseSunDirection.x)
        
        let sunDir = normalize(SIMD3<Float>(
            cos(sunAzimuth) * cos(max(sunElevation * 0.8, -0.1)),
            max(sunElevation, 0.05),  // Keep sun slightly above horizon minimum
            sin(sunAzimuth) * cos(max(sunElevation * 0.8, -0.1))
        ))
        
        // Sky color evolves with sun position
        let sunHeight = max(sunDir.y, 0)
        let dawnDusk = 1.0 - abs(timeOfDay - 0.5) * 4.0  // Peaks at dawn/dusk
        let dawnDuskFactor = max(dawnDusk, 0.0)
        
        // Zenith darkens toward night
        let nightFactor = max(1.0 - sunHeight * 3.0, 0.0)
        var zenith = planetConfig.palette.skyZenith
        zenith = simd_mix(zenith, zenith * 0.05, SIMD3<Float>(repeating: nightFactor))
        
        // Horizon warms at dawn/dusk
        var horizon = planetConfig.palette.skyHorizon
        let warmShift = SIMD3<Float>(0.2, -0.05, -0.15) * dawnDuskFactor
        horizon = simd_clamp(horizon + warmShift, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
        
        // Ambient dims at night
        var ambient = planetConfig.palette.ambientColor
        ambient *= (0.1 + sunHeight * 0.9)
        
        // Update params
        currentParams.horizonColor = horizon
        currentParams.zenithColor = zenith
        currentParams.ambientColor = ambient
        currentParams.ambientIntensity = 0.1 + sunHeight * 0.4
        
        // Fog changes with time
        let fogTimeMod: Float = 1.0 + sin(totalTime * 0.05) * 0.3
        currentParams.fogDensityBase = planetConfig.fogDensity * fogTimeMod
        
        // Apply weather visibility
        currentParams.weatherVisibility = weatherVisibility
    }
    
    // MARK: - Sun
    
    var sunDirection: SIMD3<Float> {
        let sunAngle = (timeOfDay - 0.25) * .pi * 2
        let sunElevation = sin(sunAngle)
        let sunAzimuth = atan2(baseSunDirection.z, baseSunDirection.x)
        
        return normalize(SIMD3<Float>(
            cos(sunAzimuth) * cos(max(sunElevation * 0.8, -0.1)),
            max(sunElevation, 0.05),
            sin(sunAzimuth) * cos(max(sunElevation * 0.8, -0.1))
        ))
    }
    
    var sunColor: SIMD3<Float> {
        let sunHeight = max(sunDirection.y, 0)
        // Redden sun near horizon
        let reddening = 1.0 - sunHeight
        return simd_mix(
            planetConfig.palette.sunColor,
            SIMD3<Float>(1.0, 0.4, 0.1),
            SIMD3<Float>(repeating: reddening * reddening * 0.6)
        )
    }
    
    var sunIntensity: Float {
        let sunHeight = max(sunDirection.y, 0)
        return planetConfig.sunIntensity * (0.1 + sunHeight * 0.9)
    }
}
