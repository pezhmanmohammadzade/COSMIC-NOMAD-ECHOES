//
//  ShaderCommon.h
//  COSMIC NOMAD: ECHOES
//
//  Shared header between all Metal shader files.
//  Contains structure definitions, noise functions, PBR utilities,
//  and common helper functions.
//

#ifndef ShaderCommon_h
#define ShaderCommon_h

#include <metal_stdlib>
using namespace metal;

// MARK: - Enums (must match Swift ShaderTypes)

enum BufferIndex {
    BufferIndexVertices = 0,
    BufferIndexUniforms = 1,
    BufferIndexMaterialUniforms = 2,
    BufferIndexTerrainParams = 3,
    BufferIndexAtmosphereParams = 4,
    BufferIndexPostProcessParams = 5,
    BufferIndexInstanceData = 6
};

enum TextureIndex {
    TextureIndexAlbedo = 0,
    TextureIndexNormal = 1,
    TextureIndexPbrParams = 2,
    TextureIndexDepth = 3,
    TextureIndexLitScene = 4,
    TextureIndexSkyLUT = 5,
    TextureIndexFogVolume = 6,
    TextureIndexTerrainAlbedo0 = 7,
    TextureIndexTerrainAlbedo1 = 8,
    TextureIndexTerrainAlbedo2 = 9,
    TextureIndexTerrainNormal0 = 10,
    TextureIndexTerrainNormal1 = 11,
    TextureIndexTerrainNormal2 = 12,
    TextureIndexBloomInput = 13,
    TextureIndexBloomBlurred = 14,
    TextureIndexColorLUT = 15,
    TextureIndexShadowMap = 16,
    TextureIndexSSAO = 17
};

// MARK: - Shared Structures (must match Swift ShaderTypes)

struct TerrainVertex {
    float3 position;
    float3 normal;
    float2 texCoord;
    float4 materialWeights;
};

struct FullscreenVertex {
    float2 position;
    float2 texCoord;
};

struct FrameUniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 viewProjectionMatrix;
    float4x4 inverseViewMatrix;
    float4x4 inverseProjectionMatrix;
    float3 cameraPosition;
    float3 cameraForward;
    float3 sunDirection;
    float3 sunColor;
    float sunIntensity;
    float time;
    float deltaTime;
    float2 screenSize;
    float nearPlane;
    float farPlane;
    float fogDensity;
    float _padding;
    float4x4 lightViewProjectionMatrix;
};

struct TerrainParams {
    float4x4 modelMatrix;
    float2 chunkWorldPosition;
    float chunkSize;
    float lodLevel;
    float heightScale;
    float textureScale;
    float2 _padding;
};

struct AtmosphereParams {
    float3 rayleighCoefficients;
    float mieCoefficient;
    float rayleighScaleHeight;
    float mieScaleHeight;
    float mieDirectionality;
    float atmosphereRadius;
    float planetRadius;
    float3 fogColor;
    float fogDensityBase;
    float fogHeightFalloff;
    float fogStartDistance;
    float3 fogInscatteringColor;
    float fogInscatteringIntensity;
    float3 horizonColor;
    float3 zenithColor;
    float3 ambientColor;
    float ambientIntensity;
    float weatherCloudCoverage;
    float weatherVisibility;
    float2 _padding;
};

struct PostProcessParams {
    float exposure;
    float contrast;
    float saturation;
    float temperature;
    float tint;
    float vignetteIntensity;
    float vignetteRadius;
    float filmGrainIntensity;
    float filmGrainSize;
    float chromaticAberrationIntensity;
    float bloomThreshold;
    float bloomIntensity;
    float dofFocusDistance;
    float dofFocusRange;
    float dofBokehSize;
    float _padding;
};

struct Particle {
    float3 position;
    float3 velocity;
    float4 color;
    float size;
    float life;
    float maxLife;
    float type; // 0 = dust, 1 = rain, 2 = snow
};

struct EntityInstance {
    float4x4 modelMatrix;
    float4 colorAndMaterial; // RGB = Base Color, A = Material Type (0=metal, 1=glass, 2=ruin, 3=memoryFragment)
};

struct ParticleUniforms {
    float3 emitterPosition;
    float3 windDirection;
    float time;
    float deltaTime;
    uint particleCount;
    float activeType;
    float2 _padding;
};

// MARK: - Vertex Outputs

struct GBufferVertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 texCoord;
    float4 materialWeights;
    float depth;
};

struct FullscreenVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - G-Buffer Output

