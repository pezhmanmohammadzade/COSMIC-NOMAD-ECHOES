//
//  StatisticsManager.swift
//  COSMIC NOMAD: ECHOES
//
//  Persistent lifetime statistics tracker.
//  Tracks all player activity for the Statistics screen.
//

import Foundation

@MainActor
final class StatisticsManager {
    
    static let shared = StatisticsManager()
    
    // MARK: - Stat Keys
    
    private let kStats = "cn_statistics"
    
    // MARK: - In-Memory Counters (synced to disk periodically)
    
    private(set) var totalDistanceWalked: Float = 0
    private(set) var totalFragmentsDiscovered: Int = 0
    private(set) var totalLegendaryFragments: Int = 0
    private(set) var totalCreaturesScanned: Int = 0
    private(set) var totalDataCoresEarned: Int = 0
    private(set) var totalPlayTimeSeconds: Float = 0
    private(set) var totalBlackouts: Int = 0
    private(set) var totalHazardZonesSurvived: Int = 0
    private(set) var totalCombosAchieved: Int = 0
    private(set) var bestComboMultiplier: Int = 0
    private(set) var totalPlanetsCompleted: Int = 0
    private(set) var totalBountiesCompleted: Int = 0
    private(set) var totalOxygenCachesCollected: Int = 0
    private(set) var highestStarRating: Int = 0  // Best star rating on any planet
    private(set) var endlessBestPlanets: Int = 0  // Furthest in endless mode
    private(set) var longestLoginStreak: Int = 0
    
    // Transient per-frame tracking
    private var lastPosition: SIMD3<Float>?
    private var saveTimer: Float = 0
    private let saveInterval: Float = 10.0  // Save every 10 seconds
    
    // MARK: - Init
    
    private init() {
        load()
    }
    
    // MARK: - Per-Frame Update
    
    func update(playerPosition: SIMD3<Float>, deltaTime: Float) {
        // Track distance
        if let last = lastPosition {
            let dx = playerPosition.x - last.x
            let dz = playerPosition.z - last.z
            let dist = sqrt(dx * dx + dz * dz)
            if dist < 50 { // Ignore teleports
                totalDistanceWalked += dist
            }
        }
        lastPosition = playerPosition
        
        // Track time
        totalPlayTimeSeconds += deltaTime
        
        // Periodic save
        saveTimer += deltaTime
        if saveTimer >= saveInterval {
            saveTimer = 0
            save()
        }
    }
    
    // MARK: - Event Tracking
    
    func recordFragmentDiscovered(isLegendary: Bool) {
        totalFragmentsDiscovered += 1
        if isLegendary {
            totalLegendaryFragments += 1
        }
    }
    
    func recordCreatureScanned() {
        totalCreaturesScanned += 1
    }
    
    func recordDataCoresEarned(_ amount: Int) {
        totalDataCoresEarned += amount
    }
    
    func recordBlackout() {
        totalBlackouts += 1
    }
    
    func recordHazardZoneSurvived() {
        totalHazardZonesSurvived += 1
    }
    
    func recordCombo(multiplier: Int) {
        totalCombosAchieved += 1
        if multiplier > bestComboMultiplier {
            bestComboMultiplier = multiplier
        }
    }
    
    func recordPlanetCompleted() {
        totalPlanetsCompleted += 1
    }
    
    func recordBountyCompleted() {
        totalBountiesCompleted += 1
    }
    
    func recordOxygenCacheCollected() {
        totalOxygenCachesCollected += 1
    }
    
    func recordStarRating(_ stars: Int) {
        if stars > highestStarRating {
            highestStarRating = stars
        }
    }
    
    func recordEndlessPlanets(_ count: Int) {
        if count > endlessBestPlanets {
            endlessBestPlanets = count
        }
    }
    
    func recordLoginStreak(_ streak: Int) {
        if streak > longestLoginStreak {
            longestLoginStreak = streak
        }
    }
    
    // MARK: - Formatted Strings
    
    var formattedDistance: String {
        if totalDistanceWalked > 1000 {
            return String(format: "%.1f km", totalDistanceWalked / 1000.0)
        }
        return "\(Int(totalDistanceWalked))m"
    }
    
    var formattedPlayTime: String {
        let hours = Int(totalPlayTimeSeconds) / 3600
        let minutes = (Int(totalPlayTimeSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    // MARK: - Persistence
    
    func save() {
        let dict: [String: Any] = [
            "distanceWalked": totalDistanceWalked,
            "fragmentsDiscovered": totalFragmentsDiscovered,
            "legendaryFragments": totalLegendaryFragments,
            "creaturesScanned": totalCreaturesScanned,
            "dataCoresEarned": totalDataCoresEarned,
            "playTimeSeconds": totalPlayTimeSeconds,
            "blackouts": totalBlackouts,
            "hazardZonesSurvived": totalHazardZonesSurvived,
            "combosAchieved": totalCombosAchieved,
            "bestComboMultiplier": bestComboMultiplier,
            "planetsCompleted": totalPlanetsCompleted,
            "bountiesCompleted": totalBountiesCompleted,
            "oxygenCachesCollected": totalOxygenCachesCollected,
            "highestStarRating": highestStarRating,
            "endlessBestPlanets": endlessBestPlanets,
            "longestLoginStreak": longestLoginStreak,
        ]
        UserDefaults.standard.set(dict, forKey: kStats)
    }
    
    private func load() {
        guard let dict = UserDefaults.standard.dictionary(forKey: kStats) else { return }
        totalDistanceWalked = dict["distanceWalked"] as? Float ?? 0
        totalFragmentsDiscovered = dict["fragmentsDiscovered"] as? Int ?? 0
        totalLegendaryFragments = dict["legendaryFragments"] as? Int ?? 0
        totalCreaturesScanned = dict["creaturesScanned"] as? Int ?? 0
        totalDataCoresEarned = dict["dataCoresEarned"] as? Int ?? 0
        totalPlayTimeSeconds = dict["playTimeSeconds"] as? Float ?? 0
        totalBlackouts = dict["blackouts"] as? Int ?? 0
        totalHazardZonesSurvived = dict["hazardZonesSurvived"] as? Int ?? 0
        totalCombosAchieved = dict["combosAchieved"] as? Int ?? 0
        bestComboMultiplier = dict["bestComboMultiplier"] as? Int ?? 0
        totalPlanetsCompleted = dict["planetsCompleted"] as? Int ?? 0
        totalBountiesCompleted = dict["bountiesCompleted"] as? Int ?? 0
        totalOxygenCachesCollected = dict["oxygenCachesCollected"] as? Int ?? 0
        highestStarRating = dict["highestStarRating"] as? Int ?? 0
        endlessBestPlanets = dict["endlessBestPlanets"] as? Int ?? 0
        longestLoginStreak = dict["longestLoginStreak"] as? Int ?? 0
    }
    
    func reset() {
        totalDistanceWalked = 0
        totalFragmentsDiscovered = 0
        totalLegendaryFragments = 0
        totalCreaturesScanned = 0
        totalDataCoresEarned = 0
        totalPlayTimeSeconds = 0
        totalBlackouts = 0
        totalHazardZonesSurvived = 0
        totalCombosAchieved = 0
        bestComboMultiplier = 0
        totalPlanetsCompleted = 0
        totalBountiesCompleted = 0
        totalOxygenCachesCollected = 0
        highestStarRating = 0
        endlessBestPlanets = 0
        longestLoginStreak = 0
        lastPosition = nil
        save()
    }
}

// MARK: - SIMD3 import for distance calc
import simd
