//
//  SettingsManager.swift
//  COSMIC NOMAD: ECHOES
//
//  Global manager for user preferences (Volume and Haptics)
//

import Foundation
import Combine

enum GraphicsQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var masterVolume: Float {
        didSet { UserDefaults.standard.set(masterVolume, forKey: "cn_master_volume") }
    }
    @Published var musicVolume: Float {
        didSet { UserDefaults.standard.set(musicVolume, forKey: "cn_music_volume") }
    }
    @Published var sfxVolume: Float {
        didSet { UserDefaults.standard.set(sfxVolume, forKey: "cn_sfx_volume") }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "cn_haptics") }
    }
    @Published var cameraSensitivity: Float {
        didSet { UserDefaults.standard.set(cameraSensitivity, forKey: "cn_cam_sensitivity") }
    }
    @Published var invertYAxis: Bool {
        didSet { UserDefaults.standard.set(invertYAxis, forKey: "cn_invert_y") }
    }
    @Published var graphicsQuality: GraphicsQuality {
        didSet { UserDefaults.standard.set(graphicsQuality.rawValue, forKey: "cn_graphics_quality") }
    }
    @Published var showMiniMap: Bool {
        didSet { UserDefaults.standard.set(showMiniMap, forKey: "cn_show_minimap") }
    }
    
    private init() {
        let d = UserDefaults.standard
        masterVolume = d.object(forKey: "cn_master_volume") as? Float ?? 0.8
        musicVolume = d.object(forKey: "cn_music_volume") as? Float ?? 0.7
        sfxVolume = d.object(forKey: "cn_sfx_volume") as? Float ?? 0.8
        hapticsEnabled = d.object(forKey: "cn_haptics") as? Bool ?? true
        cameraSensitivity = d.object(forKey: "cn_cam_sensitivity") as? Float ?? 1.0
        invertYAxis = d.object(forKey: "cn_invert_y") as? Bool ?? false
        showMiniMap = d.object(forKey: "cn_show_minimap") as? Bool ?? true
        if let qualStr = d.string(forKey: "cn_graphics_quality"),
           let qual = GraphicsQuality(rawValue: qualStr) {
            graphicsQuality = qual
        } else {
            graphicsQuality = .high
        }
    }
}
