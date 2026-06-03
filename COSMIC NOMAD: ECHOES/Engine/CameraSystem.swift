//
//  CameraSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Cinematic camera: floating drone-like third-person view,
//  spring-damper smoothing, automatic cinematic framing,
//  emotional zoom behavior during discoveries.
//

import simd
import Foundation

// MARK: - Camera Mode

enum CameraMode {
    case exploration      // Default floating follow
    case discovery        // Gentle pull toward object, subtle zoom
    case revelation       // Slow cinematic zoom, narrow DOF
    case transit          // Sweeping orbit for planet transition
}

// MARK: - Camera System

@MainActor
final class CameraSystem {
    
    // Camera state
    private(set) var position: SIMD3<Float> = SIMD3<Float>(0, 15, 30)
    private(set) var target: SIMD3<Float> = .zero
    private(set) var up: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    
    // Derived
    private(set) var forward: SIMD3<Float> = SIMD3<Float>(0, 0, -1)
    private(set) var right: SIMD3<Float> = SIMD3<Float>(1, 0, 0)
    
    // Camera facing yaw (derived from forward vector)
    var yaw: Float {
        atan2(forward.x, forward.z)
    }
    
    // Matrices
    private(set) var viewMatrix: float4x4 = matrix_identity_float4x4
    private(set) var projectionMatrix: float4x4 = matrix_identity_float4x4
    private(set) var viewProjectionMatrix: float4x4 = matrix_identity_float4x4
    
    // Camera parameters
    var fovDegrees: Float = 55.0
    var nearPlane: Float = 0.1
    var farPlane: Float = 2000.0
    var aspectRatio: Float = 16.0 / 9.0
    
    // Follow parameters
    var followDistance: Float = 8.0
    var followHeight: Float = 4.0
    var followLookAhead: Float = 3.0
    
    // Spring-damper parameters
    var positionSmoothTime: Float = 0.3 // Tightened for better flight tracking
    var rotationSmoothTime: Float = 0.2 // Tightened for better flight tracking
    var zoomSmoothTime: Float = 0.8
    
    // Internal spring state
    private var positionVelocity: SIMD3<Float> = .zero
    private var targetVelocity: SIMD3<Float> = .zero
    private var fovVelocity: Float = 0
    
    // Mode
    private(set) var mode: CameraMode = .exploration
    private var modeTransitionProgress: Float = 0
    private var modeStartTime: Float = 0
    
    // Discovery focus
    private var discoveryTarget: SIMD3<Float>?
    private var originalFOV: Float = 55.0
    
    // Orbital rotation (player input)
    var orbitYaw: Float = 0
    var orbitPitch: Float = 0.3  // Slight downward angle by default
    
    // Subtle idle motion
    private var idleTime: Float = 0
    
    // Camera shake
    private var shakeTrauma: Float = 0
    private let maxShakeAngle: Float = 0.05 // radians
    private let maxShakeOffset: Float = 0.3
    
    func addTrauma(_ amount: Float) {
        shakeTrauma = simd_clamp(shakeTrauma + amount, 0, 1.0)
    }
    
    // MARK: - Update
    
    func update(player: PlayerController, terrainHeight: Float?, deltaTime: Float, totalTime: Float) {
        idleTime += deltaTime
        
        // Handle high impacts (hard landings)
        if player.lastImpactVelocity > 15.0 {
            let impactForce = (player.lastImpactVelocity - 15.0) / 10.0
            addTrauma(impactForce * 0.5)
        }
        
        switch mode {
        case .exploration:
            updateExploration(player: player, terrainHeight: terrainHeight, deltaTime: deltaTime)
        case .discovery:
            updateDiscovery(playerPosition: player.position, deltaTime: deltaTime)
        case .revelation:
            updateRevelation(playerPosition: player.position, deltaTime: deltaTime)
        case .transit:
            updateTransit(deltaTime: deltaTime)
        }
        
        // Dynamic FOV based on speed
        if mode == .exploration {
            let speed = length(SIMD2<Float>(player.velocity.x, player.velocity.z))
            let fovOffset = simd_clamp((speed - player.baseSpeed) / player.baseSpeed * 10.0, 0, 15.0)
            let targetFOV = originalFOV + fovOffset
            
            fovDegrees = Interpolation.springDamp(
                current: fovDegrees,
                target: targetFOV,
                velocity: &fovVelocity,
                smoothTime: zoomSmoothTime,
                deltaTime: deltaTime
            )
        }
        
        // Add subtle idle breathing motion
        let breathX = sin(totalTime * 0.3) * 0.05
        let breathY = sin(totalTime * 0.2) * 0.08
        position += SIMD3<Float>(breathX, breathY, 0) * deltaTime
        
        // Apply Camera Shake
        if shakeTrauma > 0 {
            let shakeSquare = shakeTrauma * shakeTrauma
            
            // Positional shake
            let offsetX = maxShakeOffset * shakeSquare * Float.random(in: -1...1)
            let offsetY = maxShakeOffset * shakeSquare * Float.random(in: -1...1)
            let offsetZ = maxShakeOffset * shakeSquare * Float.random(in: -1...1)
            position += SIMD3<Float>(offsetX, offsetY, offsetZ)
            
            // Trauma decays over time
            shakeTrauma = max(shakeTrauma - deltaTime * 1.5, 0)
        }
        
        // Ensure camera doesn't clip through terrain
        if let th = terrainHeight {
            let minCamHeight = th + 1.0 // 1 meter above ground minimum
            if position.y < minCamHeight {
                position.y = Interpolation.springDamp(
                    current: position.y,
                    target: minCamHeight,
                    velocity: &positionVelocity.y,
                    smoothTime: 0.1,
                    deltaTime: deltaTime
                )
            }
        }
        
        // Update matrices
        updateMatrices()
        
        // Rotational shake applied after matrices
        if shakeTrauma > 0 {
            let shakeSquare = shakeTrauma * shakeTrauma
            let angleX = maxShakeAngle * shakeSquare * Float.random(in: -1...1)
            let angleY = maxShakeAngle * shakeSquare * Float.random(in: -1...1)
            
            // Simple rotational shake by translating the view matrix slightly and rotating it.
            let shakeRot = MatrixUtil.rotation(pitch: angleX, yaw: angleY, roll: 0)
            viewMatrix = shakeRot * viewMatrix
            viewProjectionMatrix = projectionMatrix * viewMatrix
        }
    }
    
