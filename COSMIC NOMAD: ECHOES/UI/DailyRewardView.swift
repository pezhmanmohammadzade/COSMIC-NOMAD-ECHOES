//
//  DailyRewardView.swift
//  COSMIC NOMAD: ECHOES
//
//  AAA Sci-Fi Orbital Re-Supply Pod / Daily Telemetry Link.
//  Tactical authorization sequence for orbital cargo and Data Cores.
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
    @State private var pulseScale: CGFloat = 0.95
    @State private var coreRotation: Double = 0
    
    private let dayRewards = [0, 1, 2, 3, 5, 5, 7, 10]
    private let impactGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        ZStack {
            // Backdrop with dark glass overlay
            Color(red: 0.02, green: 0.03, blue: 0.06).opacity(0.94).ignoresSafeArea()
            
            // Atmospheric scanlines
            AAAScanlineOverlay()
                .opacity(0.4)
                .ignoresSafeArea()
            
            // Central Telemetry Cargo Terminal
            VStack(spacing: 20) {
                // Top Telemetry Header
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.95, green: 0.75, blue: 0.25))
                            .frame(width: 6, height: 6)
                            .shadow(color: Color(red: 0.95, green: 0.75, blue: 0.25), radius: 5)
                        
                        Text("ORBITAL RE-SUPPLY CARRIER // SYS_PAYLOAD")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.85))
                            .tracking(2)
                    }
                    
                    Text("NOMAD TELEMETRY LINK")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)
                    
                    Text("DAILY RE-SUPPLY PROTOCOL ACTIVE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.5)
                }
                .opacity(headerOpacity)
                
                // Streak Timeline Conduit (7 Chamfered Cells)
                ZStack {
                    // Laser conduit track
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 2)
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            let isPastOrCurrent = day <= streak
                            let isCurrent = day == streak
                            
                            VStack(spacing: 4) {
                                ZStack {
                                    AAAShape.ChamferedRectangle(chamfer: 4)
                                        .fill(isCurrent ? Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.25) : (isPastOrCurrent ? Color.white.opacity(0.08) : Color.white.opacity(0.02)))
                                        .frame(width: 38, height: 38)
                                    
                                    AAAShape.ChamferedRectangle(chamfer: 4)
                                        .stroke(isCurrent ? Color(red: 0.95, green: 0.75, blue: 0.25) : (isPastOrCurrent ? Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.4) : Color.white.opacity(0.12)), lineWidth: isCurrent ? 2 : 1)
                                        .frame(width: 38, height: 38)
                                    
                                    if isPastOrCurrent {
                                        Image(systemName: "diamond.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))
                                            .shadow(color: isCurrent ? Color(red: 0.95, green: 0.75, blue: 0.25) : .clear, radius: 4)
                                    } else {
                                        Text("\(dayRewards[day])")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                                .scaleEffect(isCurrent ? pulseScale : 1.0)
                                
                                Text("DAY \(day)")
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundColor(isCurrent ? Color(red: 0.95, green: 0.75, blue: 0.25) : .white.opacity(0.35))
                            }
                        }
                    }
                }
                .opacity(rewardOpacity)
                .padding(.vertical, 6)
                
                // Big Reward Telemetry Pod
                VStack(spacing: 10) {
                    ZStack {
                        // Rotating tech reticle
                        Circle()
                            .stroke(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(coreRotation))
                        
                        Circle()
                            .fill(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.12))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))
                            .shadow(color: Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.8), radius: 10)
                    }
                    
                    HStack(spacing: 6) {
                        Text("+\(reward)")
                            .font(.system(size: 34, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))
                        
                        Text("DATA CORES")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .tracking(2)
                    }
                    
                    Text("TELEMETRIC BUFFER CRATE // STREAK MULTIPLIER: \(streak)x")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.7))
                }
                .opacity(rewardOpacity)
                
                // Tactical Collect Button
                Button(action: {
                    if SettingsManager.shared.hapticsEnabled {
                        impactGenerator.notificationOccurred(.success)
                    }
                    onDismiss()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.to.line.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                        
                        Text("AUTHORIZE RECOVERY")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .tracking(2.5)
                    }
                    .foregroundColor(Color(red: 0.05, green: 0.06, blue: 0.1))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.85, blue: 0.35),
                                Color(red: 0.90, green: 0.65, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(AAAShape.ChamferedRectangle(chamfer: 8))
                    .overlay(
                        AAAShape.ChamferedRectangle(chamfer: 8)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.4), radius: 12)
                }
                .opacity(buttonOpacity)
            }
            .padding(28)
            .background(
                ZStack {
                    AAAShape.ChamferedRectangle(chamfer: 14)
                        .fill(Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.92))
                    
                    AAAShape.ChamferedRectangle(chamfer: 14)
                        .stroke(Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.3), lineWidth: 1)
                    
                    AAAHUDCornerBrackets(bracketSize: 14, color: Color(red: 0.95, green: 0.75, blue: 0.25))
                        .padding(4)
                }
            )
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                headerOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                rewardOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                buttonOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
            withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
                coreRotation = 360
            }
        }
    }
}
