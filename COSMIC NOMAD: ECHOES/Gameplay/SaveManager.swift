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
        defaults.removeObject(forKey: kPlanetStars)
        defaults.removeObject(forKey: kScannedCreatures)
        defaults.removeObject(forKey: kIsEndlessMode)
        defaults.removeObject(forKey: kEndlessBest)
        defaults.synchronize()
    }
    
    // MARK: - Daily Login Rewards
    
    private let kDailyLastPlayed = "cn_daily_last_played"
    private let kDailyStreak = "cn_daily_streak"
    
    func getDailyStreak() -> Int {
        return UserDefaults.standard.integer(forKey: kDailyStreak)
    }
    
    func getLastPlayedDate() -> Date? {
        return UserDefaults.standard.object(forKey: kDailyLastPlayed) as? Date
    }
    
    /// Check if a daily reward is available. Returns (isNewDay, currentStreak).
    func checkDailyReward() -> (isNewDay: Bool, streak: Int) {
        let calendar = Calendar.current
        _ = Date()
        let currentStreak = getDailyStreak()
        
        guard let lastPlayed = getLastPlayedDate() else {
            // First ever play
            return (true, 0)
        }
        
        if calendar.isDateInToday(lastPlayed) {
            // Already played today
            return (false, currentStreak)
        }
        
        if calendar.isDateInYesterday(lastPlayed) {
            // Consecutive day — streak continues
            return (true, currentStreak)
        }
        
        // Streak broken (gap of 2+ days)
        return (true, 0)
    }
    
    /// Claim the daily reward. Returns the Data Cores awarded.
    func claimDailyReward() -> Int {
        let (_, currentStreak) = checkDailyReward()
        let newStreak = (currentStreak % 7) + 1  // 1-7 cycle
        
        UserDefaults.standard.set(Date(), forKey: kDailyLastPlayed)
        UserDefaults.standard.set(newStreak, forKey: kDailyStreak)
        
        // Scaling rewards: Day 1=1, 2=2, 3=3, 4=5, 5=5, 6=7, 7=10
        let rewards = [0, 1, 2, 3, 5, 5, 7, 10]
        let reward = rewards[min(newStreak, 7)]
        
        StatisticsManager.shared.recordLoginStreak(newStreak)
        
        return reward
    }
    
    // MARK: - Planet Star Ratings
    
    private let kPlanetStars = "cn_planet_stars"
    
    func getStarRating(forPlanet level: Int) -> Int {
        guard let dict = UserDefaults.standard.dictionary(forKey: kPlanetStars) as? [String: Int] else {
            return 0
        }
        return dict["\(level)"] ?? 0
    }
    
    func saveStarRating(_ stars: Int, forPlanet level: Int) {
        var dict = (UserDefaults.standard.dictionary(forKey: kPlanetStars) as? [String: Int]) ?? [:]
        let existing = dict["\(level)"] ?? 0
        if stars > existing {
            dict["\(level)"] = stars
            UserDefaults.standard.set(dict, forKey: kPlanetStars)
        }
    }
    
    // MARK: - Scanned Creatures (Bestiary)
    
    private let kScannedCreatures = "cn_scanned_creatures"
    
    func getScannedCreatures() -> [String] {
        return UserDefaults.standard.stringArray(forKey: kScannedCreatures) ?? []
    }
    
    func addScannedCreature(_ name: String) {
        var current = getScannedCreatures()
        if !current.contains(name) {
            current.append(name)
            UserDefaults.standard.set(current, forKey: kScannedCreatures)
        }
    }
    
    // MARK: - Endless Mode
    
    private let kIsEndlessMode = "cn_is_endless"
    private let kEndlessBest = "cn_endless_best"
    
    func isEndlessMode() -> Bool {
        return UserDefaults.standard.bool(forKey: kIsEndlessMode)
    }
    
    func setEndlessMode(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: kIsEndlessMode)
    }
    
    func getEndlessBest() -> Int {
        return UserDefaults.standard.integer(forKey: kEndlessBest)
    }
    
    func saveEndlessBest(_ count: Int) {
        let current = getEndlessBest()
        if count > current {
            UserDefaults.standard.set(count, forKey: kEndlessBest)
        }
    }
    
    // MARK: - Mid-Level Save State
    
    private let kMidLevelPosX = "cn_midlevel_pos_x"
    private let kMidLevelPosY = "cn_midlevel_pos_y"
    private let kMidLevelPosZ = "cn_midlevel_pos_z"
    private let kMidLevelYaw = "cn_midlevel_yaw"
    private let kMidLevelDiscovered = "cn_midlevel_discovered"
    private let kMidLevelSeed = "cn_midlevel_seed"
    
    func saveMidLevelState(position: SIMD3<Float>, yaw: Float, discoveredFactIds: [Int], currentSeed: UInt64) {
        let defaults = UserDefaults.standard
        defaults.set(position.x, forKey: kMidLevelPosX)
        defaults.set(position.y, forKey: kMidLevelPosY)
        defaults.set(position.z, forKey: kMidLevelPosZ)
        defaults.set(yaw, forKey: kMidLevelYaw)
        defaults.set(discoveredFactIds, forKey: kMidLevelDiscovered)
        defaults.set(String(currentSeed), forKey: kMidLevelSeed)
    }
    
    func getMidLevelState() -> (position: SIMD3<Float>, yaw: Float, discoveredFactIds: [Int], seed: UInt64)? {
        let defaults = UserDefaults.standard
        guard let seedString = defaults.string(forKey: kMidLevelSeed), let seed = UInt64(seedString) else {
            return nil // No mid-level state exists
        }
        
        let x = defaults.float(forKey: kMidLevelPosX)
        let y = defaults.float(forKey: kMidLevelPosY)
        let z = defaults.float(forKey: kMidLevelPosZ)
        let yaw = defaults.float(forKey: kMidLevelYaw)
        let discoveredFactIds = defaults.array(forKey: kMidLevelDiscovered) as? [Int] ?? []
        
        return (SIMD3<Float>(x, y, z), yaw, discoveredFactIds, seed)
    }
    
    func clearMidLevelState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: kMidLevelPosX)
        defaults.removeObject(forKey: kMidLevelPosY)
        defaults.removeObject(forKey: kMidLevelPosZ)
        defaults.removeObject(forKey: kMidLevelYaw)
        defaults.removeObject(forKey: kMidLevelDiscovered)
        defaults.removeObject(forKey: kMidLevelSeed)
    }
}
