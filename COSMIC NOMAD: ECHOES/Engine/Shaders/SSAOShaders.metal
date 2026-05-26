//
//  SSAOShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  Screen-Space Ambient Occlusion: samples depth/normals from the G-buffer
//  to estimate soft contact shadows in crevices and near surfaces.
//

#include "ShaderCommon.h"

// SSAO kernel — hemisphere samples in tangent space
constant int SSAO_KERNEL_SIZE = 16;

fragment float4 ssaoFragment(FullscreenVertexOut in [[stage_in]],
                              constant FrameUniforms &frame [[buffer(1)]],
                              texture2d<float> normalTex [[texture(1)]],
                              depth2d<float> depthTex [[texture(3)]]) {
    constexpr sampler pointSamp(mag_filter::nearest, min_filter::nearest);
    
    float2 uv = in.texCoord;
    float depth = depthTex.sample(pointSamp, uv);
    
    // Skip sky pixels
    if (depth >= 1.0) {
        return float4(1.0);
    }
    
    // Decode normal
    float4 normalSample = normalTex.sample(pointSamp, uv);
    float3 N = octDecode(normalSample.rg);
    
    // Reconstruct view-space position
    float4 clipPos = float4(uv * 2.0 - 1.0, depth, 1.0);
    clipPos.y = -clipPos.y;
    float4 viewPos = frame.inverseProjectionMatrix * clipPos;
    viewPos /= viewPos.w;
    
    float3 fragPos = viewPos.xyz;
    
    // Random rotation from pixel position (avoids banding)
    float2 noiseUV = uv * frame.screenSize / 4.0;
    float rotAngle = hash(noiseUV + fract(frame.time * 0.1)) * M_PI_F * 2.0;
    float cosR = cos(rotAngle);
    float sinR = sin(rotAngle);
    
    // Build TBN in view space
    float3 viewN = normalize((frame.viewMatrix * float4(N, 0.0)).xyz);
    float3 tangent = normalize(cross(viewN, float3(0, 0, 1)));
    if (length(tangent) < 0.001) tangent = normalize(cross(viewN, float3(1, 0, 0)));
    float3 bitangent = cross(viewN, tangent);
    
    float occlusion = 0.0;
    float sampleRadius = 1.5; // World-space radius
    
    for (int i = 0; i < SSAO_KERNEL_SIZE; i++) {
        // Generate hemisphere sample
        float fi = float(i);
        float r = (fi + 0.5) / float(SSAO_KERNEL_SIZE);
        float phi = fi * 2.399963; // golden angle
        float cosTheta = sqrt(1.0 - r);
        float sinTheta = sqrt(r);
        
        float3 sampleDir = float3(
            sinTheta * cos(phi),
            sinTheta * sin(phi),
            cosTheta
        );
        
        // Random rotation
        float rx = sampleDir.x * cosR - sampleDir.y * sinR;
        float ry = sampleDir.x * sinR + sampleDir.y * cosR;
        sampleDir = float3(rx, ry, sampleDir.z);
        
        // Scale — closer samples contribute more
        float scale = 0.1 + r * 0.9;
        
        // Transform to view space
        float3 samplePos = fragPos + (tangent * sampleDir.x + bitangent * sampleDir.y + viewN * sampleDir.z) * sampleRadius * scale;
        
        // Project to screen
        float4 offset = frame.projectionMatrix * float4(samplePos, 1.0);
        offset /= offset.w;
        float2 sampleUV = offset.xy * float2(0.5, -0.5) + 0.5;
        
        // Check bounds
        if (sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0) continue;
        
        // Sample depth
        float sampleDepth = depthTex.sample(pointSamp, sampleUV);
        float4 sampleClip = float4(sampleUV * 2.0 - 1.0, sampleDepth, 1.0);
        sampleClip.y = -sampleClip.y;
        float4 sampleViewPos = frame.inverseProjectionMatrix * sampleClip;
        sampleViewPos /= sampleViewPos.w;
        
        // Range check and occlusion
        float rangeCheck = smoothstep(0.0, 1.0, sampleRadius / max(abs(fragPos.z - sampleViewPos.z), 0.001));
        occlusion += (sampleViewPos.z >= samplePos.z + 0.025 ? 1.0 : 0.0) * rangeCheck;
    }
    
    occlusion = 1.0 - (occlusion / float(SSAO_KERNEL_SIZE));
    occlusion = pow(occlusion, 2.0); // Stronger effect
    
    return float4(occlusion, occlusion, occlusion, 1.0);
}

// Simple box blur for SSAO
fragment float4 ssaoBlurFragment(FullscreenVertexOut in [[stage_in]],
                                  texture2d<float> ssaoTex [[texture(0)]]) {
    constexpr sampler samp(mag_filter::linear, min_filter::linear);
    
    float2 texelSize = 1.0 / float2(ssaoTex.get_width(), ssaoTex.get_height());
    float2 uv = in.texCoord;
    
    float result = 0.0;
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            float2 offset = float2(float(x), float(y)) * texelSize;
            result += ssaoTex.sample(samp, uv + offset).r;
        }
    }
    result /= 25.0;
    
    return float4(result, result, result, 1.0);
}
