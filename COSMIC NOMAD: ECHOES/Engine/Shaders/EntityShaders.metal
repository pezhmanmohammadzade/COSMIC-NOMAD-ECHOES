//
//  EntityShaders.metal
//  COSMIC NOMAD: ECHOES
//
//  Instanced rendering for 3D elements (cities, memory fragments).
//  Outputs to G-Buffer for deferred lighting and atmospheric integration.
//

#include "ShaderCommon.h"

// MARK: - Vertex Shader

struct EntityVertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct EntityVertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 texCoord;
    float4 colorAndMaterial;
    float depth;
};

vertex EntityVertexOut entityVertexShader(
    EntityVertexIn in [[stage_in]],
    constant FrameUniforms &uniforms [[buffer(BufferIndexUniforms)]],
    constant EntityInstance *instances [[buffer(BufferIndexInstanceData)]],
    uint instanceId [[instance_id]]
) {
    EntityVertexOut out;
    
    EntityInstance instanceData = instances[instanceId];
    float materialType = instanceData.colorAndMaterial.a;
    
    // Start with original local-space position and normal
    float3 localPos = in.position;
    float3 localNormal = in.normal;
    
    // --- Astronaut walk animation (material type 5.x) ---
    // Vertices are in normalized space: centered X/Z, Y from 0 (feet) to 1 (head)
    // The fractional part of materialType encodes the arm swing value
    //
    // Model analysis (normalized):
    //   Torso:  |x| < 0.19,  Y [0.3 - 0.8]
    //   Arms:   |x| > 0.20,  Y [0.5 - 0.7]  (extend to ±0.54)
    //   Legs:   |x| < 0.18,  Y [0.0 - 0.4]
    //   Head:   |x| < 0.20,  Y [0.8 - 1.0]
    if (materialType > 4.5 && materialType < 5.5) {
        // Decode arm swing: fract(5.x) maps [0, 0.99] back to [-0.55, 0.55] radians
        float normalizedSwing = fract(materialType) / 0.99;
        float swingRadians = normalizedSwing * 1.1 - 0.55;
        
        // === ARM ANIMATION ===
        // Arms extend horizontally in T-pose (|x| > 0.20 in Y [0.48-0.72])
        // Step 1: Rotate arms DOWN from T-pose to resting position (around Z axis)
        // Step 2: Apply walk swing on top (forward/backward around X axis)
        float armXThreshold = 0.20;  // Torso stops at ~0.19, arms start beyond
        float shoulderY = 0.72;      // Shoulder height
        float armBottomY = 0.48;     // Below hands
        
        if (abs(localPos.x) > armXThreshold && localPos.y > armBottomY && localPos.y < shoulderY + 0.02) {
            float armSide = sign(localPos.x);  // -1 left, +1 right
            
            // How much this vertex is "arm" vs "body" (smooth blend at seam)
            float armFactor = smoothstep(armXThreshold, armXThreshold + 0.10, abs(localPos.x));
            
            // --- Step 1: Rest-pose rotation (bring arms DOWN from T-pose) ---
            // Rotate ~63° around Z axis at shoulder pivot
            float restAngle = -armSide * 1.1 * armFactor;  // ~63° down from T-pose
            
            float shoulderX = armSide * armXThreshold;
            float relX = localPos.x - shoulderX;
            float relY = localPos.y - shoulderY;
            
            float cr = cos(restAngle);
            float sr = sin(restAngle);
            
            localPos.x = shoulderX + relX * cr - relY * sr;
            localPos.y = shoulderY + relX * sr + relY * cr;
            
            // Rotate normal for rest pose (around Z)
            float nx = localNormal.x * cr - localNormal.y * sr;
            float ny2 = localNormal.x * sr + localNormal.y * cr;
            localNormal.x = nx;
            localNormal.y = ny2;
            
            // --- Step 2: Walk swing (forward/backward around X axis at shoulder) ---
            float armSwing = swingRadians * armSide * armFactor;
            
            float relY2 = localPos.y - shoulderY;
            float relZ = localPos.z;
            
            float ca = cos(armSwing);
            float sa = sin(armSwing);
            
            localPos.y = shoulderY + relY2 * ca - relZ * sa;
            localPos.z = relZ * ca + relY2 * sa;
            
            // Rotate normal for walk swing (around X)
            float ny3 = localNormal.y * ca - localNormal.z * sa;
            float nz = localNormal.z * ca + localNormal.y * sa;
            localNormal.y = ny3;
            localNormal.z = nz;
        }
        
        // === LEG ANIMATION ===
        // Legs: lower body vertices below hip line
        float legTopY = 0.40;        // Hip height
        
        if (localPos.y < legTopY) {
            float legSide = sign(localPos.x);
            // Legs swing opposite to same-side arm, with less amplitude
            float legSwing = -swingRadians * legSide * 0.55;
            
            // Scale by distance from hip (feet swing more than thighs)
            float legFactor = 1.0 - (localPos.y / legTopY);
            legSwing *= legFactor;
            
            // Rotate around hip pivot
            float pivotY = legTopY;
            float relY = localPos.y - pivotY;
            float relZ = localPos.z;
            
            float ca = cos(legSwing);
            float sa = sin(legSwing);
            
            localPos.y = pivotY + relY * ca - relZ * sa;
            localPos.z = relZ * ca + relY * sa;
            
            float ny = localNormal.y * ca - localNormal.z * sa;
            float nz = localNormal.z * ca + localNormal.y * sa;
            localNormal.y = ny;
            localNormal.z = nz;
        }
    }
    
    // Transform position to world space
    float4 worldPos = instanceData.modelMatrix * float4(localPos, 1.0);
    
    // Float displacement visualization for Memory Fragment (Material 3)
    if (materialType > 2.5 && materialType < 3.5) {
        worldPos.y += sin(uniforms.time * 3.0) * 0.5;
    }
    
    out.worldPosition = worldPos.xyz;
    
    // Transform normal to world space
    float3x3 normalMatrix = float3x3(
        instanceData.modelMatrix[0].xyz,
        instanceData.modelMatrix[1].xyz,
        instanceData.modelMatrix[2].xyz
    );
    out.worldNormal = normalize(normalMatrix * localNormal);
    
    out.texCoord = in.texCoord;
    out.colorAndMaterial = instanceData.colorAndMaterial;
    
    // Screen space position
    out.position = uniforms.viewProjectionMatrix * worldPos;
    out.depth = out.position.z / out.position.w;
    
    return out;
}