    // MARK: - Exploration Mode
    
    private func updateExploration(player: PlayerController, terrainHeight: Float?, deltaTime: Float) {
        let playerPosition = player.position
        
        var desiredPosition: SIMD3<Float>
        var lookTarget: SIMD3<Float>
        
        if player.isAirborne && player.isJetpacking {
            // === FLIGHT MODE: Third-person view with full 360 rotation ===
            let yawRotation = MatrixUtil.rotation(pitch: 0, yaw: orbitYaw, roll: 0)
            
            // Use orbit pitch/yaw for camera placement around the flying player
            let camDist: Float = 15.0 // Slightly further for aerial view
            let pitchHeight = camDist * sin(orbitPitch)
            let pitchDist   = camDist * cos(orbitPitch)
            let baseOffset = SIMD4<Float>(0, pitchHeight, pitchDist, 0)
            let rotatedOffset = yawRotation * baseOffset
            
            desiredPosition = playerPosition + SIMD3<Float>(rotatedOffset.x, rotatedOffset.y, rotatedOffset.z)
            
            // Look directly at the player
            lookTarget = playerPosition
            
        } else {
            // === GROUND MODE: Normal third-person orbit ===
            let yawRotation = MatrixUtil.rotation(pitch: 0, yaw: orbitYaw, roll: 0)
            
            let pitchHeight = followDistance * sin(orbitPitch)
            let pitchDist   = followDistance * cos(orbitPitch)
            let baseOffset = SIMD4<Float>(0, pitchHeight, pitchDist, 0)
            let rotatedOffset = yawRotation * baseOffset
            
            desiredPosition = playerPosition + SIMD3<Float>(rotatedOffset.x, rotatedOffset.y, rotatedOffset.z)
            lookTarget = playerPosition + SIMD3<Float>(0, 1.5, 0)
            
            // Terrain clipping prevention
            if let th = terrainHeight {
                if desiredPosition.y < th + 1.0 {
                    desiredPosition.y = th + 1.0
                }
            }
        }
        
        // Spring-damped position following
        position = Interpolation.springDamp3(
            current: position,
            target: desiredPosition,
            velocity: &positionVelocity,
            smoothTime: positionSmoothTime,
            deltaTime: deltaTime
        )
        
        // Spring-damped look target
        target = Interpolation.springDamp3(
            current: target,
            target: lookTarget,
            velocity: &targetVelocity,
            smoothTime: rotationSmoothTime,
            deltaTime: deltaTime
        )
    }
    
    // MARK: - Discovery Mode
    
