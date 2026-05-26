//
//  AtmosphereShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  Atmospheric rendering: procedural sky with Rayleigh/Mie scattering,
//  volumetric fog via ray-marching, and dynamic light scattering.
//

#include "ShaderCommon.h"

// MARK: - Atmospheric Scattering

// Simplified single-scattering atmosphere model
// Based on Nishita/Preetham sky model, optimized for mobile

float atmosphereDensity(float height, float scaleHeight) {
    return exp(-max(height, 0.0) / scaleHeight);
}

float3 computeAtmosphericScattering(float3 rayDir,
                                      float3 sunDir,
                                      constant AtmosphereParams &atmo) {
    // Simplified atmosphere - no sphere intersection, just vertical gradient
    float sunDot = max(dot(rayDir, sunDir), 0.0);
    float verticalAngle = rayDir.y;
    
    // Rayleigh scattering (blue sky / red sunset)
    float rayleighPhase = 0.75 * (1.0 + sunDot * sunDot);
    float3 rayleigh = atmo.rayleighCoefficients * rayleighPhase * 15.0;
    
    // Mie scattering (sun glow)
    float g = atmo.mieDirectionality;
    float miePhase = (1.0 - g * g) / (4.0 * M_PI_F * pow(1.0 + g * g - 2.0 * g * sunDot, 1.5));
    float3 mie = float3(atmo.mieCoefficient) * miePhase * 8.0;
    
    // Optical depth approximation
    float zenithAngle = acos(max(verticalAngle, 0.0));
    float opticalDepth = 1.0 / (cos(zenithAngle) + 0.15 * pow(93.885 - (zenithAngle * 180.0 / M_PI_F), -1.253));
    
    // Extinction
    float3 extinction = exp(-(rayleigh + mie * 1.1) * opticalDepth * 0.1);
    
    // Sky color
    float3 skyColor = (rayleigh + mie) * (1.0 - extinction) * 2.0;
    
    // Blend between zenith and horizon colors
    float horizonBlend = pow(1.0 - max(verticalAngle, 0.0), 4.0);
    skyColor = mix(skyColor, atmo.horizonColor * 1.5, horizonBlend * 0.6);
    
    // Sun disc
    float sunDisc = smoothstep(0.9995, 0.9999, sunDot);
    skyColor += float3(1.0, 0.95, 0.85) * sunDisc * 50.0;
    
    // Stars (visible when looking away from sun and above horizon)
    if (verticalAngle > 0.0) {
        float starBrightness = pow(max(1.0 - sunDot, 0.0), 2.0) * verticalAngle;
        float starField = step(0.997, hash(floor(rayDir.xz * 800.0)));
        float starTwinkle = sin(hash(floor(rayDir.xz * 800.0)) * 100.0 + atmo.weatherVisibility) * 0.5 + 0.5;
        skyColor += starField * starBrightness * starTwinkle * 3.0;
    }
    
    return max(skyColor, float3(0.0));
}

// MARK: - Atmosphere Fragment Shader

