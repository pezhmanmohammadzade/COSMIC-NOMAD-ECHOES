//
//  MetalView.swift
//  COSMIC NOMAD: ECHOES
//
//  UIViewRepresentable wrapping MTKView for SwiftUI integration.
//  Handles Metal setup, display link, and touch forwarding.
//

import SwiftUI
import MetalKit

// MARK: - MetalView (SwiftUI Bridge)

struct MetalView: UIViewRepresentable {
    
    @Binding var engine: GameEngine?
    let onEngineCreated: (GameEngine) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> GameMTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        let mtkView = GameMTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = false  // Need to read back for post-processing
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        // Create game engine
        do {
            let gameEngine = try GameEngine(device: device)
            mtkView.delegate = gameEngine
            mtkView.inputManager = gameEngine.inputManager
            context.coordinator.engine = gameEngine
            
            // Notify parent
            DispatchQueue.main.async {
                onEngineCreated(gameEngine)
            }
        } catch {
            print("❌ Failed to create GameEngine: \(error)")
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: GameMTKView, context: Context) {
        // Nothing to update dynamically
    }
    
    class Coordinator {
        var engine: GameEngine?
    }
}

// MARK: - Custom MTKView with Touch Handling

class GameMTKView: MTKView {
    
    weak var inputManager: InputManager?
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        isMultipleTouchEnabled = true
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        inputManager?.screenSize = SIMD2<Float>(Float(bounds.width), Float(bounds.height))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager?.touchesBegan(touches, in: self)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager?.touchesMoved(touches, in: self)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager?.touchesEnded(touches, in: self)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager?.touchesCancelled(touches, in: self)
    }
}
