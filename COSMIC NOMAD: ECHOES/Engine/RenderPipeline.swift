//
//  RenderPipeline.swift
//  COSMIC NOMAD: ECHOES
//
//  Manages the deferred rendering pipeline: G-buffer allocation,
//  pipeline state cache, render pass configuration for each stage.
//

import Metal
import MetalKit
import simd

@MainActor
final class RenderPipeline {
    
    private let device: MTLDevice
    private let resources: ResourceManager
    
    // G-Buffer textures
    private(set) var albedoTexture: MTLTexture?
    private(set) var normalTexture: MTLTexture?
    private(set) var pbrTexture: MTLTexture?
    private(set) var depthTexture: MTLTexture?
    
    // Intermediate render targets
    private(set) var litSceneTexture: MTLTexture?
    private(set) var bloomTexture0: MTLTexture?  // Half-res for bloom
    private(set) var bloomTexture1: MTLTexture?  // Ping-pong blur target
    
    // Shadow Map
    private(set) var shadowDepthTexture: MTLTexture?
    let shadowMapResolution: Int = 2048
    
    // SSAO
    private(set) var ssaoTexture: MTLTexture?
    private(set) var ssaoBlurTexture: MTLTexture?
    
    // Pipeline states
    private(set) var terrainPipeline: MTLRenderPipelineState!
    private(set) var entityPipeline: MTLRenderPipelineState!
    private(set) var deferredLightingPipeline: MTLRenderPipelineState!
    private(set) var atmospherePipeline: MTLRenderPipelineState!
    private(set) var bloomThresholdPipeline: MTLRenderPipelineState!
    private(set) var blurHorizontalPipeline: MTLRenderPipelineState!
    private(set) var blurVerticalPipeline: MTLRenderPipelineState!
    private(set) var finalCompositePipeline: MTLRenderPipelineState!
    private(set) var shadowPipeline: MTLRenderPipelineState!
    private(set) var ssaoPipeline: MTLRenderPipelineState!
    private(set) var ssaoBlurPipeline: MTLRenderPipelineState!
    
    // Depth stencil states
    private(set) var depthWriteState: MTLDepthStencilState!
    private(set) var depthReadOnlyState: MTLDepthStencilState!
    private(set) var depthDisabledState: MTLDepthStencilState!
    
    // Current screen dimensions
    private(set) var screenWidth: Int = 1
    private(set) var screenHeight: Int = 1
    
    init(device: MTLDevice, resources: ResourceManager) {
        self.device = device
        self.resources = resources
    }
    
    // MARK: - Setup
    
