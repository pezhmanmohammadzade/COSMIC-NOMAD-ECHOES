//
//  UpgradeShopView.swift
//  COSMIC NOMAD: ECHOES
//
//  Full-screen overlay for purchasing suit upgrades with Data Cores.
//  Pastel matte color aesthetic.
//

import SwiftUI

struct UpgradeShopView: View {
    let onClose: () -> Void
    @State private var purchaseFlash: UpgradeSystem.UpgradeType? = nil
    @State private var dataCores: Int = UpgradeSystem.shared.dataCores
    
    var body: some View {
        ZStack {
            // Background
            Pastel.overlay.opacity(0.96).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SUIT UPGRADES")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(Pastel.textPrimary)
                            .tracking(4)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Pastel.gold)
                            Text("\(dataCores) DATA CORES")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(Pastel.gold)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Pastel.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                
                // Upgrade Cards
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(UpgradeSystem.UpgradeType.allCases, id: \.rawValue) { type in
                            UpgradeCardView(
                                type: type,
                                dataCores: dataCores,
                                isFlashing: purchaseFlash == type,
                                onPurchase: {
                                    purchaseUpgrade(type)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .transition(.opacity)
    }
    
    private func purchaseUpgrade(_ type: UpgradeSystem.UpgradeType) {
        guard UpgradeSystem.shared.purchase(type) else { return }
        dataCores = UpgradeSystem.shared.dataCores
        
        withAnimation(.easeOut(duration: 0.15)) {
            purchaseFlash = type
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { purchaseFlash = nil }
        }
    }
}

// MARK: - Upgrade Card

struct UpgradeCardView: View {
    let type: UpgradeSystem.UpgradeType
    let dataCores: Int
    let isFlashing: Bool
    let onPurchase: () -> Void
    
    var body: some View {
        let tier = UpgradeSystem.shared.currentTier(for: type)
        let maxed = UpgradeSystem.shared.isMaxed(type)
        let canBuy = UpgradeSystem.shared.canUpgrade(type)
        let nextCost = maxed ? 0 : type.cost(forTier: tier + 1)
        
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(maxed ? Pastel.primary.opacity(0.15) : Pastel.cardFill)
                    .frame(width: 50, height: 50)
                
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(maxed ? Pastel.primary : Pastel.textSecondary)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(type.rawValue.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Pastel.textPrimary)
                
                Text(type.description)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(Pastel.textSecondary)
                
                // Tier dots
                HStack(spacing: 6) {
                    ForEach(0..<UpgradeSystem.UpgradeType.maxTier, id: \.self) { i in
                        Circle()
                            .fill(i < tier ? Pastel.primary : Pastel.cardStroke)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle().stroke(Pastel.cardStroke, lineWidth: 0.5)
                            )
                    }
                    
                    Text("TIER \(tier)/\(UpgradeSystem.UpgradeType.maxTier)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Pastel.textMuted)
                }
            }
            
            Spacer()
            
            // Buy button
            if maxed {
                Text("MAX")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Pastel.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Pastel.primary.opacity(0.10))
                    .clipShape(Capsule())
            } else {
                Button(action: onPurchase) {
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 9))
                        Text("\(nextCost)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(canBuy ? Pastel.bg : Pastel.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(canBuy ? Pastel.gold : Pastel.cardFill)
                    .clipShape(Capsule())
                }
                .disabled(!canBuy)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isFlashing ? Pastel.primary.opacity(0.10) : Pastel.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFlashing ? Pastel.primary.opacity(0.4) : Pastel.cardStroke, lineWidth: 1)
                )
        )
    }
}
