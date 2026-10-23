//
//  AAAUISystem.swift
//  COSMIC NOMAD: ECHOES
//
//  AAA Sci-Fi Design System & Telemetry Components.
//  Provides ultra-premium glassmorphism, HUD brackets, circular telemetry gauges,
//  holographic scanlines, glowing borders, and tactile tactile micro-interactions.
//

import SwiftUI

// MARK: - AAA Visual Styling Tokens

enum AAAShape {
    /// Chamfered corner polygon for authentic aerospace/sci-fi panels
    struct ChamferedRectangle: Shape {
        var chamferSize: CGFloat = 12
        var cutTopLeft: Bool = true
        var cutBottomRight: Bool = true
        var cutTopRight: Bool = false
        var cutBottomLeft: Bool = false
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let w = rect.width
            let h = rect.height
            let c = min(chamferSize, min(w, h) / 2)
            
            // Start at top edge
            path.move(to: CGPoint(x: cutTopLeft ? c : 0, y: 0))
            path.addLine(to: CGPoint(x: cutTopRight ? w - c : w, y: 0))
            if cutTopRight { path.addLine(to: CGPoint(x: w, y: c)) }
            
            path.addLine(to: CGPoint(x: w, y: cutBottomRight ? h - c : h))
            if cutBottomRight { path.addLine(to: CGPoint(x: w - c, y: h)) }
            
            path.addLine(to: CGPoint(x: cutBottomLeft ? c : 0, y: h))
            if cutBottomLeft { path.addLine(to: CGPoint(x: 0, y: h - c)) }
            
            path.addLine(to: CGPoint(x: 0, y: cutTopLeft ? c : 0))
            if cutTopLeft { path.addLine(to: CGPoint(x: c, y: 0)) }
            
            path.closeSubpath()
            return path
        }
    }
}

// MARK: - Sci-Fi Glassmorphic Card Background

struct AAAGlassPanel<Content: View>: View {
    var chamfer: CGFloat = 10
    var borderColor: Color = Pastel.primary.opacity(0.35)
    var borderWidth: CGFloat = 1.0
    var glowColor: Color = Pastel.primary.opacity(0.15)
    var bgOpacity: Double = 0.82
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .background(
                ZStack {
                    // Dark matte backing
                    AAAShape.ChamferedRectangle(chamferSize: chamfer)
                        .fill(Pastel.surface.opacity(bgOpacity))
                    
                    // Subtle top specular gradient sheen
                    AAAShape.ChamferedRectangle(chamferSize: chamfer)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Outer stroke
                    AAAShape.ChamferedRectangle(chamferSize: chamfer)
                        .stroke(borderColor, lineWidth: borderWidth)
                }
                .shadow(color: glowColor, radius: 10, x: 0, y: 4)
            )
    }
}

// MARK: - Circular Segmented Telemetry Gauge

struct AAACircularGauge: View {
    let title: String
    let value: Float
    let maxValue: Float
    let color: Color
    let icon: String
    var size: CGFloat = 52
    
    private var ratio: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(Double(value / maxValue), 0), 1)
    }
    
    private var isCritical: Bool { ratio < 0.25 }
    
    @State private var pulse: Bool = false
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Pastel.cardStroke, lineWidth: 3.5)
                    .frame(width: size, height: size)
                
                // Segmented or continuous arc
                Circle()
                    .trim(from: 0, to: CGFloat(ratio))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                isCritical ? Pastel.danger : color.opacity(0.6),
                                isCritical ? Pastel.danger : color
                            ]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 3.8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
                    .shadow(color: (isCritical ? Pastel.danger : color).opacity(pulse ? 0.8 : 0.3), radius: isCritical ? 6 : 3)
                
                // Center icon + value
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.22, weight: .bold))
                        .foregroundColor(isCritical ? Pastel.danger : color)
                    
                    Text("\(Int(value))")
                        .font(.system(size: size * 0.24, weight: .black, design: .monospaced))
                        .foregroundColor(Pastel.textPrimary)
                }
            }
            .scaleEffect(isCritical && pulse ? 1.05 : 1.0)
            .animation(isCritical ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: pulse)
            .onAppear {
                if isCritical { pulse = true }
            }
            .onChange(of: isCritical) { _, newValue in
                pulse = newValue
            }
            
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isCritical ? Pastel.danger : Pastel.textSecondary)
                .tracking(1)
        }
    }
}

// MARK: - Sci-Fi HUD Corner Brackets

struct AAAHUDCornerBrackets: View {
    var color: Color = Pastel.primary.opacity(0.5)
    var length: CGFloat = 8
    var thickness: CGFloat = 1.5
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            Path { path in
                // Top-Left
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
                
                // Top-Right
                path.move(to: CGPoint(x: w - length, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: length))
                
                // Bottom-Left
                path.move(to: CGPoint(x: 0, y: h - length))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: length, y: h))
                
                // Bottom-Right
                path.move(to: CGPoint(x: w - length, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w, y: h - length))
            }
            .stroke(color, lineWidth: thickness)
        }
    }
}

// MARK: - Sci-Fi Scanline & Grid Effect

struct AAAScanlineOverlay: View {
    var lineSpacing: CGFloat = 4.0
    var opacity: Double = 0.04
    
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.white.opacity(opacity)), lineWidth: 1)
                y += lineSpacing
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Audio Waveform Spectrum Indicator

struct AAAWaveformView: View {
    var color: Color = Pastel.signalPulse
    var count: Int = 12
    var height: CGFloat = 18
    @State private var phase: Double = 0
    
    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<count, id: \.self) { i in
                let factor = sin(phase + Double(i) * 0.6) * 0.5 + 0.5
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2.5, height: max(3, CGFloat(factor) * height))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Aerospace Menu Action Button

struct AAAMenuButton: View {
    let index: String
    let title: String
    let icon: String
    let accentColor: Color
    var isHero: Bool = false
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: 14) {
                // Bracketed Index
                Text(index)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor.opacity(0.7))
                    .frame(width: 28, alignment: .leading)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
                    .frame(width: 20)
                
                // Title
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2.5)
                    .foregroundColor(Pastel.textPrimary)
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accentColor.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    AAAShape.ChamferedRectangle(chamferSize: 8)
                        .fill(isHero ? accentColor.opacity(0.12) : Pastel.surface.opacity(0.75))
                    
                    AAAShape.ChamferedRectangle(chamferSize: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(isHero ? 0.6 : 0.25),
                                    accentColor.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHero ? 1.5 : 1.0
                        )
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
