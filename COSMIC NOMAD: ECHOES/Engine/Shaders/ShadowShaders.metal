//
//  ShadowShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  Shadow map pass: renders terrain depth from the sun's viewpoint.
//

#include "ShaderCommon.h"

// Shadow map vertex shader — transforms terrain vertices from light's perspective
vertex float4 shadowVertex(uint vid [[vertex_id]],
                            constant TerrainVertex *vertices [[buffer(0)]],
                            constant FrameUniforms &frame [[buffer(1)]],
                            constant TerrainParams &terrain [[buffer(3)]]) {
    TerrainVertex vert = vertices[vid];
    float4 worldPos = terrain.modelMatrix * float4(vert.position, 1.0);
    return frame.lightViewProjectionMatrix * worldPos;
}

// Shadow map fragment (depth-only, no color output needed)
fragment float4 shadowFragment() {
    return float4(0.0); // Only depth is written
}
