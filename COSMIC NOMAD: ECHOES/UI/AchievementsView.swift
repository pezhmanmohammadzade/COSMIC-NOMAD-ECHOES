//
//  AchievementsView.swift
//  COSMIC NOMAD: ECHOES
//
//  AAA Sci-Fi Archive & Observation Codex.
//  Telemetric catalog of all decrypted space facts and cosmic observations.
//

import SwiftUI

struct AchievementsView: View {
    let onClose: () -> Void
    
    @State private var discoveredFacts: [SpaceFact] = []
    
    var groupedFacts: [String: [SpaceFact]] {
        Dictionary(grouping: discoveredFacts, by: { fact in
            fact.mood.capitalized
        })
    }
    
    var body: some View {
        ZStack {
            // Tactical deep space background
            Color(red: 0.02, green: 0.03, blue: 0.06).ignoresSafeArea()
            
            // Atmospheric scanline grid
            AAAScanlineOverlay()
                .opacity(0.35)
                .ignoresSafeArea()
            
            // Background ambient glow
            VStack {
                HStack {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.06))
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
                                .fill(Color(red: 0.95, green: 0.75, blue: 0.25))
                                .frame(width: 6, height: 6)
                                .shadow(color: Color(red: 0.95, green: 0.75, blue: 0.25), radius: 4)
                            
                            Text("STELLAR OBSERVATION LOG // SYS_ARCHIVE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.85))
                                .tracking(2)
                        }
                        
                        Text("DEEP SPACE ARCHIVE")
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(3)
                        
                        HStack(spacing: 6) {
                            Text("TELEMETRY:")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("\(discoveredFacts.count) OBSERVATIONS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))
                            
                            Text("LOGGED")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    
                    Spacer()
                    
                    // Tactical close button
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
                        .fill(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.4))
                        .frame(height: 1)
                    
                    Text("◆")
                        .font(.system(size: 8))
                        .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))
                        .padding(.horizontal, 8)
                    
                    Rectangle()
                        .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.4), Color.clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
                
                // Content
                if discoveredFacts.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        
                        Text("NO TELEMETRIC SIGNALS LOGGED")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(2)
                        
                        Text("Explore planetary waypoints to intercept ancient orbital broadcasts.")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 24) {
                            ForEach(groupedFacts.keys.sorted(), id: \.self) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    // Tactical classification header
                                    HStack(spacing: 8) {
                                        Text("//")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.7))
                                        
                                        Text(group.uppercased())
                                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                            .foregroundColor(.white)
                                            .tracking(2)
                                        
                                        Rectangle()
                                            .fill(Color.white.opacity(0.12))
                                            .frame(height: 1)
                                    }
                                    
                                    ForEach(groupedFacts[group] ?? [], id: \.id) { fact in
                                        AAAFactCard(fact: fact)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            loadDiscoveredFacts()
        }
    }
    
    private func loadDiscoveredFacts() {
        let ids = SaveManager.shared.getDiscoveredFacts()
        var loaded: [SpaceFact] = []
        for id in ids {
            if let fact = FactLibrary.shared.getFact(by: id) {
                loaded.append(fact)
            }
        }
        self.discoveredFacts = loaded.sorted { $0.id < $1.id }
    }
}

// MARK: - AAA Fact Card

struct AAAFactCard: View {
    let fact: SpaceFact
    
    var body: some View {
        AAAGlassPanel(accentColor: Color(red: 0.95, green: 0.75, blue: 0.25), cornerRadius: 8) {
            VStack(alignment: .leading, spacing: 10) {
                // Top telemetry row
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))
                        
                        Text("SPECIMEN #\(String(format: "%03d", fact.id))")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.12))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text("ARCHIVE STATUS: DECRYPTED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.75))
                }
                
                // Fact Title
                Text(fact.title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                // Subtle dividing line
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                
                // Observation text
                Text(fact.fact)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
            }
            .padding(14)
        }
    }
}
