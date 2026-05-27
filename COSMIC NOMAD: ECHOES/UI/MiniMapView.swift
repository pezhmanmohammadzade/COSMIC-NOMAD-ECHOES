//
//  MiniMapView.swift
//  COSMIC NOMAD: ECHOES
//
//  Always-visible mini-map showing player position, facing direction,
//  and nearby signal markers.
//  Pastel matte color aesthetic.
//

import SwiftUI
import simd

struct MiniMapView: View {
    let playerPosition: SIMD3<Float>
    let playerYaw: Float
    let signals: [MemoryFragment]
    let mapRadius: Float = 150.0 // World units visible on mini-map
    
    private let size: CGFloat = 90
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Pastel.surface.opacity(0.7))
                .frame(width: size, height: size)
            
            Circle()
                .stroke(Pastel.primary.opacity(0.2), lineWidth: 1)
                .frame(width: size, height: size)
            
            // Compass directions
            Text("N")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(Pastel.primary.opacity(0.5))
                .offset(y: -size / 2 + 8)
                .rotationEffect(.radians(Double(playerYaw)))
            
            // Signal markers
            ForEach(Array(signals.enumerated()), id: \.offset) { _, signal in
                if !signal.isDiscovered {
                    let relX = signal.worldPosition.x - playerPosition.x
                    let relZ = signal.worldPosition.z - playerPosition.z
                    
                    // Rotate by player yaw
                    let cosY = cos(playerYaw)
                    let sinY = sin(playerYaw)
                    let rotX = relX * cosY - relZ * sinY
                    let rotZ = relX * sinY + relZ * cosY
                    
                    let dist = sqrt(relX * relX + relZ * relZ)
                    
                    if dist < mapRadius * 1.5 {
                        let normX = CGFloat(rotX / mapRadius) * (size / 2 - 8)
                        let normZ = CGFloat(-rotZ / mapRadius) * (size / 2 - 8)
                        
                        // Clamp to circle
                        let clampDist = min(sqrt(normX * normX + normZ * normZ), size / 2 - 6)
                        let angle = atan2(normZ, normX)
                        let finalX = cos(angle) * clampDist
                        let finalZ = sin(angle) * clampDist
                        
                        Circle()
                            .fill(Pastel.secondary)
                            .frame(width: 4, height: 4)
                            .shadow(color: Pastel.secondary.opacity(0.6), radius: 3)
                            .offset(x: finalX, y: finalZ)
                    }
                }
            }
            
            // Player indicator (center triangle)
            Triangle()
                .fill(Pastel.primary)
                .frame(width: 8, height: 10)
                .shadow(color: Pastel.primary.opacity(0.5), radius: 4)
            
            // Range ring
            Circle()
                .stroke(Pastel.textPrimary.opacity(0.06), lineWidth: 0.5)
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
