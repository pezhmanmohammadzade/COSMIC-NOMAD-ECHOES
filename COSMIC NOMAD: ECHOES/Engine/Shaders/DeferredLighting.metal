//
//  DeferredLighting.metal
//  COSMIC NOMAD: ECHOES
//
//  G-buffer resolve pass: PBR lighting with Cook-Torrance BRDF,
//  global illumination approximation, and screen-space reflections.
//

#include "ShaderCommon.h"

// MARK: - Deferred Lighting Resolve

fragment float4 deferredLightingFragment(FullscreenVertexOut in [[stage_in]],
                                          constant FrameUniforms &frame [[buffer(1)]],
                                          constant AtmosphereParams &atmo [[buffer(4)]],
                                          texture2d<float> albedoTex [[texture(0)]],
                                          texture2d<float> normalTex [[texture(1)]],
                                          texture2d<float> pbrTex [[texture(2)]],
                                          depth2d<float> depthTex [[texture(3)]],
                                          depth2d<float> shadowMap [[texture(16)]],
                                          texture2d<float> ssaoTex [[texture(17)]]) {
    
    constexpr sampler samp(mag_filter::nearest, min_filter::nearest);
    constexpr sampler shadowSamp(mag_filter::linear, min_filter::linear, compare_func::less);
    constexpr sampler linearSamp(mag_filter::linear, min_filter::linear);
    
    float2 uv = in.texCoord;
    
    // Sample G-buffer
    float4 albedoSample = albedoTex.sample(samp, uv);
    float4 normalSample = normalTex.sample(samp, uv);
    float4 pbrSample = pbrTex.sample(samp, uv);
    float depth = depthTex.sample(samp, uv);
    
    // Early out for sky pixels
    if (depth >= 1.0) {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    
    // Decode G-buffer
    float3 albedo = albedoSample.rgb;
    float emission = albedoSample.a;
    float3 N = octDecode(normalSample.rg);
    float roughness = normalSample.b;
    float metallic = normalSample.a;
    float ao = pbrSample.r;
    
    // Reconstruct world position from depth
    float4 clipPos = float4(uv * 2.0 - 1.0, depth, 1.0);
    clipPos.y = -clipPos.y;
    float4 viewPos = frame.inverseProjectionMatrix * clipPos;
    viewPos /= viewPos.w;
    float4 worldPos4 = frame.inverseViewMatrix * viewPos;
    float3 worldPos = worldPos4.xyz;
    
    // View direction
    float3 V = normalize(frame.cameraPosition - worldPos);
    float3 L = normalize(frame.sunDirection);
    float3 H = normalize(V + L);
    
    // Dot products
    float NdotV = max(dot(N, V), 0.001);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V), 0.0);
    
    // === SHADOW MAPPING (PCF) ===
    float shadow = 1.0;
    float4 lightSpacePos = frame.lightViewProjectionMatrix * float4(worldPos, 1.0);
    lightSpacePos /= lightSpacePos.w;
    float2 shadowUV = lightSpacePos.xy * float2(0.5, -0.5) + 0.5;
    float lightDepth = lightSpacePos.z;
    
    if (shadowUV.x > 0.0 && shadowUV.x < 1.0 && shadowUV.y > 0.0 && shadowUV.y < 1.0 && lightDepth < 1.0) {
        // PCF 3x3 soft shadows
        float2 texelSize = 1.0 / float2(shadowMap.get_width(), shadowMap.get_height());
        float totalShadow = 0.0;
        float bias = max(0.005 * (1.0 - NdotL), 0.001);
        
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                float2 offset = float2(float(x), float(y)) * texelSize;
                totalShadow += shadowMap.sample_compare(shadowSamp, shadowUV + offset, lightDepth - bias);
            }
        }
        shadow = totalShadow / 9.0;
    }
    
    // === SSAO ===
    float ssao = ssaoTex.sample(linearSamp, uv).r;
    
    // PBR: Cook-Torrance BRDF
    float3 F0 = mix(float3(0.04), albedo, metallic);
    
    // Specular
    float D = distributionGGX(NdotH, roughness);
    float G = geometrySmith(NdotV, NdotL, roughness);
    float3 F = fresnelSchlick(HdotV, F0);
    
    float3 numerator = D * G * F;
    float denominator = 4.0 * NdotV * NdotL + 0.0001;
    float3 specular = numerator / denominator;
    
    // Diffuse
    float3 kD = (1.0 - F) * (1.0 - metallic);
    float3 diffuse = kD * albedo / M_PI_F;
    
    // Direct lighting (with shadow)
    float3 Lo = (diffuse + specular) * frame.sunColor * frame.sunIntensity * NdotL * shadow;
    
    // Global illumination Approximation
    float3 skyAmbient = atmo.ambientColor * atmo.ambientIntensity;
    float3 groundBounce = albedo * atmo.ambientColor * 0.1;
    float hemisphereBlend = N.y * 0.5 + 0.5;
    float3 ambient = mix(groundBounce, skyAmbient, hemisphereBlend);
    
    // Indirect specular approximation
    float3 R = reflect(-V, N);
    float3 envColor = mix(atmo.horizonColor, atmo.zenithColor, max(R.y, 0.0));
    float3 indirectSpecular = fresnelSchlickRoughness(NdotV, F0, roughness) * envColor * 0.3;
    
    // Combine (multiply ambient by SSAO)
    float3 color = Lo + (ambient * albedo + indirectSpecular) * ao * ssao;
    
    // Emission
    color += albedo * emission * 2.0;
    
    return float4(color, 1.0);
}

