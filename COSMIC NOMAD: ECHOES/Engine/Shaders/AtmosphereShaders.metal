//
//  AtmosphereShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  AAA Atmospheric Rendering:
//  Procedural planetary sky with Rayleigh/Mie physical scattering,
//  spherical celestial star cartography with optical diffraction spikes,
//  cosmic nebula dust bands, coronal sun glow, and depth-conserving aerial perspective.
//

#include "ShaderCommon.h"

// MARK: - Celestial Star Field & Nebula

inline float3 computeCelestialStars(float3 rayDir, float sunDot, float verticalAngle, float weatherVisibility) {
    if (verticalAngle <= 0.0) return float3(0.0);
    
    // Day/Night attenuation: stars fade when facing the sun or near the horizon
    float dayFade = pow(max(1.0 - sunDot, 0.0), 3.0) * smoothstep(0.04, 0.25, verticalAngle);
    if (dayFade < 0.001) return float3(0.0);
    
    // Spherical coordinates mapping (avoids polar collapse / zenith pinching)
    float u = atan2(rayDir.z, rayDir.x) / (2.0 * M_PI_F) + 0.5;
    float v = asin(clamp(rayDir.y, -1.0, 1.0)) / M_PI_F + 0.5;
    float2 skyUV = float2(u, v);
    
    float3 starLight = float3(0.0);
    
    // --- Layer 1: Background Stellar Dust / Galactic Band ---
    float bandDist = abs(rayDir.y * 0.7 + rayDir.x * 0.5 - 0.2);
    float galacticBand = exp(-bandDist * bandDist * 18.0);
    float bandNoise = fbm(rayDir * 4.0, 3, 2.0, 0.5);
    starLight += float3(0.12, 0.15, 0.24) * galacticBand * bandNoise * 0.6;
    
    // --- Layer 2: Medium Magnitude Stars ---
    float2 gridUV = skyUV * 420.0;
    float2 cell = floor(gridUV);
    float2 fracUV = fract(gridUV);
    
    float starHash = hash(cell);
    if (starHash > 0.982) {
        float2 starPos = float2(hash(cell + float2(1.3, 7.1)), hash(cell + float2(4.7, 2.9)));
        float2 diff = fracUV - starPos;
        float distSq = dot(diff, diff);
        
        // Soft Gaussian point profile (no blocky square pixels)
        float pointProfile = exp(-distSq * 180.0);
        
        // Subtle optical twinkle
        float twinkle = sin(starHash * 40.0 + weatherVisibility * 2.0) * 0.35 + 0.65;
        
        // Star color temperature (cool blue giants vs warm orange dwarfs)
        float3 starColor = mix(float3(0.85, 0.92, 1.0), float3(1.0, 0.88, 0.72), hash(cell + 0.5));
        
        starLight += starColor * pointProfile * twinkle * 1.6;
    }
    
    // --- Layer 3: 1st-Magnitude Anchor Stars (with 4-point optical diffraction spikes) ---
    float2 brightGrid = skyUV * 95.0;
    float2 bCell = floor(brightGrid);
    float2 bFrac = fract(brightGrid);
    
    float bHash = hash(bCell * 17.3 + 9.1);
    if (bHash > 0.993) {
        float2 bPos = float2(hash(bCell + 3.1), hash(bCell + 8.4));
        float2 diff = bFrac - bPos;
        float d2 = dot(diff, diff);
        
        float core = exp(-d2 * 350.0) * 4.5;
        
        // 4-point diffraction spike cross
        float spikeX = exp(-abs(diff.y) * 40.0) * exp(-abs(diff.x) * 4.0);
        float spikeY = exp(-abs(diff.x) * 40.0) * exp(-abs(diff.y) * 4.0);
        float spike = (spikeX + spikeY) * 0.8;
        
        float3 bColor = mix(float3(0.75, 0.9, 1.0), float3(1.0, 0.82, 0.5), hash(bCell));
        starLight += bColor * (core + spike) * 2.5;
    }
    
    return starLight * dayFade;
}

// MARK: - Atmospheric Scattering Core