    private func updateDiscovery(playerPosition: SIMD3<Float>, deltaTime: Float) {
        guard discoveryTarget != nil else {
            setMode(.exploration)
            return
        }
        
        modeTransitionProgress += deltaTime
        
        // Stay behind the player like exploration, but do a gentle zoom-in
        let yawRotation = MatrixUtil.rotation(pitch: 0, yaw: orbitYaw, roll: 0)
        let pitchHeight = followDistance * sin(orbitPitch)
        let pitchDist = followDistance * cos(orbitPitch)
        let baseOffset = SIMD4<Float>(0, pitchHeight, pitchDist, 0)
        let rotatedOffset = yawRotation * baseOffset
        let desiredPosition = playerPosition + SIMD3<Float>(rotatedOffset.x, rotatedOffset.y, rotatedOffset.z)
        
        // Look at a point between player and discovered object
        let lookTarget = playerPosition + SIMD3<Float>(0, 2, 0)
        
        position = Interpolation.springDamp3(
            current: position, target: desiredPosition,
            velocity: &positionVelocity, smoothTime: positionSmoothTime, deltaTime: deltaTime
        )
        
        target = Interpolation.springDamp3(
            current: target, target: lookTarget,
            velocity: &targetVelocity, smoothTime: rotationSmoothTime, deltaTime: deltaTime
        )
        
        // Slight zoom in then back out
        let zoomPulse = sin(modeTransitionProgress * .pi / 2.0) * 5.0
        fovDegrees = Interpolation.springDamp(
            current: fovDegrees, target: originalFOV - zoomPulse,
            velocity: &fovVelocity, smoothTime: 0.5, deltaTime: deltaTime
        )
        
        // Auto-return to exploration after 2 seconds
        if modeTransitionProgress > 2.0 {
            discoveryTarget = nil
            setMode(.exploration)
        }
    }
    
    // MARK: - Revelation Mode
    
    private func updateRevelation(playerPosition: SIMD3<Float>, deltaTime: Float) {
        guard let discTarget = discoveryTarget else {
            setMode(.exploration)
            return
        }
        
        modeTransitionProgress += deltaTime * 0.3
        
        // Slow cinematic zoom toward the object
        let orbitalAngle = modeTransitionProgress * 0.2
        let orbitalRadius: Float = 12.0
        let desiredPosition = discTarget + SIMD3<Float>(
            cos(orbitalAngle) * orbitalRadius,
            6.0 + sin(modeTransitionProgress * 0.5) * 2.0,
            sin(orbitalAngle) * orbitalRadius
        )
        
        position = Interpolation.springDamp3(
            current: position, target: desiredPosition,
            velocity: &positionVelocity, smoothTime: 1.5, deltaTime: deltaTime
        )
        
        target = Interpolation.springDamp3(
            current: target, target: discTarget,
            velocity: &targetVelocity, smoothTime: 1.0, deltaTime: deltaTime
        )
        
        // Narrow FOV for cinematic feel
        fovDegrees = Interpolation.springDamp(
            current: fovDegrees, target: originalFOV - 15.0,
            velocity: &fovVelocity, smoothTime: 2.0, deltaTime: deltaTime
        )
        
        // Auto-return after ~5 seconds
        if modeTransitionProgress > 5.0 {
            setMode(.exploration)
        }
    }
    
    // MARK: - Transit Mode
    
    private func updateTransit(deltaTime: Float) {
        modeTransitionProgress += deltaTime
        // Will be implemented with planet transition system
    }
    
    // MARK: - Matrix Update
    
    private func updateMatrices() {
        forward = normalize(target - position)
        right = normalize(cross(forward, SIMD3<Float>(0, 1, 0)))
        up = cross(right, forward)
        
        viewMatrix = MatrixUtil.lookAt(eye: position, target: target, up: up)
        projectionMatrix = MatrixUtil.perspective(
            fovYRadians: fovDegrees * .pi / 180.0,
            aspectRatio: aspectRatio,
            near: nearPlane,
            far: farPlane
        )
        viewProjectionMatrix = projectionMatrix * viewMatrix
    }
    
    // MARK: - Mode Transitions
    
    func setMode(_ newMode: CameraMode) {
        mode = newMode
        modeTransitionProgress = 0
    }
    
    func focusOnDiscovery(at position: SIMD3<Float>) {
        discoveryTarget = position
        setMode(.discovery)
    }
    
    func beginRevelation(at position: SIMD3<Float>) {
        discoveryTarget = position
        setMode(.revelation)
    }
    
    func endDiscovery() {
        discoveryTarget = nil
        setMode(.exploration)
    }
    
    // MARK: - Input
    
    func rotateOrbit(deltaYaw: Float, deltaPitch: Float) {
        let sensitivity = SettingsManager.shared.cameraSensitivity
        let invertY: Float = SettingsManager.shared.invertYAxis ? -1.0 : 1.0
        orbitYaw += deltaYaw * 0.01 * sensitivity
        orbitPitch = simd_clamp(orbitPitch + deltaPitch * 0.02 * sensitivity * invertY, -1.4, 1.4)
    }
    
    func zoom(delta: Float) {
        followDistance = simd_clamp(followDistance + delta, 8.0, 50.0)
    }
    
    // MARK: - Frustum
    
    func frustum() -> Frustum {
        return Frustum(viewProjection: viewProjectionMatrix)
    }
}
