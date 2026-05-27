//
//  ContentView.swift
//  COSMIC NOMAD: ECHOES
//
//  Main game view: hosts the Metal rendering view with
//  a minimal HUD overlay. Launch screen fades into gameplay.
//

import SwiftUI

enum AppState {
    case launch
    case onboarding
    case mainMenu
    case playing
    case hyperspace
}

struct ContentView: View {
    
    @State private var engine: GameEngine?
    @State private var appState: AppState = .launch
    @State private var launchOpacity: Double = 1.0
    @State private var hyperspaceDestination: String = ""
    @State private var hyperspaceDestinationMood: String = ""
    @State private var hyperspacePlanetNumber: Int = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    var body: some View {
        ZStack {
            // Metal rendering view (full screen)
            MetalView(engine: $engine) { createdEngine in
                self.engine = createdEngine
                
                // Fade out launch screen after engine is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 2.0)) {
                        launchOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            if !hasSeenOnboarding {
                                appState = .onboarding
                            } else {
                                appState = .mainMenu
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            // Navigation overlay
            switch appState {
            case .playing:
                MinimalHUD(engine: engine, appState: $appState)
                    .transition(.opacity)
            case .onboarding:
                OnboardingView(currentAppState: $appState)
                    .transition(.opacity)
            case .mainMenu:
                MainMenuView(currentAppState: $appState, engine: engine)
                    .transition(.opacity)
            case .hyperspace:
                HyperspaceView(
                    destinationName: hyperspaceDestination,
                    destinationMood: hyperspaceDestinationMood,
                    planetNumber: hyperspacePlanetNumber,
                    totalPlanets: GameEngine.totalPlanetsForEnding,
                    onComplete: {
                        withAnimation(.easeOut(duration: 0.5)) {
                            appState = .playing
                        }
                    }
                )
                .transition(.opacity)
            case .launch:
                LaunchScreenView()
                    .opacity(launchOpacity)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Launch Screen

struct LaunchScreenView: View {
    
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background — warm dark navy
            Pastel.bg
            
            // Subtle star particles (simulated with dots)
            GeometryReader { geo in
                ForEach(0..<40, id: \.self) { i in
                    Circle()
                        .fill(Pastel.textPrimary.opacity(Double.random(in: 0.08...0.35)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }
            }
            
            VStack(spacing: 20) {
                Spacer()
                
                // Title
                VStack(spacing: 8) {
                    Text("COSMIC NOMAD")
                        .font(.system(size: 32, weight: .ultraLight, design: .serif))
                        .foregroundStyle(Pastel.textPrimary)
                        .tracking(12)
                        .opacity(titleOpacity)
                    
                    // Thin divider line
                    Rectangle()
                        .fill(Pastel.primary.opacity(0.4))
                        .frame(width: 60, height: 0.5)
                        .opacity(subtitleOpacity)
                    
                    Text("ECHOES")
                        .font(.system(size: 18, weight: .thin, design: .serif))
                        .foregroundStyle(Pastel.primary.opacity(0.7))
                        .tracking(20)
                        .opacity(subtitleOpacity)
                }
                
                Spacer()
                
                // Tagline
                Text("Every world remembers. Every silence speaks.")
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .foregroundStyle(Pastel.textMuted)
                    .italic()
                    .opacity(taglineOpacity)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) {
                titleOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 1.0).delay(0.5)) {
                subtitleOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 1.0).delay(1.0)) {
                taglineOpacity = 1.0
            }
        }
    }
}

#Preview {
    ContentView()
}
