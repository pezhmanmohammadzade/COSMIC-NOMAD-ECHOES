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
    
    // Engagement HUD state
    @State private var signalStrength: Float = 0
    @State private var comboText: String = ""
    @State private var showCombo: Bool = false
    @State private var fragmentTeaser: String? = nil
    @State private var showCreatureScan: Bool = false
    @State private var creatureScanName: String = ""
    @State private var creatureScanReward: Int = 0
    @State private var ambientEventText: String? = nil
    @State private var showAmbientEvent: Bool = false
    @State private var lastDiscoveryLegendary: Bool = false
    @State private var nearOxygenCache: Bool = false
    @State private var signalPulsePhase: Double = 0
    
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
                ScannerRingView(
                    progress: engine.scanner.scanProgress,
                    playerYaw: engine.player.yaw,
                    cameraYaw: engine.camera.yaw
                )
                    .frame(width: 120, height: 120)
                    .allowsHitTesting(false)
            }
            
            // --- Signal Discovery Holographic Datapad Popup (center screen) ---
            if showDiscovery {
                VStack(spacing: 0) {
                    Spacer()
                    
                    AAAGlassPanel(
                        chamfer: 12,
                        borderColor: (lastDiscoveryLegendary ? Pastel.legendary : Pastel.primary).opacity(0.6),
                        borderWidth: lastDiscoveryLegendary ? 1.8 : 1.2,
                        glowColor: (lastDiscoveryLegendary ? Pastel.legendary : Pastel.primary).opacity(0.3),
                        bgOpacity: 0.94
                    ) {
                        VStack(spacing: 10) {
                            // Header with Hologram Decryption Badge
                            HStack(spacing: 8) {
                                Image(systemName: lastDiscoveryLegendary ? "sparkles" : "waveform.badge.magnifyingglass")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(lastDiscoveryLegendary ? Pastel.legendary : Pastel.primary)
                                
                                Text(lastDiscoveryLegendary ? "★ CLASSIFIED MEMORY DECRYPTED ★" : "TRANSMISSION DECODED")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundColor(lastDiscoveryLegendary ? Pastel.legendary : Pastel.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.easeIn(duration: 0.25)) {
                                        showDiscovery = false
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(Pastel.textSecondary)
                                }
                            }
                            
                            // Waveform + Type badge
                            HStack {
                                AAAWaveformView(color: lastDiscoveryLegendary ? Pastel.legendary : Pastel.primary, count: 10, height: 10)
                                
                                Spacer()
                                
                                Text(discoveryType.uppercased())
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(Pastel.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Pastel.secondary.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            
                            Rectangle()
                                .fill((lastDiscoveryLegendary ? Pastel.legendary : Pastel.primary).opacity(0.2))
                                .frame(height: 1)
                            
                            // Fragment Title (if available)
                            if !discoveryTitle.isEmpty {
                                Text(discoveryTitle.uppercased())
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundColor(Pastel.textPrimary)
                                    .tracking(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Lore text
                            Text(discoveryText)
                                .font(.system(size: 11, weight: .regular, design: .serif))
                                .foregroundColor(Pastel.textPrimary.opacity(0.92))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(3.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Bottom Telemetry: Remaining signals count
                            if let engine = engine {
                                let remaining = engine.world.memoryFragmentSystem.fragments.count - engine.world.memoryFragmentSystem.discoveredCount
                                HStack {
                                    Text("STATUS: ARCHIVED")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(Pastel.success.opacity(0.8))
                                    Spacer()
                                    Text("\(remaining) SIGNALS REMAINING")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(Pastel.textMuted)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(16)
                    }
                    .overlay(AAAHUDCornerBrackets(color: (lastDiscoveryLegendary ? Pastel.legendary : Pastel.primary).opacity(0.7), length: 8))
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 100)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            
            // --- Planet Info + Objective (top left) ---
            VStack {
                HStack(alignment: .top) {
                    if let engine = engine {
                        HStack(alignment: .top, spacing: 14) {
                            // Emergency Abort / Menu Button (Top Left)
                            Button(action: {
                                withAnimation(.spring(response: 0.35)) {
                                    appState = .mainMenu
                                }
                            }) {
                                ZStack {
                                    AAAShape.ChamferedRectangle(chamferSize: 8)
                                        .fill(Pastel.surface.opacity(0.85))
                                        .frame(width: 38, height: 38)
                                    AAAShape.ChamferedRectangle(chamferSize: 8)
                                        .stroke(Pastel.danger.opacity(0.4), lineWidth: 1)
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "power")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Pastel.danger)
                                }
                            }
                            
                            // Tactical Planetary HUD Panel
                            AAAGlassPanel(chamfer: 10, borderColor: Pastel.primary.opacity(0.25), glowColor: Pastel.primary.opacity(0.1)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    // Header: Sector & Planet Name
                                    HStack(spacing: 8) {
                                        Text("SECTOR 0\(engine.planetsCompleted + 1)")
                                            .font(.system(size: 8, weight: .black, design: .monospaced))
                                            .foregroundStyle(Pastel.primary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Pastel.primary.opacity(0.16))
                                            .clipShape(Capsule())
                                        
                                        Text(engine.world.planetConfig.name.uppercased())
                                            .font(.system(size: 13, weight: .black, design: .monospaced))
                                            .tracking(1.5)
                                            .foregroundStyle(Pastel.textPrimary)
                                    }
                                    
                                    // Mood & Atmosphere Tag
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Pastel.moodColor(engine.world.planetConfig.mood))
                                            .frame(width: 6, height: 6)
                                            .shadow(color: Pastel.moodColor(engine.world.planetConfig.mood), radius: 3)
                                        
                                        Text("\(engine.world.planetConfig.mood.rawValue.uppercased()) ATMOSPHERE")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Pastel.textSecondary)
                                    }
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.08))
                                        .padding(.vertical, 1)
                                    
                                    // Objective: Signals remaining with audio waveform
                                    let remaining = engine.world.memoryFragmentSystem.fragments.count - engine.world.memoryFragmentSystem.discoveredCount
                                    HStack(spacing: 8) {
                                        AAAWaveformView(color: remaining > 0 ? Pastel.secondary : Pastel.success, count: 8, height: 12)
                                        
                                        Text("SIGNALS:")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Pastel.secondary)
                                        
                                        Text("\(remaining) REMAINING")
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .foregroundStyle(remaining > 0 ? Pastel.textPrimary : Pastel.success)
                                    }
                                    
                                    // Nearest signal direction hint & distance
                                    if let nearest = nearestFragment(engine: engine) {
                                        let dist = distance2D(engine.player.position, nearest.worldPosition)
                                        HStack(spacing: 6) {
                                            ZStack {
                                                Circle()
                                                    .stroke(Pastel.primary.opacity(0.3), lineWidth: 1)
                                                    .frame(width: 16, height: 16)
                                                Image(systemName: "location.north.fill")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(Pastel.primary)
                                                    .rotationEffect(.degrees(bearingTo(from: engine.player, to: nearest.worldPosition)))
                                            }
                                            
                                            Text("\(Int(dist))m TO TARGET")
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundStyle(Pastel.primary)
                                        }
                                    }
                                    
                                    // Fragment teaser
                                    if let teaser = fragmentTeaser {
                                        HStack(spacing: 4) {
                                            Image(systemName: "waveform")
                                                .font(.system(size: 8))
                                                .foregroundStyle(Pastel.signalPulse)
                                            Text(teaser)
                                                .font(.system(size: 8, weight: .light, design: .serif))
                                                .foregroundStyle(Pastel.signalPulse.opacity(0.9))
                                                .italic()
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    // Active bounty tracker
                                    ForEach(engine.bountySystem.activeBounties) { bounty in
                                        if !bounty.isCompleted {
                                            HStack(spacing: 6) {
                                                Image(systemName: bounty.type.icon)
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(Pastel.bounty)
                                                Text("\(bounty.type.rawValue.uppercased()):")
                                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(Pastel.bounty)
                                                Text(bounty.progressText)
                                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(Pastel.textPrimary)
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                            }
                            .overlay(AAAHUDCornerBrackets(color: Pastel.primary.opacity(0.4), length: 6))
                        }
                        .padding(.top, 56)
                        .padding(.leading, 20)
                    }
                    
                    Spacer()
                    
                    // Top right: High-Tech Telemetry Cluster (Gauges + Data Cores)
                    VStack(alignment: .trailing, spacing: 8) {
                        AAAGlassPanel(chamfer: 10, borderColor: Pastel.primary.opacity(0.2), glowColor: Pastel.primary.opacity(0.08)) {
                            VStack(alignment: .trailing, spacing: 8) {
                                // Data Cores Currency Badge
                                HStack(spacing: 6) {
                                    Image(systemName: "diamond.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Pastel.gold)
                                        .shadow(color: Pastel.gold.opacity(0.6), radius: 4)
                                    Text("\(dataCores)")
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
                                        .foregroundColor(Pastel.gold)
                                    Text("CORES")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(Pastel.gold.opacity(0.6))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Pastel.gold.opacity(0.08))
                                .clipShape(Capsule())
                                
                                // Dual Circular Telemetry Gauges: O2 & PWR
                                HStack(spacing: 14) {
                                    AAACircularGauge(
                                        title: "OXYGEN",
                                        value: oxygen,
                                        maxValue: engine?.survivalSystem.maxOxygen ?? 100,
                                        color: Pastel.primary,
                                        icon: "lungs.fill",
                                        size: 46
                                    )
                                    
                                    AAACircularGauge(
                                        title: "SUIT PWR",
                                        value: suitPower,
                                        maxValue: engine?.survivalSystem.maxSuitPower ?? 100,
                                        color: Pastel.gold,
                                        icon: "bolt.fill",
                                        size: 46
                                    )
                                }
                                
                                // Thermal Telemetry
                                HStack(spacing: 5) {
                                    Image(systemName: "thermometer.medium")
                                        .font(.system(size: 10))
                                        .foregroundColor(temperatureColor)
                                    Text("\(Int(temperature))°C")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundColor(temperatureColor)
                                    Text(temperatureState.rawValue.uppercased())
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundColor(temperatureColor.opacity(0.7))
                                }
                                
                                // Quick Navigation Pill: LOG
                                Button(action: { showAchievements = true }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "book.pages.fill")
                                            .font(.system(size: 10))
                                        Text("LOG / CODEX")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .tracking(1)
                                    }
                                    .foregroundColor(Pastel.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Pastel.primary.opacity(0.14))
                                    .overlay(Capsule().stroke(Pastel.primary.opacity(0.3), lineWidth: 0.8))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(10)
                        }
                        .overlay(AAAHUDCornerBrackets(color: Pastel.primary.opacity(0.35), length: 6))
                        
                        // Debug overlay (if active)
                        if showDebugOverlay, let engine = engine {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(engine.fps) FPS")
                                    .foregroundStyle(engine.fps >= 55 ? Pastel.success : Pastel.danger)
                                Text("CHUNKS: \(engine.world.readyChunks.count)")
                                    .foregroundStyle(Pastel.textMuted)
                            }
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(6)
                            .background(Pastel.surface.opacity(0.7))
                            .cornerRadius(4)
                        }
                        
                        // Mini-Map
                        if SettingsManager.shared.showMiniMap, let engine = engine {
                            MiniMapView(
                                playerPosition: engine.player.position,
                                playerYaw: engine.player.yaw,
                                cameraYaw: engine.camera.yaw,
                                signals: engine.world.memoryFragmentSystem.fragments
                            )
                        }
                    }
                    .padding(.top, 56)
                    .padding(.trailing, 16)
                }
                
                Spacer()
                
                // --- Bottom controls: AAA Aerospace Thumbstick & Flight Controls ---
                HStack(alignment: .bottom) {
                    // Aerospace Gimbal Virtual Joystick
                    ZStack {
                        // Outer Heading Calibration Ring
                        Circle()
                            .stroke(Pastel.primary.opacity(0.18), lineWidth: 2)
                            .frame(width: 116, height: 116)
                        
                        // Degree ticks (every 30 degrees)
                        ForEach(0..<12, id: \.self) { i in
                            Rectangle()
                                .fill(Pastel.primary.opacity(i % 3 == 0 ? 0.45 : 0.2))
                                .frame(width: 1.5, height: i % 3 == 0 ? 8 : 4)
                                .offset(y: -54)
                                .rotationEffect(.degrees(Double(i) * 30))
                        }
                        
                        // Cardinal labels
                        Text("N")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundColor(Pastel.primary.opacity(0.5))
                            .offset(y: -44)
                        
                        // Inner crosshair
                        Path { path in
                            path.move(to: CGPoint(x: 58, y: 35))
                            path.addLine(to: CGPoint(x: 58, y: 81))
                            path.move(to: CGPoint(x: 35, y: 58))
                            path.addLine(to: CGPoint(x: 81, y: 58))
                        }
                        .stroke(Pastel.textPrimary.opacity(0.08), lineWidth: 0.8)
                        .frame(width: 116, height: 116)
                        
                        // Thumbstick Nub with Active Halo
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            (joystickActive ? Pastel.primary : Pastel.surface).opacity(0.8),
                                            Pastel.surface.opacity(0.9)
                                        ],
                                        center: .center,
                                        startRadius: 2,
                                        endRadius: 24
                                    )
                                )
                                .frame(width: 48, height: 48)
                            
                            Circle()
                                .stroke(
                                    joystickActive ? Pastel.primary : Pastel.cardStroke,
                                    lineWidth: joystickActive ? 2 : 1
                                )
                                .frame(width: 48, height: 48)
                                .shadow(color: joystickActive ? Pastel.primary.opacity(0.6) : Color.clear, radius: 8)
                            
                            // Center reticle
                            Circle()
                                .fill(joystickActive ? Pastel.primary : Pastel.textSecondary)
                                .frame(width: 6, height: 6)
                        }
                        .offset(x: CGFloat(joystickOffset.x * 48.0), y: CGFloat(joystickOffset.y * 48.0))
                    }
                    .padding(.leading, 26)
                    .padding(.bottom, 26)
                    
                    Spacer()
                    
                    // Action Buttons (Jetpack Flight Control + Upgrade Depot)
                    VStack(spacing: 12) {
                        // Jetpack Flight Button
                        Button(action: {
                            let newVal = !(engine?.player.isJetpacking ?? false)
                            engine?.inputManager.setJetpack(newVal)
                        }) {
                            ZStack {
                                // Pulsing thrust aura when active
                                if isJetpacking {
                                    Circle()
                                        .stroke(Pastel.primary.opacity(0.3), lineWidth: 6)
                                        .frame(width: 68, height: 68)
                                        .scaleEffect(1.08)
                                }
                                
                                Circle()
                                    .fill(isJetpacking ? Pastel.primary.opacity(0.22) : Pastel.surface.opacity(0.8))
                                    .frame(width: 58, height: 58)
                                
                                Circle()
                                    .stroke(
                                        isJetpacking ? Pastel.primary : Pastel.primary.opacity(0.3),
                                        lineWidth: isJetpacking ? 2.2 : 1.2
                                    )
                                    .frame(width: 58, height: 58)
                                    .shadow(color: isJetpacking ? Pastel.primary.opacity(0.8) : Color.clear, radius: 10)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundStyle(isJetpacking ? Pastel.primary : Pastel.textSecondary)
                                    
                                    Text("THRUST")
                                        .font(.system(size: 7, weight: .black, design: .monospaced))
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
                        
                        // Altitude Badge
                        Text("ALT: \(Int(selectedJetpackHeight))M")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(isJetpacking ? Pastel.primary : Pastel.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Pastel.surface.opacity(0.8))
                            .cornerRadius(4)
                        
                        // Upgrade Depot Button
                        Button(action: { showUpgradeShop = true }) {
                            ZStack {
                                AAAShape.ChamferedRectangle(chamferSize: 8)
                                    .fill(Pastel.surface.opacity(0.85))
                                    .frame(width: 48, height: 48)
                                
                                AAAShape.ChamferedRectangle(chamferSize: 8)
                                    .stroke(Pastel.gold.opacity(0.5), lineWidth: 1.2)
                                    .frame(width: 48, height: 48)
                                    .shadow(color: Pastel.gold.opacity(0.3), radius: 6)
                                
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Pastel.gold)
                            }
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 26)
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
                    starRating: engine.calculateStarRating(),
                    bountiesCompleted: engine.bountySystem.completedBountyNames,
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
                FinalRevelationView(
                    onRestart: {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showFinalRevelation = false
                        }
                        engine?.resetJourney()
                    },
                    onEndlessMode: {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showFinalRevelation = false
                        }
                        engine?.startEndlessMode()
                    }
                )
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
            
            // === AAA EMERGENCY SUIT REBOOT OVERLAY ===
            if showBlackout {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // CRT Scanlines
                    AAAScanlineOverlay(lineSpacing: 3, opacity: 0.12)
                    
                    VStack(spacing: 20) {
                        // Flashing Warning Icon with Hazard Glow
                        ZStack {
                            Circle()
                                .stroke(Pastel.danger.opacity(0.3), lineWidth: 8)
                                .frame(width: 88, height: 88)
                            
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 44, weight: .black))
                                .foregroundColor(Pastel.danger)
                                .shadow(color: Pastel.danger, radius: 14)
                        }
                        
                        VStack(spacing: 8) {
                            Text("CRITICAL SUIT INTEGRITY COMPROMISED")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(3)
                                .foregroundColor(Pastel.danger)
                            
                            Text("LIFE SUPPORT FAILURE")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundColor(Pastel.textPrimary)
                                .tracking(4)
                        }
                        
                        // Telemetry Flatline Animation
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Pastel.danger.opacity(0.4))
                                .frame(width: 60, height: 1.5)
                            Text("VITALS: FLATLINE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Pastel.danger)
                            Rectangle()
                                .fill(Pastel.danger.opacity(0.4))
                                .frame(width: 60, height: 1.5)
                        }
                        
                        // Diagnostic Reboot Progress
                        VStack(spacing: 6) {
                            Text("INITIATING EMERGENCY HYPERSPACE RESPAWN...")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(Pastel.textSecondary)
                            
                            ProgressView()
                                .tint(Pastel.primary)
                                .scaleEffect(0.8)
                        }
                        .padding(.top, 10)
                    }
                    .padding(32)
                    .background(
                        AAAShape.ChamferedRectangle(chamferSize: 14)
                            .fill(Pastel.surface.opacity(0.95))
                            .overlay(AAAShape.ChamferedRectangle(chamferSize: 14).stroke(Pastel.danger.opacity(0.6), lineWidth: 1.5))
                            .shadow(color: Pastel.danger.opacity(0.35), radius: 24)
                    )
                    .overlay(AAAHUDCornerBrackets(color: Pastel.danger, length: 12, thickness: 2))
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

        // --- Combo Banner (top center) ---
        .overlay(alignment: .top) {
            if showCombo {
                Text(comboText)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(Pastel.combo)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Pastel.combo.opacity(0.12))
                            .overlay(Capsule().stroke(Pastel.combo.opacity(0.3), lineWidth: 1))
                    )
                    .shadow(color: Pastel.combo.opacity(0.3), radius: 12)
                    .padding(.top, 120)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        // --- Creature Scan Popup ---
        .overlay(alignment: .top) {
            if showCreatureScan {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Pastel.tertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LIFEFORM CATALOGUED")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Pastel.textMuted)
                        Text(creatureScanName)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Pastel.tertiary)
                    }
                    Text("+\(creatureScanReward) ◆")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Pastel.gold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Pastel.surface.opacity(0.9))
                        .overlay(Capsule().stroke(Pastel.tertiary.opacity(0.3), lineWidth: 1))
                )
                .padding(.top, 155)
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        // --- Ambient Event ---
        .overlay(alignment: .top) {
            if showAmbientEvent, let text = ambientEventText {
                Text(text)
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundColor(Pastel.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Pastel.surface.opacity(0.75))
                    )
                    .padding(.top, 85)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
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
                lastDiscoveryLegendary = frag.isLegendary
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
            
            // Check for combo triggers
            if engine.engagementSystem.comboJustTriggered {
                comboText = engine.engagementSystem.lastComboText
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showCombo = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showCombo = false
                    }
                }
            }
            
            // Check for creature scans
            if let name = engine.scanner.lastScannedCreatureName {
                creatureScanName = name
                creatureScanReward = engine.scanner.lastCreatureScanReward
                engine.scanner.clearLastCreatureScan()
                withAnimation(.spring(response: 0.3)) {
                    showCreatureScan = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showCreatureScan = false
                    }
                }
            }
            
            // Sync engagement state
            signalStrength = engine.engagementSystem.signalStrength
            fragmentTeaser = engine.engagementSystem.fragmentTeaser
            nearOxygenCache = engine.engagementSystem.nearestUncollectedCacheDistance(from: engine.player.position) != nil
            
            // Ambient events
            if let event = engine.engagementSystem.currentAmbientEvent {
                let text = event.type.rawValue
                if ambientEventText != text {
                    ambientEventText = text
                    withAnimation(.easeOut(duration: 0.5)) {
                        showAmbientEvent = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation(.easeIn(duration: 0.5)) {
                            showAmbientEvent = false
                        }
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
    var playerYaw: Float = 0
    var cameraYaw: Float = 0
    
    // Haptics
    @State private var lastHapticProgress: Float = 0.0
    private let impactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let completeGenerator = UINotificationFeedbackGenerator()
    
    // Pointer direction: player facing relative to camera
    private var pointerAngle: Double {
        Double(cameraYaw - playerYaw) * (180.0 / .pi)
    }
    
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
            
            // === DIRECTIONAL POINTER ===
            // Arrow pointing in character facing direction
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius: CGFloat = 38
                let arrowSize: CGFloat = 8
                
                // Pointer triangle
                Path { path in
                    let tipX = center.x + radius * CGFloat(sin(pointerAngle * .pi / 180.0))
                    let tipY = center.y - radius * CGFloat(cos(pointerAngle * .pi / 180.0))
                    
                    let leftAngle = (pointerAngle - 150) * .pi / 180.0
                    let rightAngle = (pointerAngle + 150) * .pi / 180.0
                    
                    let leftX = tipX + arrowSize * CGFloat(sin(leftAngle))
                    let leftY = tipY - arrowSize * CGFloat(cos(leftAngle))
                    let rightX = tipX + arrowSize * CGFloat(sin(rightAngle))
                    let rightY = tipY - arrowSize * CGFloat(cos(rightAngle))
                    
                    path.move(to: CGPoint(x: tipX, y: tipY))
                    path.addLine(to: CGPoint(x: leftX, y: leftY))
                    path.addLine(to: CGPoint(x: rightX, y: rightY))
                    path.closeSubpath()
                }
                .fill(Pastel.primary.opacity(Double(0.5 + progress * 0.5)))
                
                // Pulsing dot at arrow tip
                let dotX = center.x + (radius + 4) * CGFloat(sin(pointerAngle * .pi / 180.0))
                let dotY = center.y - (radius + 4) * CGFloat(cos(pointerAngle * .pi / 180.0))
                
                Circle()
                    .fill(Pastel.primary)
                    .frame(width: 4 + CGFloat(progress * 3), height: 4 + CGFloat(progress * 3))
                    .shadow(color: Pastel.primary.opacity(0.8), radius: CGFloat(progress * 6))
                    .position(x: dotX, y: dotY)
                
                // Center-to-tip line (scan direction beam)
                Path { path in
                    let innerRadius: CGFloat = 8
                    let startX = center.x + innerRadius * CGFloat(sin(pointerAngle * .pi / 180.0))
                    let startY = center.y - innerRadius * CGFloat(cos(pointerAngle * .pi / 180.0))
                    let endX = center.x + (radius - arrowSize * 0.5) * CGFloat(sin(pointerAngle * .pi / 180.0))
                    let endY = center.y - (radius - arrowSize * 0.5) * CGFloat(cos(pointerAngle * .pi / 180.0))
                    
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(
                    Pastel.primary.opacity(Double(progress * 0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3])
                )
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
