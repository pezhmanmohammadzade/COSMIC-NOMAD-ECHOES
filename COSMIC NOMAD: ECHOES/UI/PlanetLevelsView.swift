//
//  PlanetLevelsView.swift
//  COSMIC NOMAD: ECHOES
//
//  Galaxy-scatter planet levels map showing all 10 planets as a visual
//  progression system. Completed planets are full-color and tappable
//  to travel to. Locked planets are greyed out until unlocked.
//

import SwiftUI

struct PlanetLevelsView: View {
    var engine: GameEngine?
    @Binding var appState: AppState
    let onClose: () -> Void
    
    @State private var planetsCompleted: Int = 0
    @State private var selectedPlanet: Int? = nil
    @State private var starPhase: Double = 0
    @State private var showTravelConfirm: Bool = false
    @State private var travelTargetIndex: Int = 0
    
    // Deterministic planet data for all 10 planets
    private let planets: [PlanetLevelData] = PlanetLevelData.generateAll()
    
    var body: some View {
        ZStack {
            // Deep space background
            Color.black.ignoresSafeArea()
            
            // Animated starfield background
            Canvas { context, size in
                for i in 0..<80 {
                    let seed = Double(i) * 137.508
                    let x = ((sin(seed * 0.7) + 1) / 2) * size.width
                    let y = ((cos(seed * 1.3) + 1) / 2) * size.height
                    let brightness = (sin(starPhase + seed) + 1) / 2 * 0.5 + 0.1
                    let starSize = CGFloat(1 + (sin(seed * 2.1) + 1) * 1.2)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: starSize, height: starSize)),
                        with: .color(.white.opacity(brightness))
                    )
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: true)) {
                    starPhase = .pi * 2
                }
            }
            
            VStack(spacing: 0) {
                // Header
                ZStack {
                    HStack {
                        Button(action: onClose) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14))
                                Text("BACK")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    
                    VStack(spacing: 4) {
                        Text("STAR CHART")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(4)
                        
                        Text("\(planetsCompleted) / \(planets.count) DECODED")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                // Galaxy scatter map
                ScrollView {
                    GeometryReader { geo in
                        ZStack {
                        // Connection lines between planets
                        Canvas { context, size in
                            for i in 0..<planets.count - 1 {
                                let from = planetPosition(index: i, in: size)
                                let to = planetPosition(index: i + 1, in: size)
                                
                                let isCompleted = i < planetsCompleted
                                
                                var path = Path()
                                // Curved connection
                                let midX = (from.x + to.x) / 2 + CGFloat(sin(Double(i) * 1.5)) * 30
                                let midY = (from.y + to.y) / 2
                                path.move(to: from)
                                path.addQuadCurve(to: to, control: CGPoint(x: midX, y: midY))
                                
                                context.stroke(
                                    path,
                                    with: .color(isCompleted ? .cyan.opacity(0.3) : .white.opacity(0.08)),
                                    style: StrokeStyle(lineWidth: isCompleted ? 1.5 : 0.5, dash: isCompleted ? [] : [4, 4])
                                )
                            }
                        }
                        
                        // Planet nodes
                        ForEach(0..<planets.count, id: \.self) { index in
                            let planet = planets[index]
                            let isCompleted = index < planetsCompleted
                            let isCurrent = index == planetsCompleted
                            let isLocked = index > planetsCompleted
                            
                            PlanetNode(
                                planet: planet,
                                index: index,
                                isCompleted: isCompleted,
                                isCurrent: isCurrent,
                                isLocked: isLocked,
                                isSelected: selectedPlanet == index
                            )
                            .onTapGesture {
                                if !isLocked {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedPlanet = selectedPlanet == index ? nil : index
                                    }
                                }
                            }
                            .position(planetPosition(index: index, in: CGSize(width: geo.size.width - 40, height: CGFloat(planets.count) * 100 + 100)))
                        } // close ForEach
                    } // close ZStack
                    } // close GeometryReader
                    .frame(height: CGFloat(planets.count) * 100 + 100)
                    .padding(.horizontal, 20)
                } // close ScrollView
                
                // Planet detail panel with TRAVEL button
                if let idx = selectedPlanet {
                    let isCompleted = idx < planetsCompleted
                    let isCurrent = idx == planetsCompleted
                    let isUnlocked = !( idx > planetsCompleted )
                    
                    PlanetDetailPanel(
                        planet: planets[idx],
                        isCompleted: isCompleted,
                        isCurrent: isCurrent,
                        canTravel: isUnlocked,
                        onTravel: {
                            travelTargetIndex = idx
                            withAnimation(.spring(response: 0.3)) {
                                showTravelConfirm = true
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            
            // === TRAVEL CONFIRMATION OVERLAY ===
            if showTravelConfirm {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                showTravelConfirm = false
                            }
                        }
                    
                    VStack(spacing: 20) {
                        // Planet preview
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [planets[travelTargetIndex].primaryColor, planets[travelTargetIndex].secondaryColor],
                                    center: .topLeading,
                                    startRadius: 5,
                                    endRadius: 35
                                )
                            )
                            .frame(width: 70, height: 70)
                            .overlay(Circle().stroke(planets[travelTargetIndex].accentColor.opacity(0.6), lineWidth: 2))
                            .shadow(color: planets[travelTargetIndex].accentColor.opacity(0.4), radius: 15)
                        
                        VStack(spacing: 6) {
                            Text("TRAVEL TO")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(3)
                            
                            Text(planets[travelTargetIndex].name)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .tracking(2)
                            
                            Label(planets[travelTargetIndex].mood.uppercased(), systemImage: planets[travelTargetIndex].moodIcon)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(planets[travelTargetIndex].accentColor)
                        }
                        
                        Text("Your current planet progress will be saved.")
                            .font(.system(size: 10, weight: .regular, design: .serif))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    showTravelConfirm = false
                                }
                            }) {
                                Text("CANCEL")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                            
                            Button(action: {
                                travelToPlanet(index: travelTargetIndex)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 12))
                                    Text("TRAVEL")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .tracking(2)
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: .cyan.opacity(0.4), radius: 8)
                            }
                        }
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [planets[travelTargetIndex].accentColor.opacity(0.4), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .padding(40)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onAppear {
            planetsCompleted = SaveManager.shared.getPlanetsCompleted()
        }
    }
    
    // Galaxy-scatter positions — irregular, organic layout
    private func planetPosition(index: Int, in size: CGSize) -> CGPoint {
        let progress = CGFloat(index) / CGFloat(planets.count - 1)
        let y = 60 + progress * (size.height - 120)
        
        // Scatter horizontally using a deterministic pattern
        let xBase = size.width / 2
        let scatter = sin(Double(index) * 2.3 + 0.5) * Double(size.width) * 0.3
        let x = xBase + CGFloat(scatter)
        
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - Travel to Planet
    
    private func travelToPlanet(index: Int) {
        guard let engine = engine else { return }
        
        // Get the seed for this planet
        if let savedSeed = SaveManager.shared.getSeedForPlanetLevel(index) {
            // Travel to a previously visited planet using its saved seed
            engine.visitPlanet(seed: savedSeed)
        } else {
            // Current planet — compute seed from base seed + index
            let baseSeed: UInt64 = 42
            let seed = baseSeed &+ UInt64(index)
            engine.visitPlanet(seed: seed)
        }
        
        // Close star chart and start playing
        withAnimation {
            showTravelConfirm = false
            onClose()
            appState = .playing
        }
    }
}

