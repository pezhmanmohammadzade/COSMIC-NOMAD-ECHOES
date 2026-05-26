//
//  ParticleSystem.swift
//  COSMIC NOMAD: ECHOES
//
//  Manages compute-based particle simulation and rendering.
//

import Metal
import MetalKit
import simd

final class ParticleSystem {
    
    let maxParticles = 10000
    private var particleBuffer: MTLBuffer!
    
    private var computePipelineState: MTLComputePipelineState!
    private var renderPipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    
    var uniforms = ParticleUniforms()
    
    init(device: MTLDevice, library: MTLLibrary, colorPixelFormat: MTLPixelFormat, depthPixelFormat: MTLPixelFormat) throws {
        
        uniforms.particleCount = UInt32(maxParticles)
        
        // Setup Buffer
        let bufferSize = MemoryLayout<Particle>.stride * maxParticles
        particleBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)
        
        // Initialize particles with 0 life so they respawn
        let pointer = particleBuffer.contents().bindMemory(to: Particle.self, capacity: maxParticles)
        for i in 0..<maxParticles {
            pointer[i].life = 0
            pointer[i].maxLife = 1.0
        }
        
        // Setup Compute
        guard let computeFunc = library.makeFunction(name: "updateParticles") else {
            fatalError("Could not find updateParticles shader")
        }
        computePipelineState = try device.makeComputePipelineState(function: computeFunc)
        
        // Setup Render
        guard let vertexFunc = library.makeFunction(name: "particleVertex"),
              let fragmentFunc = library.makeFunction(name: "particleFragment") else {
            fatalError("Could not find particle rendering shaders")
        }
        
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Particle Render Pipeline"
        desc.vertexFunction = vertexFunc
        desc.fragmentFunction = fragmentFunc
        desc.colorAttachments[0].pixelFormat = colorPixelFormat
        
        // Additive Blending
        let colorAttachment = desc.colorAttachments[0]!
        colorAttachment.isBlendingEnabled = true
        colorAttachment.sourceRGBBlendFactor = .one
        colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorAttachment.sourceAlphaBlendFactor = .one
        colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        desc.depthAttachmentPixelFormat = depthPixelFormat
        
        renderPipelineState = try device.makeRenderPipelineState(descriptor: desc)
        
        // Depth state (read only, no write so particles don't occlude each other)
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = false
        depthState = device.makeDepthStencilState(descriptor: depthDesc)
    }
    
    func update(commandBuffer: MTLCommandBuffer, deltaTime: Float, time: Float, cameraPosition: SIMD3<Float>, weatherType: Float) {
        uniforms.deltaTime = deltaTime
        uniforms.time = time
        uniforms.emitterPosition = cameraPosition
        uniforms.activeType = weatherType // 0 = dust, 1 = rain, 2 = snow
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        computeEncoder.label = "Particle Compute"
        
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<ParticleUniforms>.stride, index: 1)
        
        let w = computePipelineState.threadExecutionWidth
        let threadsPerThreadgroup = MTLSizeMake(w, 1, 1)
        let threadsPerGrid = MTLSizeMake(maxParticles, 1, 1)
        
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Draw Particles")
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: maxParticles)
        
        renderEncoder.popDebugGroup()
    }
}
