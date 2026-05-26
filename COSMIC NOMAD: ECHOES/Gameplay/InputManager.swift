//
//  InputManager.swift
//  COSMIC NOMAD: ECHOES
//
//  Unified input abstraction: touch gesture recognition,
//  virtual joystick computation, scan gesture detection.
//

import UIKit
import simd

// MARK: - Input State

struct InputState {
    // Movement (virtual joystick)
    var moveDirection: SIMD2<Float> = .zero
    var moveStrength: Float = 0
    
    // Camera
    var lookDelta: SIMD2<Float> = .zero
    var zoomDelta: Float = 0
    
    // Actions
    var isScanningPressed: Bool = false
    var scanProgress: Float = 0
    var tapPosition: SIMD2<Float>?
    var isJetpackPressed: Bool = false
    var isJumpPressed: Bool = false
    
    // Raw
    var primaryTouchPosition: SIMD2<Float>?
    var touchCount: Int = 0
    
    // Movement info
    var isMoving: Bool { moveStrength > 0.01 }
}

// MARK: - Input Manager

@MainActor
final class InputManager {
    
    private(set) var state = InputState()
    
    func setJetpack(_ active: Bool) {
        state.isJetpackPressed = active
    }
    
    // Virtual joystick
    private var joystickCenter: SIMD2<Float>?
    private var joystickTouchID: UITouch?
    private let joystickDeadzone: Float = 10  // pixels
    private let joystickMaxRadius: Float = 60  // pixels
    
    // Camera touch
    private var cameraTouchID: UITouch?
    private var lastCameraPosition: SIMD2<Float>?
    private var lastTapTime: CFAbsoluteTime = 0
    
    // Scan gesture
    private var scanTouchStart: CFAbsoluteTime = 0
    private var scanInitialPosition: SIMD2<Float>?
    private let scanHoldDuration: Float = 0.5  // seconds to start scanning
    private let scanCompleteDuration: Float = 2.0  // seconds to complete scan
    private var isScanTouch: Bool = false
    
    // Screen size for normalization
    var screenSize: SIMD2<Float> = SIMD2<Float>(1, 1)
    
    // MARK: - Touch Handling
    
    func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let loc = touch.location(in: view)
            let pos = SIMD2<Float>(Float(loc.x), Float(loc.y))
            
            // Left half = joystick, Right half = camera
            let isLeftSide = pos.x < screenSize.x * 0.4
            
            if isLeftSide && joystickTouchID == nil {
                // Start virtual joystick
                joystickTouchID = touch
                joystickCenter = pos
                state.moveDirection = .zero
                state.moveStrength = 0
            } else if !isLeftSide && cameraTouchID == nil {
                // Start camera control
                cameraTouchID = touch
                lastCameraPosition = pos
                
                // Check for long press (scan)
                scanTouchStart = CFAbsoluteTimeGetCurrent()
                scanInitialPosition = pos
                isScanTouch = true
            }
        }
        
        state.touchCount = countActiveTouches()
    }
    
    func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let loc = touch.location(in: view)
            let pos = SIMD2<Float>(Float(loc.x), Float(loc.y))
            
            if touch === joystickTouchID, let center = joystickCenter {
                // Update joystick
                let delta = pos - center
                let distance = length(delta)
                
                if distance > joystickDeadzone {
                    let clamped = min(distance, joystickMaxRadius)
                    state.moveDirection = normalize(delta)
                    state.moveStrength = (clamped - joystickDeadzone) / (joystickMaxRadius - joystickDeadzone)
                    state.moveStrength = simd_clamp(state.moveStrength, 0, 1)
                } else {
                    state.moveDirection = .zero
                    state.moveStrength = 0
                }
            }
            
            if touch === cameraTouchID, let lastPos = lastCameraPosition {
                let delta = pos - lastPos
                state.lookDelta = delta
                lastCameraPosition = pos
                
                // If moved significantly from initial touch, cancel scan
                if let initial = scanInitialPosition, length(pos - initial) > 15 {
                    isScanTouch = false
                    state.isScanningPressed = false
                    state.scanProgress = 0
                }
            }
        }
    }
    
    func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            if touch === joystickTouchID {
                joystickTouchID = nil
                joystickCenter = nil
                state.moveDirection = .zero
                state.moveStrength = 0
            }
            
            if touch === cameraTouchID {
                // Check for tap
                let elapsed = Float(CFAbsoluteTimeGetCurrent() - scanTouchStart)
                if elapsed < 0.3 && isScanTouch {
                    let loc = touch.location(in: view)
                    state.tapPosition = SIMD2<Float>(Float(loc.x) / screenSize.x, Float(loc.y) / screenSize.y)
                    
                    let currentTime = CFAbsoluteTimeGetCurrent()
                    if currentTime - lastTapTime < 0.35 {
                        state.isJumpPressed = true
                        lastTapTime = 0
                    } else {
                        lastTapTime = currentTime
                    }
                }
                
                cameraTouchID = nil
                lastCameraPosition = nil
                scanInitialPosition = nil
                state.lookDelta = .zero
                state.isScanningPressed = false
                state.scanProgress = 0
                isScanTouch = false
            }
        }
        
        state.touchCount = countActiveTouches()
    }
    
    func touchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
        touchesEnded(touches, in: view)
    }
    
    // MARK: - Pinch Handling
    
    func handlePinch(scale: Float) {
        state.zoomDelta = (1.0 - scale) * 5.0
    }
    
    // MARK: - Per-Frame Update
    
    func update(deltaTime: Float) {
        // Update scan progress
        if isScanTouch && cameraTouchID != nil {
            let elapsed = Float(CFAbsoluteTimeGetCurrent() - scanTouchStart)
            
            if elapsed > scanHoldDuration {
                state.isScanningPressed = true
                state.scanProgress = min((elapsed - scanHoldDuration) / scanCompleteDuration, 1.0)
            }
        }
    }
    
    // Call at the END of the frame
    func clearDeltas() {
        // Clear per-frame events
        state.tapPosition = nil
        state.lookDelta = .zero
        state.zoomDelta = 0
        state.isJumpPressed = false
    }
    
    // MARK: - Helpers
    
    private func countActiveTouches() -> Int {
        var count = 0
        if joystickTouchID != nil { count += 1 }
        if cameraTouchID != nil { count += 1 }
        return count
    }
}