// MARK: - Planet Node
struct PlanetNode: View {
    let planet: PlanetLevelData
    let index: Int
    let isCompleted: Bool
    let isCurrent: Bool
    let isLocked: Bool
    let isSelected: Bool
    
    @State private var pulsePhase: Double = 0
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Glow ring for current planet
                if isCurrent {
                    Circle()
                        .stroke(planet.accentColor.opacity(0.3 + sin(pulsePhase) * 0.2), lineWidth: 2)
                        .frame(width: 62, height: 62)
                        .scaleEffect(1.0 + CGFloat(sin(pulsePhase) * 0.05))
                }
                
                // Planet sphere
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isLocked
                                ? [.gray.opacity(0.3), .gray.opacity(0.1)]
                                : [planet.primaryColor, planet.secondaryColor],
                            center: .topLeading,
                            startRadius: 5,
                            endRadius: 30
                        )
                    )
                    .frame(width: isSelected ? 52 : 44, height: isSelected ? 52 : 44)
                    .overlay(
                        Circle()
                            .stroke(
                                isCompleted ? planet.accentColor.opacity(0.6) :
                                isCurrent ? planet.accentColor.opacity(0.4) :
                                .white.opacity(0.1),
                                lineWidth: isCompleted ? 2 : 1
                            )
                    )
                    .shadow(color: isLocked ? .clear : planet.accentColor.opacity(0.3), radius: isSelected ? 12 : 6)
                
                // Status icon
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                        .offset(x: 18, y: -18)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
                
                // Planet number
                if !isLocked {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Planet name
            Text(planet.name)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isLocked ? .white.opacity(0.2) : .white.opacity(0.7))
                .lineLimit(1)
        }
        .onAppear {
            if isCurrent {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulsePhase = .pi * 2
                }
            }
        }
    }
}

