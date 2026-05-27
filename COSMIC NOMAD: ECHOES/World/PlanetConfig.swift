//
//  PlanetConfig.swift
//  COSMIC NOMAD: ECHOES
//
//  Planet identity and configuration: emotional tone, atmosphere,
//  terrain parameters, color palettes, and weather tables.
//  All palettes use a pastel matte aesthetic for AAA-quality visuals.
//

import simd
import Foundation

// MARK: - Planet Emotional Tone

enum PlanetMood: String, CaseIterable {
    case lonely   // Vast emptiness, long sight lines, muted colors
    case decayed  // Overgrown ruins, warm but faded palette
    case serene   // Calm, beautiful, gentle light
    case hostile  // Harsh contrast, dangerous-feeling atmosphere
    case surreal  // Impossible geometry feel, vivid otherworldly colors
}

// MARK: - Weather Type

enum WeatherType: String, CaseIterable {
    case clear
    case foggy
    case dustStorm
    case alienRain
    case aurora
    case electricStorm
}

// MARK: - Planet Color Palette (Pastel Matte)

struct PlanetPalette {
    var skyZenith: SIMD3<Float>
    var skyHorizon: SIMD3<Float>
    var fogColor: SIMD3<Float>
    var sunColor: SIMD3<Float>
    var ambientColor: SIMD3<Float>
    var terrainTint: SIMD3<Float>
    var accentColor: SIMD3<Float>  // For glows, particles, UI hints
    
    /// Generate a mood-appropriate pastel matte palette from seed
    static func generate(mood: PlanetMood, seed: UInt64) -> PlanetPalette {
        var rng = SeededRNG(seed: seed)
        
        switch mood {
        case .lonely:
            // Dusty periwinkle — vast, quiet, soft blue-gray skies
            return PlanetPalette(
                skyZenith: SIMD3<Float>(0.10 + rng.nextFloat() * 0.04, 0.12 + rng.nextFloat() * 0.04, 0.22 + rng.nextFloat() * 0.06),
                skyHorizon: SIMD3<Float>(0.52 + rng.nextFloat() * 0.10, 0.50 + rng.nextFloat() * 0.08, 0.62 + rng.nextFloat() * 0.08),
                fogColor: SIMD3<Float>(0.55, 0.55, 0.65),
                sunColor: SIMD3<Float>(1.0, 0.95, 0.88),
                ambientColor: SIMD3<Float>(0.25, 0.26, 0.35),
                terrainTint: SIMD3<Float>(0.72, 0.70, 0.75),
                accentColor: SIMD3<Float>(0.58, 0.68, 0.88)
            )
        case .decayed:
            // Warm sand & peach — ancient, sun-bleached, soft amber
            return PlanetPalette(
                skyZenith: SIMD3<Float>(0.12 + rng.nextFloat() * 0.04, 0.10 + rng.nextFloat() * 0.03, 0.08),
                skyHorizon: SIMD3<Float>(0.72 + rng.nextFloat() * 0.10, 0.55 + rng.nextFloat() * 0.08, 0.45 + rng.nextFloat() * 0.06),
                fogColor: SIMD3<Float>(0.62, 0.55, 0.48),
                sunColor: SIMD3<Float>(1.0, 0.92, 0.78),
                ambientColor: SIMD3<Float>(0.28, 0.24, 0.20),
                terrainTint: SIMD3<Float>(0.72, 0.65, 0.55),
                accentColor: SIMD3<Float>(0.88, 0.72, 0.52)
            )
        case .serene:
            // Soft seafoam & mint — tranquil, gentle, dreamy greens
            return PlanetPalette(
                skyZenith: SIMD3<Float>(0.08, 0.14 + rng.nextFloat() * 0.06, 0.20 + rng.nextFloat() * 0.08),
                skyHorizon: SIMD3<Float>(0.58 + rng.nextFloat() * 0.10, 0.70 + rng.nextFloat() * 0.08, 0.68 + rng.nextFloat() * 0.08),
                fogColor: SIMD3<Float>(0.68, 0.75, 0.72),
                sunColor: SIMD3<Float>(1.0, 0.98, 0.95),
                ambientColor: SIMD3<Float>(0.28, 0.32, 0.30),
                terrainTint: SIMD3<Float>(0.68, 0.75, 0.68),
                accentColor: SIMD3<Float>(0.55, 0.82, 0.72)
            )
        case .hostile:
            // Dusty rose & terracotta — warm danger, soft coral glow
            return PlanetPalette(
                skyZenith: SIMD3<Float>(0.18 + rng.nextFloat() * 0.04, 0.10, 0.10),
                skyHorizon: SIMD3<Float>(0.78 + rng.nextFloat() * 0.10, 0.50 + rng.nextFloat() * 0.06, 0.45),
                fogColor: SIMD3<Float>(0.65, 0.48, 0.45),
                sunColor: SIMD3<Float>(1.0, 0.85, 0.70),
                ambientColor: SIMD3<Float>(0.30, 0.20, 0.18),
                terrainTint: SIMD3<Float>(0.72, 0.58, 0.52),
                accentColor: SIMD3<Float>(0.88, 0.60, 0.55)
            )
        case .surreal:
            // Lavender & wisteria — otherworldly, soft violet dreamscape
            return PlanetPalette(
                skyZenith: SIMD3<Float>(0.14 + rng.nextFloat() * 0.06, 0.08, 0.22 + rng.nextFloat() * 0.10),
                skyHorizon: SIMD3<Float>(0.55 + rng.nextFloat() * 0.10, 0.52 + rng.nextFloat() * 0.12, 0.70 + rng.nextFloat() * 0.10),
                fogColor: SIMD3<Float>(0.58, 0.55, 0.65),
                sunColor: SIMD3<Float>(0.95, 0.92, 1.0),
                ambientColor: SIMD3<Float>(0.24, 0.20, 0.30),
                terrainTint: SIMD3<Float>(0.65, 0.58, 0.72),
                accentColor: SIMD3<Float>(0.75, 0.55, 0.85)
            )
        }
    }
}

