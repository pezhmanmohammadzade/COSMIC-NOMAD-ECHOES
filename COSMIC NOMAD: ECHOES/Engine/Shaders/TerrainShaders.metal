//
//  TerrainShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  Terrain vertex and fragment shaders for G-buffer pass.
//  PBR-based with height/slope material blending.
//

#include "ShaderCommon.h"

// MARK: - Terrain Vertex Shader

vertex GBufferVertexOut terrainVertex(uint vid [[vertex_id]],
                                      constant TerrainVertex *vertices [[buffer(0)]],
                                      constant FrameUniforms &frame [[buffer(1)]],
                                      constant TerrainParams &terrain [[buffer(3)]]) {
    GBufferVertexOut out;
    
    TerrainVertex vert = vertices[vid];
    float4 worldPos = terrain.modelMatrix * float4(vert.position, 1.0);
    
    out.position = frame.viewProjectionMatrix * worldPos;
    out.worldPosition = worldPos.xyz;
    out.worldNormal = normalize((terrain.modelMatrix * float4(vert.normal, 0.0)).xyz);
    out.texCoord = vert.texCoord * terrain.textureScale;
    out.materialWeights = vert.materialWeights;
    out.depth = out.position.z / out.position.w;
    
    return out;
}

inline float triplanarNoise(float3 pos, float3 normal, float scale) {
    float3 blendWeights = abs(normal);
    blendWeights = max(blendWeights - 0.2, 0.0); // sharpen blend
    blendWeights /= (blendWeights.x + blendWeights.y + blendWeights.z);
    
    float nx = fbm(pos.yz * scale, 3, 2.0, 0.5);
    float ny = fbm(pos.xz * scale, 3, 2.0, 0.5);
    float nz = fbm(pos.xy * scale, 3, 2.0, 0.5);
    
    return nx * blendWeights.x + ny * blendWeights.y + nz * blendWeights.z;
}

// MARK: - Terrain Fragment Shader (G-Buffer Output)

// Enhanced tri-planar with detail layers at multiple frequencies
inline float3 triplanarColor(float3 pos, float3 normal, float3 colorA, float3 colorB, float scale, float detailScale) {
    float3 blendWeights = abs(normal);
    blendWeights = pow(blendWeights, 4.0); // sharper blending at edges
    blendWeights /= (blendWeights.x + blendWeights.y + blendWeights.z + 0.0001);
    
    // Main pattern
    float nx = fbm(pos.yz * scale, 4, 2.0, 0.5);
    float ny = fbm(pos.xz * scale, 4, 2.0, 0.5);
    float nz = fbm(pos.xy * scale, 4, 2.0, 0.5);
    float mainPattern = nx * blendWeights.x + ny * blendWeights.y + nz * blendWeights.z;
    
    // Detail layer (higher frequency for close-up)
    float dx = fbm(pos.yz * detailScale, 3, 2.0, 0.5);
    float dy = fbm(pos.xz * detailScale, 3, 2.0, 0.5);
    float dz = fbm(pos.xy * detailScale, 3, 2.0, 0.5);
    float detail = dx * blendWeights.x + dy * blendWeights.y + dz * blendWeights.z;
    
    float3 color = mix(colorA, colorB, mainPattern);
    color += (detail - 0.5) * 0.08; // subtle close-up detail
    
    return color;
}

// Macro-variation: large-scale color shifts to break repetition
inline float macroVariation(float3 worldPos) {
    return fbm(worldPos.xz * 0.003, 2, 2.0, 0.5);
}

