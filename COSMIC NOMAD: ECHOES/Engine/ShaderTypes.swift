//
//  ShaderTypes.swift
//  COSMIC NOMAD: ECHOES
//
//  Shared type definitions between Swift and Metal shaders.
//  These structs must have identical memory layouts to their Metal counterparts.
//

import simd

// MARK: - Buffer Indices

/// Indices for vertex buffer bindings in Metal shaders
enum BufferIndex: Int {
    case vertices = 0
    case uniforms = 1
    case materialUniforms = 2
    case terrainParams = 3
    case atmosphereParams = 4
    case postProcessParams = 5
    case instanceData = 6
}

/// Indices for texture bindings
enum TextureIndex: Int {
    // G-Buffer textures
    case albedo = 0
    case normal = 1
    case pbrParams = 2
    case depth = 3
    
    // Lighting output
    case litScene = 4
    
    // Atmosphere
    case skyLUT = 5
    case fogVolume = 6
    
    // Terrain materials
    case terrainAlbedo0 = 7
    case terrainAlbedo1 = 8
    case terrainAlbedo2 = 9
    case terrainNormal0 = 10
    case terrainNormal1 = 11
    case terrainNormal2 = 12
    
    // Post-process
    case bloomInput = 13
    case bloomBlurred = 14
    case colorLUT = 15
    
    // Shadow / AO
    case shadowMap = 16
    case ssao = 17
}

// MARK: - Vertex Formats

/// Standard terrain vertex — position, normal, UV, material weights
struct TerrainVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var texCoord: SIMD2<Float>
    var materialWeights: SIMD4<Float>  // weights for up to 4 material layers
    
    init(position: SIMD3<Float> = .zero,
         normal: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
         texCoord: SIMD2<Float> = .zero,
         materialWeights: SIMD4<Float> = SIMD4<Float>(1, 0, 0, 0)) {
        self.position = position
        self.normal = normal
        self.texCoord = texCoord
        self.materialWeights = materialWeights
    }
}

/// Full-screen quad vertex for post-processing passes
struct FullscreenVertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
}

/// Vertex for 3D entities (e.g. cities, memory fragments)
struct EntityVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var texCoord: SIMD2<Float>
    
    init(position: SIMD3<Float> = .zero, normal: SIMD3<Float> = SIMD3<Float>(0, 1, 0), texCoord: SIMD2<Float> = .zero) {
        self.position = position
        self.normal = normal
        self.texCoord = texCoord
    }
}

/// Instance data for instanced rendering of 3D elements
struct EntityInstance {
    var modelMatrix: float4x4
    var colorAndMaterial: SIMD4<Float> // RGB = Base Color, A = Material Type
    
    init(modelMatrix: float4x4 = matrix_identity_float4x4, colorAndMaterial: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 0)) {
        self.modelMatrix = modelMatrix
        self.colorAndMaterial = colorAndMaterial
    }
}

// MARK: - Uniform Buffers

/// Per-frame uniforms sent to all shaders
struct FrameUniforms {
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var viewProjectionMatrix: float4x4
    var inverseViewMatrix: float4x4
    var inverseProjectionMatrix: float4x4
    var cameraPosition: SIMD3<Float>
    var cameraForward: SIMD3<Float>
    var sunDirection: SIMD3<Float>
    var sunColor: SIMD3<Float>
    var sunIntensity: Float
    var time: Float
    var deltaTime: Float
    var screenSize: SIMD2<Float>
    var nearPlane: Float
    var farPlane: Float
    var fogDensity: Float
    var _padding: Float = 0
    var lightViewProjectionMatrix: float4x4
    
    init() {
        viewMatrix = matrix_identity_float4x4
        projectionMatrix = matrix_identity_float4x4
        viewProjectionMatrix = matrix_identity_float4x4
        inverseViewMatrix = matrix_identity_float4x4
        inverseProjectionMatrix = matrix_identity_float4x4
        cameraPosition = .zero
        cameraForward = SIMD3<Float>(0, 0, -1)
        sunDirection = normalize(SIMD3<Float>(0.5, 0.8, 0.3))
        sunColor = SIMD3<Float>(1.0, 0.95, 0.9)
        sunIntensity = 2.0
        time = 0
        deltaTime = 0
        screenSize = SIMD2<Float>(1920, 1080)
        nearPlane = 0.1
        farPlane = 2000.0
        fogDensity = 0.01
        lightViewProjectionMatrix = matrix_identity_float4x4
    }
}

/// Per-chunk terrain parameters
struct TerrainParams {
    var modelMatrix: float4x4
    var chunkWorldPosition: SIMD2<Float>
    var chunkSize: Float
    var lodLevel: Float
    var heightScale: Float
    var textureScale: Float
    var _padding: SIMD2<Float> = .zero
    