fragment float4 atmosphereFragment(FullscreenVertexOut in [[stage_in]],
                                    constant FrameUniforms &frame [[buffer(1)]],
                                    constant AtmosphereParams &atmo [[buffer(4)]],
                                    texture2d<float> litScene [[texture(4)]],
                                    depth2d<float> depthTex [[texture(3)]]) {
    
    constexpr sampler samp(mag_filter::linear, min_filter::linear);
    constexpr sampler pointSamp(mag_filter::nearest, min_filter::nearest);
    
    float2 uv = in.texCoord;
    float4 sceneColor = litScene.sample(samp, uv);
    float depth = depthTex.sample(pointSamp, uv);
    
    // Reconstruct view ray direction
    float2 ndc = uv * 2.0 - 1.0;
    ndc.y = -ndc.y;
    float4 clipPos = float4(ndc, 1.0, 1.0);
    float4 viewDir4 = frame.inverseProjectionMatrix * clipPos;
    viewDir4 /= viewDir4.w;
    float3 viewDir = normalize((frame.inverseViewMatrix * float4(viewDir4.xyz, 0.0)).xyz);
    
    float3 sunDir = normalize(frame.sunDirection);
    
    // Sky for background pixels
    if (depth >= 1.0) {
        float3 sky = computeAtmosphericScattering(viewDir, sunDir, atmo);
        return float4(sky, 1.0);
    }
    
    // For scene pixels, apply aerial perspective (fog blending toward atmosphere)
    float4 viewPos = frame.inverseProjectionMatrix * float4(ndc, depth, 1.0);
    viewPos /= viewPos.w;
    float linearDepth = -viewPos.z;
    
    // Distance-based fog
    float fogFactor = 1.0 - exp(-linearDepth * atmo.fogDensityBase * 0.01);
    fogFactor = clamp(fogFactor, 0.0, 1.0);
    
    // Height fog
    float4 worldPos4 = frame.inverseViewMatrix * viewPos;
    float worldHeight = worldPos4.y;
    float heightFog = exp(-max(worldHeight, 0.0) * atmo.fogHeightFalloff);
    fogFactor = max(fogFactor, heightFog * 0.3);
    
    // Fog color with inscattering
    float sunInfluence = max(dot(viewDir, sunDir), 0.0);
    float3 fogColor = mix(atmo.fogColor, atmo.fogInscatteringColor,
                          pow(sunInfluence, 8.0) * atmo.fogInscatteringIntensity);
    
    // Apply weather visibility
    fogFactor *= (2.0 - atmo.weatherVisibility);
    fogFactor = clamp(fogFactor, 0.0, 0.95);
    
    float3 finalColor = mix(sceneColor.rgb, fogColor, fogFactor);
    
    return float4(finalColor, 1.0);
}

// MARK: - Volumetric Fog (Half-Resolution)

fragment float4 volumetricFogFragment(FullscreenVertexOut in [[stage_in]],
                                       constant FrameUniforms &frame [[buffer(1)]],
                                       constant AtmosphereParams &atmo [[buffer(4)]],
                                       depth2d<float> depthTex [[texture(3)]]) {
    
    constexpr sampler pointSamp(mag_filter::nearest, min_filter::nearest);
    
    float2 uv = in.texCoord;
    float depth = depthTex.sample(pointSamp, uv);
    
    // Reconstruct ray
    float2 ndc = uv * 2.0 - 1.0;
    ndc.y = -ndc.y;
    float4 viewRay = frame.inverseProjectionMatrix * float4(ndc, 1.0, 1.0);
    viewRay /= viewRay.w;
    float3 worldRayDir = normalize((frame.inverseViewMatrix * float4(viewRay.xyz, 0.0)).xyz);
    
    // Ray march through fog volume
    float maxDist = (depth < 1.0) ? linearizeDepth(depth, frame.nearPlane, frame.farPlane) : 500.0;
    maxDist = min(maxDist, 500.0);
    
    int numSteps = 16;
    float stepSize = maxDist / float(numSteps);
    
    float3 accumFog = float3(0.0);
    float accumDensity = 0.0;
    
    float3 sunDir = normalize(frame.sunDirection);
    
    for (int i = 0; i < numSteps; i++) {
        float t = (float(i) + 0.5) * stepSize;
        float3 samplePos = frame.cameraPosition + worldRayDir * t;
        
        // Fog density at this point
        float baseDensity = atmo.fogDensityBase;
        
        // Height falloff
        float heightDensity = exp(-max(samplePos.y, 0.0) * atmo.fogHeightFalloff);
        
        // Noise-based density variation
        float noiseDensity = fbm(samplePos.xz * 0.01 + frame.time * 0.02, 3, 2.0, 0.5);
        noiseDensity = smoothstep(0.3, 0.7, noiseDensity);
        
        float density = baseDensity * heightDensity * (0.5 + noiseDensity * 0.5);
        
        // Light contribution at this point
        float sunVis = 1.0; // Simplified - no shadow marching for performance
        float phase = (1.0 - atmo.mieDirectionality * atmo.mieDirectionality) /
                      (4.0 * M_PI_F * pow(1.0 + atmo.mieDirectionality * atmo.mieDirectionality -
                       2.0 * atmo.mieDirectionality * dot(worldRayDir, sunDir), 1.5));
        
        float3 lightContrib = frame.sunColor * sunVis * phase * density * stepSize;
        float3 ambientContrib = atmo.ambientColor * density * stepSize * 0.3;
        
        accumFog += (lightContrib + ambientContrib) * exp(-accumDensity);
        accumDensity += density * stepSize;
    }
    
    float transmittance = exp(-accumDensity);
    
    return float4(accumFog, 1.0 - transmittance);
}