    func buildPipelines() throws {
        // --- Terrain G-Buffer Pipeline ---
        let terrainVD = MTLVertexDescriptor()
        // Position
        terrainVD.attributes[0].format = .float3
        terrainVD.attributes[0].offset = 0
        terrainVD.attributes[0].bufferIndex = 0
        // Normal
        terrainVD.attributes[1].format = .float3
        terrainVD.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        terrainVD.attributes[1].bufferIndex = 0
        // TexCoord
        terrainVD.attributes[2].format = .float2
        terrainVD.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride * 2
        terrainVD.attributes[2].bufferIndex = 0
        // Material Weights
        terrainVD.attributes[3].format = .float4
        terrainVD.attributes[3].offset = MemoryLayout<SIMD3<Float>>.stride * 2 + MemoryLayout<SIMD2<Float>>.stride
        terrainVD.attributes[3].bufferIndex = 0
        // Layout
        terrainVD.layouts[0].stride = MemoryLayout<TerrainVertex>.stride
        terrainVD.layouts[0].stepFunction = .perVertex
        
        terrainPipeline = try resources.makeRenderPipelineState(
            vertexFunction: "terrainVertex",
            fragmentFunction: "terrainFragment",
            colorFormats: [.rgba8Unorm, .rgba16Float, .rgba8Unorm],
            depthFormat: .depth32Float,
            vertexDescriptor: terrainVD,
            label: "Terrain G-Buffer"
        )
        
        // --- Entity G-Buffer Pipeline ---
        let entityVD = MTLVertexDescriptor()
        // Position
        entityVD.attributes[0].format = .float3
        entityVD.attributes[0].offset = 0
        entityVD.attributes[0].bufferIndex = 0
        // Normal
        entityVD.attributes[1].format = .float3
        entityVD.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        entityVD.attributes[1].bufferIndex = 0
        // TexCoord
        entityVD.attributes[2].format = .float2
        entityVD.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride * 2
        entityVD.attributes[2].bufferIndex = 0
        // Layout
        entityVD.layouts[0].stride = MemoryLayout<EntityVertex>.stride
        entityVD.layouts[0].stepFunction = .perVertex
        
        entityPipeline = try resources.makeRenderPipelineState(
            vertexFunction: "entityVertexShader",
            fragmentFunction: "entityFragmentShader",
            colorFormats: [.rgba8Unorm, .rgba16Float, .rgba8Unorm],
            depthFormat: .depth32Float,
            vertexDescriptor: entityVD,
            label: "Entity G-Buffer"
        )
        
        // --- Deferred Lighting ---
        deferredLightingPipeline = try resources.makeFullscreenPipelineState(
            fragmentFunction: "deferredLightingFragment",
            colorFormats: [.rgba16Float],
            label: "Deferred Lighting"
        )
        
        // --- Atmosphere ---
        atmospherePipeline = try resources.makeFullscreenPipelineState(
            fragmentFunction: "atmosphereFragment",
            colorFormats: [.rgba16Float],
            label: "Atmosphere"
        )
        
        // --- Bloom ---
        bloomThresholdPipeline = try resources.makeFullscreenPipelineState(
            fragmentFunction: "bloomThresholdFragment",
            colorFormats: [.rgba16Float],
            label: "Bloom Threshold"
        )
        
        blurHorizontalPipeline = try resources.makeFullscreenPipelineState(
            fragmentFunction: "gaussianBlurHorizontal",
            colorFormats: [.rgba16Float],
            label: "Blur Horizontal"
        )
        
        blurVerticalPipeline = try resources.makeFullscreenPipelineState(
            fragmentFunction: "gaussianBlurVertical",
            colorFormats: [.rgba16Float],
            label: "Blur Vertical"
        )
        
        // --- Final Composite ---
        finalCompositePipeline = try resources.makeFullscreenPipelineState(
            fragmentFunction: "finalCompositeFragment",
            colorFormats: [.bgra8Unorm],
            depthFormat: .invalid,
            label: "Final Composite"
        )
        
        // --- Depth Stencil States ---
        depthWriteState = resources.makeDepthStencilState(depthCompare: .less, depthWrite: true)
        depthReadOnlyState = resources.makeDepthStencilState(depthCompare: .less, depthWrite: false)
        depthDisabledState = resources.makeDepthStencilState(depthCompare: .always, depthWrite: false)
        
        // --- Shadow Map Pipeline ---
        let shadowVD = MTLVertexDescriptor()
        shadowVD.attributes[0].format = .float3
        shadowVD.attributes[0].offset = 0
        shadowVD.attributes[0].bufferIndex = 0
        shadowVD.attributes[1].format = .float3
        shadowVD.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        shadowVD.attributes[1].bufferIndex = 0
        shadowVD.attributes[2].format = .float2
        shadowVD.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride * 2
        shadowVD.attributes[2].bufferIndex = 0
        shadowVD.attributes[3].format = .float4
        shadowVD.attributes[3].offset = MemoryLayout<SIMD3<Float>>.stride * 2 + MemoryLayout<SIMD2<Float>>.stride
        shadowVD.attributes[3].bufferIndex = 0
        shadowVD.layouts[0].stride = MemoryLayout<TerrainVertex>.stride
        shadowVD.layouts[0].stepFunction = .perVertex
        
        shadowPipeline = try resources.makeRenderPipelineState(
            vertexFunction: "shadowVertex",
            fragmentFunction: "shadowFragment",
            colorFormats: [],
            depthFormat: .depth32Float,
            vertexDescriptor: shadowVD,
            label: "Shadow Map"
        )
        
        // --- SSAO Pipeline ---
        ssaoPipeline = try resources.makeFullscreenPipelineState(
            fragmentFunction: "ssaoFragment",
            colorFormats: [.r8Unorm],
            label: "SSAO"
        )
        
        ssaoBlurPipeline = try resources.makeFullscreenPipelineState(
            fragmentFunction: "ssaoBlurFragment",
            colorFormats: [.r8Unorm],
            label: "SSAO Blur"
        )
    }
    
    // MARK: - Screen-Size-Dependent Resources
    
