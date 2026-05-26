//
//  MetalRenderer.swift
//  COSMIC NOMAD: ECHOES
//
//  Core Metal rendering coordinator: orchestrates the deferred rendering pipeline
//  through G-buffer → Lighting → Atmosphere → Post-processing stages.
//  Triple-buffered command submission targeting 60fps.
//

import Metal
import MetalKit
import simd

@MainActor
final class MetalRenderer: NSObject {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let resources: ResourceManager
    let pipeline: RenderPipeline
    
    // Systems
    var particleSystem: ParticleSystem?
    var astronautRenderer: AstronautRenderer?
    var gemRenderer: GemRenderer?
    
    // World reference (set by GameEngine for gem rendering)
    weak var world: WorldGenerator?
    
    // NPC data (set by GameEngine)
    var npcRenderer: NPCRenderer?
    var npcCreatures: [AlienCreature] = []
    
    // Frame synchronization
    private let frameSemaphore = DispatchSemaphore(value: ResourceManager.maxFramesInFlight)
    private var frameIndex: Int = 0
    
    // Frame timing
    private(set) var totalTime: Float = 0
    private(set) var deltaTime: Float = 0
    private var lastFrameTime: CFAbsoluteTime = 0
    
    // Frame uniforms
    private var frameUniforms = FrameUniforms()
    private var atmosphereParams = AtmosphereParams()
    private var postProcessParams = PostProcessParams()
    
    // References to game systems (set by GameEngine)
    weak var camera: CameraSystem?
    weak var player: PlayerController?
    var terrainChunks: [TerrainChunk] = []
    var terrainParamsList: [TerrainParams] = []
    var currentWeatherType: Float = 0.0 // 0=dust, 1=rain, 2=snow
    
    // Performance stats
    private(set) var lastGPUTime: Double = 0
    private(set) var frameCount: Int = 0
    
    // MARK: - Init
    
    init(device: MTLDevice) throws {
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            throw EngineError.resourceAllocationFailed("Failed to create command queue")
        }
        self.commandQueue = queue
        self.resources = try ResourceManager(device: device)
        self.pipeline = RenderPipeline(device: device, resources: resources)
        
        super.init()
        
        try pipeline.buildPipelines()
        
        // Initialize particle system
        if let library = device.makeDefaultLibrary() {
            self.particleSystem = try? ParticleSystem(
                device: device,
                library: library,
                colorPixelFormat: .rgba16Float, // Matches litScene format
                depthPixelFormat: .depth32Float
            )
        }
        
        self.astronautRenderer = AstronautRenderer(device: device)
        self.gemRenderer = GemRenderer(device: device)
        
