//
//  GameCompletionViews.swift
//  COSMIC NOMAD: ECHOES
//
//  Planet Decoded cinematic screen and Final Revelation endgame screen.
//  These are the key reward moments in the game loop.
//  Pastel matte color aesthetic with fun rounded typography.
//

import SwiftUI

// MARK: - Planet Decoded Screen

struct PlanetDecodedView: View {
    let planetName: String
    let planetMood: PlanetMood
    let planetsCompleted: Int
    let totalPlanets: Int
    let starRating: Int  // 1-3 stars earned
    let bountiesCompleted: [String]  // Names of completed bounties
    let onContinue: () -> Void
    
    @State private var phase: Int = 0
    @State private var textOpacity: Double = 0
    @State private var summaryOpacity: Double = 0
    @State private var quoteOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0
    @State private var starsOpacity: Double = 0
    @State private var bountyOpacity: Double = 0
    
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
                .frame(width: 160, height: 160)
                .scaleEffect(ringScale)
            
            Circle()
                .stroke(moodColor.opacity(ringOpacity * 0.35), lineWidth: 1)
                .frame(width: 210, height: 210)
                .scaleEffect(ringScale * 0.9)
            
            GeometryReader { geo in
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 18) { // Increased spacing slightly
                        Spacer(minLength: 30)
                        
                        // Status
                        Text("PLANET DECODED")
                            .font(.custom("Chalkboard SE", size: 13).weight(.heavy))
                            .foregroundColor(moodColor)
                            .tracking(6)
                            .opacity(textOpacity)
                        
                        // Planet name
                        Text(planetName.uppercased())
                            .font(.custom("Chalkboard SE", size: 26).weight(.bold))
                            .foregroundColor(Pastel.textPrimary)
                            .tracking(4)
                            .minimumScaleFactor(0.5)
                            .opacity(textOpacity)
                        
                        // Mood badge
                        Text(planetMood.rawValue.uppercased())
                            .font(.custom("Chalkboard SE", size: 10).weight(.semibold))
                            .foregroundColor(moodColor.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(moodColor.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(moodColor.opacity(0.2), lineWidth: 0.5))
                            .opacity(textOpacity)
                        
                        // Divider
                        Rectangle()
                            .fill(moodColor.opacity(0.25))
                            .frame(width: 80, height: 0.5)
                            .opacity(summaryOpacity)
                        
                        // Planet-specific summary in a minimal transparent box
                        VStack {
                            Text(LoreLibrary.planetSummary(forLevel: planetsCompleted))
                                .font(.custom("Chalkboard SE", size: 10).weight(.regular))
                                .foregroundColor(Pastel.textPrimary.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(moodColor.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(moodColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 48)
                        .opacity(summaryOpacity)
                        
                        // Unique inspirational quote in a minimal box
                        VStack(spacing: 8) {
                            Text(levelQuote.quote)
                                .font(.custom("Chalkboard SE", size: 12).weight(.regular))
                                .italic()
                                .foregroundColor(moodColor.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .minimumScaleFactor(0.7)
                            
                            Text(levelQuote.author)
                                .font(.custom("Chalkboard SE", size: 9).weight(.bold))
                                .foregroundColor(Pastel.textMuted)
                                .tracking(1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(moodColor.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(moodColor.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 32)
                        .opacity(quoteOpacity)
                        
                        // Signals collected
                        Text("ALL SIGNALS RECONSTRUCTED")
                            .font(.custom("Chalkboard SE", size: 9).weight(.heavy))
                            .foregroundColor(Pastel.textMuted)
                            .tracking(1)
                            .opacity(quoteOpacity)
                        
                        // Star Rating in a box
                        VStack(spacing: 8) {
                            Text("PERFORMANCE")
                                .font(.custom("Chalkboard SE", size: 9).weight(.bold))
                                .foregroundColor(Pastel.textPrimary.opacity(0.7))
                                .tracking(2)
                            
                            HStack(spacing: 8) {
                                ForEach(0..<3, id: \.self) { s in
                                    Image(systemName: s < starRating ? "star.fill" : "star")
                                        .font(.system(size: 22))
                                        .foregroundColor(s < starRating ? Pastel.gold : Pastel.textMuted.opacity(0.2))
                                        .scaleEffect(s < starRating ? 1.0 : 0.8)
                                }
                            }
                            
                            Text(starRatingDescription)
                                .font(.custom("Chalkboard SE", size: 10).weight(.medium))
                                .foregroundColor(Pastel.textMuted)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(moodColor.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Pastel.gold.opacity(0.25), lineWidth: 1)
                                )
                        )
                        .opacity(starsOpacity)
                        
                        // Bounties completed in a box
                        if !bountiesCompleted.isEmpty {
                            VStack(spacing: 6) {
                                Text("BOUNTIES COMPLETED")
                                    .font(.custom("Chalkboard SE", size: 9).weight(.bold))
                                    .foregroundColor(Pastel.bounty)
                                    .tracking(2)
                                
                                ForEach(bountiesCompleted, id: \.self) { name in
                                    HStack(spacing: 6) {
                                        Image(systemName: "target")
                                            .font(.system(size: 9))
                                        Text(name)
                                            .font(.custom("Chalkboard SE", size: 11).weight(.bold))
                                    }
                                    .foregroundColor(Pastel.bounty.opacity(0.9))
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Pastel.bounty.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Pastel.bounty.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .opacity(bountyOpacity)
                        }
                        
                        Spacer(minLength: 20)
                        
                        // Progress dots
                        HStack(spacing: 10) {
                            ForEach(0..<totalPlanets, id: \.self) { i in
                                Circle()
                                    .fill(i < planetsCompleted ? moodColor : Pastel.cardStroke)
                                    .frame(width: 8, height: 8)
                                    .overlay(
                                        Circle()
                                            .stroke(Pastel.textMuted, lineWidth: 0.5)
                                    )
                            }
                        }
                        .opacity(buttonOpacity)
                        
                        // Continue button
                        Button(action: onContinue) {
                            HStack(spacing: 8) {
                                Text(planetsCompleted < totalPlanets ? "TRAVEL TO NEXT WORLD" : "FINAL REVELATION")
                                    .font(.custom("Chalkboard SE", size: 13).weight(.heavy))
                                    .foregroundColor(Pastel.bg)
                                
                                Image(systemName: "arrow.right")
                                    .font(.custom("Chalkboard SE", size: 12).weight(.bold))
                                    .foregroundColor(Pastel.bg)
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 14)
                            .background(moodColor)
                            .clipShape(Capsule())
                        }
                        .opacity(buttonOpacity)
                        
                        // Scroll indicator
                        VStack(spacing: 2) {
                            Image(systemName: "chevron.compact.down")
                                .font(.system(size: 16))
                                .foregroundColor(Pastel.textMuted.opacity(0.5))
                            Text("scroll")
                                .font(.custom("Chalkboard SE", size: 8).weight(.bold))
                                .foregroundColor(Pastel.textMuted.opacity(0.4))
                        }
                        .opacity(buttonOpacity * 0.7)
                        .padding(.bottom, 30)
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
            withAnimation(.easeOut(duration: 1.0).delay(4.5)) {
                starsOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(5.0)) {
                bountyOpacity = 1.0
            }
        }
    }
    
    private var moodColor: Color {
        Pastel.moodColor(planetMood)
    }
    
    private var starRatingDescription: String {
        switch starRating {
        case 3: return "Perfect run — no blackouts!"
        case 2: return "Good pace — try without blackouts for 3 stars"
        default: return "Planet decoded — keep exploring for more stars"
        }
    }
}

// MARK: - Final Revelation Screen

struct FinalRevelationView: View {
    let onRestart: () -> Void
    let onEndlessMode: () -> Void
    
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
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 24) {
                        Spacer(minLength: 40)
                        
                        // Title
                        VStack(spacing: 12) {
                            Text("THE FINAL ECHO")
                                .font(.custom("Chalkboard SE", size: 15).weight(.heavy))
                                .foregroundColor(Pastel.primary)
                                .tracking(8)
                                .opacity(phase1)
                            
                            Rectangle()
                                .fill(Pastel.primary.opacity(0.3))
                                .frame(width: 60, height: 1)
                                .opacity(phase1)
                        }
                        
                        // Revelation text in a minimal transparent box
                        VStack {
                            Text(LoreLibrary.finalRevelation)
                                .font(.custom("Chalkboard SE", size: 15).weight(.medium))
                                .foregroundColor(Pastel.textPrimary.opacity(0.95))
                                .multilineTextAlignment(.center)
                                .lineSpacing(8)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Pastel.primary.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Pastel.primary.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .opacity(phase2)
                        
                        Spacer(minLength: 30)
                        
                        // Journey stats in a minimal box
                        VStack(spacing: 8) {
                            Text("JOURNEY COMPLETE")
                                .font(.custom("Chalkboard SE", size: 11).weight(.heavy))
                                .foregroundColor(Pastel.textMuted)
                                .tracking(3)
                            
                            let stats = StatisticsManager.shared
                            Text("\(stats.totalPlanetsCompleted) worlds  •  \(stats.totalFragmentsDiscovered) signals  •  \(stats.formattedPlayTime)")
                                .font(.custom("Chalkboard SE", size: 11).weight(.bold))
                                .foregroundColor(Pastel.textPrimary.opacity(0.7))
                            
                            // 5 filled dots
                            HStack(spacing: 8) {
                                ForEach(0..<5, id: \.self) { _ in
                                    Circle()
                                        .fill(Pastel.primary.opacity(0.8))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 30)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Pastel.primary.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Pastel.textMuted.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .opacity(phase3)
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            // Endless Mode button (Primary)
                            Button(action: onEndlessMode) {
                                HStack(spacing: 8) {
                                    Image(systemName: "infinity")
                                        .font(.custom("Chalkboard SE", size: 14).weight(.bold))
                                    Text("ENDLESS MODE")
                                        .font(.custom("Chalkboard SE", size: 13).weight(.heavy))
                                }
                                .foregroundColor(Pastel.bg)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Pastel.tertiary, Pastel.primary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: Pastel.tertiary.opacity(0.4), radius: 10)
                            }
                            
                            // Restart button (Secondary)
                            Button(action: onRestart) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.custom("Chalkboard SE", size: 12).weight(.bold))
                                    Text("BEGIN AGAIN")
                                        .font(.custom("Chalkboard SE", size: 12).weight(.bold))
                                }
                                .foregroundColor(Pastel.textPrimary.opacity(0.8))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Pastel.primary.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Pastel.primary.opacity(0.3), lineWidth: 1))
                            }
                        }
                        .padding(.top, 10)
                        .opacity(phase4)
                        
                        // Scroll indicator
                        VStack(spacing: 2) {
                            Image(systemName: "chevron.compact.down")
                                .font(.system(size: 16))
                                .foregroundColor(Pastel.textMuted.opacity(0.5))
                            Text("scroll")
                                .font(.custom("Chalkboard SE", size: 8).weight(.bold))
                                .foregroundColor(Pastel.textMuted.opacity(0.4))
                        }
                        .opacity(phase4 * 0.7)
                        .padding(.bottom, 40)
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