    func resize(width: Int, height: Int) {
        guard width > 0 && height > 0 else { return }
        guard width != screenWidth || height != screenHeight else { return }
        
        screenWidth = width
        screenHeight = height
        
        // G-Buffer textures
        albedoTexture = resources.createRenderTarget(
            width: width, height: height,
            format: .rgba8Unorm,
            label: "G-Buffer Albedo"
        )
        
        normalTexture = resources.createRenderTarget(
            width: width, height: height,
            format: .rgba16Float,
            label: "G-Buffer Normal"
        )
        
        pbrTexture = resources.createRenderTarget(
            width: width, height: height,
            format: .rgba8Unorm,
            label: "G-Buffer PBR"
        )
        
        depthTexture = resources.createDepthTexture(width: width, height: height)
        
        // Lit scene (HDR)
        litSceneTexture = resources.createRenderTarget(
            width: width, height: height,
            format: .rgba16Float,
            label: "Lit Scene HDR"
        )
        
        // Bloom textures (half resolution)
        let bloomW = width / 2
        let bloomH = height / 2
        bloomTexture0 = resources.createRenderTarget(
            width: bloomW, height: bloomH,
            format: .rgba16Float,
            label: "Bloom 0"
        )
        bloomTexture1 = resources.createRenderTarget(
            width: bloomW, height: bloomH,
            format: .rgba16Float,
            label: "Bloom 1"
        )
        
        print("🖥️ RenderPipeline: Resized to \(width)×\(height), Memory: \(resources.memoryUsageString)")
        
        // Shadow map (fixed size, not screen-dependent, but create on first resize)
        if shadowDepthTexture == nil {
            let shadowDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .depth32Float,
                width: shadowMapResolution,
                height: shadowMapResolution,
                mipmapped: false
            )
            shadowDesc.storageMode = .private
            shadowDesc.usage = [.renderTarget, .shaderRead]
            shadowDepthTexture = device.makeTexture(descriptor: shadowDesc)
            shadowDepthTexture?.label = "Shadow Depth Map"
        }
        
        // SSAO textures (half resolution)
        let ssaoW = max(1, width / 2)
        let ssaoH = max(1, height / 2)
        ssaoTexture = resources.createRenderTarget(
            width: ssaoW, height: ssaoH,
            format: .r8Unorm,
            label: "SSAO Raw"
        )
        ssaoBlurTexture = resources.createRenderTarget(
            width: ssaoW, height: ssaoH,
            format: .r8Unorm,
            label: "SSAO Blurred"
        )
    }
    
    // MARK: - Render Pass Descriptors
    
    func gBufferPassDescriptor() -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        
        desc.colorAttachments[0].texture = albedoTexture
        desc.colorAttachments[0].loadAction = .clear
        desc.colorAttachments[0].storeAction = .store
        desc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        desc.colorAttachments[1].texture = normalTexture
        desc.colorAttachments[1].loadAction = .clear
        desc.colorAttachments[1].storeAction = .store
        desc.colorAttachments[1].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0)
        
        desc.colorAttachments[2].texture = pbrTexture
        desc.colorAttachments[2].loadAction = .clear
        desc.colorAttachments[2].storeAction = .store
        desc.colorAttachments[2].clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 0)
        
        desc.depthAttachment.texture = depthTexture
        desc.depthAttachment.loadAction = .clear
        desc.depthAttachment.storeAction = .store
        desc.depthAttachment.clearDepth = 1.0
        
        return desc
    }
    
    func lightingPassDescriptor() -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = litSceneTexture
        desc.colorAttachments[0].loadAction = .clear
        desc.colorAttachments[0].storeAction = .store
        desc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        return desc
    }
    
    func atmospherePassDescriptor() -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = litSceneTexture
        desc.colorAttachments[0].loadAction = .load
        desc.colorAttachments[0].storeAction = .store
        return desc
    }
    
    func bloomPassDescriptor(target: MTLTexture) -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = target
        desc.colorAttachments[0].loadAction = .dontCare
        desc.colorAttachments[0].storeAction = .store
        return desc
    }
    
    func finalPassDescriptor(drawable: MTLTexture) -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = drawable
        desc.colorAttachments[0].loadAction = .dontCare
        desc.colorAttachments[0].storeAction = .store
        return desc
    }
    
    func shadowPassDescriptor() -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        // Dummy color attachment (required by pipeline)
        // We only care about depth, but pipeline has a color format
        desc.depthAttachment.texture = shadowDepthTexture
        desc.depthAttachment.loadAction = .clear
        desc.depthAttachment.storeAction = .store
        desc.depthAttachment.clearDepth = 1.0
        return desc
    }
    
    func ssaoPassDescriptor() -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = ssaoTexture
        desc.colorAttachments[0].loadAction = .dontCare
        desc.colorAttachments[0].storeAction = .store
        return desc
    }
    
    func ssaoBlurPassDescriptor() -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].texture = ssaoBlurTexture
        desc.colorAttachments[0].loadAction = .dontCare
        desc.colorAttachments[0].storeAction = .store
        return desc
    }
}