    init() {
        modelMatrix = matrix_identity_float4x4
        chunkWorldPosition = .zero
        chunkSize = 64.0
        lodLevel = 0
        heightScale = 50.0
        textureScale = 1.0
    }
}

/// Atmosphere rendering parameters
struct AtmosphereParams {
    // Sky
    var rayleighCoefficients: SIMD3<Float>
    var mieCoefficient: Float
    var rayleighScaleHeight: Float
    var mieScaleHeight: Float
    var mieDirectionality: Float  // g parameter for Henyey-Greenstein
    var atmosphereRadius: Float
    var planetRadius: Float
    
    // Fog
    var fogColor: SIMD3<Float>
    var fogDensityBase: Float
    var fogHeightFalloff: Float
    var fogStartDistance: Float
    var fogInscatteringColor: SIMD3<Float>
    var fogInscatteringIntensity: Float
    
    // Color grading
    var horizonColor: SIMD3<Float>
    var zenithColor: SIMD3<Float>
    var ambientColor: SIMD3<Float>
    var ambientIntensity: Float
    
    // Weather influence
    var weatherCloudCoverage: Float
    var weatherVisibility: Float
    var _padding: SIMD2<Float> = .zero
    
    init() {
        // Default Earth-like atmosphere
        rayleighCoefficients = SIMD3<Float>(5.5e-6, 13.0e-6, 22.4e-6)
        mieCoefficient = 21e-6
        rayleighScaleHeight = 8000
        mieScaleHeight = 1200
        mieDirectionality = 0.758
        atmosphereRadius = 6420000
        planetRadius = 6360000
        fogColor = SIMD3<Float>(0.5, 0.6, 0.7)
        fogDensityBase = 0.01
        fogHeightFalloff = 0.05
        fogStartDistance = 50
        fogInscatteringColor = SIMD3<Float>(0.8, 0.85, 0.9)
        fogInscatteringIntensity = 0.5
        horizonColor = SIMD3<Float>(0.8, 0.4, 0.2)
        zenithColor = SIMD3<Float>(0.1, 0.15, 0.4)
        ambientColor = SIMD3<Float>(0.2, 0.25, 0.3)
        ambientIntensity = 0.3
        weatherCloudCoverage = 0.0
        weatherVisibility = 1.0
    }
}

/// Post-processing parameters
struct PostProcessParams {
    var exposure: Float
    var contrast: Float
    var saturation: Float
    var temperature: Float     // color temperature shift
    var tint: Float            // green-magenta tint
    var vignetteIntensity: Float
    var vignetteRadius: Float
    var filmGrainIntensity: Float
    var filmGrainSize: Float
    var chromaticAberrationIntensity: Float
    var bloomThreshold: Float
    var bloomIntensity: Float
    var dofFocusDistance: Float
    var dofFocusRange: Float
    var dofBokehSize: Float
    var _padding: Float = 0
    
    init() {
        exposure = 1.0
        contrast = 1.05
        saturation = 1.1
        temperature = 0.0
        tint = 0.0
        vignetteIntensity = 0.3
        vignetteRadius = 0.8
        filmGrainIntensity = 0.04
        filmGrainSize = 1.5
        chromaticAberrationIntensity = 0.002
        bloomThreshold = 1.0
        bloomIntensity = 0.15
        dofFocusDistance = 50.0
        dofFocusRange = 30.0
        dofBokehSize = 3.0
    }
}

// MARK: - Particle System Types

struct Particle {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var color: SIMD4<Float>
    var size: Float
    var life: Float
    var maxLife: Float
    var type: Float // 0 = dust, 1 = rain, 2 = snow
}

struct ParticleUniforms {
    var emitterPosition: SIMD3<Float>
    var windDirection: SIMD3<Float>
    var time: Float
    var deltaTime: Float
    var particleCount: UInt32
    var activeType: Float
    var _padding: SIMD2<Float> = .zero
    
    init() {
        emitterPosition = .zero
        windDirection = SIMD3<Float>(1.0, 0.0, 0.5)
        time = 0
        deltaTime = 0
        particleCount = 0
        activeType = 0
    }
}

// MARK: - Fullscreen Quad Data

/// Pre-built fullscreen triangle (covers entire screen with a single triangle)
let fullscreenTriangleVertices: [FullscreenVertex] = [
    FullscreenVertex(position: SIMD2<Float>(-1, -1), texCoord: SIMD2<Float>(0, 1)),
    FullscreenVertex(position: SIMD2<Float>(-1,  3), texCoord: SIMD2<Float>(0, -1)),
    FullscreenVertex(position: SIMD2<Float>( 3, -1), texCoord: SIMD2<Float>(2, 1)),
]
