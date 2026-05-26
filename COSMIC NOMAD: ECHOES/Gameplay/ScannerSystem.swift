//
//  ScannerSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Object scanning mechanic: scan radius detection,
//  scan progress with visual feedback, triggers AI interpretation.
//

import simd
import Foundation

// MARK: - Scan Result

struct ScanResult {
    let objectType: String
    let worldPosition: SIMD3<Float>
    let scanTime: Float
    let interpretations: [String]  // Multiple possible meanings
    let confidence: Float          // 0-1 how certain the AI is
}

// MARK: - Scanner System

@MainActor
final class ScannerSystem {
    
    // Scanner state
    private(set) var isScanning: Bool = false
    private(set) var scanProgress: Float = 0     // 0-1
    private(set) var lastScanResult: ScanResult?
    
    // Scanner parameters
    let scanRadius: Float = 20.0       // Detection radius
    let scanDuration: Float = 2.0      // Seconds to complete scan
    let scanCooldown: Float = 1.0      // Seconds before next scan
    
    // Internal
    private var cooldownTimer: Float = 0
    private var currentTarget: SIMD3<Float>?
    
    // Callbacks
    var onScanComplete: ((ScanResult) -> Void)?
    var onScanStarted: (() -> Void)?
    
    // MARK: - Update
    
    func update(isPressed: Bool, inputProgress: Float, playerPosition: SIMD3<Float>, cameraForward: SIMD3<Float>, world: WorldGenerator, deltaTime: Float) {
        // Cooldown
        if cooldownTimer > 0 {
            cooldownTimer -= deltaTime
            return
        }
        
        if isPressed {
            if !isScanning {
                // Start scanning
                isScanning = true
                scanProgress = 0
                currentTarget = playerPosition + cameraForward * scanRadius * 0.5
                onScanStarted?()
            }
            
            // Update progress
            scanProgress = inputProgress
            
            if scanProgress >= 1.0 {
                // Scan complete!
                completeScan(at: playerPosition, cameraForward: cameraForward, world: world)
            }
        } else {
            if isScanning {
                // Cancelled
                isScanning = false
                scanProgress = 0
                currentTarget = nil
            }
        }
    }
    
    // MARK: - Scan Completion
    
    private func completeScan(at position: SIMD3<Float>, cameraForward: SIMD3<Float>, world: WorldGenerator) {
        isScanning = false
        scanProgress = 0
        cooldownTimer = scanCooldown
        
        let lookPoint = position + cameraForward * scanRadius * 0.5
        
        // Find nearest memory fragment
        var nearestFrag: MemoryFragment? = nil
        var minDist: Float = scanRadius
        
        for frag in world.memoryFragmentSystem.fragments {
            let dx = frag.worldPosition.x - lookPoint.x
            let dz = frag.worldPosition.z - lookPoint.z
            let dist = sqrt(dx*dx + dz*dz)
            
            if dist < minDist {
                minDist = dist
                nearestFrag = frag
            }
        }
        
        let result: ScanResult
        
        if let frag = nearestFrag {
            // Found a fragment!
            world.memoryFragmentSystem.markDiscovered(id: frag.id)
            result = ScanResult(
                objectType: frag.fragmentType.rawValue,
                worldPosition: frag.worldPosition,
                scanTime: 0,
                interpretations: [frag.title, frag.content],
                confidence: 0.95
            )
        } else {
            // Found nothing specific, generic terrain scan
            let h = world.heightAt(worldX: lookPoint.x, worldZ: lookPoint.z) ?? 0
            result = ScanResult(
                objectType: "Terrain Analysis",
                worldPosition: SIMD3<Float>(lookPoint.x, h, lookPoint.z),
                scanTime: 0,
                interpretations: [
                    "Mineral composition matches standard planetary crust.",
                    "No anomalous energy signatures detected.",
                    "Elevation: \(Int(h))m"
                ],
                confidence: 0.8
            )
        }
        
        lastScanResult = result
        onScanComplete?(result)
        currentTarget = nil
    }
    
    // MARK: - Visual State
    
    var scannerRingScale: Float {
        if isScanning {
            return 0.5 + scanProgress * 0.5  // Grows as scan progresses
        }
        return 0
    }
    
    var scannerRingAlpha: Float {
        if isScanning {
            return 0.3 + scanProgress * 0.7
        }
        return 0
    }
}
