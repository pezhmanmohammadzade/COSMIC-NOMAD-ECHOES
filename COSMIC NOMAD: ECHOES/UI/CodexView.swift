//
//  CodexView.swift
//  COSMIC NOMAD: ECHOES
//
//  Full gallery of all memory fragments discovered across the journey.
//  Organized by planet. Undiscovered fragments show as [CORRUPTED].
//

import SwiftUI

struct CodexView: View {
    let onClose: () -> Void
    
    @State private var fragments: [[String: String]] = []
    @State private var selectedPlanet: String? = nil
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CODEX")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(6)
                        
                        Text("\(fragments.count) FRAGMENTS RECOVERED")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.6))
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
                .padding(.bottom, 16)
                
                // Planet filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        PlanetTabButton(name: "ALL", isSelected: selectedPlanet == nil) {
                            selectedPlanet = nil
                        }
                        
                        ForEach(planetNames, id: \.self) { planet in
                            PlanetTabButton(name: planet, isSelected: selectedPlanet == planet) {
                                selectedPlanet = planet
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 12)
                
                // Divider
                Rectangle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(height: 1)
                
                // Fragment list
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredFragments, id: \.self) { frag in
                            CodexFragmentCard(fragment: frag)
                        }
                        
                        // Corrupted placeholders
                        ForEach(0..<corruptedCount, id: \.self) { _ in
                            CorruptedFragmentCard()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .onAppear {
            fragments = SaveManager.shared.getCodexFragments()
        }
        .transition(.opacity)
    }
    
    // MARK: - Computed
    
    private var planetNames: [String] {
        let names = Set(fragments.compactMap { $0["planet"] })
        return names.sorted()
    }
    
    private var filteredFragments: [[String: String]] {
        if let planet = selectedPlanet {
            return fragments.filter { $0["planet"] == planet }
        }
        return fragments
    }
    
    private var corruptedCount: Int {
        // Show some corrupted placeholders to tease undiscovered content
        let total = (SaveManager.shared.getPlanetsCompleted() + 1) * 5
        return max(0, total - fragments.count)
    }
}

// MARK: - Planet Tab

struct PlanetTabButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .black : .white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.cyan : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Fragment Card

struct CodexFragmentCard: View {
    let fragment: [String: String]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Type badge
                Text((fragment["type"] ?? "UNKNOWN").uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Planet name
                Text(fragment["planet"] ?? "")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.5))
            }
            
            Text(fragment["title"] ?? "Unknown Signal")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            if isExpanded {
                Text(fragment["content"] ?? "")
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundColor(.white.opacity(0.75))
                    .lineSpacing(4)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.1), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Corrupted Fragment

struct CorruptedFragmentCard: View {
    @State private var flicker = false
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundColor(.red.opacity(0.4))
            
            Text("[CORRUPTED DATA]")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.red.opacity(0.3))
            
            Spacer()
            
            Text("SIGNAL LOST")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.15))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(flicker ? 0.04 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                flicker = true
            }
        }
    }
}
