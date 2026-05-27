//
//  DailyRewardView.swift
//  COSMIC NOMAD: ECHOES
//
//  "Welcome Back, Nomad" daily login reward popup.
//  Shows streak counter with scaling Data Core rewards.
//

import SwiftUI

struct DailyRewardView: View {
    let reward: Int
    let streak: Int
    let onDismiss: () -> Void
    
    @State private var showReward: Bool = false
    @State private var headerOpacity: Double = 0
    @State private var rewardOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var pulseScale: CGFloat = 0.8
    
    private let dayRewards = [0, 1, 2, 3, 5, 5, 7, 10]  // Index 0 unused
    
    private let impactGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        ZStack {
            Pastel.overlay.opacity(0.92)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("WELCOME BACK")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Pastel.gold.opacity(0.7))
                        .tracking(6)
                    
                    Text("NOMAD")
                        .font(.system(size: 28, weight: .ultraLight, design: .serif))
                        .foregroundColor(Pastel.textPrimary)
                        .tracking(8)
                    
                    Rectangle()
                        .fill(Pastel.gold.opacity(0.3))
                        .frame(width: 60, height: 0.5)
                }
                .opacity(headerOpacity)
                
                // Streak display (7 circles)
                HStack(spacing: 10) {
                    ForEach(1...7, id: \.self) { day in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(day <= streak ? Pastel.gold.opacity(0.2) : Pastel.cardFill)
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .stroke(day <= streak ? Pastel.gold.opacity(0.5) : Pastel.cardStroke, lineWidth: day == streak ? 2 : 1)
                                    .frame(width: 36, height: 36)
                                
                                if day <= streak {
                                    Image(systemName: "diamond.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Pastel.gold)
                                } else {
                                    Text("\(dayRewards[day])")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(Pastel.textMuted)
                                }
                            }
                            .scaleEffect(day == streak ? pulseScale : 1.0)
                            
                            Text("D\(day)")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(day == streak ? Pastel.gold : Pastel.textMuted)
                        }
                    }
                }
                .opacity(rewardOpacity)
                
                // Reward amount
                VStack(spacing: 8) {
                    Text("DAY \(streak) REWARD")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Pastel.textMuted)
                        .tracking(3)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Pastel.gold)
                        
                        Text("+\(reward)")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(Pastel.gold)
                    }
                    
                    Text("DATA CORES")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Pastel.gold.opacity(0.6))
                        .tracking(3)
                }
                .opacity(rewardOpacity)
                
                // Collect button
                Button(action: {
                    if SettingsManager.shared.hapticsEnabled {
                        impactGenerator.notificationOccurred(.success)
                    }
                    onDismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("COLLECT")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(2)
                    }
                    .foregroundColor(Pastel.bg)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Pastel.gold, Pastel.gold.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Pastel.gold.opacity(0.25), radius: 10)
                }
                .opacity(buttonOpacity)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Pastel.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Pastel.gold.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                headerOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                rewardOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
                buttonOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.5)) {
                pulseScale = 1.1
            }
        }
    }
}