// MARK: - Planet Detail Panel
struct PlanetDetailPanel: View {
    let planet: PlanetLevelData
    let isCompleted: Bool
    let isCurrent: Bool
    var canTravel: Bool = false
    var onTravel: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            // Mini planet sphere
            Circle()
                .fill(
                    RadialGradient(
                        colors: [planet.primaryColor, planet.secondaryColor],
                        center: .topLeading,
                        startRadius: 5,
                        endRadius: 25
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(planet.accentColor.opacity(0.4), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(planet.name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Label(planet.mood.uppercased(), systemImage: planet.moodIcon)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(planet.accentColor)
                    
                    if isCompleted {
                        Text("DECODED")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    } else if isCurrent {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                Text(planet.description)
                    .font(.system(size: 9, weight: .regular, design: .serif))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Travel button for unlocked planets
            if canTravel, let onTravel = onTravel {
                Button(action: onTravel) {
                    VStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                        Text("TRAVEL")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.cyan)
                    .frame(width: 50, height: 50)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(planet.accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Planet Level Data
struct PlanetLevelData {
    let name: String
    let mood: String
    let moodIcon: String
    let description: String
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    
    static func generateAll() -> [PlanetLevelData] {
        let masterSeed: UInt64 = 42
        let totalPlanets = 10
        
        // Procedural name parts
        let prefixes = ["Nyx", "Aur", "Vel", "Kor", "Thal", "Zyx", "Fen", "Ori", "Sol", "Cryo"]
        let suffixes = ["ara", "ion", "ius", "oth", "ene", "ura", "alis", "ix", "on", "um"]
        
        return (0..<totalPlanets).map { i in
            let seed = masterSeed &+ UInt64(i) &* 7919
            var rng = SeededRNG(seed: seed)
            let mood = PlanetMood.allCases[Int(rng.next() % UInt64(PlanetMood.allCases.count))]
            let name = "\(prefixes[i])\(suffixes[Int(rng.next() % UInt64(suffixes.count))])-\(i + 1)"
            
            let (primary, secondary, accent, moodStr, icon, desc): (Color, Color, Color, String, String, String) = {
                switch mood {
                case .lonely:
                    return (.init(red: 0.15, green: 0.2, blue: 0.4), .init(red: 0.05, green: 0.08, blue: 0.2), .init(red: 0.3, green: 0.5, blue: 0.8), "lonely", "wind", "Vast emptiness stretches beyond comprehension")
                case .decayed:
                    return (.init(red: 0.4, green: 0.3, blue: 0.15), .init(red: 0.2, green: 0.15, blue: 0.08), .init(red: 0.8, green: 0.5, blue: 0.2), "decayed", "leaf.fill", "Ancient ruins whisper forgotten histories")
                case .serene:
                    return (.init(red: 0.2, green: 0.35, blue: 0.45), .init(red: 0.1, green: 0.2, blue: 0.3), .init(red: 0.4, green: 0.7, blue: 0.9), "serene", "sparkles", "Gentle light bathes peaceful landscapes")
                case .hostile:
                    return (.init(red: 0.8, green: 0.4, blue: 0.35), .init(red: 0.6, green: 0.2, blue: 0.2), .init(red: 1.0, green: 0.5, blue: 0.4), "hostile", "flame.fill", "Harsh terrain threatens every step")
                case .surreal:
                    return (.init(red: 0.35, green: 0.15, blue: 0.5), .init(red: 0.15, green: 0.05, blue: 0.3), .init(red: 0.6, green: 0.2, blue: 0.9), "surreal", "wand.and.stars", "Reality bends in impossible ways")
                }
            }()
            
            return PlanetLevelData(name: name, mood: moodStr, moodIcon: icon, description: desc, primaryColor: primary, secondaryColor: secondary, accentColor: accent)
        }
    }
}
