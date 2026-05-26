//
//  SaveManager.swift
//  COSMIC NOMAD: ECHOES
//
//  Manages game persistence using UserDefaults.
//

import Foundation

final class SaveManager {
    static let shared = SaveManager()
    
    private let kPlanetsCompleted = "cn_planets_completed"
    private let kDiscoveredFacts = "cn_discovered_facts"
    private let kPlanetSeed = "cn_current_planet_seed"
    private let kDataCores = "cn_data_cores"
    private let kUpgradeLevels = "cn_upgrade_levels"
    private let kCodexFragments = "cn_codex_fragments"
    private let kPlanetSeedHistory = "cn_planet_seed_history"
    
    private init() {}
    
    // MARK: - Planets
    
    func getPlanetsCompleted() -> Int {
        return UserDefaults.standard.integer(forKey: kPlanetsCompleted)
    }
    
    func savePlanetsCompleted(_ count: Int) {
        UserDefaults.standard.set(count, forKey: kPlanetsCompleted)
    }
    
    func getPlanetSeed() -> UInt64 {
        if let seedString = UserDefaults.standard.string(forKey: kPlanetSeed), let seed = UInt64(seedString) {
            return seed
        }
        return 42
    }
    
    func savePlanetSeed(_ seed: UInt64) {
        UserDefaults.standard.set(String(seed), forKey: kPlanetSeed)
    }
    
    // MARK: - Planet Seed History (for Star Chart navigation)
    
    /// Returns the game seed for each completed planet level (0-indexed)
    func getPlanetSeedHistory() -> [String] {
        return UserDefaults.standard.stringArray(forKey: kPlanetSeedHistory) ?? []
    }
    
    /// Save the seed used for a planet at a specific level (0-indexed)
    func savePlanetSeedForLevel(_ level: Int, seed: UInt64) {
        var history = getPlanetSeedHistory()
        let seedStr = String(seed)
        // Ensure array is large enough
        while history.count <= level {
            history.append("")
        }
        history[level] = seedStr
        UserDefaults.standard.set(history, forKey: kPlanetSeedHistory)
    }
    
    /// Get the game seed for a given planet level, or nil if not unlocked
    func getSeedForPlanetLevel(_ level: Int) -> UInt64? {
        let history = getPlanetSeedHistory()
        guard level < history.count, !history[level].isEmpty else { return nil }
        return UInt64(history[level])
    }
    
    // MARK: - Facts
    
    func getDiscoveredFacts() -> [Int] {
        return UserDefaults.standard.array(forKey: kDiscoveredFacts) as? [Int] ?? []
    }
    
    func addDiscoveredFact(id: Int) {
        var current = getDiscoveredFacts()
        if !current.contains(id) {
            current.append(id)
            UserDefaults.standard.set(current, forKey: kDiscoveredFacts)
        }
    }
    
    // MARK: - Data Cores (Currency)
    
    func getDataCores() -> Int {
        return UserDefaults.standard.integer(forKey: kDataCores)
    }
    
    func saveDataCores(_ count: Int) {
        UserDefaults.standard.set(count, forKey: kDataCores)
    }
    
    // MARK: - Upgrade Levels
    
    func getUpgradeLevels() -> [UpgradeSystem.UpgradeType: Int] {
        guard let dict = UserDefaults.standard.dictionary(forKey: kUpgradeLevels) as? [String: Int] else {
            return [:]
        }
        var result: [UpgradeSystem.UpgradeType: Int] = [:]
        for (key, value) in dict {
            if let type = UpgradeSystem.UpgradeType(rawValue: key) {
                result[type] = value
            }
        }
        return result
    }
    
    func saveUpgradeLevels(_ levels: [UpgradeSystem.UpgradeType: Int]) {
        var dict: [String: Int] = [:]
        for (key, value) in levels {
            dict[key.rawValue] = value
        }
        UserDefaults.standard.set(dict, forKey: kUpgradeLevels)
    }
    
    // MARK: - Codex (discovered fragments across all planets)
    
    func getCodexFragments() -> [[String: String]] {
        return UserDefaults.standard.array(forKey: kCodexFragments) as? [[String: String]] ?? []
    }
    
    func addCodexFragment(planetName: String, title: String, content: String, type: String) {
        var current = getCodexFragments()
        // Avoid duplicates by title
        if !current.contains(where: { $0["title"] == title && $0["planet"] == planetName }) {
            current.append([
                "planet": planetName,
                "title": title,
                "content": content,
                "type": type
            ])
            UserDefaults.standard.set(current, forKey: kCodexFragments)
        }
    }
    
    // MARK: - Reset
    
    func resetProgress() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: kPlanetsCompleted)
        defaults.removeObject(forKey: kDiscoveredFacts)
        defaults.removeObject(forKey: kPlanetSeed)
        defaults.removeObject(forKey: kDataCores)
        defaults.removeObject(forKey: kUpgradeLevels)
        defaults.removeObject(forKey: kCodexFragments)
        defaults.removeObject(forKey: kPlanetSeedHistory)
        defaults.synchronize()
    }
}

