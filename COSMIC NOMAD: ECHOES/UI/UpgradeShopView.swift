//
//  UpgradeShopView.swift
//  COSMIC NOMAD: ECHOES
//
//  Full-screen overlay for purchasing suit upgrades with Data Cores.
//

import SwiftUI

struct UpgradeShopView: View {
    let onClose: () -> Void
    @State private var purchaseFlash: UpgradeSystem.UpgradeType? = nil
    @State private var dataCores: Int = UpgradeSystem.shared.dataCores
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.92).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SUIT UPGRADES")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(4)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            Text("\(dataCores) DATA CORES")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
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
                    .fill(maxed ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08))
                    .frame(width: 50, height: 50)
                
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(maxed ? .cyan : .white.opacity(0.7))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(type.rawValue.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(type.description)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                
                // Tier dots
                HStack(spacing: 6) {
                    ForEach(0..<UpgradeSystem.UpgradeType.maxTier, id: \.self) { i in
                        Circle()
                            .fill(i < tier ? Color.cyan : Color.white.opacity(0.15))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    
                    Text("TIER \(tier)/\(UpgradeSystem.UpgradeType.maxTier)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            
            Spacer()
            
            // Buy button
            if maxed {
                Text("MAX")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Button(action: onPurchase) {
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 9))
                        Text("\(nextCost)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(canBuy ? .black : .white.opacity(0.3))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(canBuy ? Color.yellow : Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .disabled(!canBuy)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isFlashing ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFlashing ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
