//
//  GameCompletionViews.swift
//  COSMIC NOMAD: ECHOES
//
//  Planet Decoded cinematic screen and Final Revelation endgame screen.
//  These are the key reward moments in the game loop.
//  Pastel matte color aesthetic.
//

import SwiftUI

// MARK: - Planet Decoded Screen

struct PlanetDecodedView: View {
    let planetName: String
    let planetMood: PlanetMood
    let planetsCompleted: Int
    let totalPlanets: Int
    let onContinue: () -> Void
    
    @State private var phase: Int = 0
    @State private var textOpacity: Double = 0
    @State private var summaryOpacity: Double = 0
    @State private var quoteOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0
    
    private let impactGenerator = UINotificationFeedbackGenerator()
    
    // Get the unique quote for this planet level
    private var levelQuote: (quote: String, author: String) {
        LoreLibrary.planetQuote(forLevel: planetsCompleted)
    }
    
    var body: some View {
        ZStack {
            // Dark overlay
            Pastel.bg.opacity(0.95)
                .ignoresSafeArea()
            
            // Animated ring
            Circle()
                .stroke(moodColor.opacity(ringOpacity * 0.7), lineWidth: 2)
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale)
            
            Circle()
                .stroke(moodColor.opacity(ringOpacity * 0.35), lineWidth: 1)
                .frame(width: 260, height: 260)
                .scaleEffect(ringScale * 0.9)
            
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: geo.size.height > 700 ? 24 : 16) {
                        Spacer(minLength: 40)
                        
                        // Status
                        Text("PLANET DECODED")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(moodColor)
                            .tracking(8)
                            .opacity(textOpacity)
                        
                        // Planet name
                        Text(planetName.uppercased())
                            .font(.system(size: 28, weight: .ultraLight, design: .serif))
                            .foregroundColor(Pastel.textPrimary)
                            .tracking(6)
                            .minimumScaleFactor(0.5)
                            .opacity(textOpacity)
                        
                        // Mood badge
                        Text(planetMood.rawValue.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(moodColor.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(moodColor.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(moodColor.opacity(0.2), lineWidth: 0.5))
                            .opacity(textOpacity)
                        
                        // Divider
                        Rectangle()
                            .fill(moodColor.opacity(0.25))
                            .frame(width: 100, height: 0.5)
                            .opacity(summaryOpacity)
                        
                        // Planet-specific summary (unique per level!)
                        Text(LoreLibrary.planetSummary(forLevel: planetsCompleted))
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundColor(Pastel.textPrimary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 40)
                            .minimumScaleFactor(0.7)
                            .opacity(summaryOpacity)
                        
                        // Unique inspirational quote per level
                        VStack(spacing: 8) {
                            Rectangle()
                                .fill(moodColor.opacity(0.12))
                                .frame(width: 30, height: 0.5)
                            
                            Text(levelQuote.quote)
                                .font(.system(size: 13, weight: .light, design: .serif))
                                .italic()
                                .foregroundColor(moodColor.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.horizontal, 36)
                                .minimumScaleFactor(0.7)
                            
                            Text(levelQuote.author)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Pastel.textMuted)
                                .tracking(1)
                        }
                        .padding(.vertical, 8)
                        .opacity(quoteOpacity)
                        
                        // Signals collected
                        Text("ALL SIGNALS RECONSTRUCTED")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Pastel.textMuted)
                            .opacity(quoteOpacity)
                        
                        Spacer(minLength: 40)
                        
                        // Progress dots
                        HStack(spacing: 12) {
                            ForEach(0..<totalPlanets, id: \.self) { i in
                                Circle()
                                    .fill(i < planetsCompleted ? moodColor : Pastel.cardStroke)
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        Circle()
                                            .stroke(Pastel.textMuted, lineWidth: 0.5)
                                    )
                            }
                        }
                        .opacity(buttonOpacity)
                        
                        // Continue button
                        Button(action: onContinue) {
                            HStack(spacing: 10) {
                                Text(planetsCompleted < totalPlanets ? "TRAVEL TO NEXT WORLD" : "FINAL REVELATION")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Pastel.bg)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Pastel.bg)
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(moodColor)
                            .clipShape(Capsule())
                        }
                        .opacity(buttonOpacity)
                        .padding(.bottom, 40)
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .onAppear {
            if SettingsManager.shared.hapticsEnabled {
                impactGenerator.notificationOccurred(.success)
            }
            
            withAnimation(.easeOut(duration: 1.5)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.0).delay(1.5)) {
                summaryOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.2).delay(2.5)) {
                quoteOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(3.8)) {
                buttonOpacity = 1.0
            }
        }
    }
    
    private var moodColor: Color {
        Pastel.moodColor(planetMood)
    }
}

// MARK: - Final Revelation Screen

struct FinalRevelationView: View {
    let onRestart: () -> Void
    
    @State private var phase1: Double = 0
    @State private var phase2: Double = 0
    @State private var phase3: Double = 0
    @State private var phase4: Double = 0
    
    var body: some View {
        ZStack {
            // Deep matte background
            Pastel.bg
                .ignoresSafeArea()
            
            // Subtle starfield
            GeometryReader { geo in
                ForEach(0..<60, id: \.self) { i in
                    Circle()
                        .fill(Pastel.textPrimary.opacity(Double.random(in: 0.06...0.35)))
                        .frame(width: CGFloat.random(in: 1...2.5))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .opacity(phase1)
                }
            }
            
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: geo.size.height > 700 ? 30 : 20) {
                        Spacer(minLength: 60)
                        
                        // Title
                        VStack(spacing: 12) {
                            Text("THE FINAL ECHO")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Pastel.primary)
                                .tracking(10)
                                .opacity(phase1)
                            
                            Rectangle()
                                .fill(Pastel.primary.opacity(0.25))
                                .frame(width: 60, height: 0.5)
                                .opacity(phase1)
                        }
                        
                        // Revelation text
                        Text(LoreLibrary.finalRevelation)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundColor(Pastel.textPrimary.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                            .padding(.horizontal, 36)
                            .minimumScaleFactor(0.7)
                            .opacity(phase2)
                        
                        Spacer(minLength: 60)
                        
                        // Journey stats
                        VStack(spacing: 8) {
                            Text("JOURNEY COMPLETE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Pastel.textMuted)
                                .tracking(4)
                            
                            Text("5 worlds explored  •  100 signals decoded")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(Pastel.textMuted.opacity(0.8))
                            
                            // 5 filled dots
                            HStack(spacing: 8) {
                                ForEach(0..<5, id: \.self) { _ in
                                    Circle()
                                        .fill(Pastel.primary)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .opacity(phase3)
                        
                        // Restart button
                        Button(action: onRestart) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .bold))
                                Text("BEGIN AGAIN")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(Pastel.textPrimary)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Pastel.cardFill)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Pastel.primary.opacity(0.4), lineWidth: 1))
                        }
                        .opacity(phase4)
                        .padding(.bottom, 60)
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.0)) { phase1 = 1.0 }
            withAnimation(.easeOut(duration: 2.0).delay(1.5)) { phase2 = 1.0 }
            withAnimation(.easeOut(duration: 1.5).delay(3.5)) { phase3 = 1.0 }
            withAnimation(.easeOut(duration: 1.0).delay(5.0)) { phase4 = 1.0 }
        }
    }
}
