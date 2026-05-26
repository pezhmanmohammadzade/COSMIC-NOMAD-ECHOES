//
//  PostProcessShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  Post-processing pipeline: bloom, depth of field, color grading,
//  film grain, chromatic aberration, vignette, ACES tone mapping.
//

#include "ShaderCommon.h"

// MARK: - Bloom Threshold

fragment float4 bloomThresholdFragment(FullscreenVertexOut in [[stage_in]],
                                         constant PostProcessParams &pp [[buffer(5)]],
                                         texture2d<float> litScene [[texture(4)]]) {
    constexpr sampler samp(mag_filter::linear, min_filter::linear);
    
    float3 color = litScene.sample(samp, in.texCoord).rgb;
    
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    float contribution = max(luminance - pp.bloomThreshold, 0.0);
    contribution /= (luminance + 0.001);
    
    return float4(color * contribution, 1.0);
}

// MARK: - Gaussian Blur (for bloom)

fragment float4 gaussianBlurHorizontal(FullscreenVertexOut in [[stage_in]],
                                         constant float2 &texelSize [[buffer(0)]],
                                         texture2d<float> inputTex [[texture(0)]]) {
    constexpr sampler samp(mag_filter::linear, min_filter::linear);
    
    float weights[5] = { 0.227027, 0.194946, 0.121622, 0.054054, 0.016216 };
    
    float3 result = inputTex.sample(samp, in.texCoord).rgb * weights[0];
    
    for (int i = 1; i < 5; i++) {
        float2 offset = float2(float(i) * texelSize.x, 0.0);
        result += inputTex.sample(samp, in.texCoord + offset).rgb * weights[i];
        result += inputTex.sample(samp, in.texCoord - offset).rgb * weights[i];
    }
    
    return float4(result, 1.0);
}

fragment float4 gaussianBlurVertical(FullscreenVertexOut in [[stage_in]],
                                       constant float2 &texelSize [[buffer(0)]],
                                       texture2d<float> inputTex [[texture(0)]]) {
    constexpr sampler samp(mag_filter::linear, min_filter::linear);
    
    float weights[5] = { 0.227027, 0.194946, 0.121622, 0.054054, 0.016216 };
    
    float3 result = inputTex.sample(samp, in.texCoord).rgb * weights[0];
    
    for (int i = 1; i < 5; i++) {
        float2 offset = float2(0.0, float(i) * texelSize.y);
        result += inputTex.sample(samp, in.texCoord + offset).rgb * weights[i];
        result += inputTex.sample(samp, in.texCoord - offset).rgb * weights[i];
    }
    
    return float4(result, 1.0);
}

// MARK: - Final Composite (Bloom + Color Grade + Film Grain + Vignette)

fragment float4 finalCompositeFragment(FullscreenVertexOut in [[stage_in]],
                                         constant FrameUniforms &frame [[buffer(1)]],
                                         constant PostProcessParams &pp [[buffer(5)]],
                                         texture2d<float> litScene [[texture(4)]],
                                         texture2d<float> bloomTex [[texture(14)]],
                                         depth2d<float> depthTex [[texture(3)]]) {
    constexpr sampler samp(mag_filter::linear, min_filter::linear);
    constexpr sampler pointSamp(mag_filter::nearest, min_filter::nearest);
    
    float2 uv = in.texCoord;
    
    // --- Chromatic Aberration ---
    float2 distFromCenter = uv - 0.5;
    float dist2 = dot(distFromCenter, distFromCenter);
    float caStrength = pp.chromaticAberrationIntensity * dist2;
    
    float3 color;
    color.r = litScene.sample(samp, uv + distFromCenter * caStrength).r;
    color.g = litScene.sample(samp, uv).g;
    color.b = litScene.sample(samp, uv - distFromCenter * caStrength).b;
    
    // --- Depth of Field ---
    float depth = depthTex.sample(pointSamp, uv);
    if (depth < 1.0) {
        float linearDepth = linearizeDepth(depth, frame.nearPlane, frame.farPlane);
        float dofFactor = abs(linearDepth - pp.dofFocusDistance) / pp.dofFocusRange;
        dofFactor = clamp(dofFactor, 0.0, 1.0);
        dofFactor = smoothstep(0.0, 1.0, dofFactor);
        
        // Simple DOF: blur by sampling neighbors
        if (dofFactor > 0.01) {
            float2 texelSize = 1.0 / frame.screenSize;
            float blurRadius = dofFactor * pp.dofBokehSize;
            
            float3 blurred = float3(0.0);
            float totalWeight = 0.0;
            
            for (int y = -2; y <= 2; y++) {
                for (int x = -2; x <= 2; x++) {
                    float2 offset = float2(float(x), float(y)) * texelSize * blurRadius;
                    float weight = 1.0 / (1.0 + length(float2(float(x), float(y))));
                    blurred += litScene.sample(samp, uv + offset).rgb * weight;
                    totalWeight += weight;
                }
            }
            blurred /= totalWeight;
            
            color = mix(color, blurred, dofFactor);
        }
    }
    
    // --- Bloom & Procedural Lens Dirt ---
    float3 bloom = bloomTex.sample(samp, uv).rgb;
    
    // Procedural lens dirt (simulates smudges on the camera lens)
    float lensDirt = fbm(uv * 8.0, 4, 2.0, 0.5);
    lensDirt = smoothstep(0.5, 0.8, lensDirt) * 2.0;
    
    // Bloom adds normally, but bright bloom areas illuminate the lens dirt
    color += bloom * pp.bloomIntensity;
    color += bloom * lensDirt * pp.bloomIntensity * 2.5;
    
    // --- Exposure ---
    color *= pp.exposure;
    
    // --- ACES Tone Mapping ---
    color = acesFilm(color);
    
    // --- Color Temperature ---
    float temp = pp.temperature;
    color.r *= 1.0 + temp * 0.1;
    color.b *= 1.0 - temp * 0.1;
    
    // --- Contrast ---
    color = ((color - 0.5) * pp.contrast) + 0.5;
    
    // --- Saturation ---
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    color = mix(float3(luma), color, pp.saturation);
    
    // --- Vignette ---
    float vigDist = length(distFromCenter) * 1.41421;
    float vignette = smoothstep(pp.vignetteRadius, pp.vignetteRadius - 0.45, vigDist);
    color *= mix(1.0 - pp.vignetteIntensity, 1.0, vignette);
    
    // --- Film Grain ---
    float2 grainUV = uv * frame.screenSize / pp.filmGrainSize;
    float grain = hash(grainUV + fract(frame.time * 137.0)) - 0.5;
    grain *= pp.filmGrainIntensity;
    color += grain;
    
    // --- Final Clamp ---
    color = clamp(color, 0.0, 1.0);
    
    // Linear to sRGB
    color = pow(color, float3(1.0 / 2.2));
    
    return float4(color, 1.0);
}
