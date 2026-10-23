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
            // Icon in chamfered tech container
            ZStack {
                AAAShape.ChamferedRectangle(chamferSize: 8)
                    .fill(maxed ? Pastel.primary.opacity(0.18) : Pastel.surface.opacity(0.85))
                    .frame(width: 48, height: 48)
                
                AAAShape.ChamferedRectangle(chamferSize: 8)
                    .stroke(maxed ? Pastel.primary.opacity(0.6) : Pastel.cardStroke, lineWidth: 1)
                    .frame(width: 48, height: 48)
                
                Image(systemName: type.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(maxed ? Pastel.primary : Pastel.textSecondary)
                    .shadow(color: maxed ? Pastel.primary.opacity(0.5) : Color.clear, radius: 4)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 5) {
                Text(type.rawValue.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(Pastel.textPrimary)
                
                Text(type.description)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Pastel.textSecondary)
                
                // Tier telemetry dots
                HStack(spacing: 6) {
                    ForEach(0..<UpgradeSystem.UpgradeType.maxTier, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(i < tier ? Pastel.primary : Pastel.cardStroke)
                            .frame(width: 14, height: 4)
                            .shadow(color: i < tier ? Pastel.primary.opacity(0.7) : Color.clear, radius: 2)
                    }
                    
                    Text("TIER \(tier)/\(UpgradeSystem.UpgradeType.maxTier)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(maxed ? Pastel.primary : Pastel.textMuted)
                }
            }
            
            Spacer()
            
            // Buy button
            if maxed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("MAXED")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(Pastel.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Pastel.primary.opacity(0.12))
                .overlay(Capsule().stroke(Pastel.primary.opacity(0.3), lineWidth: 1))
                .clipShape(Capsule())
            } else {
                Button(action: onPurchase) {
                    HStack(spacing: 5) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(nextCost)")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(canBuy ? Pastel.bg : Pastel.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        canBuy ?
                            LinearGradient(colors: [Pastel.gold, Color(red: 0.95, green: 0.75, blue: 0.40)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Pastel.cardFill, Pastel.cardFill], startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(Capsule())
                    .shadow(color: canBuy ? Pastel.gold.opacity(0.4) : Color.clear, radius: 6)
                }
                .disabled(!canBuy)
            }
        }
        .padding(16)
        .background(
            AAAShape.ChamferedRectangle(chamferSize: 10)
                .fill(isFlashing ? Pastel.primary.opacity(0.16) : Pastel.surface.opacity(0.85))
                .overlay(
                    AAAShape.ChamferedRectangle(chamferSize: 10)
                        .stroke(
                            isFlashing ? Pastel.primary : (maxed ? Pastel.primary.opacity(0.3) : Pastel.cardStroke),
                            lineWidth: isFlashing ? 1.5 : 1.0
                        )
                )
        )
        .overlay(AAAHUDCornerBrackets(color: (maxed ? Pastel.primary : Pastel.cardStroke).opacity(0.4), length: 6))
    }
}
