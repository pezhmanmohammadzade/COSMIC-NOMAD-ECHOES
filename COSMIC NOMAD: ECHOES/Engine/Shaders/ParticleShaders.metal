//
//  ParticleShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  Compute shader for particle simulation (dust, snow, rain)
//  and vertex/fragment shaders for rendering them.
//

#include "ShaderCommon.h"

// MARK: - Particle Compute Shader

kernel void updateParticles(device Particle *particles [[buffer(0)]],
                             constant ParticleUniforms &uniforms [[buffer(1)]],
                             uint id [[thread_position_in_grid]]) {
    
    if (id >= uniforms.particleCount) return;
    
    Particle p = particles[id];
    
    // Update life
    p.life -= uniforms.deltaTime;
    
    if (p.life <= 0.0) {
        // Respawn particle
        p.life = p.maxLife * (0.5 + hash(float2(id, uniforms.time)) * 0.5);
        
        // Spawn around emitter
        float r1 = hash(float2(uniforms.time, id));
        float r2 = hash(float2(id, uniforms.time));
        float r3 = hash(float2(r1, r2));
        
        float radius = 30.0;
        p.position = uniforms.emitterPosition + float3(
            (r1 - 0.5) * radius,
            (r2 - 0.2) * radius,
            (r3 - 0.5) * radius
        );
        
        p.type = uniforms.activeType;
        
        if (p.type == 0.0) {
            // Dust
            p.velocity = float3(
                (hash(float2(r2, r1)) - 0.5) * 0.5,
                (hash(float2(r3, r2)) - 0.5) * 0.5,
                (hash(float2(r1, r3)) - 0.5) * 0.5
            ) + uniforms.windDirection * 0.5;
            p.size = 0.05 + r1 * 0.1;
            p.color = float4(1.0, 0.9, 0.8, 0.5);
        } else if (p.type == 1.0) {
            // Rain
            p.velocity = uniforms.windDirection * 2.0 + float3(0, -15.0 - r2 * 5.0, 0);
            p.size = 0.02; // very thin
            p.color = float4(0.8, 0.9, 1.0, 0.3);
        } else {
            // Snow / Ash
            p.velocity = uniforms.windDirection * 1.5 + float3(
                sin(uniforms.time * 2.0 + id) * 0.5,
                -2.0 - r2 * 2.0,
                cos(uniforms.time * 2.0 + id) * 0.5
            );
            p.size = 0.1 + r1 * 0.15;
            p.color = float4(1.0, 1.0, 1.0, 0.6);
        }
    } else {
        // Update physics
        
        if (p.type == 0.0) {
            // Dust floats with noise
            float3 noiseOffset = float3(
                fbm(p.position.yz * 0.1 + uniforms.time, 2, 2.0, 0.5),
                fbm(p.position.xz * 0.1 + uniforms.time, 2, 2.0, 0.5),
                fbm(p.position.xy * 0.1 + uniforms.time, 2, 2.0, 0.5)
            ) * 2.0 - 1.0;
            p.velocity += noiseOffset * uniforms.deltaTime * 0.5;
            
            // Fade in/out
            p.color.a = min(p.color.a, sin((p.life / p.maxLife) * M_PI_F) * 0.5);
        }
        
        p.position += p.velocity * uniforms.deltaTime;
        
        // Wrap around emitter if too far
        float3 diff = p.position - uniforms.emitterPosition;
        float dist = length(diff);
        if (dist > 30.0) {
            p.position = uniforms.emitterPosition - (diff * 0.9);
        }
    }
    
    particles[id] = p;
}

// MARK: - Particle Render Shaders

struct ParticleVertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
};

vertex ParticleVertexOut particleVertex(uint vid [[vertex_id]],
                                         device const Particle *particles [[buffer(0)]],
                                         constant FrameUniforms &frame [[buffer(1)]]) {
    
    Particle p = particles[vid];
    ParticleVertexOut out;
    
    float4 worldPos = float4(p.position, 1.0);
    out.position = frame.viewProjectionMatrix * worldPos;
    
    // Scale by distance
    float dist = out.position.z;
    out.pointSize = max(1.0, (p.size * 1000.0) / dist);
    
    // Fade out near camera and far away
    float alphaFade = smoothstep(1.0, 5.0, dist) * (1.0 - smoothstep(40.0, 50.0, dist));
    
    out.color = p.color;
    out.color.a *= alphaFade;
    
    return out;
}

fragment float4 particleFragment(ParticleVertexOut in [[stage_in]],
                                  float2 pointCoord [[point_coord]]) {
    
    // Soft circle
    float2 centerCoord = pointCoord * 2.0 - 1.0;
    float distSq = dot(centerCoord, centerCoord);
    
    if (distSq > 1.0) discard_fragment();
    
    float alpha = in.color.a * (1.0 - distSq);
    
    // Pre-multiplied alpha
    return float4(in.color.rgb * alpha, alpha);
}
