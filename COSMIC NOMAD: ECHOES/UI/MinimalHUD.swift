//
//  MinimalHUD.swift
//  COSMIC NOMAD: ECHOES
//
//  Transparent overlay HUD: minimal, atmospheric, no quest markers.
//  Scanner ring, memory fragments, discovery notifications.
//  Pastel matte color scheme.
//

import SwiftUI
import Combine

// MARK: - Minimal HUD

struct MinimalHUD: View {
    
    let engine: GameEngine?
    @Binding var appState: AppState
    
    @State private var scanProgress: Float = 0
    @State private var discoveryText: String = ""
    @State private var discoveryTitle: String = ""
    @State private var discoveryType: String = ""
    @State private var showDiscovery: Bool = false
    @State private var showDebugOverlay: Bool = false
    @State private var showAchievements: Bool = false
    @State private var showPlanetDecoded: Bool = false
    @State private var showFinalRevelation: Bool = false
    @State private var showUpgradeShop: Bool = false
    @State private var showBlackout: Bool = false
    @State private var showJetpackPicker: Bool = false
    @State private var selectedJetpackHeight: Float = 20.0
    
    // Survival HUD state (updated from timer)
    @State private var oxygen: Float = 100
    @State private var suitPower: Float = 100
    @State private var temperature: Float = 25
    @State private var temperatureState: TemperatureState = .comfortable
    @State private var dataCores: Int = 0
    @State private var isJetpacking: Bool = false
    
    @State private var joystickActive: Bool = false
    @State private var joystickOffset: CGPoint = .zero
    @State private var lastStepTime: Double = 0.0
    private let stepGenerator = UIImpactFeedbackGenerator(style: .light)
    private let discoveryGenerator = UINotificationFeedbackGenerator()
    