// MARK: - Screen Space Reflections (SSR)

fragment float4 ssrFragment(FullscreenVertexOut in [[stage_in]],
                             constant FrameUniforms &frame [[buffer(1)]],
                             texture2d<float> litScene [[texture(4)]],
                             texture2d<float> normalTex [[texture(1)]],
                             texture2d<float> pbrTex [[texture(2)]],
                             depth2d<float> depthTex [[texture(3)]]) {
    
    constexpr sampler samp(mag_filter::linear, min_filter::linear);
    constexpr sampler pointSamp(mag_filter::nearest, min_filter::nearest);
    
    float2 uv = in.texCoord;
    float4 litColor = litScene.sample(samp, uv);
    
    // Only apply SSR to sufficiently reflective surfaces
    float4 normalSample = normalTex.sample(pointSamp, uv);
    float roughness = normalSample.b;
    float metallic = normalSample.a;
    
    if (roughness > 0.7 || metallic < 0.05) {
        return litColor; // Skip SSR for rough/non-metallic surfaces
    }
    
    float depth = depthTex.sample(pointSamp, uv);
    if (depth >= 1.0) return litColor;
    
    float3 N = octDecode(normalSample.rg);
    
    // Reconstruct view-space position
    float4 clipPos = float4(uv * 2.0 - 1.0, depth, 1.0);
    clipPos.y = -clipPos.y;
    float4 viewPos = frame.inverseProjectionMatrix * clipPos;
    viewPos /= viewPos.w;
    
    // Reflection direction in view space
    float3 viewNormal = (frame.viewMatrix * float4(N, 0.0)).xyz;
    float3 viewDir = normalize(viewPos.xyz);
    float3 reflDir = reflect(viewDir, viewNormal);
    
    // Ray march in screen space (optimized: max 16 steps)
    float3 rayPos = viewPos.xyz;
    float stepSize = 0.5;
    float3 rayStep = reflDir * stepSize;
    
    float3 reflColor = float3(0.0);
    float reflWeight = 0.0;
    
    for (int i = 0; i < 16; i++) {
        rayPos += rayStep;
        stepSize *= 1.2; // Exponential steps
        rayStep = reflDir * stepSize;
        
        // Project to screen
        float4 projPos = frame.projectionMatrix * float4(rayPos, 1.0);
        projPos /= projPos.w;
        float2 screenPos = projPos.xy * float2(0.5, -0.5) + 0.5;
        
        // Check bounds
        if (screenPos.x < 0.0 || screenPos.x > 1.0 || screenPos.y < 0.0 || screenPos.y > 1.0) break;
        
        // Compare depths
        float sceneDepth = depthTex.sample(pointSamp, screenPos);
        float4 sceneViewPos = frame.inverseProjectionMatrix * float4(screenPos * 2.0 - 1.0, sceneDepth, 1.0);
        sceneViewPos /= sceneViewPos.w;
        
        float depthDiff = rayPos.z - sceneViewPos.z;
        
        if (depthDiff > 0.0 && depthDiff < 2.0) {
            // Hit! Sample the lit scene color
            reflColor = litScene.sample(samp, screenPos).rgb;
            
            // Fade at screen edges
            float2 edgeFade = smoothstep(float2(0.0), float2(0.05), screenPos) *
                              (1.0 - smoothstep(float2(0.95), float2(1.0), screenPos));
            reflWeight = edgeFade.x * edgeFade.y;
            
            // Fade based on roughness
            reflWeight *= (1.0 - roughness);
            break;
        }
    }
    
    // Blend reflection with scene
    float3 finalColor = mix(litColor.rgb, reflColor, reflWeight * 0.5);
    
    return float4(finalColor, litColor.a);
}