fragment GBufferOutput terrainFragment(GBufferVertexOut in [[stage_in]],
                                        constant FrameUniforms &frame [[buffer(1)]],
                                        constant TerrainParams &terrain [[buffer(3)]]) {
    GBufferOutput gbuf;
    
    float3 normal = normalize(in.worldNormal);
    float3 worldPos = in.worldPosition;
    
    float3 baseColor;
    float roughness;
    float metallic;
    
    // Macro-variation (breaks large-scale tiling patterns)
    float macro = macroVariation(worldPos);
    
    // Single triplanar noise sample for detail (replaces multiple per-material calls)
    float noiseDetail = triplanarNoise(worldPos, normal, 0.5);
    float noiseMicro = triplanarNoise(worldPos, normal, 4.0);
    
    // --- Height-based splatting with sharper transitions ---
    float4 w = in.materialWeights;
    w.x += (macro - 0.5) * 0.15; // use macro for large blending variation
    w.y += (noiseDetail - 0.5) * 0.1;
    w.z += (noiseMicro - 0.5) * 0.05;
    w = max(w, 0.0);
    w /= (w.x + w.y + w.z + w.w + 0.0001);
    
    // Base colors for each biome/height
    float3 soilColor = float3(0.08, 0.06, 0.12);
    float3 rockColor = float3(0.25, 0.22, 0.20);
    float3 mineralColor = float3(0.35, 0.30, 0.45);
    float3 cliffColor = float3(0.20, 0.18, 0.22);
    
    // Blend base colors first
    baseColor = soilColor * w.x +
                rockColor * w.y +
                mineralColor * w.z +
                cliffColor * w.w;
                
    // Apply detail variation globally instead of per-material
    baseColor += (macro - 0.5) * 0.15;
    baseColor += (noiseDetail - 0.5) * 0.08;
    baseColor -= noiseMicro * 0.04;
    
    // --- Roughness with micro-detail variation ---
    float soilRough = 0.85 + noiseMicro * 0.1;
    float rockRough = 0.6 + noiseDetail * 0.25;
    float mineralRough = 0.2 + noiseMicro * 0.3;
    float cliffRough = 0.7 + noiseDetail * 0.2;
    
    roughness = soilRough * w.x + rockRough * w.y + mineralRough * w.z + cliffRough * w.w;
    roughness = clamp(roughness, 0.05, 1.0);
    
    // Metallic for mineral areas
    metallic = w.z * (0.3 + noiseMicro * 0.5);
    
    // --- Multi-frequency normal perturbation ---
    float eps = 0.1;
    
    // Medium frequency bump
    float h0 = triplanarNoise(worldPos, normal, 2.0);
    float hX0 = triplanarNoise(worldPos + float3(eps, 0, 0), normal, 2.0);
    float hZ0 = triplanarNoise(worldPos + float3(0, 0, eps), normal, 2.0);
    float3 bump0 = normalize(float3(h0 - hX0, eps * 2.0, h0 - hZ0));
    
    // High frequency detail bump
    float epsD = 0.03;
    float h1 = triplanarNoise(worldPos, normal, 8.0);
    float hX1 = triplanarNoise(worldPos + float3(epsD, 0, 0), normal, 8.0);
    float hZ1 = triplanarNoise(worldPos + float3(0, 0, epsD), normal, 8.0);
    float3 bump1 = normalize(float3(h1 - hX1, epsD * 2.0, h1 - hZ1));
    
    // Blend bumps (detail fades with distance)
    float distToCamera = length(frame.cameraPosition - worldPos);
    float detailFade = 1.0 - smoothstep(10.0, 80.0, distToCamera);
    float microFade = 1.0 - smoothstep(5.0, 30.0, distToCamera);
    
    float3 combinedBump = normalize(bump0 + (bump1 - float3(0, 1, 0)) * microFade * 0.4);
    
    // Transform to world space via TBN
    float3 T = normalize(cross(normal, float3(0, 0, 1)));
    if (length(T) < 0.001) T = normalize(cross(normal, float3(1, 0, 0)));
    float3 B = cross(normal, T);
    float3x3 TBN = float3x3(T, B, normal);
    float3 perturbedNormal = normalize(TBN * combinedBump);
    
    float3 finalNormal = normalize(mix(normal, perturbedNormal, detailFade * 0.8));
    
    // Output to G-buffer
    gbuf.albedo = float4(baseColor, 0.0);
    gbuf.normal = float4(octEncode(finalNormal), roughness, metallic);
    gbuf.pbrParams = float4(1.0, 0.0, 0.0, 0.0);
    gbuf.depth = in.depth;
    
    return gbuf;
}