struct GBufferOutput {
    float4 albedo [[color(0)]];     // RGB albedo, A = emission mask
    float4 normal [[color(1)]];     // RG = encoded normal, B = roughness, A = metallic
    float4 pbrParams [[color(2)]];  // R = AO, G = reserved, BA = velocity
    float depth [[depth(any)]];
};

// MARK: - Noise Functions (GPU-side)

inline float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

inline float hash3D(float3 p) {
    p = fract(p * float3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

inline float2 gradientDir(float2 p) {
    p = fmod(p, float2(289.0));
    float x = fmod((34.0 * p.x + 1.0) * p.x, 289.0) + p.y;
    x = fmod((34.0 * x + 1.0) * x, 289.0);
    x = fract(x / 41.0) * 2.0 - 1.0;
    return normalize(float2(x, abs(x) - 0.5));
}

inline float gradientNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float2 g00 = gradientDir(i);
    float2 g10 = gradientDir(i + float2(1.0, 0.0));
    float2 g01 = gradientDir(i + float2(0.0, 1.0));
    float2 g11 = gradientDir(i + float2(1.0, 1.0));
    float n00 = dot(g00, f);
    float n10 = dot(g10, f - float2(1.0, 0.0));
    float n01 = dot(g01, f - float2(0.0, 1.0));
    float n11 = dot(g11, f - float2(1.0, 1.0));
    return mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y) * 0.5 + 0.5;
}

inline float fbm(float2 p, int octaves, float lacunarity, float persistence) {
    float value = 0.0;
    float amplitude = 1.0;
    float maxValue = 0.0;
    for (int i = 0; i < octaves; i++) {
        value += gradientNoise(p) * amplitude;
        maxValue += amplitude;
        amplitude *= persistence;
        p *= lacunarity;
    }
    return value / maxValue;
}

inline float ridgeNoise(float2 p, int octaves, float lacunarity, float persistence) {
    float value = 0.0;
    float amplitude = 1.0;
    float maxValue = 0.0;
    float weight = 1.0;
    for (int i = 0; i < octaves; i++) {
        float signal = gradientNoise(p);
        signal = 1.0 - abs(signal * 2.0 - 1.0);
        signal *= signal;
        signal *= weight;
        weight = clamp(signal * 2.0, 0.0, 1.0);
        value += signal * amplitude;
        maxValue += amplitude;
        amplitude *= persistence;
        p *= lacunarity;
    }
    return value / maxValue;
}

inline float worleyNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float minDist = 1.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 neighbor = float2(float(x), float(y));
            float2 point = float2(hash(i + neighbor), hash(i + neighbor + float2(127.1, 311.7)));
            float2 diff = neighbor + point - f;
            minDist = min(minDist, length(diff));
        }
    }
    return minDist;
}

// MARK: - Normal Encoding/Decoding (Octahedral)

inline float2 octEncode(float3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    if (n.z < 0.0) {
        n.xy = (1.0 - abs(n.yx)) * select(float2(-1.0), float2(1.0), n.xy >= 0.0);
    }
    return n.xy * 0.5 + 0.5;
}

inline float3 octDecode(float2 e) {
    e = e * 2.0 - 1.0;
    float3 n = float3(e.x, e.y, 1.0 - abs(e.x) - abs(e.y));
    if (n.z < 0.0) {
        n.xy = (1.0 - abs(n.yx)) * select(float2(-1.0), float2(1.0), n.xy >= 0.0);
    }
    return normalize(n);
}

// MARK: - PBR Utilities

inline float distributionGGX(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float denom = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (M_PI_F * denom * denom);
}

inline float geometrySchlickGGX(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

inline float geometrySmith(float NdotV, float NdotL, float roughness) {
    return geometrySchlickGGX(NdotV, roughness) * geometrySchlickGGX(NdotL, roughness);
}

inline float3 fresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

inline float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness) {
    return F0 + (max(float3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// MARK: - Tone Mapping

inline float3 acesFilm(float3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// MARK: - Utility

inline float linearizeDepth(float depth, float near, float far) {
    return near * far / (far - depth * (far - near));
}

inline float3 reconstructWorldPos(float2 uv, float depth, float4x4 inverseViewProj) {
    float4 clipPos = float4(uv * 2.0 - 1.0, depth, 1.0);
    clipPos.y = -clipPos.y;
    float4 worldPos = inverseViewProj * clipPos;
    return worldPos.xyz / worldPos.w;
}

#endif /* ShaderCommon_h */
