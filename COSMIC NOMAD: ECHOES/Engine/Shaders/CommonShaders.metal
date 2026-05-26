//
//  CommonShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  Contains the fullscreen vertex shader shared across passes.
//  All structures and utilities are in ShaderCommon.h.
//

#include "ShaderCommon.h"

// MARK: - Fullscreen Vertex Shader (shared by all fullscreen passes)

vertex FullscreenVertexOut fullscreenVertex(uint vid [[vertex_id]],
                                             constant FullscreenVertex *vertices [[buffer(0)]]) {
    FullscreenVertexOut out;
    out.position = float4(vertices[vid].position, 0.0, 1.0);
    out.texCoord = vertices[vid].texCoord;
    return out;
}
