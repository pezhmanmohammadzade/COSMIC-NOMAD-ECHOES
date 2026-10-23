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
    float3 objectPos;     // Local position scaled to real-world size (stable surface detail)
    float3 objectNormal;  // Local-space normal
};

// MARK: - Character Material Helpers

inline float valueNoise3D(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash3D(i);
    float n100 = hash3D(i + float3(1, 0, 0));
    float n010 = hash3D(i + float3(0, 1, 0));
    float n110 = hash3D(i + float3(1, 1, 0));
    float n001 = hash3D(i + float3(0, 0, 1));
    float n101 = hash3D(i + float3(1, 0, 1));
    float n011 = hash3D(i + float3(0, 1, 1));
    float n111 = hash3D(i + float3(1, 1, 1));
    return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
               mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

inline float fbm3D(float3 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += valueNoise3D(p) * a;
        p = p * 2.03 + float3(17.1, 9.2, 3.7);
        a *= 0.5;
    }
    return v;
}

/// Tangent-free bump mapping from a scalar height using screen-space derivatives
/// (Mikkelsen, "Bump Mapping Unparametrized Surfaces on the GPU").
inline float3 perturbNormal(float3 N, float3 worldPos, float height) {
    float3 dpdx = dfdx(worldPos);
    float3 dpdy = dfdy(worldPos);
    float dhdx = dfdx(height);
    float dhdy = dfdy(height);
    float3 r1 = cross(dpdy, N);
    float3 r2 = cross(N, dpdx);
    float det = dot(dpdx, r1);
    if (abs(det) < 1e-10) return N;
    float3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
    return normalize(abs(det) * N - grad);
}

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
    
    // Transform normal to world space using the cofactor matrix
    // (proportional to the inverse-transpose; correct under non-uniform scale)
    float3 c0 = instanceData.modelMatrix[0].xyz;
    float3 c1 = instanceData.modelMatrix[1].xyz;
    float3 c2 = instanceData.modelMatrix[2].xyz;
    float3x3 normalMatrix = float3x3(cross(c1, c2), cross(c2, c0), cross(c0, c1));
    out.worldNormal = normalize(normalMatrix * localNormal);
    
    // Object-space coordinates in real-world units (for swim-free procedural detail)
    out.objectPos = localPos * float3(length(c0), length(c1), length(c2));
    out.objectNormal = localNormal;
    
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
    
    float3 N = normalize(in.worldNormal);
    
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
    } else if (materialType < 5.5) {
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
    } else {
        // ================= REALISTIC EVA SUIT MATERIALS (6–10) =================
        float matID = floor(materialType + 0.001);
        float param = fract(materialType);
        float3 op = in.objectPos;
        float3 V = normalize(uniforms.cameraPosition - in.worldPosition);
        
        // Anti-aliasing factor for fine procedural detail
        float pixelSize = length(fwidth(in.worldPosition));
        float fineDetail = 1.0 - smoothstep(0.004, 0.02, pixelSize);
        
        if (matID < 6.5) {
            // 6 = Ortho-fabric (Teflon/Nomex/Kevlar weave), fract = regolith dust
            float dust = saturate(param / 0.9);
            
            // Soft cloth folds (low frequency) + creases (mid frequency)
            float folds = fbm3D(op * float3(9.0, 4.0, 9.0));
            float creases = 1.0 - abs(valueNoise3D(op * 22.0) * 2.0 - 1.0);
            creases = pow(creases, 6.0);
            
            // Ripstop weave grid (faded with distance)
            float2 weaveUV = (op.xy + op.zy) * 260.0;
            float weave = (abs(sin(weaveUV.x)) * abs(sin(weaveUV.y)));
            
            float h = folds * 0.010 - creases * 0.0025 + weave * 0.0004 * fineDetail;
            N = perturbNormal(N, in.worldPosition, h);
            
            ao = 0.78 + 0.22 * folds - creases * 0.10;
            roughness = 0.88 - weave * 0.05 * fineDetail;
            metallic = 0.0;
            
            // Subtle off-white variation
            baseColor *= 0.94 + 0.08 * valueNoise3D(op * 6.0);
            
            // Regolith dust: accumulates in creases and lower surfaces
            float dustMask = dust * smoothstep(0.35, 0.75, fbm3D(op * 14.0 + 3.1) + creases * 0.4);
            baseColor = mix(baseColor, float3(0.46, 0.42, 0.38), dustMask * 0.75);
            roughness = mix(roughness, 0.97, dustMask);
            
            // Cloth sheen (velvet-like rim, very subtle)
            float NdotV = saturate(dot(N, V));
            emission = pow(1.0 - NdotV, 5.0) * 0.06;
        } else if (matID < 7.5) {
            // 7 = Hard composite shell (helmet, PLSS, DCM, boots), fract = dust
            float dust = saturate(param / 0.9);
            
            // Fine orange-peel clearcoat + micro scratches
            float peel = valueNoise3D(op * 180.0);
            float scratches = pow(1.0 - abs(valueNoise3D(op * float3(400.0, 6.0, 400.0)) * 2.0 - 1.0), 24.0);
            N = perturbNormal(N, in.worldPosition, peel * 0.00012 * fineDetail);
            
            roughness = 0.28 + peel * 0.08 + scratches * 0.25 * fineDetail;
            metallic = 0.0;
            ao = 0.95;
            baseColor *= 0.97 + 0.03 * peel;
            
            float dustMask = dust * smoothstep(0.40, 0.80, fbm3D(op * 10.0 + 7.3));
            baseColor = mix(baseColor, float3(0.45, 0.41, 0.37), dustMask * 0.8);
            roughness = mix(roughness, 0.92, dustMask);
        } else if (matID < 8.5) {
            // 8 = Gold-coated sun visor: highly reflective, mirrors sky & horizon
            float3 R = reflect(-V, N);
            float sky = saturate(R.y * 0.5 + 0.5);
            float3 skyCol = mix(float3(0.10, 0.09, 0.08), float3(0.85, 0.80, 0.72), smoothstep(0.35, 0.95, sky));
            // Sharp horizon line reflection
            float horizon = exp(-pow((R.y - 0.02) * 18.0, 2.0));
            skyCol += float3(1.0, 0.92, 0.75) * horizon * 0.6;
            // Sun glint
            float sunSpec = pow(saturate(dot(R, normalize(uniforms.sunDirection))), 600.0);
            skyCol += float3(1.0, 0.95, 0.85) * sunSpec * 6.0;
            
            float NdotV = saturate(dot(N, V));
            float fres = 0.55 + 0.45 * pow(1.0 - NdotV, 3.0);
            
            baseColor = baseColor * skyCol * fres;
            metallic = 1.0;
            roughness = 0.06;
            ao = 1.0;
            emission = 0.38;
        } else if (matID < 9.75) {
            // 9.0 = Rubber, 9.5 = ribbed convolute bellows / tread
            bool ribbed = param > 0.25;
            roughness = 0.82;
            metallic = 0.0;
            if (ribbed) {
                // Ribs run around the joint / across the sole (object Y and Z)
                float ribs = sin(op.y * 210.0 + op.z * 60.0);
                float h = ribs * 0.0016;
                N = perturbNormal(N, in.worldPosition, h);
                ao = 0.80 + 0.20 * (ribs * 0.5 + 0.5);
                roughness = 0.72 + 0.12 * (ribs * 0.5 + 0.5);
            }
            baseColor *= 0.96 + 0.06 * valueNoise3D(op * 40.0);
        } else {
            // 10 = Brushed / anodised aluminium (bearings, bottles, connectors)
            float brushed = valueNoise3D(float3(op.x * 6.0, op.y * 900.0, op.z * 6.0));
            metallic = 1.0;
            roughness = 0.24 + brushed * 0.14 * fineDetail;
            baseColor *= 0.92 + 0.08 * brushed;
            ao = 0.9;
            // Cheap environment glint so metal never reads as flat grey
            float3 R = reflect(-V, N);
            float env = saturate(R.y * 0.5 + 0.5);
            emission = 0.06 + 0.10 * smoothstep(0.55, 1.0, env);
        }
    }
    
    // Output to G-Buffer
    out.albedo = float4(baseColor, emission);
    out.normal = float4(octEncode(N), roughness, metallic);
    out.pbrParams = float4(ao, 0.0, 0.0, 0.0); // No velocity yet
    out.depth = in.depth;
    
    return out;
}
