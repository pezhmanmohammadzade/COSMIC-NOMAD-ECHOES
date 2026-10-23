//
//  CodexView.swift
//  COSMIC NOMAD: ECHOES
//
//  AAA Sci-Fi Archive & Memory Codex.
//  Tactical telemetry display of all decrypted signals and corrupted transmissions.
//

import SwiftUI

struct CodexView: View {
    let onClose: () -> Void
    
    @State private var fragments: [[String: String]] = []
    @State private var selectedPlanet: String? = nil
    
    var body: some View {
        ZStack {
            // Deep space tactical backdrop
            Color(red: 0.02, green: 0.03, blue: 0.06).ignoresSafeArea()
            
            // Atmospheric scanline grid
            AAAScanlineOverlay()
                .opacity(0.35)
                .ignoresSafeArea()
            
            // Subtle ambient energy glows
            VStack {
                HStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.06))
                        .frame(width: 320, height: 320)
                        .blur(radius: 70)
                        .offset(x: -80, y: -60)
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 6, height: 6)
                                .shadow(color: Color.cyan, radius: 4)
                            
                            Text("TELEMETRY ARCHIVE // SYS_CODEX_04")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.8))
                                .tracking(2)
                        }
                        
                        Text("MEMORY FRAGMENTS")
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(3)
                        
                        HStack(spacing: 6) {
                            Text("RECOVERED:")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("\(fragments.count)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                            
                            Text("SECTORS MONITORED")
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
                
                // Planet Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        AAAPlanetTabButton(name: "ALL SECTORS", isSelected: selectedPlanet == nil) {
                            selectedPlanet = nil
                        }
                        
                        ForEach(planetNames, id: \.self) { planet in
                            AAAPlanetTabButton(name: planet, isSelected: selectedPlanet == planet) {
                                selectedPlanet = planet
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.bottom, 14)
                
                // Telemetry separating line with tech notch
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.cyan.opacity(0.35))
                        .frame(height: 1)
                    
                    Text("◆")
                        .font(.system(size: 8))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 8)
                    
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.cyan.opacity(0.35), Color.clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
                
                // Fragment Stream
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredFragments, id: \.self) { frag in
                            AAACodexFragmentCard(fragment: frag)
                        }
                        
                        // Corrupted placeholders
                        ForEach(0..<corruptedCount, id: \.self) { idx in
                            AAACorruptedFragmentCard(index: idx)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            fragments = SaveManager.shared.getCodexFragments()
        }
        .transition(.opacity)
    }
    
    // MARK: - Computed
    
    private var planetNames: [String] {
        let names = Set(fragments.compactMap { $0["planet"] })
        return names.sorted()
    }
    
    private var filteredFragments: [[String: String]] {
        if let planet = selectedPlanet {
            return fragments.filter { $0["planet"] == planet }
        }
        return fragments
    }
    
    private var corruptedCount: Int {
        let total = (SaveManager.shared.getPlanetsCompleted() + 1) * 5
        return max(0, total - fragments.count)
    }
}

// MARK: - Tactical Planet Filter Tab

struct AAAPlanetTabButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 4, height: 4)
                        .shadow(color: Color.cyan, radius: 3)
                }
                
                Text(name.uppercased())
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                AAAShape.ChamferedRectangle(chamfer: 6)
                    .fill(isSelected ? Color.cyan.opacity(0.18) : Color.white.opacity(0.04))
            )
            .overlay(
                AAAShape.ChamferedRectangle(chamfer: 6)
                    .stroke(isSelected ? Color.cyan.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - AAA Codex Fragment Card

struct AAACodexFragmentCard: View {
    let fragment: [String: String]
    @State private var isExpanded = false
    
    var body: some View {
        AAAGlassPanel(accentColor: .cyan, cornerRadius: 8) {
            VStack(alignment: .leading, spacing: 10) {
                // Top telemetry bar
                HStack(alignment: .center) {
                    // Classification badge
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 9))
                            .foregroundColor(.cyan)
                        
                        Text((fragment["type"] ?? "SIGNAL").uppercased())
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.12))
                    .clipShape(Capsule())
                    
                    Text("// SECTOR DECRYPTED")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Spacer()
                    
                    // Planet coordinates
                    HStack(spacing: 4) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(fragment["planet"] ?? "UNKNOWN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                
                // Title
                HStack {
                    Text(fragment["title"] ?? "Unknown Signal")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.7))
                }
                
                // Expanded Content
                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        Rectangle()
                            .fill(Color.cyan.opacity(0.2))
                            .frame(height: 1)
                        
                        Text(fragment["content"] ?? "")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(5)
                        
                        // Holographic audio waveform visualizer
                        HStack(spacing: 3) {
                            Text("AUDIO CARRIER FREQ:")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.6))
                            
                            AAAWaveformView(barCount: 16, accentColor: .cyan)
                                .frame(height: 12)
                            
                            Spacer()
                            
                            Text("1420.405 MHz")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 4)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - AAA Corrupted Fragment Card

struct AAACorruptedFragmentCard: View {
    let index: Int
    @State private var flicker = false
    
    var body: some View {
        ZStack {
            AAAShape.ChamferedRectangle(chamfer: 8)
                .fill(Color(red: 0.12, green: 0.04, blue: 0.04).opacity(flicker ? 0.45 : 0.25))
                .overlay(
                    AAAShape.ChamferedRectangle(chamfer: 8)
                        .stroke(Color.red.opacity(flicker ? 0.35 : 0.15), lineWidth: 1)
                )
            
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("[ENCRYPTED // CORRUPTED TRANSMISSION]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.85))
                    
                    Text("CHECKSUM ERROR: 0x\(String(format: "%04X", 0x4A10 + index * 0x1F)) • SIGNAL CARRIER DEGRADED")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }
                
                Spacer()
                
                Text("LOCKED")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.red.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                flicker = true
            }
        }
    }
}
