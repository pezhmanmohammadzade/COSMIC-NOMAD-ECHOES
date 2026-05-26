//
//  MathUtilities.swift
//  COSMIC NOMAD: ECHOES
//
//  Foundation math: matrix operations, noise functions, interpolation utilities.
//  Optimized for Apple Silicon with simd.
//

import simd
import Foundation

// MARK: - Matrix Utilities

enum MatrixUtil {
    
    /// Creates a perspective projection matrix
    static func perspective(fovYRadians: Float, aspectRatio: Float, near: Float, far: Float) -> float4x4 {
        let yScale = 1.0 / tan(fovYRadians * 0.5)
        let xScale = yScale / aspectRatio
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2.0 * far * near / zRange
        
        return float4x4(columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, wzScale, 0)
        ))
    }
    
    /// Creates a look-at view matrix
    static func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
        let forward = normalize(target - eye)
        let right = normalize(cross(forward, up))
        let newUp = cross(right, forward)
        
        return float4x4(columns: (
            SIMD4<Float>(right.x, newUp.x, -forward.x, 0),
            SIMD4<Float>(right.y, newUp.y, -forward.y, 0),
            SIMD4<Float>(right.z, newUp.z, -forward.z, 0),
            SIMD4<Float>(-dot(right, eye), -dot(newUp, eye), dot(forward, eye), 1)
        ))
    }
    
    /// Creates a translation matrix
    static func translation(_ t: SIMD3<Float>) -> float4x4 {
        return float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(t.x, t.y, t.z, 1)
        ))
    }
    
    /// Creates a rotation matrix from euler angles (radians)
    static func rotation(pitch: Float, yaw: Float, roll: Float) -> float4x4 {
        let cx = cos(pitch), sx = sin(pitch)
        let cy = cos(yaw),   sy = sin(yaw)
        let cz = cos(roll),  sz = sin(roll)
        
        return float4x4(columns: (
            SIMD4<Float>(cy*cz, cy*sz, -sy, 0),
            SIMD4<Float>(sx*sy*cz - cx*sz, sx*sy*sz + cx*cz, sx*cy, 0),
            SIMD4<Float>(cx*sy*cz + sx*sz, cx*sy*sz - sx*cz, cx*cy, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
    
    /// Creates a uniform scale matrix
    static func scale(_ s: Float) -> float4x4 {
        return float4x4(columns: (
            SIMD4<Float>(s, 0, 0, 0),
            SIMD4<Float>(0, s, 0, 0),
            SIMD4<Float>(0, 0, s, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
    
    /// Creates a non-uniform scale matrix
    static func scale(_ s: SIMD3<Float>) -> float4x4 {
        return float4x4(columns: (
            SIMD4<Float>(s.x, 0, 0, 0),
            SIMD4<Float>(0, s.y, 0, 0),
            SIMD4<Float>(0, 0, s.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
    
    /// Creates an orthographic projection matrix (for shadow mapping)
    static func orthographic(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> float4x4 {
        let rl = right - left
        let tb = top - bottom
        let fn = far - near
        return float4x4(columns: (
            SIMD4<Float>(2.0 / rl, 0, 0, 0),
            SIMD4<Float>(0, 2.0 / tb, 0, 0),
            SIMD4<Float>(0, 0, -1.0 / fn, 0),
            SIMD4<Float>(-(right + left) / rl, -(top + bottom) / tb, -near / fn, 1)
        ))
    }
}

// MARK: - Frustum Culling

struct Frustum {
    var planes: [SIMD4<Float>] = []
    
    init(viewProjection: float4x4) {
        let m = viewProjection
        planes = [
            // Left
            SIMD4<Float>(m[0][3] + m[0][0], m[1][3] + m[1][0], m[2][3] + m[2][0], m[3][3] + m[3][0]),
            // Right
            SIMD4<Float>(m[0][3] - m[0][0], m[1][3] - m[1][0], m[2][3] - m[2][0], m[3][3] - m[3][0]),
            // Bottom
            SIMD4<Float>(m[0][3] + m[0][1], m[1][3] + m[1][1], m[2][3] + m[2][1], m[3][3] + m[3][1]),
            // Top
            SIMD4<Float>(m[0][3] - m[0][1], m[1][3] - m[1][1], m[2][3] - m[2][1], m[3][3] - m[3][1]),
            // Near
            SIMD4<Float>(m[0][3] + m[0][2], m[1][3] + m[1][2], m[2][3] + m[2][2], m[3][3] + m[3][2]),
            // Far
            SIMD4<Float>(m[0][3] - m[0][2], m[1][3] - m[1][2], m[2][3] - m[2][2], m[3][3] - m[3][2])
        ]
        
        // Normalize planes
        for i in 0..<planes.count {
            let len = length(SIMD3<Float>(planes[i].x, planes[i].y, planes[i].z))
            if len > 0 {
                planes[i] /= len
            }
        }
    }
    
    /// Tests if an axis-aligned bounding box is inside or intersects the frustum
    func containsAABB(min: SIMD3<Float>, max: SIMD3<Float>) -> Bool {
        for plane in planes {
            let px: Float = plane.x > 0 ? max.x : min.x
            let py: Float = plane.y > 0 ? max.y : min.y
            let pz: Float = plane.z > 0 ? max.z : min.z
            
            if dot(SIMD3<Float>(plane.x, plane.y, plane.z), SIMD3<Float>(px, py, pz)) + plane.w < 0 {
                return false
            }
        }
        return true
    }
}

// MARK: - Noise Functions (CPU-side)

/// Deterministic noise generator for procedural terrain and world generation
public enum Noise: Sendable {
    
    // Permutation table for noise
    nonisolated(unsafe) private static var noisePermutation: [Int] = {
        var p = Array(0..<256)
        // Fisher-Yates shuffle with deterministic seed
        var rng = SeededRNG(seed: 42)
        for i in stride(from: 255, through: 1, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            p.swapAt(i, j)
        }
        return p + p // Double to avoid index wrapping
    }()
    
    private nonisolated static func fade(_ t: Float) -> Float {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    private nonisolated static func grad(_ hash: Int, _ x: Float, _ y: Float, _ z: Float) -> Float {
        let h = hash & 15
        let u: Float = h < 8 ? x : y
        let v: Float = h < 4 ? y : (h == 12 || h == 14 ? x : z)
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
    
    /// 3D Perlin noise, returns value in [-1, 1]
    nonisolated static func perlin(_ x: Float, _ y: Float, _ z: Float) -> Float {
        let xi = Int(floor(x)) & 255
        let yi = Int(floor(y)) & 255
        let zi = Int(floor(z)) & 255
        
        let xf = x - floor(x)
        let yf = y - floor(y)
        let zf = z - floor(z)
        
        let u = fade(xf)
        let v = fade(yf)
        let w = fade(zf)
        
        let aaa = noisePermutation[noisePermutation[noisePermutation[xi] + yi] + zi]
        let aba = noisePermutation[noisePermutation[noisePermutation[xi] + yi + 1] + zi]
        let aab = noisePermutation[noisePermutation[noisePermutation[xi] + yi] + zi + 1]
        let abb = noisePermutation[noisePermutation[noisePermutation[xi] + yi + 1] + zi + 1]
        let baa = noisePermutation[noisePermutation[noisePermutation[xi + 1] + yi] + zi]
        let bba = noisePermutation[noisePermutation[noisePermutation[xi + 1] + yi + 1] + zi]
        let bab = noisePermutation[noisePermutation[noisePermutation[xi + 1] + yi] + zi + 1]
        let bbb = noisePermutation[noisePermutation[noisePermutation[xi + 1] + yi + 1] + zi + 1]
        
        let x1 = grad(aaa, xf, yf, zf) + (grad(baa, xf - 1, yf, zf) - grad(aaa, xf, yf, zf)) * u
        let x2 = grad(aba, xf, yf - 1, zf) + (grad(bba, xf - 1, yf - 1, zf) - grad(aba, xf, yf - 1, zf)) * u
        let y1 = x1 + (x2 - x1) * v
        
        let x3 = grad(aab, xf, yf, zf - 1) + (grad(bab, xf - 1, yf, zf - 1) - grad(aab, xf, yf, zf - 1)) * u
        let x4 = grad(abb, xf, yf - 1, zf - 1) + (grad(bbb, xf - 1, yf - 1, zf - 1) - grad(abb, xf, yf - 1, zf - 1)) * u
        let y2 = x3 + (x4 - x3) * v
        
        return y1 + (y2 - y1) * w
    }
    
    /// 2D Perlin noise for terrain heightfields
    nonisolated static func perlin2D(_ x: Float, _ y: Float) -> Float {
        return perlin(x, y, 0)
    }
    
    /// Fractal Brownian Motion — layered noise for terrain
    nonisolated static func fbm(_ x: Float, _ y: Float, octaves: Int = 6, lacunarity: Float = 2.0, persistence: Float = 0.5) -> Float {
        var value: Float = 0
        var amplitude: Float = 1.0
        var frequency: Float = 1.0
        var maxValue: Float = 0
        
        for _ in 0..<octaves {
            value += perlin2D(x * frequency, y * frequency) * amplitude
            maxValue += amplitude
            amplitude *= persistence
            frequency *= lacunarity
        }
        
        return value / maxValue
    }
    
    /// Ridge noise for mountain ranges
    nonisolated static func ridged(_ x: Float, _ y: Float, octaves: Int = 6, lacunarity: Float = 2.0, persistence: Float = 0.5) -> Float {
        var value: Float = 0
        var amplitude: Float = 1.0
        var frequency: Float = 1.0
        var maxValue: Float = 0
        var weight: Float = 1.0
        
        for _ in 0..<octaves {
            var signal = perlin2D(x * frequency, y * frequency)
            signal = 1.0 - abs(signal) // Create ridges
            signal *= signal           // Sharpen ridges
            signal *= weight           // Weight by previous octave
            weight = simd_clamp(signal * 2.0, 0, 1)
            
            value += signal * amplitude
            maxValue += amplitude
            amplitude *= persistence
            frequency *= lacunarity
        }
        
        return value / maxValue
    }
    
    /// Domain-warped noise for alien terrain
    nonisolated static func domainWarped(_ x: Float, _ y: Float, warpStrength: Float = 0.5) -> Float {
        let warpX = fbm(x + 5.2, y + 1.3, octaves: 4) * warpStrength
        let warpY = fbm(x + 1.7, y + 9.2, octaves: 4) * warpStrength
        return fbm(x + warpX, y + warpY, octaves: 6)
    }
}

// MARK: - Seeded RNG

/// Simple deterministic random number generator for procedural generation
public struct SeededRNG: Sendable {
    private var state: UInt64
    
    nonisolated init(seed: UInt64) {
        self.state = seed
    }
    
    nonisolated mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    
    mutating func nextFloat() -> Float {
        return Float(next() & 0xFFFFFF) / Float(0xFFFFFF)
    }
    
    mutating func nextFloatRange(_ min: Float, _ max: Float) -> Float {
        return min + nextFloat() * (max - min)
    }
    
    /// Seed from two coordinates (for chunk-based generation)
    nonisolated static func seedFromCoords(_ x: Int, _ y: Int, baseSeed: UInt64) -> UInt64 {
        var seed = baseSeed
        seed ^= UInt64(bitPattern: Int64(x)) &* 0x9E3779B97F4A7C15
        seed ^= UInt64(bitPattern: Int64(y)) &* 0x517CC1B727220A95
        return seed
    }
}

// MARK: - Interpolation Utilities

/// Smooth interpolation functions
enum Interpolation {
    
    /// Hermite smoothstep
    static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = simd_clamp((x - edge0) / (edge1 - edge0), 0, 1)
        return t * t * (3 - 2 * t)
    }
    
    /// Quintic smootherstep (C2 continuous)
    static func smootherstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = simd_clamp((x - edge0) / (edge1 - edge0), 0, 1)
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    /// Spring-damper for camera/UI (critically damped)
    static func springDamp(current: Float, target: Float, velocity: inout Float, smoothTime: Float, deltaTime: Float) -> Float {
        let omega = 2.0 / smoothTime
        let x = omega * deltaTime
        let exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
        let change = current - target
        let temp = (velocity + omega * change) * deltaTime
        velocity = (velocity - omega * temp) * exp
        return target + (change + temp) * exp
    }
    
    /// Spring-damper for SIMD3 values
    static func springDamp3(current: SIMD3<Float>, target: SIMD3<Float>, velocity: inout SIMD3<Float>, smoothTime: Float, deltaTime: Float) -> SIMD3<Float> {
        var vx = velocity.x, vy = velocity.y, vz = velocity.z
        let rx = springDamp(current: current.x, target: target.x, velocity: &vx, smoothTime: smoothTime, deltaTime: deltaTime)
        let ry = springDamp(current: current.y, target: target.y, velocity: &vy, smoothTime: smoothTime, deltaTime: deltaTime)
        let rz = springDamp(current: current.z, target: target.z, velocity: &vz, smoothTime: smoothTime, deltaTime: deltaTime)
        velocity = SIMD3<Float>(vx, vy, vz)
        return SIMD3<Float>(rx, ry, rz)
    }
    
    /// Exponential decay interpolation (frame-rate independent)
    static func expDecay(current: Float, target: Float, rate: Float, deltaTime: Float) -> Float {
        return target + (current - target) * exp(-rate * deltaTime)
    }
    
    static func expDecay3(current: SIMD3<Float>, target: SIMD3<Float>, rate: Float, deltaTime: Float) -> SIMD3<Float> {
        let factor = exp(-rate * deltaTime)
        return target + (current - target) * factor
    }
}
