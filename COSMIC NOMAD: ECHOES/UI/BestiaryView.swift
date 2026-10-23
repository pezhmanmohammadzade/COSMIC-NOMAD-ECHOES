//
//  BestiaryView.swift
//  COSMIC NOMAD: ECHOES
//
//  AAA Sci-Fi Xenobiology Bio-Scanner Terminal.
//  Telemetric catalog of all scanned extraterrestrial lifeforms.
//

import SwiftUI

struct BestiaryView: View {
    let onClose: () -> Void
    
    @State private var scannedCreatures: [String] = []
    
    private let allCreatures: [(name: String, type: String, threat: String, icon: String, description: String, color: Color)] = [
        ("Luminous Drifter", "Atmospheric Cnidaria", "DOCILE", "drop.fill",
         "Bioluminescent organisms that drift through alien atmospheres. They pulse with soft light and are drawn to nearby movement. Mostly harmless, but their tentacles carry a mild electrical charge.",
         Color(red: 0.45, green: 0.75, blue: 0.95)),
        
        ("Husk Crawler", "Chitinous Lithopod", "TERRITORIAL", "ant.fill",
         "Armored surface predators that patrol territorial routes. They detect vibrations through the ground and aggressively charge toward intruders. Their exoskeletons are remarkably dense.",
         Color(red: 0.95, green: 0.45, blue: 0.35)),
        
        ("Void Leviathan", "Colossal Aerostat", "NEUTRAL", "wind",
         "Massive aerial creatures that circle at extreme altitudes. They filter atmospheric particles for sustenance and communicate through deep infrasonic pulses that can be felt more than heard.",
         Color(red: 0.65, green: 0.85, blue: 0.65)),
    ]
    
    var body: some View {
        ZStack {
            // Dark tactical backdrop
            Color(red: 0.02, green: 0.03, blue: 0.06).ignoresSafeArea()
            
            // Atmospheric scanline grid
            AAAScanlineOverlay()
                .opacity(0.35)
                .ignoresSafeArea()
            
            // Background ambient glow
            VStack {
                HStack {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.85, blue: 0.65).opacity(0.06))
                        .frame(width: 320, height: 320)
                        .blur(radius: 80)
                        .offset(x: -60, y: -40)
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 0.35, green: 0.85, blue: 0.65))
                                .frame(width: 6, height: 6)
                                .shadow(color: Color(red: 0.35, green: 0.85, blue: 0.65), radius: 4)
                            
                            Text("BIO-TELEMETRY // SYS_XENOBIOLOGY")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.65).opacity(0.85))
                                .tracking(2)
                        }
                        
                        Text("XENOBIOLOGY CODEX")
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(3)
                        
                        HStack(spacing: 6) {
                            Text("SPECIMENS CATALOGUED:")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("\(scannedCreatures.count)/\(allCreatures.count)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.65))
                            
                            Text("DISCOVERED")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    
                    Spacer()
                    
                    // Tactical Close Button
                    Button(action: onClose) {
                        ZStack {
                            AAAShape.ChamferedRectangle(chamfer: 6)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    AAAShape.ChamferedRectangle(chamfer: 6)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .frame(width: 38, height: 38)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)
                .padding(.bottom, 16)
                
                // Telemetry divider
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(red: 0.35, green: 0.85, blue: 0.65).opacity(0.4))
                        .frame(height: 1)
                    
                    Text("◆")
                        .font(.system(size: 8))
                        .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.65))
                        .padding(.horizontal, 8)
                    
                    Rectangle()
                        .fill(LinearGradient(colors: [Color(red: 0.35, green: 0.85, blue: 0.65).opacity(0.4), Color.clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
                
                // Creature List
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(allCreatures, id: \.name) { creature in
                            let isScanned = scannedCreatures.contains(creature.name)
                            AAACreatureCard(
                                name: creature.name,
                                type: creature.type,
                                threat: creature.threat,
                                icon: creature.icon,
                                description: creature.description,
                                color: creature.color,
                                isScanned: isScanned
                            )
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            scannedCreatures = SaveManager.shared.getScannedCreatures()
        }
    }
}

// MARK: - AAA Creature Card

struct AAACreatureCard: View {
    let name: String
    let type: String
    let threat: String
    let icon: String
    let description: String
    let color: Color
    let isScanned: Bool
    
    @State private var scanPulse = false
    
    var body: some View {
        AAAGlassPanel(accentColor: isScanned ? color : .white.opacity(0.2), cornerRadius: 8) {
            HStack(alignment: .top, spacing: 16) {
                // Bio-specimen scanner hologram chamber
                ZStack {
                    AAAShape.ChamferedRectangle(chamfer: 6)
                        .fill(isScanned ? color.opacity(0.12) : Color.white.opacity(0.03))
                        .frame(width: 64, height: 64)
                    
                    AAAShape.ChamferedRectangle(chamfer: 6)
                        .stroke(isScanned ? color.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: 64, height: 64)
                    
                    if isScanned {
                        // Pulsing bio ring
                        Circle()
                            .stroke(color.opacity(scanPulse ? 0.6 : 0.2), lineWidth: 1)
                            .frame(width: 48, height: 48)
                            .scaleEffect(scanPulse ? 1.05 : 0.95)
                        
                        Image(systemName: icon)
                            .font(.system(size: 26))
                            .foregroundColor(color)
                            .shadow(color: color.opacity(0.6), radius: 6)
                    } else {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.25))
                    }
                }
                
                // Telemetry Details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(isScanned ? name : "[UNKNOWN BIO-ENTITY]")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(isScanned ? .white : .white.opacity(0.4))
                        
                        Spacer()
                        
                        if isScanned {
                            HStack(spacing: 4) {
                                Text("THREAT:")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                
                                Text(threat)
                                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                    .foregroundColor(threat == "TERRITORIAL" ? .red : (threat == "DOCILE" ? .green : .cyan))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                        } else {
                            Text("SCAN REQUIRED")
                                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                                .foregroundColor(.yellow.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(isScanned ? type.uppercased() : "TAXONOMY UNINDEXED")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(isScanned ? color.opacity(0.85) : .white.opacity(0.3))
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                        .padding(.vertical, 2)
                    
                    if isScanned {
                        Text(description)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                            .lineSpacing(3)
                    } else {
                        Text("Approach specimen in planetary field and hold scanner reticle to decrypt anatomical telemetry.")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                            .italic()
                    }
                }
            }
            .padding(14)
        }
        .onAppear {
            if isScanned {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    scanPulse = true
                }
            }
        }
    }
}
