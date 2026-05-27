//
//  StatisticsView.swift
//  COSMIC NOMAD: ECHOES
//
//  Full-screen statistics modal showing all tracked player stats.
//  Pastel matte aesthetic.
//

import SwiftUI

struct StatisticsView: View {
    let onClose: () -> Void
    
    private let stats = StatisticsManager.shared
    
    var body: some View {
        ZStack {
            Pastel.overlay.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STATISTICS")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(Pastel.primary)
                            .tracking(4)
                        
                        Text("YOUR JOURNEY IN NUMBERS")
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
                    .fill(LinearGradient(colors: [Pastel.primary.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Journey Section
                        StatSection(title: "JOURNEY", icon: "globe.americas.fill", color: Pastel.primary) {
                            StatRow(label: "Planets Completed", value: "\(stats.totalPlanetsCompleted)", icon: "globe")
                            StatRow(label: "Distance Traveled", value: stats.formattedDistance, icon: "figure.walk")
                            StatRow(label: "Play Time", value: stats.formattedPlayTime, icon: "clock")
                            StatRow(label: "Highest Star Rating", value: "\(stats.highestStarRating) ⭐", icon: "star.fill")
                        }
                        
                        // Discovery Section
                        StatSection(title: "DISCOVERY", icon: "antenna.radiowaves.left.and.right", color: Pastel.secondary) {
                            StatRow(label: "Signals Discovered", value: "\(stats.totalFragmentsDiscovered)", icon: "antenna.radiowaves.left.and.right")
                            StatRow(label: "Legendary Signals", value: "\(stats.totalLegendaryFragments)", icon: "sparkles")
                            StatRow(label: "Creatures Scanned", value: "\(stats.totalCreaturesScanned)", icon: "eye")
                            StatRow(label: "O₂ Caches Collected", value: "\(stats.totalOxygenCachesCollected)", icon: "drop.fill")
                        }
                        
                        // Performance Section
                        StatSection(title: "PERFORMANCE", icon: "bolt.fill", color: Pastel.combo) {
                            StatRow(label: "Signal Combos", value: "\(stats.totalCombosAchieved)", icon: "bolt.horizontal.fill")
                            StatRow(label: "Best Combo", value: "×\(stats.bestComboMultiplier)", icon: "flame.fill")
                            StatRow(label: "Bounties Completed", value: "\(stats.totalBountiesCompleted)", icon: "target")
                            StatRow(label: "Login Streak Record", value: "\(stats.longestLoginStreak) days", icon: "calendar")
                        }
                        
                        // Survival Section
                        StatSection(title: "SURVIVAL", icon: "shield.fill", color: Pastel.danger) {
                            StatRow(label: "Blackouts", value: "\(stats.totalBlackouts)", icon: "exclamationmark.triangle")
                            StatRow(label: "Hazard Zones Survived", value: "\(stats.totalHazardZonesSurvived)", icon: "flame")
                        }
                        
                        // Economy Section
                        StatSection(title: "ECONOMY", icon: "diamond.fill", color: Pastel.gold) {
                            StatRow(label: "Total Data Cores Earned", value: "\(stats.totalDataCoresEarned)", icon: "diamond.fill")
                            StatRow(label: "Endless Mode Best", value: "\(stats.endlessBestPlanets) planets", icon: "infinity")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Stat Section

struct StatSection<Content: View>: View {
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
                
                Rectangle()
                    .fill(color.opacity(0.15))
                    .frame(height: 1)
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Pastel.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Pastel.textMuted)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(Pastel.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Pastel.textPrimary)
        }
    }
}
