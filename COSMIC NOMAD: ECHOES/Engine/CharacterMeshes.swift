//
//  CharacterMeshes.swift
//  COSMIC NOMAD: ECHOES
//
//  Smooth procedural primitive library used to build the realistic
//  astronaut (and available to any other entity renderer).
//
//  Every primitive is authored in a unit volume (-0.5 … 0.5 on every axis)
//  so it can be dropped in wherever the old unit cube was used and sized
//  with a per-instance scale matrix. All meshes use counter-clockwise
//  front faces (matching the G-buffer pass cull settings) and smooth,
//  analytically-correct normals.
//

import Metal
import simd

// MARK: - Mesh Container

struct PrimitiveMesh {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indexCount: Int
}

// MARK: - Mesh Kinds

enum CharacterMeshKind: Int, CaseIterable {
    case sphere        // UV sphere
    case capsule       // Cylinder with soft elliptical end caps (limbs, hoses, tanks)
    case softBox       // Heavily rounded box (fabric segments, padding)
    case hardBox       // Lightly rounded box (hard shell plates, PLSS, DCM)
    case torus         // Bearing rings, cuffs, neck ring
    case ring          // Thin trim ring (visor rim, seals)
    case cylinder      // Flat-capped cylinder (connectors, valves)
    case bell          // Frustum (thruster nozzles, boot heels)
    case visorCap      // Spherical cap around -Z (helmet visor), half-angle 62°
}

// MARK: - Library

@MainActor
final class CharacterMeshLibrary {
    
    /// Half-angle (radians) of the visor spherical cap — used to place the visor rim torus.
    static let visorHalfAngle: Float = 62.0 * .pi / 180.0
    
    private(set) var meshes: [CharacterMeshKind: PrimitiveMesh] = [:]
    
