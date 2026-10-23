//
//  TerrainShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  AAA Planetary Terrain Shaders for G-buffer pass.
//  Multi-scale procedural detail, geological strata layering,
//  slope-based sediment distribution, and planet-specific PBR materials.
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

// MARK: - Procedural Terrain Noise & Stratification

inline float triplanarNoise(float3 pos, float3 normal, float scale) {
    float3 blendWeights = abs(normal);
    blendWeights = pow(blendWeights, 3.0);
    blendWeights /= (blendWeights.x + blendWeights.y + blendWeights.z + 0.0001);
    
    float nx = fbm(pos.yz * scale, 3, 2.0, 0.5);
    float ny = fbm(pos.xz * scale, 3, 2.0, 0.5);
    float nz = fbm(pos.xy * scale, 3, 2.0, 0.5);
    
    return nx * blendWeights.x + ny * blendWeights.y + nz * blendWeights.z;
}

inline float macroVariation(float3 worldPos) {
    return fbm(worldPos.xz * 0.002, 3, 2.0, 0.5);
}

// MARK: - Terrain Fragment Shader (G-Buffer Output)

fragment GBufferOutput terrainFragment(GBufferVertexOut in [[stage_in]],
                                        constant FrameUniforms &frame [[buffer(1)]],
                                        constant TerrainParams &terrain [[buffer(3)]]) {
    GBufferOutput gbuf;
    
    float3 normal = normalize(in.worldNormal);
    float3 worldPos = in.worldPosition;
    float distToCamera = length(frame.cameraPosition - worldPos);
    
    // Distance detail fade factors
    float detailFade = 1.0 - smoothstep(12.0, 90.0, distToCamera);
    float microFade = 1.0 - smoothstep(4.0, 32.0, distToCamera);
    
    // Planet palette
    float3 planetTint = terrain.terrainTintAndWeight.rgb;
    float3 rockBedTint = terrain.rockTintAndMood.rgb;
    float moodIndex = terrain.rockTintAndMood.w;
    
    // Macro-variation across the landscape (continental color and value shifts)
    float macro = macroVariation(worldPos);
    float meso = triplanarNoise(worldPos, normal, 0.08);
    float micro = triplanarNoise(worldPos, normal, 1.2) * microFade;
    
    // Slope calculation (0 = flat plains, 1 = vertical cliff)
    float slope = 1.0 - saturate(normal.y);
    float cliffFactor = smoothstep(0.35, 0.72, slope);
    
    // Geological horizontal sedimentary strata on slopes and canyon walls
    float strataNoise = fbm(worldPos.xz * 0.02, 2, 2.0, 0.5);
    float strataBands = sin((worldPos.y * 1.8 + strataNoise * 3.5)) * 0.5 + 0.5;
    strataBands = pow(strataBands, 2.0);
    
    // Wind-blown sand ripples on flat ground
    float2 rippleUV = worldPos.xz * 1.8 + fbm(worldPos.xz * 0.05, 2, 2.0, 0.5) * 1.5;
    float sandRipples = sin(rippleUV.x * 2.5 + rippleUV.y * 1.2) * 0.5 + 0.5;
    sandRipples = (sandRipples - 0.5) * 0.08 * (1.0 - cliffFactor) * microFade;
    
    // Primary soil / regolith tone (tinted by the planet's atmospheric identity)
    float3 soilColor = planetTint * (0.82 + (macro - 0.5) * 0.25 + (meso - 0.5) * 0.12);
    
    // Weathered rock & bedrock tone (darker, mineral-rich with strata striations)
    float3 cliffColor = rockBedTint * (0.75 + strataBands * 0.35 + (macro - 0.5) * 0.15);
    
    // Mineral veins (subtle crystal deposits that catch highlights)
    float mineralMask = smoothstep(0.68, 0.85, meso + (micro * 0.5));
    float3 mineralColor = mix(planetTint * 1.35, float3(0.95, 0.92, 0.88), 0.4);
    
    // Blend base color based on slope and heightfield material weights
    float4 w = in.materialWeights;
    w = max(w, 0.0);
    w /= (w.x + w.y + w.z + w.w + 0.0001);
    
    // Composite albedo
    float3 baseColor = mix(soilColor, cliffColor, cliffFactor);
    baseColor = mix(baseColor, mineralColor, mineralMask * 0.35 * cliffFactor);
    baseColor += sandRipples;
    
    // PBR Roughness & Metallic
    // Flat powdery soil is high roughness; exposed cliff strata and mineral veins are slicker
    float soilRough = 0.82 + (micro - 0.5) * 0.15;
    float rockRough = 0.52 + strataBands * 0.18;
    float mineralRough = 0.22;
    
    float roughness = mix(soilRough, rockRough, cliffFactor);
    roughness = mix(roughness, mineralRough, mineralMask * 0.4);
    roughness = clamp(roughness, 0.08, 0.98);
    
    float metallic = mineralMask * cliffFactor * 0.35;
    
    // --- Multi-scale Normal Perturbation ---
    // Macro dune / rock contours + micro sand grains
    float eps = 0.08;
    float h0 = triplanarNoise(worldPos, normal, 0.8);
    float hX0 = triplanarNoise(worldPos + float3(eps, 0, 0), normal, 0.8);
    float hZ0 = triplanarNoise(worldPos + float3(0, 0, eps), normal, 0.8);
    float3 bumpMeso = normalize(float3(h0 - hX0, eps * 2.2, h0 - hZ0));
    
    // Close-up micro grain
    float epsD = 0.02;
    float h1 = triplanarNoise(worldPos, normal, 5.0);
    float hX1 = triplanarNoise(worldPos + float3(epsD, 0, 0), normal, 5.0);
    float hZ1 = triplanarNoise(worldPos + float3(0, 0, epsD), normal, 5.0);
    float3 bumpMicro = normalize(float3(h1 - hX1, epsD * 2.5, h1 - hZ1));
    
    // Blend bumps with distance falloff
    float3 combinedBump = normalize(bumpMeso + (bumpMicro - float3(0, 1, 0)) * microFade * 0.45);
    
    // World space TBN projection
    float3 T = normalize(cross(normal, float3(0, 0, 1)));
    if (length(T) < 0.001) T = normalize(cross(normal, float3(1, 0, 0)));
    float3 B = cross(normal, T);
    float3x3 TBN = float3x3(T, B, normal);
    float3 perturbedNormal = normalize(TBN * combinedBump);
    
    float3 finalNormal = normalize(mix(normal, perturbedNormal, detailFade * 0.75));
    
    // Output to G-buffer
    gbuf.albedo = float4(baseColor, 0.0);
    gbuf.normal = float4(octEncode(finalNormal), roughness, metallic);
    gbuf.pbrParams = float4(1.0, 0.0, 0.0, 0.0); // Ambient occlusion = 1.0, unused = 0
    gbuf.depth = in.depth;
    
    return gbuf;
}