// MARK: - Planet Configuration

struct PlanetConfig {
    let seed: UInt64
    let name: String
    let mood: PlanetMood
    let palette: PlanetPalette
    
    // Terrain
    let terrainScale: Float        // World-space scale of terrain noise
    let terrainHeightScale: Float   // Maximum terrain height
    let terrainOctaves: Int         // FBM octaves for detail
    let terrainLacunarity: Float
    let terrainPersistence: Float
    let terrainRidgeFactor: Float   // 0=smooth, 1=ridged mountains
    let terrainWarpStrength: Float  // Domain warping for alien feel
    let terrainErosionPasses: Int   // Erosion simulation iterations
    
    // Atmosphere
    let fogDensity: Float
    let fogHeightFalloff: Float
    let atmosphereScatteringStrength: Float
    let mieDirectionality: Float
    
    // Sun
    let sunDirection: SIMD3<Float>
    let sunIntensity: Float
    
    // Weather
    let weatherProbabilities: [WeatherType: Float]
    let weatherChangeInterval: Float  // seconds between weather changes
    
    // Object density
    let objectDensity: Float  // 0-1, how many objects per chunk
    
    /// Generate a complete planet configuration from a seed
    static func generate(seed: UInt64) -> PlanetConfig {
        var rng = SeededRNG(seed: seed)
        
        let mood = PlanetMood.allCases[Int(rng.next() % UInt64(PlanetMood.allCases.count))]
        let palette = PlanetPalette.generate(mood: mood, seed: seed &+ 1000)
        
        // Generate a procedural name
        let name = PlanetNameGenerator.generate(seed: seed)
        
        // Terrain parameters vary by mood
        let (heightScale, ridgeFactor, warpStrength): (Float, Float, Float) = {
            switch mood {
            case .lonely:  return (80, 0.3, 0.3)
            case .decayed: return (40, 0.2, 0.4)
            case .serene:  return (30, 0.1, 0.2)
            case .hostile: return (100, 0.7, 0.5)
            case .surreal: return (60, 0.5, 0.8)
            }
        }()
        
        // Sun direction
        let sunAngle = rng.nextFloatRange(0.2, 1.2)
        let sunAzimuth = rng.nextFloatRange(0, .pi * 2)
        let sunDir = normalize(SIMD3<Float>(
            cos(sunAzimuth) * cos(sunAngle),
            sin(sunAngle),
            sin(sunAzimuth) * cos(sunAngle)
        ))
        
        // Weather
        var weatherProbs: [WeatherType: Float] = [:]
        switch mood {
        case .lonely:
            weatherProbs = [.clear: 0.5, .foggy: 0.3, .dustStorm: 0.1, .aurora: 0.1]
        case .decayed:
            weatherProbs = [.clear: 0.3, .foggy: 0.4, .alienRain: 0.2, .dustStorm: 0.1]
        case .serene:
            weatherProbs = [.clear: 0.6, .foggy: 0.2, .aurora: 0.2]
        case .hostile:
            weatherProbs = [.clear: 0.2, .dustStorm: 0.3, .electricStorm: 0.3, .foggy: 0.2]
        case .surreal:
            weatherProbs = [.clear: 0.3, .aurora: 0.4, .foggy: 0.2, .alienRain: 0.1]
        }
        
        return PlanetConfig(
            seed: seed,
            name: name,
            mood: mood,
            palette: palette,
            terrainScale: rng.nextFloatRange(0.005, 0.02),
            terrainHeightScale: heightScale + rng.nextFloatRange(-10, 10),
            terrainOctaves: Int(rng.nextFloatRange(5, 8)),
            terrainLacunarity: rng.nextFloatRange(1.8, 2.2),
            terrainPersistence: rng.nextFloatRange(0.4, 0.6),
            terrainRidgeFactor: ridgeFactor + rng.nextFloatRange(-0.1, 0.1),
            terrainWarpStrength: warpStrength + rng.nextFloatRange(-0.1, 0.1),
            terrainErosionPasses: Int(rng.nextFloatRange(2, 6)),
            fogDensity: rng.nextFloatRange(0.005, 0.03),
            fogHeightFalloff: rng.nextFloatRange(0.02, 0.08),
            atmosphereScatteringStrength: rng.nextFloatRange(0.5, 2.0),
            mieDirectionality: rng.nextFloatRange(0.6, 0.9),
            sunDirection: sunDir,
            sunIntensity: rng.nextFloatRange(1.0, 3.0),
            weatherProbabilities: weatherProbs,
            weatherChangeInterval: rng.nextFloatRange(60, 300),
            objectDensity: rng.nextFloatRange(0.1, 0.5)
        )
    }
    