float3 computeAtmosphericScattering(float3 rayDir,
                                    float3 sunDir,
                                    constant AtmosphereParams &atmo) {
    float sunDot = max(dot(rayDir, sunDir), 0.0);
    float verticalAngle = rayDir.y;
    
    // Rayleigh scattering phase
    float rayleighPhase = 0.75 * (1.0 + sunDot * sunDot);
    float3 rayleigh = atmo.rayleighCoefficients * rayleighPhase * 16.0;
    
    // Mie scattering phase (forward sun glow)
    float g = atmo.mieDirectionality;
    float miePhase = (1.0 - g * g) / (4.0 * M_PI_F * pow(1.0 + g * g - 2.0 * g * sunDot, 1.5));
    float3 mie = float3(atmo.mieCoefficient) * miePhase * 9.0;
    
    // Optical depth
    float zenithAngle = acos(max(verticalAngle, 0.0));
    float opticalDepth = 1.0 / (cos(zenithAngle) + 0.15 * pow(93.885 - (zenithAngle * 180.0 / M_PI_F), -1.253));
    
    // Extinction
    float3 extinction = exp(-(rayleigh + mie * 1.1) * opticalDepth * 0.1);
    
    // Sky color base
    float3 skyColor = (rayleigh + mie) * (1.0 - extinction) * 2.2;
    
    // Smooth horizon gradient
    float horizonBlend = pow(1.0 - max(verticalAngle, 0.0), 3.5);
    skyColor = mix(skyColor, atmo.horizonColor * 1.35, horizonBlend * 0.7);
    
    // Coronal solar flare & sun disc
    float sunCorona = exp(-(1.0 - sunDot) * 90.0) * 1.8;
    float sunDisc = smoothstep(0.9994, 0.9998, sunDot);
    skyColor += float3(1.0, 0.96, 0.88) * (sunDisc * 45.0 + sunCorona);
    
    // Celestial star field
    skyColor += computeCelestialStars(rayDir, sunDot, verticalAngle, atmo.weatherVisibility);
    
    return max(skyColor, float3(0.0));
}

// MARK: - Atmosphere & Aerial Perspective Fragment Shader

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
    
    // Aerial perspective for scene pixels
    float4 viewPos = frame.inverseProjectionMatrix * float4(ndc, depth, 1.0);
    viewPos /= viewPos.w;
    float linearDepth = -viewPos.z;
    
    // Distance fog: smooth exponential falloff with zero fog at camera plane
    float distFog = 1.0 - exp(-linearDepth * atmo.fogDensityBase * 0.008);
    
    // Height fog: carefully modulated by distance to eliminate washed-out foreground milky cast
    float4 worldPos4 = frame.inverseViewMatrix * viewPos;
    float worldHeight = worldPos4.y;
    float heightFog = exp(-max(worldHeight, 0.0) * atmo.fogHeightFalloff);
    float distanceModulation = smoothstep(5.0, 45.0, linearDepth);
    float combinedHeightFog = heightFog * distanceModulation * 0.45;
    
    float fogFactor = saturate(distFog + combinedHeightFog);
    
    // Inscattering sun glow in fog
    float sunInfluence = max(dot(viewDir, sunDir), 0.0);
    float3 fogColor = mix(atmo.fogColor, atmo.fogInscatteringColor,
                          pow(sunInfluence, 6.0) * atmo.fogInscatteringIntensity);
    
    // Weather visibility modulation
    fogFactor *= (2.0 - atmo.weatherVisibility * 0.5);
    fogFactor = clamp(fogFactor, 0.0, 0.94);
    
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
    
    float2 ndc = uv * 2.0 - 1.0;
    ndc.y = -ndc.y;
    float4 viewRay = frame.inverseProjectionMatrix * float4(ndc, 1.0, 1.0);
    viewRay /= viewRay.w;
    float3 worldRayDir = normalize((frame.inverseViewMatrix * float4(viewRay.xyz, 0.0)).xyz);
    
    float maxDist = (depth < 1.0) ? linearizeDepth(depth, frame.nearPlane, frame.farPlane) : 450.0;
    maxDist = min(maxDist, 450.0);
    
    int numSteps = 16;
    float stepSize = maxDist / float(numSteps);
    float3 sunDir = normalize(frame.sunDirection);
    
    float3 accumFog = float3(0.0);
    float accumDensity = 0.0;
    
    for (int i = 0; i < numSteps; i++) {
        float t = (float(i) + 0.5) * stepSize;
        float3 samplePos = frame.cameraPosition + worldRayDir * t;
        
        float density = exp(-max(samplePos.y, 0.0) * atmo.fogHeightFalloff) * atmo.fogDensityBase * 0.01;
        
        float sunDot = max(dot(worldRayDir, sunDir), 0.0);
        float phase = 0.75 * (1.0 + sunDot * sunDot);
        float3 lightContrib = atmo.fogInscatteringColor * phase * density * stepSize;
        
        accumFog += lightContrib * exp(-accumDensity);
        accumDensity += density * stepSize;
    }
    
    return float4(accumFog, saturate(accumDensity));
}
