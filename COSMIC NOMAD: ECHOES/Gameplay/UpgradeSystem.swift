//
//  UpgradeSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Manages persistent suit upgrades purchased with Data Cores.
//  Each upgrade has 3 tiers with increasing cost.
//

import Foundation

@MainActor
final class UpgradeSystem {
    
    static let shared = UpgradeSystem()
    
    // MARK: - Data Cores (Currency)
    
    private(set) var dataCores: Int {
        didSet { SaveManager.shared.saveDataCores(dataCores) }
    }
    
    // MARK: - Upgrade Definitions
    
    enum UpgradeType: String, CaseIterable {
        case oxygenCapacity    = "Oxygen Tank"
        case suitPowerCapacity = "Power Cell"
        case scannerRange      = "Scanner Range"
        case sprintSpeed       = "Sprint Booster"
        case jetpackFuel       = "Jetpack Fuel"
        
        var icon: String {
            switch self {
            case .oxygenCapacity:    return "lungs"
            case .suitPowerCapacity: return "bolt.batteryblock"
            case .scannerRange:      return "scope"
            case .sprintSpeed:       return "figure.run"
            case .jetpackFuel:       return "arrow.up.to.line"
            }
        }
        
        var description: String {
            switch self {
            case .oxygenCapacity:    return "Increases maximum oxygen capacity"
            case .suitPowerCapacity: return "Increases maximum suit power"
            case .scannerRange:      return "Increases signal detection range"
            case .sprintSpeed:       return "Increases sprint speed"
            case .jetpackFuel:       return "Increases jetpack duration"
            }
        }
        
        /// Cost for each tier (1, 2, 3)
        func cost(forTier tier: Int) -> Int {
            switch tier {
            case 1: return 3
            case 2: return 8
            case 3: return 15
            default: return 0
            }
        }
        
        /// The bonus value at each tier
        func bonus(forTier tier: Int) -> Float {
            switch self {
            case .oxygenCapacity:
                return [0, 25, 50, 100][min(tier, 3)]       // +25, +50, +100 max O2
            case .suitPowerCapacity:
                return [0, 25, 50, 100][min(tier, 3)]       // +25, +50, +100 max power
            case .scannerRange:
                return [0, 3, 6, 12][min(tier, 3)]          // +3m, +6m, +12m range
            case .sprintSpeed:
                return [0, 0.3, 0.6, 1.0][min(tier, 3)]    // +0.3x, +0.6x, +1.0x speed mult
            case .jetpackFuel:
                return [0, 0.2, 0.5, 1.0][min(tier, 3)]    // reduction in fuel drain
            }
        }
        
        static let maxTier = 3
    }
    
    // MARK: - Current Levels
    
    private var upgradeLevels: [UpgradeType: Int]
    
    // MARK: - Init
    
    private init() {
        self.dataCores = SaveManager.shared.getDataCores()
        self.upgradeLevels = SaveManager.shared.getUpgradeLevels()
    }
    
    // MARK: - API
    
    func currentTier(for type: UpgradeType) -> Int {
        return upgradeLevels[type] ?? 0
    }
    
    func currentBonus(for type: UpgradeType) -> Float {
        let tier = currentTier(for: type)
        return type.bonus(forTier: tier)
    }
    
    func canUpgrade(_ type: UpgradeType) -> Bool {
        let tier = currentTier(for: type)
        guard tier < UpgradeType.maxTier else { return false }
        let cost = type.cost(forTier: tier + 1)
        return dataCores >= cost
    }
    
    func isMaxed(_ type: UpgradeType) -> Bool {
        return currentTier(for: type) >= UpgradeType.maxTier
    }
    
    @discardableResult
    func purchase(_ type: UpgradeType) -> Bool {
        let tier = currentTier(for: type)
        guard tier < UpgradeType.maxTier else { return false }
        let cost = type.cost(forTier: tier + 1)
        guard dataCores >= cost else { return false }
        
        dataCores -= cost
        upgradeLevels[type] = tier + 1
        SaveManager.shared.saveUpgradeLevels(upgradeLevels)
        
        return true
    }
    
    func awardDataCores(_ amount: Int) {
        dataCores += amount
    }
    
    // MARK: - Computed Bonuses (for easy access)
    
    var oxygenCapacityBonus: Float { currentBonus(for: .oxygenCapacity) }
    var suitPowerCapacityBonus: Float { currentBonus(for: .suitPowerCapacity) }
    var scannerRangeBonus: Float { currentBonus(for: .scannerRange) }
    var sprintSpeedBonus: Float { currentBonus(for: .sprintSpeed) }
    var jetpackFuelBonus: Float { currentBonus(for: .jetpackFuel) }
    
    // MARK: - Reset
    
    func reset() {
        dataCores = 0
        upgradeLevels = [:]
        SaveManager.shared.saveDataCores(0)
        SaveManager.shared.saveUpgradeLevels([:])
    }
}
