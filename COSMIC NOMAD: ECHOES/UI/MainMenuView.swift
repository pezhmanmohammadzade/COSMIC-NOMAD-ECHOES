//
//  MainMenuView.swift
//  COSMIC NOMAD: ECHOES
//
//  Home page for the game.
//

import SwiftUI

struct MainMenuView: View {
    @Binding var currentAppState: AppState
    var engine: GameEngine?
    
    @State private var hasSavedProgress: Bool = false
    @State private var showSettings: Bool = false
    @State private var showWipeConfirm: Bool = false
    @State private var showCodex: Bool = false
    @State private var showPlanets: Bool = false
    
    // UI animations
    @State private var titleOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            AnimatedStarfield()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Title
                VStack(spacing: 6) {
                    Text("COSMIC NOMAD")
                        .font(.system(size: 26, weight: .ultraLight, design: .serif))
                        .foregroundStyle(.white)
                        .tracking(10)
                    
                    Rectangle()
                        .fill(.cyan.opacity(0.4))
                        .frame(width: 60, height: 0.5)
                    
                    Text("ECHOES")
                        .font(.system(size: 15, weight: .thin, design: .serif))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(16)
                }
                .opacity(titleOpacity)
                
                Spacer()
                    .frame(maxHeight: 60)
                
                // Menu Buttons
                VStack(spacing: 14) {
                    if hasSavedProgress {
                        MenuButton(title: "RESUME JOURNEY", icon: "play.fill", color: .cyan) {
                            startGame(reset: false)
                        }
                        
                        MenuButton(title: "NEW JOURNEY", icon: "plus.circle", color: .orange) {
                            showWipeConfirm = true
                        }
                    } else {
                        MenuButton(title: "BEGIN JOURNEY", icon: "play.fill", color: .cyan) {
                            startGame(reset: true)
                        }
                    }
                    
                    MenuButton(title: "SETTINGS", icon: "gearshape", color: .white.opacity(0.6)) {
                        withAnimation { showSettings = true }
                    }
                    
                    MenuButton(title: "STAR CHART", icon: "globe.americas.fill", color: .purple.opacity(0.7)) {
                        withAnimation { showPlanets = true }
                    }
                    
                    MenuButton(title: "CODEX", icon: "book.closed.fill", color: .cyan.opacity(0.5)) {
                        withAnimation { showCodex = true }
                    }
                }
                .opacity(buttonsOpacity)
                
                Spacer()
                    .frame(maxHeight: 40)
            }
            .padding(.bottom, 20)
            
            // Settings Overlay
            if showSettings {
                SettingsOverlayView(onClose: {
                    withAnimation { showSettings = false }
                })
            }
            
            // Codex Overlay
            if showCodex {
                CodexView(onClose: {
                    withAnimation { showCodex = false }
                })
            }
            
            // Planet Levels Map (Star Chart)
            if showPlanets {
                PlanetLevelsView(
                    engine: engine,
                    appState: $currentAppState,
                    onClose: {
                        withAnimation { showPlanets = false }
                    }
                )
            }
            
            // Wipe Confirmation Overlay
            if showWipeConfirm {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("WARNING")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                    
                    Text("Starting a new journey will erase all your current progress.")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    HStack(spacing: 20) {
                        Button("CANCEL") {
                            withAnimation { showWipeConfirm = false }
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        
                        Button("ERASE") {
                            withAnimation {
                                showWipeConfirm = false
                                startGame(reset: true)
                            }
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .clipShape(Capsule())
                    }
                }
                .padding(30)
                .background(Color.black.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                .cornerRadius(16)
                .padding(40)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            checkProgress()
            
            withAnimation(.easeOut(duration: 1.5)) {
                titleOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.8)) {
                buttonsOpacity = 1.0
            }
        }
    }
    
    private func checkProgress() {
        let planetsCompleted = SaveManager.shared.getPlanetsCompleted()
        let discoveredFacts = SaveManager.shared.getDiscoveredFacts()
        // If they have completed any planet or discovered any fact, there is progress.
        hasSavedProgress = planetsCompleted > 0 || !discoveredFacts.isEmpty
    }
    
    private func startGame(reset: Bool) {
        if reset {
            engine?.resetJourney()
        }
        withAnimation {
            currentAppState = .playing
        }
    }
}

// MARK: - Menu Button
struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2)
            }
            .foregroundColor(color)
            .frame(width: 220)
            .padding(.vertical, 14)
            .background(color.opacity(0.1))
            .overlay(
                Capsule().stroke(color.opacity(0.3), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Functional Settings
struct SettingsOverlayView: View {
    let onClose: () -> Void
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("SETTINGS")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)
                    
                    // === AUDIO ===
                    SettingsSection(title: "AUDIO", icon: "speaker.wave.3.fill", color: .cyan) {
                        SettingsSlider(label: "MASTER VOLUME", value: $settings.masterVolume, color: .cyan)
                        SettingsSlider(label: "MUSIC", value: $settings.musicVolume, color: .cyan)
                        SettingsSlider(label: "SFX", value: $settings.sfxVolume, color: .cyan)
                    }
                    
                    // === CONTROLS ===
                    SettingsSection(title: "CONTROLS", icon: "hand.draw.fill", color: .orange) {
                        SettingsSlider(label: "CAMERA SENSITIVITY", value: $settings.cameraSensitivity, range: 0.2...3.0, color: .orange)
                        
                        Toggle(isOn: $settings.invertYAxis) {
                            Text("INVERT Y-AXIS")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .tint(.orange)
                        
                        Toggle(isOn: $settings.hapticsEnabled) {
                            Text("HAPTICS")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .tint(.orange)
                    }
                    
                    // === GRAPHICS ===
                    SettingsSection(title: "GRAPHICS", icon: "paintbrush.fill", color: .purple) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("QUALITY")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack(spacing: 8) {
                                ForEach(GraphicsQuality.allCases, id: \.rawValue) { quality in
                                    Button(action: { settings.graphicsQuality = quality }) {
                                        Text(quality.rawValue.uppercased())
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(settings.graphicsQuality == quality ? .black : .white.opacity(0.6))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(settings.graphicsQuality == quality ? Color.purple : Color.white.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                            
                            Text(qualityDescription)
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    
                    // === DISPLAY ===
                    SettingsSection(title: "DISPLAY", icon: "map.fill", color: .green) {
                        Toggle(isOn: $settings.showMiniMap) {
                            Text("MINI-MAP")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .tint(.green)
                    }
                    
                    Button(action: onClose) {
                        Text("CLOSE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(30)
            }
            .frame(maxWidth: 340, maxHeight: 580)
            .background(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .transition(.opacity)
    }
    
    private var qualityDescription: String {
        switch settings.graphicsQuality {
        case .low: return "Reduced shadow/AO resolution. Best for older devices."
        case .medium: return "Balanced quality and performance."
        case .high: return "Full resolution shadows and ambient occlusion."
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))
                    .tracking(2)
            }
            
            content
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Settings Slider
struct SettingsSlider: View {
    let label: String
    @Binding var value: Float
    var range: ClosedRange<Float> = 0...1
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(Int(((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            Slider(value: $value, in: range)
                .tint(color)
        }
    }
}

