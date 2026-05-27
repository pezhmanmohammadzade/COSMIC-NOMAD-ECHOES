//
//  AchievementsView.swift
//  COSMIC NOMAD: ECHOES
//
//  A UI overlay showing all discovered space facts,
//  grouped by the planet/level they were found on.
//  Pastel matte color aesthetic.
//

import SwiftUI

struct AchievementsView: View {
    let onClose: () -> Void
    
    @State private var discoveredFacts: [SpaceFact] = []
    
    // Group facts by their mood or approximate level (using ID ranges)
    // Since IDs increment sequentially in our generator, we can group them loosely.
    var groupedFacts: [String: [SpaceFact]] {
        Dictionary(grouping: discoveredFacts, by: { fact in
            // For now, group by mood to give a thematic categorization
            return fact.mood.capitalized
        })
    }
    
    var body: some View {
        ZStack {
            // Background blur
            Pastel.overlay.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ARCHIVE")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(Pastel.primary)
                        
                        Text("\(discoveredFacts.count) SIGNALS DISCOVERED")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Pastel.secondary.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Pastel.textSecondary)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Divider
                Rectangle()
                    .fill(
                        LinearGradient(colors: [Pastel.primary.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(height: 1)
                    .padding(.bottom, 20)
                
                // Fact List
                if discoveredFacts.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(Pastel.textMuted)
                        Text("No signals discovered yet.")
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundStyle(Pastel.textMuted)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 30) {
                            ForEach(groupedFacts.keys.sorted(), id: \.self) { group in
                                VStack(alignment: .leading, spacing: 16) {
                                    // Group Header
                                    HStack {
                                        Text(group.uppercased())
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Pastel.textSecondary)
                                        
                                        Rectangle()
                                            .fill(Pastel.cardStroke)
                                            .frame(height: 1)
                                    }
                                    
                                    // Facts in this group
                                    ForEach(groupedFacts[group] ?? [], id: \.id) { fact in
                                        FactCard(fact: fact)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 60)
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
        
        // Sort by ID to keep chronological discovery order roughly intact
        self.discoveredFacts = loaded.sorted { $0.id < $1.id }
    }
}

struct FactCard: View {
    let fact: SpaceFact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(Pastel.primary)
                
                Text(fact.title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Pastel.primary.opacity(0.9))
                
                Spacer()
                
                Text("#\(fact.id)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Pastel.textMuted)
            }
            
            Text(fact.fact)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundStyle(Pastel.textPrimary.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Pastel.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Pastel.cardStroke, lineWidth: 1)
                )
        )
    }
}