    let timer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // --- Hazard Zone Warning ---
            if let engine = engine, let warning = engine.hazardSystem.warningText {
                let hazardColor: Color = {
                    switch engine.hazardSystem.activeHazardType {
                    case .toxic: return Pastel.hazardToxic
                    case .radiation: return Pastel.hazardRadiation
                    case .lava: return Pastel.hazardLava
                    case .unstable: return Pastel.hazardUnstable
                    case .none: return .clear
                    }
                }()
                
                RoundedRectangle(cornerRadius: 0)
                    .stroke(hazardColor.opacity(Double(engine.hazardSystem.activeIntensity) * 0.35), lineWidth: 8)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                // Warning text at top
                VStack {
                    Text(warning)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(hazardColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Pastel.surface.opacity(0.85))
                        .cornerRadius(6)
                        .padding(.top, 100)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            
            // --- Scanner Ring (center of screen) ---
            if let engine = engine, engine.scanner.isScanning {
                ScannerRingView(progress: engine.scanner.scanProgress)
                    .frame(width: 120, height: 120)
                    .allowsHitTesting(false)
            }
            
            // --- Signal Discovery Popup (center screen) ---
            if showDiscovery {
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        // Header
                        ZStack {
                            HStack(spacing: 6) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(Pastel.primary)
                                
                                Text("SIGNAL ACQUIRED")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Pastel.primary)
                            }
                            
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation(.easeIn(duration: 0.3)) {
                                        showDiscovery = false
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Pastel.textSecondary)
                                }
                            }
                        }
                        
                        // Type badge
                        Text(discoveryType.uppercased())
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(Pastel.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Pastel.secondary.opacity(0.12))
                            .clipShape(Capsule())
                        
                        // Divider
                        Rectangle()
                            .fill(Pastel.primary.opacity(0.2))
                            .frame(height: 0.5)
                            .padding(.horizontal, 12)
                        
                        // Lore text
                        Text(discoveryText)
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .foregroundColor(Pastel.textPrimary.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 10)
                        
                        // Remaining count
                        if let engine = engine {
                            let remaining = engine.world.memoryFragmentSystem.fragments.count - engine.world.memoryFragmentSystem.discoveredCount
                            Text("\(remaining) signals remaining")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundColor(Pastel.textMuted)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Pastel.surface.opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Pastel.primary.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .frame(maxWidth: 260)
                    .padding(.horizontal, 50)
                    .padding(.bottom, 100)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            
            // --- Planet Info + Objective (top left) ---
            VStack {
                HStack(alignment: .top) {
                    if let engine = engine {
                        HStack(alignment: .top, spacing: 16) {
                            // Quit Game Button (Top Left)
                            Button(action: {
                                withAnimation {
                                    appState = .mainMenu
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Pastel.surface.opacity(0.7))
                                        .frame(width: 40, height: 40)
                                    Circle()
                                        .stroke(Pastel.danger.opacity(0.5), lineWidth: 1)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "door.left.hand.open")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Pastel.danger)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                Text(engine.world.planetConfig.name)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Pastel.textPrimary.opacity(0.8))
                                
                                Text("PLANET \(engine.planetsCompleted + 1)/\(GameEngine.totalPlanetsForEnding)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Pastel.primary.opacity(0.6))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Pastel.primary.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            
                            Text(engine.world.planetConfig.mood.rawValue.uppercased())
                                .font(.system(size: 9, weight: .light, design: .monospaced))
                                .foregroundStyle(Pastel.textMuted)
                            
                            // Objective
                            HStack(spacing: 4) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Pastel.secondary)
                                
                                let remaining = engine.world.memoryFragmentSystem.fragments.count - engine.world.memoryFragmentSystem.discoveredCount
                                Text("SIGNALS: \(remaining) remaining")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Pastel.secondary.opacity(0.9))
                            }
                            .padding(.top, 4)
                            
                            // Nearest signal direction hint
                            if let nearest = nearestFragment(engine: engine) {
                                let dist = distance2D(engine.player.position, nearest.worldPosition)
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Pastel.primary.opacity(0.6))
                                        .rotationEffect(.degrees(bearingTo(from: engine.player, to: nearest.worldPosition)))
                                    
                                    Text("\(Int(dist))m to nearest signal")
                                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                                        .foregroundStyle(Pastel.primary.opacity(0.5))
                                }
                            }
                        }
                        }
                        .padding(.top, 60)
                        .padding(.leading, 20)
                    }
                    
                    Spacer()
                    
                    // Top right: Survival bars + data cores
                    VStack(alignment: .trailing, spacing: 8) {
                        // Data Cores
                        HStack(spacing: 4) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Pastel.gold)
                            Text("\(dataCores)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Pastel.gold)
                        }
                        
                        // Oxygen bar
                        SurvivalBarView(label: "O₂", value: oxygen, maxValue: engine?.survivalSystem.maxOxygen ?? 100, color: Pastel.primary, icon: "lungs")
                        
                        // Suit Power bar
                        SurvivalBarView(label: "PWR", value: suitPower, maxValue: engine?.survivalSystem.maxSuitPower ?? 100, color: Pastel.gold, icon: "bolt.fill")
                        
                        // Temperature
                        HStack(spacing: 4) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 10))
                                .foregroundColor(temperatureColor)
                            Text("\(Int(temperature))°")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(temperatureColor)
                            Text(temperatureState.rawValue)
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundColor(temperatureColor.opacity(0.7))
                        }
                        
                        // Achievements button
                        Button(action: { showAchievements = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 12))
                                Text("LOG")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(Pastel.secondary.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Pastel.secondary.opacity(0.10))
                            .clipShape(Capsule())
                        }
                        
                        if showDebugOverlay, let engine = engine {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(engine.fps) FPS")
                                    .foregroundStyle(engine.fps >= 55 ? Pastel.success.opacity(0.6) : Pastel.danger.opacity(0.6))
                                Text("Chunks: \(engine.world.readyChunks.count)")
                                    .foregroundStyle(Pastel.textMuted)
                                Text("Weather: \(engine.world.weatherSystem.weatherDescription)")
                                    .foregroundStyle(Pastel.textMuted)
                            }
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                        }
                        
                        // Mini-Map
                        if SettingsManager.shared.showMiniMap, let engine = engine {
                            MiniMapView(
                                playerPosition: engine.player.position,
                                playerYaw: engine.player.yaw,
                                signals: engine.world.memoryFragmentSystem.fragments
                            )
                        }
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 16)
                }
                
                Spacer()
                
                // --- Bottom controls ---
                HStack(alignment: .bottom) {
                    // Virtual joystick (always visible)
                    ZStack {
                        // Outer ring — always show
                        Circle()
                            .stroke(Pastel.textPrimary.opacity(0.18), lineWidth: 1.5)
                            .frame(width: 110, height: 110)
                        
                        // Crosshair lines
                        Path { path in
                            path.move(to: CGPoint(x: 55, y: 25))
                            path.addLine(to: CGPoint(x: 55, y: 85))
                            path.move(to: CGPoint(x: 25, y: 55))
                            path.addLine(to: CGPoint(x: 85, y: 55))
                        }
                        .stroke(Pastel.textPrimary.opacity(0.06), lineWidth: 0.5)
                        .frame(width: 110, height: 110)
                        
                        // Inner thumbstick
                        Circle()
                            .fill(Pastel.textPrimary.opacity(joystickActive ? 0.3 : 0.10))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Pastel.primary.opacity(joystickActive ? 0.5 : 0.0), lineWidth: 1.5)
                            )
                            .offset(x: CGFloat(joystickOffset.x * 50.0), y: CGFloat(joystickOffset.y * 50.0))
                    }
                    .padding(.leading, 30)
                    .padding(.bottom, 30)
                    
                    Spacer()
                    
                    // Action buttons (right side)
                    VStack(spacing: 12) {
                        // Jetpack button
                        Button(action: {
                            let newVal = !(engine?.player.isJetpacking ?? false)
                            engine?.inputManager.setJetpack(newVal)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(isJetpacking ? Pastel.primary.opacity(0.25) : Pastel.surface.opacity(0.5))
                                    .frame(width: 54, height: 54)
                                Circle()
                                    .stroke(isJetpacking ? Pastel.primary : Pastel.textPrimary.opacity(0.2), lineWidth: isJetpacking ? 2 : 1)
                                    .frame(width: 54, height: 54)
                                VStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(isJetpacking ? Pastel.primary : Pastel.textSecondary)
                                    Text("JET")
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundStyle(isJetpacking ? Pastel.primary : Pastel.textMuted)
                                }
                            }
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.3)) {
                                        showJetpackPicker = true
                                    }
                                }
                        )
                        
                        // Jetpack height indicator
                        Text("\(Int(selectedJetpackHeight))m")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Pastel.primary.opacity(0.5))
                        
                        // Upgrade Shop
                        Button(action: { showUpgradeShop = true }) {
                            ZStack {
                                Circle()
                                    .fill(Pastel.surface.opacity(0.5))
                                    .frame(width: 48, height: 48)
                                Circle()
                                    .stroke(Pastel.gold.opacity(0.4), lineWidth: 1)
                                    .frame(width: 48, height: 48)
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Pastel.gold.opacity(0.7))
                            }
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 30)
                }
            }
            
            // Achievements Overlay
            if showAchievements {
                AchievementsView(onClose: {
                    showAchievements = false
                })
            }
            
            // === PLANET DECODED SCREEN ===
            if showPlanetDecoded, let engine = engine {
                PlanetDecodedView(
                    planetName: engine.world.planetConfig.name,
                    planetMood: engine.world.planetConfig.mood,
                    planetsCompleted: engine.planetsCompleted + 1,
                    totalPlanets: GameEngine.totalPlanetsForEnding,
                    onContinue: {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showPlanetDecoded = false
                        }
                        engine.advanceToNextPlanet()
                    }
                )
                .transition(.opacity)
            }
            
            // === FINAL REVELATION SCREEN ===
            if showFinalRevelation {
                FinalRevelationView(onRestart: {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showFinalRevelation = false
                    }
                    engine?.resetJourney()
                })
                .transition(.opacity)
            }
            // Upgrade Shop Overlay
            if showUpgradeShop {
                UpgradeShopView(onClose: {
                    withAnimation { showUpgradeShop = false }
                    dataCores = UpgradeSystem.shared.dataCores
                    // Apply purchased upgrades immediately
                    engine?.applySurvivalUpgrades()
                })
            }
            
            // === BLACKOUT OVERLAY ===
            if showBlackout {
                ZStack {
                    Pastel.bg.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Pastel.danger)
                        Text("SUIT FAILURE")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(Pastel.danger)
                            .tracking(6)
                        Text("EMERGENCY RESPAWN")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Pastel.textSecondary)
                    }
                }
                .transition(.opacity)
            }
            
            // === JETPACK HEIGHT PICKER ===
            if showJetpackPicker {
                ZStack {
                    Pastel.overlay.opacity(0.85).ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                showJetpackPicker = false
                            }
                        }
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Pastel.primary)
                            Text("JETPACK ALTITUDE")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(Pastel.textPrimary)
                                .tracking(3)
                        }
                        
                        Text("Select flight height")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(Pastel.textSecondary)
                        
                        HStack(spacing: 16) {
                            jetpackHeightButton(height: 20, label: "20m", subtitle: "Low")
                            jetpackHeightButton(height: 30, label: "30m", subtitle: "Mid")
                            jetpackHeightButton(height: 50, label: "50m", subtitle: "High")
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Pastel.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Pastel.primary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            guard let engine = engine else { return }
            let state = engine.inputManager.state
            if state.moveStrength > 0.01 {
                joystickActive = true
                joystickOffset = CGPoint(x: CGFloat(state.moveDirection.x * state.moveStrength),
                                         y: CGFloat(state.moveDirection.y * state.moveStrength))
                
                // Walking haptics (trigger every ~0.4s based on movement speed)
                let time = CACurrentMediaTime()
                if time - lastStepTime > 0.4 / Double(state.moveStrength) {
                    if SettingsManager.shared.hapticsEnabled {
                        stepGenerator.impactOccurred(intensity: CGFloat(state.moveStrength * 0.5))
                    }
                    lastStepTime = time
                }
            } else {
                joystickActive = false
                joystickOffset = .zero
            }
            
            // Check for new signal discoveries
            if let frag = engine.lastDiscoveredFragment {
                discoveryType = frag.fragmentType.rawValue
                discoveryTitle = frag.title
                discoveryText = frag.content
                engine.clearLastDiscovery()
                
                // Haptic feedback
                if SettingsManager.shared.hapticsEnabled {
                    discoveryGenerator.notificationOccurred(.success)
                }
                
                // Show popup with animation
                withAnimation(.easeOut(duration: 0.4)) {
                    showDiscovery = true
                }
                
                // Auto-hide after 12 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
                    withAnimation(.easeIn(duration: 0.6)) {
                        showDiscovery = false
                    }
                }
            }
            
            // Check for planet decoded event
            if engine.isPlanetDecoded && !showPlanetDecoded && !showDiscovery {
                withAnimation(.easeOut(duration: 0.8)) {
                    showPlanetDecoded = true
                }
            }
            
            // Check for final revelation
            if engine.showFinalRevelation && !showFinalRevelation {
                withAnimation(.easeOut(duration: 1.0)) {
                    showFinalRevelation = true
                }
            }
            
            // --- Sync survival state ---
            oxygen = engine.survivalSystem.oxygen
            suitPower = engine.survivalSystem.suitPower
            temperature = engine.survivalSystem.temperature
            temperatureState = engine.survivalSystem.temperatureState
            dataCores = UpgradeSystem.shared.dataCores
            isJetpacking = engine.player.isJetpacking
            
            // Blackout handling
            if engine.survivalSystem.isBlackedOut && !showBlackout {
                withAnimation(.easeIn(duration: 0.5)) { showBlackout = true }
            } else if !engine.survivalSystem.isBlackedOut && showBlackout {
                withAnimation(.easeOut(duration: 1.0)) { showBlackout = false }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func nearestFragment(engine: GameEngine) -> MemoryFragment? {
        let playerPos = engine.player.position
        return engine.world.memoryFragmentSystem.fragments
            .filter { !$0.isDiscovered }
            .min(by: { distance2D($0.worldPosition, playerPos) < distance2D($1.worldPosition, playerPos) })
    }
    
    private func distance2D(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let dx = a.x - b.x
        let dz = a.z - b.z
        return sqrt(dx * dx + dz * dz)
    }
    
    private func bearingTo(from player: PlayerController, to target: SIMD3<Float>) -> Double {
        let dx = Double(target.x - player.position.x)
        let dz = Double(target.z - player.position.z)
        let worldAngle = atan2(dx, dz) * 180 / .pi
        let playerAngle = atan2(Double(player.forward.x), Double(player.forward.z)) * 180 / .pi
        return worldAngle - playerAngle
    }
    
    private var temperatureColor: Color {
        switch temperatureState {
        case .freezing:    return Pastel.tempFreezing
        case .cold:        return Pastel.tempCold
        case .comfortable: return Pastel.tempComfort
        case .hot:         return Pastel.tempHot
        case .scorching:   return Pastel.tempScorch
        }
    }
    
    // MARK: - Jetpack Height Button
    
    private func jetpackHeightButton(height: Float, label: String, subtitle: String) -> some View {
        let isSelected = selectedJetpackHeight == height
        
        return Button(action: {
            selectedJetpackHeight = height
            engine?.player.jetpackAltitude = height
            
            withAnimation(.spring(response: 0.3)) {
                showJetpackPicker = false
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Pastel.primary.opacity(0.25) : Pastel.cardFill)
                        .frame(width: 60, height: 60)
                    Circle()
                        .stroke(isSelected ? Pastel.primary : Pastel.cardStroke, lineWidth: isSelected ? 2 : 1)
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? Pastel.primary : Pastel.textSecondary)
                        Text(label)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? Pastel.primary : Pastel.textSecondary)
                    }
                }
                
                Text(subtitle.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? Pastel.primary.opacity(0.8) : Pastel.textMuted)
            }
        }
    }
}