    /// Convert planet config to atmosphere shader params
    func toAtmosphereParams() -> AtmosphereParams {
        var params = AtmosphereParams()
        params.rayleighCoefficients = SIMD3<Float>(5.5e-6, 13.0e-6, 22.4e-6) * atmosphereScatteringStrength
        params.mieCoefficient = 21e-6 * atmosphereScatteringStrength
        params.mieDirectionality = mieDirectionality
        params.fogColor = palette.fogColor
        params.fogDensityBase = fogDensity
        params.fogHeightFalloff = fogHeightFalloff
        params.fogInscatteringColor = palette.sunColor * 0.8
        params.fogInscatteringIntensity = 0.5
        params.horizonColor = palette.skyHorizon
        params.zenithColor = palette.skyZenith
        params.ambientColor = palette.ambientColor
        params.ambientIntensity = 0.3
        return params
    }
}

// MARK: - Planet Name Generator

enum PlanetNameGenerator {
    
    private static let prefixes = [
        "Aeth", "Vor", "Kel", "Nyx", "Thal", "Sor", "Zeph", "Lyr", "Mor",
        "Xen", "Dra", "Ark", "Vel", "Cyr", "Pho", "Eri", "Oth", "Qua"
    ]
    
    private static let middles = [
        "an", "or", "is", "en", "al", "ir", "os", "um", "el", "ax",
        "on", "ar", "us", "eth", "ix"
    ]
    
    private static let suffixes = [
        "ius", "ara", "ion", "oth", "yne", "ael", "rix", "phe",
        "ros", "nia", "ven", "tos", "dar", "lis", "mun"
    ]
    
    static func generate(seed: UInt64) -> String {
        var rng = SeededRNG(seed: seed &* 7919)
        
        let prefix = prefixes[Int(rng.next() % UInt64(prefixes.count))]
        let middle = middles[Int(rng.next() % UInt64(middles.count))]
        let suffix = suffixes[Int(rng.next() % UInt64(suffixes.count))]
        
        // Sometimes add a designation number
        let hasDesignation = rng.nextFloat() > 0.5
        let designation = hasDesignation ? "-\(Int(rng.next() % 999) + 1)" : ""
        
        return "\(prefix)\(middle)\(suffix)\(designation)"
    }
}