// MARK: - Fragment Shader

fragment GBufferOutput entityFragmentShader(
    EntityVertexOut in [[stage_in]],
    constant FrameUniforms &uniforms [[buffer(BufferIndexUniforms)]]
) {
    GBufferOutput out;
    
    float3 baseColor = in.colorAndMaterial.rgb;
    float materialType = in.colorAndMaterial.a;
    
    float roughness = 0.5;
    float metallic = 0.0;
    float ao = 1.0;
    float emission = 0.0;
    
    // Basic noise for texture variation
    float2 noiseUV = in.worldPosition.xz * 0.1;
    float surfaceNoise = fbm(noiseUV, 3, 2.0, 0.5);
    
    if (materialType < 0.5) {
        // 0 = Metal (Cities)
        metallic = 0.9;
        roughness = 0.2 + surfaceNoise * 0.2;
        baseColor *= 0.8 + surfaceNoise * 0.2; // Add some grit
    } else if (materialType < 1.5) {
        // 1 = Glass / Emissive Energy
        metallic = 0.8;
        roughness = 0.1;
        emission = 1.0;
        baseColor *= 1.5; // Brighten
    } else if (materialType < 2.5) {
        // 2 = Ruin (Stone)
        metallic = 0.0;
        roughness = 0.8 + surfaceNoise * 0.2;
        baseColor *= 0.5 + surfaceNoise * 0.5;
    } else if (materialType < 3.5) {
        // 3 = Memory Fragment (Glowing)
        metallic = 0.1;
        roughness = 0.1;
        emission = 1.0;
        
        // Pulse effect
        float pulse = (sin(uniforms.time * 2.0 + in.worldPosition.x) * 0.5 + 0.5);
        baseColor = mix(baseColor, float3(1.0, 1.0, 1.0), pulse * 0.5);
    } else {
        // 4.x = AAA Astronaut Suit (Layered composite armor with micro-panel detail)
        metallic = 0.12;
        
        // Micro-panel seam lines — creates hi-tech armor plate look
        float2 panelUV = in.worldPosition.xy * 18.0 + in.worldPosition.yz * 18.0;
        float seamX = smoothstep(0.92, 1.0, abs(sin(panelUV.x * 3.14159)));
        float seamY = smoothstep(0.92, 1.0, abs(sin(panelUV.y * 3.14159)));
        float seamPattern = max(seamX, seamY);
        
        // Subtle fabric/composite weave texture
        float2 weaveUV = in.worldPosition.xy * 60.0 + in.worldPosition.yz * 60.0;
        float weavePattern = abs(sin(weaveUV.x + weaveUV.y) * cos(weaveUV.x - weaveUV.y));
        
        roughness = 0.45 + weavePattern * 0.2 + seamPattern * 0.15;
        
        // Darken seam lines slightly
        baseColor *= (1.0 - seamPattern * 0.15);
        
        // Professional soft fresnel rim lighting
        float3 viewDir = normalize(uniforms.cameraPosition - in.worldPosition);
        float NdotV = max(dot(normalize(in.worldNormal), viewDir), 0.0);
        float fresnel = pow(1.0 - NdotV, 4.0) * 0.5;
        
        // Subtle ambient occlusion in crevices
        float ao_hint = 0.85 + weavePattern * 0.15;
        baseColor *= ao_hint;
        
        // Soft edge glow for character readability
        emission = fresnel * 0.45;
    }
    
    // Output to G-Buffer
    out.albedo = float4(baseColor, emission);
    out.normal = float4(octEncode(normalize(in.worldNormal)), roughness, metallic);
    out.pbrParams = float4(ao, 0.0, 0.0, 0.0); // No velocity yet
    out.depth = in.depth;
    
    return out;
}