// MARK: - Survival Bar View

struct SurvivalBarView: View {
    let label: String
    let value: Float
    let maxValue: Float
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.8))
                .frame(width: 12)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Pastel.cardFill)
                    .frame(width: 80, height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(barGradient)
                    .frame(width: max(0, CGFloat(value / maxValue) * 80), height: 6)
                    .animation(.easeOut(duration: 0.3), value: value)
            }
            
            Text("\(Int(value))")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(value / maxValue < 0.25 ? 1.0 : 0.7))
                .frame(width: 24, alignment: .trailing)
        }
    }
    
    private var barGradient: LinearGradient {
        let ratio = value / maxValue
        if ratio < 0.25 {
            return LinearGradient(colors: [Pastel.danger, color.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [color.opacity(0.5), color], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Scanner Ring View

struct ScannerRingView: View {
    let progress: Float
    
    // Haptics
    @State private var lastHapticProgress: Float = 0.0
    private let impactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let completeGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        ZStack {
            let rotationAngle = Double(progress) * 45.0
            
            Circle()
                .stroke(Pastel.textPrimary.opacity(0.08), lineWidth: 1.5)
                .rotation3DEffect(.degrees(rotationAngle), axis: (x: 1, y: 0.5, z: 0))
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(
                        colors: [
                            Pastel.primary.opacity(0.3),
                            Pastel.primary.opacity(0.7),
                            Pastel.textPrimary.opacity(0.8)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2 + CGFloat(progress * 2.0), lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .rotation3DEffect(.degrees(rotationAngle), axis: (x: 1, y: 0.5, z: 0))
            
            if progress > 0.5 {
                Circle()
                    .stroke(Pastel.primary.opacity(0.3), lineWidth: 1)
                    .frame(width: 80 - CGFloat((progress - 0.5) * 40))
                    .opacity(Double(1.0 - progress))
            }
            
            Circle()
                .fill(Pastel.textPrimary.opacity(Double(progress) * 0.7))
                .frame(width: 4 + CGFloat(progress * 4.0), height: 4 + CGFloat(progress * 4.0))
                .shadow(color: Pastel.primary.opacity(0.6), radius: CGFloat(progress * 8.0))
            
            if progress > 0.1 {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Pastel.textPrimary.opacity(Double(progress) * 0.8))
                    .shadow(color: Pastel.primary.opacity(0.4), radius: 4)
                    .offset(y: 24)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: progress)
        .onChange(of: progress) { oldValue, newValue in
            if newValue > lastHapticProgress + 0.1 {
                if SettingsManager.shared.hapticsEnabled {
                    impactGenerator.impactOccurred(intensity: CGFloat(newValue))
                }
                lastHapticProgress = newValue
            }
            
            if newValue >= 1.0 && lastHapticProgress < 1.0 {
                if SettingsManager.shared.hapticsEnabled {
                    completeGenerator.notificationOccurred(.success)
                }
                lastHapticProgress = 1.0
            }
            
            if newValue == 0.0 {
                lastHapticProgress = 0.0
            }
        }
    }
}
