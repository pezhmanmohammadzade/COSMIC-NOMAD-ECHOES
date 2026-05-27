//
//  OnboardingView.swift
//  COSMIC NOMAD: ECHOES
//
//  Modern, graphical onboarding shown once upon install.
//  Pastel matte color aesthetic.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Binding var currentAppState: AppState
    
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            Pastel.bg.ignoresSafeArea()
            
            // Subtle animated background
            AnimatedStarfield()
            
            TabView(selection: $currentPage) {
                // Page 1: Introduction
                OnboardingPage(
                    title: "WELCOME NOMAD",
                    subtitle: "A universe of silence awaits.",
                    description: "You are the last listener, drifting through forgotten worlds to uncover the echoes of what was lost.",
                    icon: "sparkles",
                    color: Pastel.primary
                )
                .tag(0)
                
                // Page 2: Exploration
                OnboardingPage(
                    title: "EXPLORATION",
                    subtitle: "Navigate the unknown.",
                    description: "Use the virtual joystick on the left to move across procedurally generated planets. Every world is unique.",
                    icon: "location.circle",
                    color: Pastel.secondary
                )
                .tag(1)
                
                // Page 3: Survival
                OnboardingPage(
                    title: "SURVIVAL",
                    subtitle: "Manage your suit resources.",
                    description: "Your oxygen depletes over time. Hostile planets drain it faster. Find signals to refill O₂ and earn Data Cores for upgrades.",
                    icon: "lungs",
                    color: Pastel.danger
                )
                .tag(2)
                
                // Page 4: Jetpack & Upgrades
                OnboardingPage(
                    title: "UPGRADES",
                    subtitle: "Evolve your suit.",
                    description: "Use the jetpack to reach high terrain. Spend Data Cores in the Upgrade Shop to boost oxygen, power, speed, and scanner range.",
                    icon: "arrow.up.to.line",
                    color: Pastel.gold
                )
                .tag(3)
                
                // Page 5: Anomalies
                OnboardingPage(
                    title: "ANOMALIES",
                    subtitle: "Danger and reward.",
                    description: "Watch for geysers, radiation zones, and energy vortexes. Some drain your suit; others reward you with bonus Data Cores.",
                    icon: "tornado",
                    color: Pastel.tertiary
                )
                .tag(4)
                
                // Page 6: Scanning
                OnboardingPage(
                    title: "DISCOVERY",
                    subtitle: "Listen to the echoes.",
                    description: "Follow the scanner to locate memory fragments. Stand near them to reconstruct the history of the world.",
                    icon: "antenna.radiowaves.left.and.right",
                    color: Pastel.success
                )
                .tag(5)
                
                // Page 7: Begin
                VStack(spacing: 40) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "globe.americas")
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundStyle(Pastel.primary)
                            .shadow(color: Pastel.primary.opacity(0.4), radius: 20)
                        
                        Text("YOUR JOURNEY BEGINS")
                            .font(.system(size: 24, weight: .ultraLight, design: .serif))
                            .foregroundStyle(Pastel.textPrimary)
                            .tracking(8)
                        
                        Text("Decode \(GameEngine.totalPlanetsForEnding) planets to reach the final revelation.")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(Pastel.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            hasSeenOnboarding = true
                            currentAppState = .mainMenu
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("AWAKEN")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(Pastel.bg)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Pastel.primary)
                        .clipShape(Capsule())
                        .shadow(color: Pastel.primary.opacity(0.3), radius: 10)
                    }
                    .padding(.bottom, 80)
                }
                .tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Onboarding Page Component
struct OnboardingPage: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    
    @State private var iconScale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 80, weight: .ultraLight))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.35), radius: 20)
                .scaleEffect(iconScale)
                .opacity(opacity)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 28, weight: .ultraLight, design: .serif))
                    .foregroundStyle(Pastel.textPrimary)
                    .tracking(6)
                    .opacity(opacity)
                
                Rectangle()
                    .fill(color.opacity(0.4))
                    .frame(width: 40, height: 1)
                    .opacity(opacity)
                
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(color.opacity(0.75))
                    .opacity(opacity)
                
                Text(description)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(Pastel.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                    .opacity(opacity)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                iconScale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Background Stars
struct AnimatedStarfield: View {
    @State private var phase: Double = 0
    
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<50, id: \.self) { i in
                Circle()
                    .fill(Pastel.textPrimary.opacity(Double.random(in: 0.06...0.28)))
                    .frame(width: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height)
                    )
                    .scaleEffect(CGFloat(sin(phase + Double(i)) * 0.2 + 0.8))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}