    init(device: MTLDevice) {
        for kind in CharacterMeshKind.allCases {
            let (verts, indices) = Self.build(kind)
            guard
                let vb = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<EntityVertex>.stride, options: .storageModeShared),
                let ib = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .storageModeShared)
            else { continue }
            vb.label = "CharacterMesh.\(kind) Vertices"
            ib.label = "CharacterMesh.\(kind) Indices"
            meshes[kind] = PrimitiveMesh(vertexBuffer: vb, indexBuffer: ib, indexCount: indices.count)
        }
    }
    
    subscript(kind: CharacterMeshKind) -> PrimitiveMesh? { meshes[kind] }
    
    // MARK: - Builders
    
    private static func build(_ kind: CharacterMeshKind) -> ([EntityVertex], [UInt16]) {
        switch kind {
        case .sphere:   return revolve(profile: sphereProfile(rings: 18), segments: 28)
        case .capsule:  return revolve(profile: capsuleProfile(capHeight: 0.16, capRings: 6), segments: 22)
        case .softBox:  return roundedBox(radius: 0.42, edgeSteps: 4)
        case .hardBox:  return roundedBox(radius: 0.16, edgeSteps: 3)
        case .torus:    return revolve(profile: torusProfile(major: 0.40, minor: 0.10, steps: 12), segments: 28)
        case .ring:     return revolve(profile: torusProfile(major: 0.46, minor: 0.04, steps: 8), segments: 36)
        case .cylinder: return revolve(profile: frustumProfile(bottomRadius: 0.5, topRadius: 0.5), segments: 20)
        case .bell:     return revolve(profile: frustumProfile(bottomRadius: 0.5, topRadius: 0.26), segments: 20)
        case .visorCap: return visorCap()
        }
    }
    
    /// A point on a revolution profile: radius from Y axis, height, and 2D normal (radial, y).
    private struct ProfilePoint {
        var r: Float
        var y: Float
        var nr: Float
        var ny: Float
    }
    
    // MARK: Profiles (always authored bottom → top along the outer surface)
    
    private static func sphereProfile(rings: Int) -> [ProfilePoint] {
        (0...rings).map { j in
            let theta = Float.pi * (1 - Float(j) / Float(rings))  // π (bottom) → 0 (top)
            let r = 0.5 * sin(theta), y = 0.5 * cos(theta)
            return ProfilePoint(r: r, y: y, nr: sin(theta), ny: cos(theta))
        }
    }
    
    private static func capsuleProfile(capHeight c: Float, capRings: Int) -> [ProfilePoint] {
        var pts: [ProfilePoint] = []
        let a: Float = 0.5
        // Bottom cap: t from -π/2 → 0
        for k in 0...capRings {
            let t = -Float.pi / 2 + (Float.pi / 2) * Float(k) / Float(capRings)
            let n = normalize(SIMD2<Float>(cos(t) / a, sin(t) / c))
            pts.append(ProfilePoint(r: a * cos(t), y: (-0.5 + c) + c * sin(t), nr: n.x, ny: n.y))
        }
        // Top cap: t from 0 → π/2
        for k in 0...capRings {
            let t = (Float.pi / 2) * Float(k) / Float(capRings)
            let n = normalize(SIMD2<Float>(cos(t) / a, sin(t) / c))
            pts.append(ProfilePoint(r: a * cos(t), y: (0.5 - c) + c * sin(t), nr: n.x, ny: n.y))
        }
        return pts
    }
    
    private static func torusProfile(major R: Float, minor t: Float, steps: Int) -> [ProfilePoint] {
        (0...steps).map { k in
            let a = -Float.pi + 2 * Float.pi * Float(k) / Float(steps)
            return ProfilePoint(r: R + t * cos(a), y: t * sin(a), nr: cos(a), ny: sin(a))
        }
    }
    
    private static func frustumProfile(bottomRadius rb: Float, topRadius rt: Float) -> [ProfilePoint] {
        let side = normalize(SIMD2<Float>(1.0, rb - rt))
        return [
            ProfilePoint(r: 0,  y: -0.5, nr: 0, ny: -1),
            ProfilePoint(r: rb, y: -0.5, nr: 0, ny: -1),
            ProfilePoint(r: rb, y: -0.5, nr: side.x, ny: side.y),
            ProfilePoint(r: rt, y:  0.5, nr: side.x, ny: side.y),
            ProfilePoint(r: rt, y:  0.5, nr: 0, ny: 1),
            ProfilePoint(r: 0,  y:  0.5, nr: 0, ny: 1),
        ]
    }
    
    // MARK: Revolution
    
    /// Revolves a profile around +Y. x = r·cosφ, z = −r·sinφ gives outward CCW winding.
    private static func revolve(profile: [ProfilePoint], segments: Int) -> ([EntityVertex], [UInt16]) {
        var verts: [EntityVertex] = []
        var indices: [UInt16] = []
        let rows = profile.count
        verts.reserveCapacity((segments + 1) * rows)
        
        for i in 0...segments {
            let phi = 2 * Float.pi * Float(i) / Float(segments)
            let c = cos(phi), s = -sin(phi)
            for (j, p) in profile.enumerated() {
                let pos = SIMD3<Float>(p.r * c, p.y, p.r * s)
                var n = SIMD3<Float>(p.nr * c, p.ny, p.nr * s)
                let len = length(n)
                n = len > 1e-5 ? n / len : SIMD3<Float>(0, p.ny >= 0 ? 1 : -1, 0)
                verts.append(EntityVertex(position: pos, normal: n,
                                          texCoord: SIMD2<Float>(Float(i) / Float(segments), Float(j) / Float(rows - 1))))
            }
        }
        for i in 0..<segments {
            for j in 0..<(rows - 1) {
                let a = UInt16(i * rows + j)
                let b = UInt16((i + 1) * rows + j)
                let c = a + 1
                let d = b + 1
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }
        return (verts, indices)
    }
    
    // MARK: Visor cap
    
    /// Spherical cap (radius 0.5) centred on −Z with the configured half-angle.
    private static func visorCap() -> ([EntityVertex], [UInt16]) {
        let rings = 10
        let alpha = visorHalfAngle
        // Cap around +Y, authored edge (bottom) → pole (top)
        let profile: [ProfilePoint] = (0...rings).map { j in
            let theta = alpha * (1 - Float(j) / Float(rings))
            return ProfilePoint(r: 0.5 * sin(theta), y: 0.5 * cos(theta), nr: sin(theta), ny: cos(theta))
        }
        let built = revolve(profile: profile, segments: 32)
        var verts = built.0
        // Rotate +Y → −Z  (rotation of −90° about X: y → −z, z → y).
        // Proper rotation (det = +1) so winding is preserved.
        for k in 0..<verts.count {
            let p = verts[k].position, n = verts[k].normal
            verts[k].position = SIMD3<Float>(p.x, p.z, -p.y)
            verts[k].normal = SIMD3<Float>(n.x, n.z, -n.y)
        }
        return (verts, built.1)
    }
    
    // MARK: Rounded box
    
    /// Subdivided cube projected onto a rounded box. `radius` is in half-extent units (0…1).
    private static func roundedBox(radius r: Float, edgeSteps: Int) -> ([EntityVertex], [UInt16]) {
        // Grid coordinates concentrated in the rounded edge band so the arc is smooth.
        var coords: [Float] = []
        for k in 0...edgeSteps {                       // -1 → -1+r
            let d = r * tan(Float(edgeSteps - k) / Float(edgeSteps) * .pi / 4)
            coords.append(-1 + r - d)
        }
        coords.append(0)                               // flat centre
        for k in 0...edgeSteps {                       // 1-r → 1
            let d = r * tan(Float(k) / Float(edgeSteps) * .pi / 4)
            coords.append(1 - r + d)
        }
        
        // (normal, u, v) with u × v = normal
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            (SIMD3( 1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)),
            (SIMD3(-1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, 1, 0)),
            (SIMD3( 0, 1, 0), SIMD3(0, 0, 1), SIMD3(1, 0, 0)),
            (SIMD3( 0,-1, 0), SIMD3(1, 0, 0), SIMD3(0, 0, 1)),
            (SIMD3( 0, 0, 1), SIMD3(1, 0, 0), SIMD3(0, 1, 0)),
            (SIMD3( 0, 0,-1), SIMD3(0, 1, 0), SIMD3(1, 0, 0)),
        ]
        
        var verts: [EntityVertex] = []
        var indices: [UInt16] = []
        let n = coords.count
        let inner = 1 - r
        
        for (normal, u, v) in faces {
            let base = UInt16(verts.count)
            for (ia, a) in coords.enumerated() {
                for (ib, b) in coords.enumerated() {
                    let p = normal + u * a + v * b
                    let q = simd_clamp(p, SIMD3<Float>(repeating: -inner), SIMD3<Float>(repeating: inner))
                    let nrm = normalize(p - q)
                    let pos = (q + nrm * r) * 0.5
                    verts.append(EntityVertex(position: pos, normal: nrm,
                                              texCoord: SIMD2<Float>(Float(ia) / Float(n - 1), Float(ib) / Float(n - 1))))
                }
            }
            for ia in 0..<(n - 1) {
                for ib in 0..<(n - 1) {
                    let i00 = base + UInt16(ia * n + ib)          // (a, b)
                    let i10 = base + UInt16((ia + 1) * n + ib)    // (a+1, b)
                    let i01 = i00 + 1                             // (a, b+1)
                    let i11 = i10 + 1
                    indices.append(contentsOf: [i00, i10, i01, i10, i11, i01])
                }
            }
        }
        return (verts, indices)
    }
}
