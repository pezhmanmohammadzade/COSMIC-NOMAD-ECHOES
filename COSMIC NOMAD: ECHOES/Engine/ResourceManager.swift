//
//  ResourceManager.swift
//  COSMIC NOMAD: ECHOES
//
//  Metal resource management: buffer pools, texture caching,
//  memory budget tracking for Apple Silicon unified memory.
//

import Metal
import MetalKit
import simd

// MARK: - Resource Manager

@MainActor
final class ResourceManager {
    
    let device: MTLDevice
    let library: MTLLibrary
    
    // Buffer pool for reusable temporary buffers
    private var bufferPool: [Int: [MTLBuffer]] = [:]  // size -> available buffers
    private var activeBuffers: Set<ObjectIdentifier> = []
    
    // Texture cache
    private var textureCache: [String: MTLTexture] = [:]
    
    // Memory tracking
    private(set) var totalAllocatedMemory: Int = 0
    private let memoryBudget: Int = 512 * 1024 * 1024  // 512 MB budget
    
    // Fullscreen triangle buffer (shared)
    private(set) var fullscreenTriangleBuffer: MTLBuffer!
    
    // Triple-buffered uniform buffers
    static let maxFramesInFlight = 3
    private var uniformBuffers: [[BufferIndex: MTLBuffer]] = []
    private var currentFrameIndex = 0
    
    init(device: MTLDevice) throws {
        self.device = device
        
        guard let library = device.makeDefaultLibrary() else {
            throw EngineError.shaderCompilationFailed("Failed to create default Metal library")
        }
        self.library = library
        
        // Create fullscreen triangle buffer
        fullscreenTriangleBuffer = device.makeBuffer(
            bytes: fullscreenTriangleVertices,
            length: MemoryLayout<FullscreenVertex>.stride * fullscreenTriangleVertices.count,
            options: .storageModeShared
        )
        fullscreenTriangleBuffer.label = "Fullscreen Triangle"
        
        // Initialize triple-buffered uniform buffers
        for i in 0..<Self.maxFramesInFlight {
            var frameBuffers: [BufferIndex: MTLBuffer] = [:]
            
            frameBuffers[.uniforms] = createBuffer(
                length: MemoryLayout<FrameUniforms>.stride,
                options: .storageModeShared,
                label: "Frame Uniforms \(i)"
            )
            
            frameBuffers[.terrainParams] = createBuffer(
                length: MemoryLayout<TerrainParams>.stride * 256,  // Up to 256 chunks
                options: .storageModeShared,
                label: "Terrain Params \(i)"
            )
            
            frameBuffers[.atmosphereParams] = createBuffer(
                length: MemoryLayout<AtmosphereParams>.stride,
                options: .storageModeShared,
                label: "Atmosphere Params \(i)"
            )
            
            frameBuffers[.postProcessParams] = createBuffer(
                length: MemoryLayout<PostProcessParams>.stride,
                options: .storageModeShared,
                label: "Post Process Params \(i)"
            )
            
            uniformBuffers.append(frameBuffers)
        }
        
        // Initialize primitives
        buildPrimitives()
    }
    
