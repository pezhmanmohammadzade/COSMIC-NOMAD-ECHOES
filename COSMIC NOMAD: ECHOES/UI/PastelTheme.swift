//
//  PastelTheme.swift
//  COSMIC NOMAD: ECHOES
//
//  Centralized pastel matte color theme — AAA-grade design tokens.
//  Every UI view references these tokens for a cohesive, modern feel.
//

import SwiftUI

// MARK: - Pastel Theme Namespace

enum Pastel {
    
    // MARK: - Backgrounds
    
    /// Deep matte background — warm dark navy, never pure black
    static let bg = Color(red: 0.06, green: 0.06, blue: 0.10)
    
    /// Slightly elevated surface (cards, panels)
    static let surface = Color(red: 0.10, green: 0.10, blue: 0.15)
    
    /// Overlay backdrop (modal sheets)
    static let overlay = Color(red: 0.04, green: 0.04, blue: 0.08)
    
    /// Subtle card fill
    static let cardFill = Color.white.opacity(0.04)
    
    /// Subtle border
    static let cardStroke = Color.white.opacity(0.08)
    
    // MARK: - Primary Accent  (replaces cyan)
    
    /// Soft periwinkle blue — primary interactive color
    static let primary = Color(red: 0.65, green: 0.74, blue: 0.92)
    
    // MARK: - Secondary Accent  (replaces orange)
    
    /// Warm peach — secondary accent, objectives, signals
    static let secondary = Color(red: 0.92, green: 0.72, blue: 0.62)
    
    // MARK: - Tertiary Accent  (replaces purple)
    
    /// Soft lavender — special actions, surreal theme
    static let tertiary = Color(red: 0.74, green: 0.64, blue: 0.86)
    
    // MARK: - Danger  (replaces red)
    
    /// Dusty rose — warnings, hazards
    static let danger = Color(red: 0.85, green: 0.52, blue: 0.56)
    
    // MARK: - Success  (replaces green)
    
    /// Sage green — completion, safe states
    static let success = Color(red: 0.60, green: 0.80, blue: 0.66)
    
    // MARK: - Currency / Highlight  (replaces yellow)
    
    /// Soft butter gold — data cores, currency
    static let gold = Color(red: 0.92, green: 0.85, blue: 0.62)
    
    // MARK: - Text Colors
    
    /// Primary text — warm off-white
    static let textPrimary = Color(red: 0.92, green: 0.90, blue: 0.88)
    
    /// Secondary text
    static let textSecondary = Color.white.opacity(0.55)
    
    /// Muted text
    static let textMuted = Color.white.opacity(0.35)
    
    // MARK: - Mood-Specific Colors (for PlanetDecoded, PlanetLevels, etc.)
    
    static func moodColor(_ mood: PlanetMood) -> Color {
        switch mood {
        case .lonely:  return Color(red: 0.58, green: 0.68, blue: 0.88)
        case .decayed: return Color(red: 0.88, green: 0.72, blue: 0.52)
        case .serene:  return Color(red: 0.55, green: 0.82, blue: 0.72)
        case .hostile: return Color(red: 0.88, green: 0.58, blue: 0.55)
        case .surreal: return Color(red: 0.75, green: 0.55, blue: 0.85)
        }
    }
    
    // MARK: - Temperature Colors (HUD)
    
    static let tempFreezing = Color(red: 0.55, green: 0.68, blue: 0.88)
    static let tempCold     = Color(red: 0.62, green: 0.75, blue: 0.88)
    static let tempComfort  = Color(red: 0.60, green: 0.80, blue: 0.66)
    static let tempHot      = Color(red: 0.92, green: 0.72, blue: 0.55)
    static let tempScorch   = Color(red: 0.88, green: 0.55, blue: 0.52)
    
    // MARK: - Hazard Colors (HUD)
    
    static let hazardToxic     = Color(red: 0.60, green: 0.80, blue: 0.58)
    static let hazardRadiation = Color(red: 0.92, green: 0.85, blue: 0.55)
    static let hazardLava      = Color(red: 0.88, green: 0.55, blue: 0.52)
    static let hazardUnstable  = Color(red: 0.92, green: 0.72, blue: 0.55)
    
    // MARK: - Planet Level Colors (Star Chart)
    
    struct PlanetColors {
        let primary: Color
        let secondary: Color
        let accent: Color
    }
    
    static func planetColors(_ mood: PlanetMood) -> PlanetColors {
        switch mood {
        case .lonely:
            return PlanetColors(
                primary:   Color(red: 0.42, green: 0.48, blue: 0.65),
                secondary: Color(red: 0.22, green: 0.25, blue: 0.42),
                accent:    Color(red: 0.58, green: 0.68, blue: 0.88)
            )
        case .decayed:
            return PlanetColors(
                primary:   Color(red: 0.62, green: 0.52, blue: 0.40),
                secondary: Color(red: 0.40, green: 0.32, blue: 0.25),
                accent:    Color(red: 0.88, green: 0.72, blue: 0.52)
            )
        case .serene:
            return PlanetColors(
                primary:   Color(red: 0.45, green: 0.60, blue: 0.58),
                secondary: Color(red: 0.28, green: 0.40, blue: 0.38),
                accent:    Color(red: 0.55, green: 0.82, blue: 0.72)
            )
        case .hostile:
            return PlanetColors(
                primary:   Color(red: 0.68, green: 0.48, blue: 0.45),
                secondary: Color(red: 0.48, green: 0.30, blue: 0.28),
                accent:    Color(red: 0.88, green: 0.58, blue: 0.55)
            )
        case .surreal:
            return PlanetColors(
                primary:   Color(red: 0.52, green: 0.38, blue: 0.62),
                secondary: Color(red: 0.32, green: 0.22, blue: 0.45),
                accent:    Color(red: 0.75, green: 0.55, blue: 0.85)
            )
        }
    }
}
