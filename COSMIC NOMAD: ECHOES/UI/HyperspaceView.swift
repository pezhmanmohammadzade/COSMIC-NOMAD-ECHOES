//
//  HyperspaceView.swift
//  COSMIC NOMAD: ECHOES
//
//  Cinematic hyperspace jump animation shown during planet transitions.
//  Streaking stars, planet name reveal, and immersive sound design.
//

import SwiftUI

struct HyperspaceView: View {
    let destinationName: String
    let destinationMood: String
    let planetNumber: Int
    let totalPlanets: Int
    let onComplete: () -> Void
    
    @State private var phase: HyperspacePhase = .charging
    @State private var starStreakLength: CGFloat = 0
    @State private var warpIntensity: Double = 0
    @State private var nameOpacity: Double = 0
    @State private var subOpacity: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var backgroundHue: Double = 0.55
    
    enum HyperspacePhase {
        case charging, jumping, arriving
    }
    
    var body: some View {
        ZStack {
            // Deep space background
            Color.black.ignoresSafeArea()
            
            // Star field
            GeometryReader { geo in
                ZStack {
                    // Static stars that become streaks
                    ForEach(0..<60, id: \.self) { i in
                        let seed = Double(i) * 137.508
                        let x = CGFloat((seed.truncatingRemainder(dividingBy: 1.0) + Double(i) * 0.017).truncatingRemainder(dividingBy: 1.0)) * geo.size.width
                        let y = CGFloat((seed * 0.618).truncatingRemainder(dividingBy: 1.0)) * geo.size.height
                        let brightness = (seed * 0.3).truncatingRemainder(dividingBy: 0.6) + 0.2
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(brightness))
                            .frame(width: 2, height: 2 + starStreakLength * CGFloat(0.5 + brightness))
                            .position(x: x, y: y)
                            .blur(radius: starStreakLength > 20 ? 1 : 0)
                    }
                }
            }
            
            // Warp tunnel effect — Canvas-drawn concentric rings
            if warpIntensity > 0.1 {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let maxRadius = max(size.width, size.height) * 0.8
                    let ringCount = 15
                    
                    for i in 0..<ringCount {
                        let progress = Double(i) / Double(ringCount)
                        let radius = maxRadius * CGFloat(progress) * CGFloat(warpIntensity)
                        let hue = (backgroundHue + progress * 0.2).truncatingRemainder(dividingBy: 1.0)
                        let alpha = (1.0 - progress) * warpIntensity * 0.3
                        
                        let rect = CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        
                        context.stroke(
                            Path(ellipseIn: rect),
                            with: .color(Color(hue: hue, saturation: 0.7, brightness: 0.8).opacity(alpha)),
                            lineWidth: 2 + CGFloat(warpIntensity) * 3
                        )
                    }
                }
                .ignoresSafeArea()
                .blur(radius: 8)
                
                // Color tunnel gradient
                RadialGradient(
                    colors: [
                        Color(hue: backgroundHue, saturation: 0.8, brightness: 0.4).opacity(warpIntensity * 0.5),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
                .blur(radius: 20)
            }
            
            // Letterbox bars for cinematic feel
            if phase == .arriving {
                VStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 50)
                    Spacer()
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 50)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
            
            // White flash on arrival
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
            
            // Planet info (arrives)
            if phase == .arriving {
                VStack(spacing: 16) {
                    Text("ENTERING ORBIT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(subOpacity * 0.6))
                        .tracking(6)
                    
                    Text(destinationName)
                        .font(.system(size: 28, weight: .ultraLight, design: .serif))
                        .foregroundColor(.white)
                        .opacity(nameOpacity)
                        .tracking(8)
                    
                    Rectangle()
                        .fill(Color.white.opacity(nameOpacity * 0.3))
                        .frame(width: 40, height: 0.5)
                    
                    Text(destinationMood.uppercased())
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundColor(.white.opacity(subOpacity * 0.5))
                        .tracking(4)
                    
                    Text("PLANET \(planetNumber)/\(totalPlanets)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(subOpacity * 0.4))
                        .padding(.top, 8)
                }
            }
            
            // Charging text
            if phase == .charging {
                VStack(spacing: 8) {
                    Text("INITIATING WARP DRIVE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.6))
                        .tracking(4)
                    
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(0.8)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            startSequence()
        }
    }
    
    private func startSequence() {
        // Phase 1: Charging (1.5s)
        withAnimation(.easeIn(duration: 1.5)) {
            starStreakLength = 5
        }
        
        // Phase 2: Jump (1s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            phase = .jumping
            
            withAnimation(.easeIn(duration: 0.8)) {
                starStreakLength = 200
                warpIntensity = 1.0
            }
        }
        
        // Phase 3: Flash & Arrive (after 2.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            // White flash
            withAnimation(.easeOut(duration: 0.15)) {
                flashOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                phase = .arriving
                starStreakLength = 0
                warpIntensity = 0
                
                withAnimation(.easeOut(duration: 0.8)) {
                    flashOpacity = 0
                }
                
                withAnimation(.easeOut(duration: 1.2)) {
                    nameOpacity = 1.0
                }
                
                withAnimation(.easeOut(duration: 1.5).delay(0.3)) {
                    subOpacity = 1.0
                }
            }
        }
        
        // Auto-dismiss after full sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation(.easeOut(duration: 1.0)) {
                nameOpacity = 0
                subOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onComplete()
            }
        }
    }
}