    private func buildPrimitives() {
        // Build a unit cube (-0.5 to 0.5 in all axes)
        let s: Float = 0.5
        let vertices: [EntityVertex] = [
            // Front face (+Z)
            EntityVertex(position: SIMD3<Float>(-s, -s,  s), normal: SIMD3<Float>( 0,  0,  1), texCoord: SIMD2<Float>(0, 1)),
            EntityVertex(position: SIMD3<Float>( s, -s,  s), normal: SIMD3<Float>( 0,  0,  1), texCoord: SIMD2<Float>(1, 1)),
            EntityVertex(position: SIMD3<Float>(-s,  s,  s), normal: SIMD3<Float>( 0,  0,  1), texCoord: SIMD2<Float>(0, 0)),
            EntityVertex(position: SIMD3<Float>( s,  s,  s), normal: SIMD3<Float>( 0,  0,  1), texCoord: SIMD2<Float>(1, 0)),
            // Back face (-Z)
            EntityVertex(position: SIMD3<Float>( s, -s, -s), normal: SIMD3<Float>( 0,  0, -1), texCoord: SIMD2<Float>(0, 1)),
            EntityVertex(position: SIMD3<Float>(-s, -s, -s), normal: SIMD3<Float>( 0,  0, -1), texCoord: SIMD2<Float>(1, 1)),
            EntityVertex(position: SIMD3<Float>( s,  s, -s), normal: SIMD3<Float>( 0,  0, -1), texCoord: SIMD2<Float>(0, 0)),
            EntityVertex(position: SIMD3<Float>(-s,  s, -s), normal: SIMD3<Float>( 0,  0, -1), texCoord: SIMD2<Float>(1, 0)),
            // Top face (+Y)
            EntityVertex(position: SIMD3<Float>(-s,  s,  s), normal: SIMD3<Float>( 0,  1,  0), texCoord: SIMD2<Float>(0, 1)),
            EntityVertex(position: SIMD3<Float>( s,  s,  s), normal: SIMD3<Float>( 0,  1,  0), texCoord: SIMD2<Float>(1, 1)),
            EntityVertex(position: SIMD3<Float>(-s,  s, -s), normal: SIMD3<Float>( 0,  1,  0), texCoord: SIMD2<Float>(0, 0)),
            EntityVertex(position: SIMD3<Float>( s,  s, -s), normal: SIMD3<Float>( 0,  1,  0), texCoord: SIMD2<Float>(1, 0)),
            // Bottom face (-Y)
            EntityVertex(position: SIMD3<Float>(-s, -s, -s), normal: SIMD3<Float>( 0, -1,  0), texCoord: SIMD2<Float>(0, 1)),
            EntityVertex(position: SIMD3<Float>( s, -s, -s), normal: SIMD3<Float>( 0, -1,  0), texCoord: SIMD2<Float>(1, 1)),
            EntityVertex(position: SIMD3<Float>(-s, -s,  s), normal: SIMD3<Float>( 0, -1,  0), texCoord: SIMD2<Float>(0, 0)),
            EntityVertex(position: SIMD3<Float>( s, -s,  s), normal: SIMD3<Float>( 0, -1,  0), texCoord: SIMD2<Float>(1, 0)),
            // Right face (+X)
            EntityVertex(position: SIMD3<Float>( s, -s,  s), normal: SIMD3<Float>( 1,  0,  0), texCoord: SIMD2<Float>(0, 1)),
            EntityVertex(position: SIMD3<Float>( s, -s, -s), normal: SIMD3<Float>( 1,  0,  0), texCoord: SIMD2<Float>(1, 1)),
            EntityVertex(position: SIMD3<Float>( s,  s,  s), normal: SIMD3<Float>( 1,  0,  0), texCoord: SIMD2<Float>(0, 0)),
            EntityVertex(position: SIMD3<Float>( s,  s, -s), normal: SIMD3<Float>( 1,  0,  0), texCoord: SIMD2<Float>(1, 0)),
            // Left face (-X)
            EntityVertex(position: SIMD3<Float>(-s, -s, -s), normal: SIMD3<Float>(-1,  0,  0), texCoord: SIMD2<Float>(0, 1)),
            EntityVertex(position: SIMD3<Float>(-s, -s,  s), normal: SIMD3<Float>(-1,  0,  0), texCoord: SIMD2<Float>(1, 1)),
            EntityVertex(position: SIMD3<Float>(-s,  s, -s), normal: SIMD3<Float>(-1,  0,  0), texCoord: SIMD2<Float>(0, 0)),
            EntityVertex(position: SIMD3<Float>(-s,  s,  s), normal: SIMD3<Float>(-1,  0,  0), texCoord: SIMD2<Float>(1, 0)),
        ]
        
        let indices: [UInt16] = [
            0,  1,  2,  2,  1,  3,  // Front
            4,  5,  6,  6,  5,  7,  // Back
            8,  9, 10, 10,  9, 11,  // Top
            12, 13, 14, 14, 13, 15, // Bottom
            16, 17, 18, 18, 17, 19, // Right
            20, 21, 22, 22, 21, 23  // Left
        ]
        
        cubeVertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<EntityVertex>.stride, options: .storageModeShared)
        cubeVertexBuffer.label = "Cube Vertices"
        
        cubeIndexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .storageModeShared)
        cubeIndexBuffer.label = "Cube Indices"
        
        cubeIndexCount = indices.count
    }
    
    // MARK: - Frame Cycling
    
    func advanceFrame() -> Int {
        currentFrameIndex = (currentFrameIndex + 1) % Self.maxFramesInFlight
        return currentFrameIndex
    }
    
    func uniformBuffer(for index: BufferIndex) -> MTLBuffer? {
        return uniformBuffers[currentFrameIndex][index]
    }
    
    func updateUniforms(_ uniforms: FrameUniforms) {
        guard let buffer = uniformBuffers[currentFrameIndex][.uniforms] else { return }
        buffer.contents().storeBytes(of: uniforms, as: FrameUniforms.self)
    }
    
    func updateAtmosphereParams(_ params: AtmosphereParams) {
        guard let buffer = uniformBuffers[currentFrameIndex][.atmosphereParams] else { return }
        buffer.contents().storeBytes(of: params, as: AtmosphereParams.self)
    }
    
    func updatePostProcessParams(_ params: PostProcessParams) {
        guard let buffer = uniformBuffers[currentFrameIndex][.postProcessParams] else { return }
        buffer.contents().storeBytes(of: params, as: PostProcessParams.self)
    }
    
    func updateTerrainParams(_ params: [TerrainParams]) {
        guard let buffer = uniformBuffers[currentFrameIndex][.terrainParams] else { return }
        let ptr = buffer.contents().bindMemory(to: TerrainParams.self, capacity: params.count)
        for (i, param) in params.enumerated() {
            ptr[i] = param
        }
    }
    
    // Primitives
    private(set) var cubeVertexBuffer: MTLBuffer!
    private(set) var cubeIndexBuffer: MTLBuffer!
    private(set) var cubeIndexCount: Int = 0
    
    // MARK: - Buffer Management
    
    func createBuffer(length: Int, options: MTLResourceOptions = .storageModeShared, label: String? = nil) -> MTLBuffer? {
        guard totalAllocatedMemory + length <= memoryBudget else {
            print("⚠️ ResourceManager: Memory budget exceeded (\(totalAllocatedMemory / 1024 / 1024)MB / \(memoryBudget / 1024 / 1024)MB)")
            return nil
        }
        
        guard let buffer = device.makeBuffer(length: length, options: options) else {
            return nil
        }
        
        buffer.label = label
        totalAllocatedMemory += length
        return buffer
    }
    
    func createBuffer<T>(data: [T], options: MTLResourceOptions = .storageModeShared, label: String? = nil) -> MTLBuffer? {
        let length = MemoryLayout<T>.stride * data.count
        guard let buffer = data.withUnsafeBytes({ ptr in
            device.makeBuffer(bytes: ptr.baseAddress!, length: length, options: options)
        }) else {
            return nil
        }
        buffer.label = label
        totalAllocatedMemory += length
        return buffer
    }
    
    // MARK: - Texture Management
    
    func createTexture(descriptor: MTLTextureDescriptor, label: String? = nil) -> MTLTexture? {
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        texture.label = label
        
        let estimatedSize = descriptor.width * descriptor.height *
            pixelFormatSize(descriptor.pixelFormat) * max(descriptor.depth, 1)
        totalAllocatedMemory += estimatedSize
        
        return texture
    }
    
    func createRenderTarget(width: Int, height: Int, format: MTLPixelFormat, label: String) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        
        return createTexture(descriptor: desc, label: label)
    }
    
    func createDepthTexture(width: Int, height: Int) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        
        return createTexture(descriptor: desc, label: "Depth Buffer")
    }
    
    // MARK: - Pipeline Creation Helpers
    
    func makeRenderPipelineState(
        vertexFunction: String,
        fragmentFunction: String,
        colorFormats: [MTLPixelFormat],
        depthFormat: MTLPixelFormat = .depth32Float,
        vertexDescriptor: MTLVertexDescriptor? = nil,
        label: String = ""
    ) throws -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = label
        desc.vertexFunction = library.makeFunction(name: vertexFunction)
        desc.fragmentFunction = library.makeFunction(name: fragmentFunction)
        
        for (i, format) in colorFormats.enumerated() {
            desc.colorAttachments[i].pixelFormat = format
        }
        desc.depthAttachmentPixelFormat = depthFormat
        
        if let vd = vertexDescriptor {
            desc.vertexDescriptor = vd
        }
        
        return try device.makeRenderPipelineState(descriptor: desc)
    }
    
    func makeFullscreenPipelineState(
        fragmentFunction: String,
        colorFormats: [MTLPixelFormat],
        depthFormat: MTLPixelFormat = .invalid,
        label: String = ""
    ) throws -> MTLRenderPipelineState {
        return try makeRenderPipelineState(
            vertexFunction: "fullscreenVertex",
            fragmentFunction: fragmentFunction,
            colorFormats: colorFormats,
            depthFormat: depthFormat,
            label: label
        )
    }
    
    func makeDepthStencilState(depthCompare: MTLCompareFunction = .less, depthWrite: Bool = true) -> MTLDepthStencilState? {
        let desc = MTLDepthStencilDescriptor()
        desc.depthCompareFunction = depthCompare
        desc.isDepthWriteEnabled = depthWrite
        return device.makeDepthStencilState(descriptor: desc)
    }
    
    // MARK: - Memory Info
    
    var memoryUsageString: String {
        let usedMB = totalAllocatedMemory / (1024 * 1024)
        let budgetMB = memoryBudget / (1024 * 1024)
        return "\(usedMB)MB / \(budgetMB)MB"
    }
    
    private func pixelFormatSize(_ format: MTLPixelFormat) -> Int {
        switch format {
        case .rgba8Unorm, .rgba8Snorm, .bgra8Unorm: return 4
        case .rgba16Float: return 8
        case .rg16Float: return 4
        case .r16Float: return 2
        case .depth32Float: return 4
        case .r8Unorm: return 1
        default: return 4
        }
    }
}

// MARK: - Engine Errors

enum EngineError: Error, LocalizedError {
    case metalNotSupported
    case shaderCompilationFailed(String)
    case pipelineCreationFailed(String)
    case resourceAllocationFailed(String)
    case worldGenerationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .metalNotSupported: return "Metal is not supported on this device"
        case .shaderCompilationFailed(let msg): return "Shader compilation failed: \(msg)"
        case .pipelineCreationFailed(let msg): return "Pipeline creation failed: \(msg)"
        case .resourceAllocationFailed(let msg): return "Resource allocation failed: \(msg)"
        case .worldGenerationFailed(let msg): return "World generation failed: \(msg)"
        }
    }
}