        print("🎨 MetalRenderer: Initialized with \(device.name)")
    }
    
    // MARK: - Resize
    
    func resize(width: Int, height: Int) {
        pipeline.resize(width: width, height: height)
    }
    
    // MARK: - Update Params
    
    func setAtmosphereParams(_ params: AtmosphereParams) {
        self.atmosphereParams = params
    }
    
    func setPostProcessParams(_ params: PostProcessParams) {
        self.postProcessParams = params
    }
    
    // MARK: - Render Frame
    
    func renderFrame(in view: MTKView) {
        // Wait for available frame slot
        frameSemaphore.wait()
        
        // Timing
        let currentTime = CFAbsoluteTimeGetCurrent()
        if lastFrameTime > 0 {
            deltaTime = Float(currentTime - lastFrameTime)
        }
        lastFrameTime = currentTime
        totalTime += deltaTime
        frameCount += 1
        
        // Advance triple-buffer index
        frameIndex = resources.advanceFrame()
        
        // Update frame uniforms
        updateFrameUniforms()
        
        // Get drawable
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            frameSemaphore.signal()
            return
        }
        
        commandBuffer.label = "Frame \(frameCount)"
        
        let quality = SettingsManager.shared.graphicsQuality
        
        // --- Pass 0: Shadow Map ---
        if quality != .low {
            renderShadowPass(commandBuffer: commandBuffer)
        }
        
        // --- Pass 1: G-Buffer ---
        renderGBufferPass(commandBuffer: commandBuffer)
        
        // --- Pass 1.5: SSAO ---
        if quality != .low {
            renderSSAOPass(commandBuffer: commandBuffer)
        }
        
        // --- Pass 2: Deferred Lighting ---
        renderLightingPass(commandBuffer: commandBuffer)
        
        // --- Pass 3: Atmosphere + Fog ---
        renderAtmospherePass(commandBuffer: commandBuffer)
        
        // --- Pass 3.5: Particles ---
        renderParticles(commandBuffer: commandBuffer)
        
        // --- Pass 4: Bloom ---
        renderBloomPass(commandBuffer: commandBuffer)
        
        // --- Pass 5: Final Composite ---
        renderFinalComposite(commandBuffer: commandBuffer, drawable: drawable.texture)
        
        // Present and signal
        commandBuffer.present(drawable)
        
        let sem = frameSemaphore
        commandBuffer.addCompletedHandler { _ in
            sem.signal()
        }
        
        commandBuffer.commit()
    }
    
    // MARK: - Frame Uniforms Update
    
    private func updateFrameUniforms() {
        guard let cam = camera else { return }
        
        frameUniforms.viewMatrix = cam.viewMatrix
        frameUniforms.projectionMatrix = cam.projectionMatrix
        frameUniforms.viewProjectionMatrix = cam.viewProjectionMatrix
        frameUniforms.inverseViewMatrix = cam.viewMatrix.inverse
        frameUniforms.inverseProjectionMatrix = cam.projectionMatrix.inverse
        frameUniforms.cameraPosition = cam.position
        frameUniforms.cameraForward = cam.forward
        frameUniforms.time = totalTime
        frameUniforms.deltaTime = deltaTime
        frameUniforms.screenSize = SIMD2<Float>(Float(pipeline.screenWidth), Float(pipeline.screenHeight))
        frameUniforms.nearPlane = cam.nearPlane
        frameUniforms.farPlane = cam.farPlane
        
        // Compute light view-projection matrix for shadow mapping
        let sunDir = frameUniforms.sunDirection
        let playerPos = player?.position ?? .zero
        let lightTarget = playerPos
        let lightPos = lightTarget + SIMD3<Float>(sunDir.x, sunDir.y, sunDir.z) * 100.0
        let lightUp = SIMD3<Float>(0, 1, 0)
        let lightView = MatrixUtil.lookAt(eye: lightPos, target: lightTarget, up: lightUp)
        let shadowExtent: Float = 120.0
        let lightProjection = MatrixUtil.orthographic(
            left: -shadowExtent, right: shadowExtent,
            bottom: -shadowExtent, top: shadowExtent,
            near: 0.1, far: 300.0
        )
        frameUniforms.lightViewProjectionMatrix = lightProjection * lightView
        
        resources.updateUniforms(frameUniforms)
        resources.updateAtmosphereParams(atmosphereParams)
        resources.updatePostProcessParams(postProcessParams)
        
        if !terrainParamsList.isEmpty {
            resources.updateTerrainParams(terrainParamsList)
        }
    }
    
    // MARK: - Pass 1: G-Buffer
    
    private func renderGBufferPass(commandBuffer: MTLCommandBuffer) {
        let passDesc = pipeline.gBufferPassDescriptor()
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.label = "G-Buffer Pass"
        
        encoder.setRenderPipelineState(pipeline.terrainPipeline)
        encoder.setDepthStencilState(pipeline.depthWriteState)
        encoder.setCullMode(.back)
        encoder.setFrontFacing(.counterClockwise)
        
        // Bind frame uniforms
        encoder.setVertexBuffer(resources.uniformBuffer(for: .uniforms), offset: 0, index: BufferIndex.uniforms.rawValue)
        encoder.setFragmentBuffer(resources.uniformBuffer(for: .uniforms), offset: 0, index: BufferIndex.uniforms.rawValue)
        
        // Draw terrain chunks
        let terrainParamsBuffer = resources.uniformBuffer(for: .terrainParams)
        
        for (index, chunk) in terrainChunks.enumerated() {
            guard chunk.isReady else { continue }
            
            let paramsOffset = index * MemoryLayout<TerrainParams>.stride
            encoder.setVertexBuffer(chunk.vertexBuffer, offset: 0, index: BufferIndex.vertices.rawValue)
            encoder.setVertexBuffer(terrainParamsBuffer, offset: paramsOffset, index: BufferIndex.terrainParams.rawValue)
            encoder.setFragmentBuffer(terrainParamsBuffer, offset: paramsOffset, index: BufferIndex.terrainParams.rawValue)
            
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: chunk.indexCount,
                indexType: .uint32,
                indexBuffer: chunk.indexBuffer!,
                indexBufferOffset: 0
            )
        }
        
        // --- Draw Entities (Instanced) ---
        encoder.setRenderPipelineState(pipeline.entityPipeline)
        encoder.setVertexBuffer(resources.cubeVertexBuffer, offset: 0, index: BufferIndex.vertices.rawValue)
        
        for chunk in terrainChunks {
            guard chunk.isReady, let instanceBuffer = chunk.entityInstanceBuffer, !chunk.entities.isEmpty else { continue }
            
            encoder.setVertexBuffer(instanceBuffer, offset: 0, index: BufferIndex.instanceData.rawValue)
            
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: resources.cubeIndexCount,
                indexType: .uint16,
                indexBuffer: resources.cubeIndexBuffer,
                indexBufferOffset: 0,
                instanceCount: chunk.entities.count
            )
        }
        
        // --- Draw Astronaut ---
        if let player = self.player {
            let isMoving = player.isMoving
            astronautRenderer?.update(isMoving: isMoving, deltaTime: deltaTime, isFlying: player.isJetpacking, isSprinting: player.isSprinting)
            astronautRenderer?.draw(
                player: player,
                encoder: encoder,
                resources: resources,
                pipeline: pipeline,
                time: totalTime,
                isMoving: isMoving
            )
        }
        
        // --- Draw Gem markers at undiscovered signal locations ---
        if let world = self.world {
            gemRenderer?.draw(
                fragments: world.memoryFragmentSystem.fragments,
                world: world,
                encoder: encoder,
                resources: resources,
                pipeline: pipeline,
                time: totalTime
            )
        }
        
        // --- Draw NPC creatures ---
        if !npcCreatures.isEmpty {
            npcRenderer?.draw(
                creatures: npcCreatures,
                encoder: encoder,
                resources: resources,
                pipeline: pipeline,
                time: totalTime
            )
        }
        
        encoder.endEncoding()
    }
    
    // MARK: - Pass 2: Deferred Lighting
    
    private func renderLightingPass(commandBuffer: MTLCommandBuffer) {
        let passDesc = pipeline.lightingPassDescriptor()
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.label = "Lighting Pass"
        
        encoder.setRenderPipelineState(pipeline.deferredLightingPipeline)
        encoder.setDepthStencilState(pipeline.depthDisabledState)
        
        // Bind uniforms
        encoder.setFragmentBuffer(resources.uniformBuffer(for: .uniforms), offset: 0, index: BufferIndex.uniforms.rawValue)
        encoder.setFragmentBuffer(resources.uniformBuffer(for: .atmosphereParams), offset: 0, index: BufferIndex.atmosphereParams.rawValue)
        
        // Bind G-buffer textures
        encoder.setFragmentTexture(pipeline.albedoTexture, index: TextureIndex.albedo.rawValue)
        encoder.setFragmentTexture(pipeline.normalTexture, index: TextureIndex.normal.rawValue)
        encoder.setFragmentTexture(pipeline.pbrTexture, index: TextureIndex.pbrParams.rawValue)
        encoder.setFragmentTexture(pipeline.depthTexture, index: TextureIndex.depth.rawValue)
        
        // Bind shadow map and SSAO
        encoder.setFragmentTexture(pipeline.shadowDepthTexture, index: TextureIndex.shadowMap.rawValue)
        encoder.setFragmentTexture(pipeline.ssaoBlurTexture ?? pipeline.ssaoTexture, index: TextureIndex.ssao.rawValue)
        
        // Draw fullscreen triangle
        encoder.setVertexBuffer(resources.fullscreenTriangleBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        encoder.endEncoding()
    }
    
    // MARK: - Pass 3: Atmosphere
    
    private func renderAtmospherePass(commandBuffer: MTLCommandBuffer) {
        let passDesc = pipeline.atmospherePassDescriptor()
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.label = "Atmosphere Pass"
        
        encoder.setRenderPipelineState(pipeline.atmospherePipeline)
        encoder.setDepthStencilState(pipeline.depthDisabledState)
        
        encoder.setFragmentBuffer(resources.uniformBuffer(for: .uniforms), offset: 0, index: BufferIndex.uniforms.rawValue)
        encoder.setFragmentBuffer(resources.uniformBuffer(for: .atmosphereParams), offset: 0, index: BufferIndex.atmosphereParams.rawValue)
        
        encoder.setFragmentTexture(pipeline.litSceneTexture, index: TextureIndex.litScene.rawValue)
        encoder.setFragmentTexture(pipeline.depthTexture, index: TextureIndex.depth.rawValue)
        
        encoder.setVertexBuffer(resources.fullscreenTriangleBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        encoder.endEncoding()
    }
    
    // MARK: - Pass 3.5: Particles
    
    private func renderParticles(commandBuffer: MTLCommandBuffer) {
        guard let particleSystem = particleSystem, let camera = camera else { return }
        
        // Update particles (Compute)
        particleSystem.update(
            commandBuffer: commandBuffer,
            deltaTime: deltaTime,
            time: totalTime,
            cameraPosition: camera.position,
            weatherType: currentWeatherType
        )
        
        // Render particles (onto litScene)
        let passDesc = pipeline.atmospherePassDescriptor() // Re-use atmosphere pass desc (targets litScene, keeps contents)
        passDesc.colorAttachments[0].loadAction = .load
        passDesc.depthAttachment.loadAction = .load
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.label = "Particles Pass"
        
        encoder.setFragmentBuffer(resources.uniformBuffer(for: .uniforms), offset: 0, index: BufferIndex.uniforms.rawValue)
        
        particleSystem.render(renderEncoder: encoder)
        
        encoder.endEncoding()
    }
    
    // MARK: - Pass 4: Bloom
    
    private func renderBloomPass(commandBuffer: MTLCommandBuffer) {
        guard let bloom0 = pipeline.bloomTexture0,
              let bloom1 = pipeline.bloomTexture1 else { return }
        
        // Step 1: Threshold extraction
        let threshDesc = pipeline.bloomPassDescriptor(target: bloom0)
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: threshDesc) {
            encoder.label = "Bloom Threshold"
            encoder.setRenderPipelineState(pipeline.bloomThresholdPipeline)
            encoder.setFragmentBuffer(resources.uniformBuffer(for: .postProcessParams), offset: 0, index: BufferIndex.postProcessParams.rawValue)
            encoder.setFragmentTexture(pipeline.litSceneTexture, index: TextureIndex.litScene.rawValue)
            encoder.setVertexBuffer(resources.fullscreenTriangleBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
        }
        
        // Steps 2-3: Ping-pong Gaussian blur (2 passes)
        let texelSize = SIMD2<Float>(1.0 / Float(bloom0.width), 1.0 / Float(bloom0.height))
        
        for _ in 0..<2 {
            // Horizontal blur: bloom0 → bloom1
            let hDesc = pipeline.bloomPassDescriptor(target: bloom1)
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: hDesc) {
                encoder.label = "Bloom Blur H"
                encoder.setRenderPipelineState(pipeline.blurHorizontalPipeline)
                var ts = texelSize
                encoder.setFragmentBytes(&ts, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
                encoder.setFragmentTexture(bloom0, index: 0)
                encoder.setVertexBuffer(resources.fullscreenTriangleBuffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
            }
            
            // Vertical blur: bloom1 → bloom0
            let vDesc = pipeline.bloomPassDescriptor(target: bloom0)
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: vDesc) {
                encoder.label = "Bloom Blur V"
                encoder.setRenderPipelineState(pipeline.blurVerticalPipeline)
                var ts = texelSize
                encoder.setFragmentBytes(&ts, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
                encoder.setFragmentTexture(bloom1, index: 0)
                encoder.setVertexBuffer(resources.fullscreenTriangleBuffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
            }
        }
    }
    
    // MARK: - Pass 5: Final Composite
    
    private func renderFinalComposite(commandBuffer: MTLCommandBuffer, drawable: MTLTexture) {
        let passDesc = pipeline.finalPassDescriptor(drawable: drawable)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.label = "Final Composite"
        
        encoder.setRenderPipelineState(pipeline.finalCompositePipeline)
        encoder.setDepthStencilState(pipeline.depthDisabledState)
        
        encoder.setFragmentBuffer(resources.uniformBuffer(for: .uniforms), offset: 0, index: BufferIndex.uniforms.rawValue)
        encoder.setFragmentBuffer(resources.uniformBuffer(for: .postProcessParams), offset: 0, index: BufferIndex.postProcessParams.rawValue)
        
        encoder.setFragmentTexture(pipeline.litSceneTexture, index: TextureIndex.litScene.rawValue)
        encoder.setFragmentTexture(pipeline.bloomTexture0, index: TextureIndex.bloomBlurred.rawValue)
        encoder.setFragmentTexture(pipeline.depthTexture, index: TextureIndex.depth.rawValue)
        
        encoder.setVertexBuffer(resources.fullscreenTriangleBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        encoder.endEncoding()
    }
    
    // MARK: - Pass 0: Shadow Map
    
    private func renderShadowPass(commandBuffer: MTLCommandBuffer) {
        // Shadow pass needs the depth texture, a color texture attachment for the pipeline
        guard let shadowDepth = pipeline.shadowDepthTexture else { return }
        
        let passDesc = MTLRenderPassDescriptor()
        passDesc.depthAttachment.texture = shadowDepth
        passDesc.depthAttachment.loadAction = .clear
        passDesc.depthAttachment.storeAction = .store
        passDesc.depthAttachment.clearDepth = 1.0
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.label = "Shadow Map Pass"
        
        encoder.setRenderPipelineState(pipeline.shadowPipeline)
        encoder.setDepthStencilState(pipeline.depthWriteState)
        encoder.setCullMode(.front) // Front-face culling reduces shadow acne
        encoder.setFrontFacing(.counterClockwise)
        
        // Bind frame uniforms (contains lightViewProjectionMatrix)
        encoder.setVertexBuffer(resources.uniformBuffer(for: .uniforms), offset: 0, index: BufferIndex.uniforms.rawValue)
        
        // Draw terrain chunks into shadow map
        let terrainParamsBuffer = resources.uniformBuffer(for: .terrainParams)
        
        // Shadow mapping distance check
        let playerPos = player?.position ?? .zero
        let maxShadowDistSq: Float = SettingsManager.shared.graphicsQuality == .high ? 20000 : 8000
        
        for (index, chunk) in terrainChunks.enumerated() {
            guard chunk.isReady else { continue }
            
            // Distance cull for shadows
            let dx = chunk.worldOriginX - playerPos.x
            let dz = chunk.worldOriginZ - playerPos.z
            if (dx*dx + dz*dz) > maxShadowDistSq { continue }
            
            let paramsOffset = index * MemoryLayout<TerrainParams>.stride
            encoder.setVertexBuffer(chunk.vertexBuffer, offset: 0, index: BufferIndex.vertices.rawValue)
            encoder.setVertexBuffer(terrainParamsBuffer, offset: paramsOffset, index: BufferIndex.terrainParams.rawValue)
            
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: chunk.indexCount,
                indexType: .uint32,
                indexBuffer: chunk.indexBuffer!,
                indexBufferOffset: 0
            )
        }
        
        encoder.endEncoding()
    }
    
    // MARK: - Pass 1.5: SSAO
    
    private func renderSSAOPass(commandBuffer: MTLCommandBuffer) {
        guard pipeline.ssaoTexture != nil else { return }
        
        // Step 1: Generate SSAO
        let ssaoDesc = pipeline.ssaoPassDescriptor()
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: ssaoDesc) else { return }
        encoder.label = "SSAO Pass"
        
        encoder.setRenderPipelineState(pipeline.ssaoPipeline)
        encoder.setDepthStencilState(pipeline.depthDisabledState)
        
        encoder.setFragmentBuffer(resources.uniformBuffer(for: .uniforms), offset: 0, index: BufferIndex.uniforms.rawValue)
        encoder.setFragmentTexture(pipeline.normalTexture, index: TextureIndex.normal.rawValue)
        encoder.setFragmentTexture(pipeline.depthTexture, index: TextureIndex.depth.rawValue)
        
        encoder.setVertexBuffer(resources.fullscreenTriangleBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        
        // Step 2: Blur SSAO
        guard pipeline.ssaoBlurTexture != nil else { return }
        let blurDesc = pipeline.ssaoBlurPassDescriptor()
        guard let blurEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: blurDesc) else { return }
        blurEncoder.label = "SSAO Blur"
        
        blurEncoder.setRenderPipelineState(pipeline.ssaoBlurPipeline)
        blurEncoder.setDepthStencilState(pipeline.depthDisabledState)
        
        blurEncoder.setFragmentTexture(pipeline.ssaoTexture, index: 0)
        
        blurEncoder.setVertexBuffer(resources.fullscreenTriangleBuffer, offset: 0, index: 0)
        blurEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        blurEncoder.endEncoding()
    }
}
