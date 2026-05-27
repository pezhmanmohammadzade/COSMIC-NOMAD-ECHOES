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
        case .lonely:  return Color(red: 0.62, green: 0.78, blue: 0.95)  // Baby blue
        case .decayed: return Color(red: 0.96, green: 0.78, blue: 0.58)  // Warm apricot
        case .serene:  return Color(red: 0.55, green: 0.90, blue: 0.78)  // Fresh mint
        case .hostile: return Color(red: 0.95, green: 0.65, blue: 0.68)  // Strawberry pink
        case .surreal: return Color(red: 0.82, green: 0.65, blue: 0.95)  // Bubblegum lilac
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
    
    // MARK: - Engagement Colors (New Systems)
    
    /// Golden shimmer for legendary fragments
    static let legendary = Color(red: 1.0, green: 0.88, blue: 0.42)
    
    /// Electric cyan for combo streaks
    static let combo = Color(red: 0.40, green: 0.92, blue: 0.95)
    
    /// Bright blue for oxygen cache indicators
    static let oxygenCache = Color(red: 0.50, green: 0.78, blue: 0.95)
    
    /// Warm signal pulse glow
    static let signalPulse = Color(red: 0.92, green: 0.88, blue: 0.75)
    
    /// Bounty accent color
    static let bounty = Color(red: 0.88, green: 0.72, blue: 0.42)
    
    // MARK: - Planet Level Colors (Star Chart)
    
    struct PlanetColors {
        let primary: Color
        let secondary: Color
        let accent: Color
    }
    
    static func planetColors(_ mood: PlanetMood) -> PlanetColors {
        switch mood {
        case .lonely:
            // Cotton candy blue — soft, dreamy, inviting
            return PlanetColors(
                primary:   Color(red: 0.55, green: 0.72, blue: 0.92),
                secondary: Color(red: 0.35, green: 0.48, blue: 0.75),
                accent:    Color(red: 0.62, green: 0.78, blue: 0.95)
            )
        case .decayed:
            // Warm apricot — cozy, golden, friendly
            return PlanetColors(
                primary:   Color(red: 0.92, green: 0.72, blue: 0.52),
                secondary: Color(red: 0.72, green: 0.50, blue: 0.35),
                accent:    Color(red: 0.96, green: 0.78, blue: 0.58)
            )
        case .serene:
            // Fresh mint — cool, refreshing, peaceful
            return PlanetColors(
                primary:   Color(red: 0.50, green: 0.85, blue: 0.72),
                secondary: Color(red: 0.32, green: 0.62, blue: 0.55),
                accent:    Color(red: 0.55, green: 0.90, blue: 0.78)
            )
        case .hostile:
            // Strawberry coral — warm pink, playful danger
            return PlanetColors(
                primary:   Color(red: 0.92, green: 0.58, blue: 0.62),
                secondary: Color(red: 0.72, green: 0.40, blue: 0.45),
                accent:    Color(red: 0.95, green: 0.65, blue: 0.68)
            )
        case .surreal:
            // Bubblegum lilac — dreamy, playful, magical
            return PlanetColors(
                primary:   Color(red: 0.75, green: 0.58, blue: 0.90),
                secondary: Color(red: 0.52, green: 0.38, blue: 0.72),
                accent:    Color(red: 0.82, green: 0.65, blue: 0.95)
            )
        }
    }
}
