//
//  BestiaryView.swift
//  COSMIC NOMAD: ECHOES
//
//  Creature catalog showing all scanned alien lifeforms.
//  Unscanned types show as locked entries.
//

import SwiftUI

struct BestiaryView: View {
    let onClose: () -> Void
    
    @State private var scannedCreatures: [String] = []
    
    private let allCreatures: [(name: String, type: String, icon: String, description: String, color: Color)] = [
        ("Luminous Drifter", "Floating Jellyfish", "drop.fill",
         "Bioluminescent organisms that drift through alien atmospheres. They pulse with soft light and are drawn to nearby movement. Mostly harmless, but their tentacles carry a mild electrical charge.",
         Color(red: 0.65, green: 0.74, blue: 0.92)),
        
        ("Husk Crawler", "Ground Crawler", "ant.fill",
         "Armored surface predators that patrol territorial routes. They detect vibrations through the ground and aggressively charge toward intruders. Their exoskeletons are remarkably dense.",
         Color(red: 0.88, green: 0.55, blue: 0.52)),
        
        ("Void Leviathan", "Sky Whale", "wind",
         "Massive aerial creatures that circle at extreme altitudes. They filter atmospheric particles for sustenance and communicate through deep infrasonic pulses that can be felt more than heard.",
         Color(red: 0.55, green: 0.72, blue: 0.92)),
    ]
    
    var body: some View {
        ZStack {
            Pastel.overlay.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BESTIARY")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(Pastel.tertiary)
                            .tracking(4)
                        
                        Text("\(scannedCreatures.count)/\(allCreatures.count) SPECIES CATALOGUED")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Pastel.textMuted)
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Pastel.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 50)
                .padding(.bottom, 16)
                
                // Divider
                Rectangle()
                    .fill(LinearGradient(colors: [Pastel.tertiary.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(allCreatures, id: \.name) { creature in
                            let isScanned = scannedCreatures.contains(creature.name)
                            CreatureCard(
                                name: creature.name,
                                type: creature.type,
                                icon: creature.icon,
                                description: creature.description,
                                color: creature.color,
                                isScanned: isScanned
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            scannedCreatures = SaveManager.shared.getScannedCreatures()
        }
    }
}

// MARK: - Creature Card

struct CreatureCard: View {
    let name: String
    let type: String
    let icon: String
    let description: String
    let color: Color
    let isScanned: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Creature icon
            ZStack {
                Circle()
                    .fill(isScanned ? color.opacity(0.15) : Pastel.cardFill)
                    .frame(width: 56, height: 56)
                Circle()
                    .stroke(isScanned ? color.opacity(0.4) : Pastel.cardStroke, lineWidth: 1)
                    .frame(width: 56, height: 56)
                
                if isScanned {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Pastel.textMuted)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(isScanned ? name : "???")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isScanned ? Pastel.textPrimary : Pastel.textMuted)
                    
                    if isScanned {
                        Text("CATALOGUED")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(Pastel.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Pastel.success.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
                
                Text(isScanned ? type : "Unknown Species")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isScanned ? color.opacity(0.8) : Pastel.textMuted)
                
                if isScanned {
                    Text(description)
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .foregroundColor(Pastel.textSecondary)
                        .lineSpacing(3)
                        .lineLimit(3)
                } else {
                    Text("Scan this creature to unlock its entry.")
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .foregroundColor(Pastel.textMuted)
                        .italic()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Pastel.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isScanned ? color.opacity(0.15) : Pastel.cardStroke, lineWidth: 1)
                )
        )
    }
}
