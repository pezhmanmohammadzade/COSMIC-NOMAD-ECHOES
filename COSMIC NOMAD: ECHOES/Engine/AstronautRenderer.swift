//
//  AstronautRenderer.swift
//  COSMIC NOMAD: ECHOES
//
//  Realistic procedural EVA astronaut (Artemis / xEMU-inspired).
//
//  • Built from smooth primitives (CharacterMeshLibrary) instead of cubes:
//    capsule limbs, rounded fabric segments, bearing rings, bubble helmet
//    with a true spherical gold visor, PLSS backpack, DCM chest unit,
//    articulated gloves with thumb + finger block, treaded boots.
//  • Physically-motivated materials (see EntityShaders.metal):
//      6.x  Ortho-fabric (fract = regolith dust amount)
//      7.x  Hard composite shell (fract = dust)
//      8.0  Gold visor (metallic, fake sky reflection)
//      9.0  Rubber / 9.5 ribbed convolute bellows
//      10.0 Brushed aluminium
//      1.0  Emissive LED / thruster plume
//  • Biomechanical gait: pelvis bob + lateral sway, pelvis/shoulder
//    counter-rotation, swing-phase knee flexion, foot levelling, elbow
//    flex, forward lean, sprint posture, breathing idle, jetpack hover
//    pose and landing crouch — all blended smoothly between states.
//

import Metal
import simd

@MainActor
final class AstronautRenderer {
    let device: MTLDevice
    
    private let meshes: CharacterMeshLibrary
    
    // Triple-buffered instance storage (avoid CPU/GPU races)
    private static let maxParts = 220
    private var instanceBuffers: [MTLBuffer] = []
    private var bufferCursor = 0
    
    // Per-mesh batches, rebuilt each frame (capacity retained)
    private var batches: [[EntityInstance]] = Array(repeating: [], count: CharacterMeshKind.allCases.count)
    
    /// Global body scale (authored in real-world metres, scaled slightly heroic for readability)
    private let bodyScale: Float = 1.08
    
    // MARK: Animation state
    
    enum AnimState { case idle, walking, sprinting, flying, landing }
    private var currentState: AnimState = .idle
    
    private var gaitPhase: Float = 0
    private var breathPhase: Float = 0
    private var clock: Float = 0
    private var moveBlend: Float = 0
    private var sprintBlend: Float = 0
    private var flyBlend: Float = 0
    private var landingImpulse: Float = 0
    private var wasFlying = false
    private var jetFlicker: Float = 1
    
    init(device: MTLDevice) {
        self.device = device
        self.meshes = CharacterMeshLibrary(device: device)
        
        for i in 0..<ResourceManager.maxFramesInFlight {
            if let buf = device.makeBuffer(length: MemoryLayout<EntityInstance>.stride * Self.maxParts,
                                           options: .storageModeShared) {
                buf.label = "Astronaut Instances \(i)"
                instanceBuffers.append(buf)
            }
        }
        for k in 0..<batches.count { batches[k].reserveCapacity(64) }
        print("🧑‍🚀 AstronautRenderer: realistic EVA suit (smooth primitives, PBR materials)")
    }
    
    // MARK: - Update
    
    func update(isMoving: Bool, deltaTime: Float, isFlying: Bool = false, isSprinting: Bool = false) {
        let dt = min(deltaTime, 1.0 / 20.0)
        clock += dt
        
        // Discrete state (kept for external readability / debugging)
        if isFlying { currentState = .flying }
        else if landingImpulse > 0.05 { currentState = .landing }
        else if isMoving { currentState = isSprinting ? .sprinting : .walking }
        else { currentState = .idle }
        
        // Smooth blends
        func approach(_ v: inout Float, _ target: Float, _ rate: Float) {
            v += (target - v) * min(1, rate * dt)
        }
        approach(&moveBlend, (isMoving && !isFlying) ? 1 : 0, 7)
        approach(&sprintBlend, (isMoving && isSprinting && !isFlying) ? 1 : 0, 5)
        approach(&flyBlend, isFlying ? 1 : 0, 4)
        
        // Landing crouch impulse
        if wasFlying && !isFlying { landingImpulse = 1 }
        wasFlying = isFlying
        landingImpulse = max(0, landingImpulse - dt * 2.6)
        
        // Gait phase (rad/s): walk ≈ 1.1 Hz, sprint ≈ 1.6 Hz
        let cadence = 7.0 + 3.6 * sprintBlend
        gaitPhase += dt * cadence * max(moveBlend, 0.0001)
        if gaitPhase > .pi * 200 { gaitPhase -= .pi * 200 }
        
        breathPhase += dt * (1.3 + 1.6 * sprintBlend)
        jetFlicker = Float.random(in: 0.82...1.18)
    }
    
    // MARK: - Draw
    
    func draw(player: PlayerController, encoder: MTLRenderCommandEncoder, resources: ResourceManager, pipeline: RenderPipeline, time: Float, isMoving: Bool) {
        guard !instanceBuffers.isEmpty else { return }
        for k in 0..<batches.count { batches[k].removeAll(keepingCapacity: true) }
        
        buildPose(player: player)
        
        // Upload batches into this frame's buffer
        bufferCursor = (bufferCursor + 1) % instanceBuffers.count
        let buffer = instanceBuffers[bufferCursor]
        let base = buffer.contents().bindMemory(to: EntityInstance.self, capacity: Self.maxParts)
        
        var cursor = 0
        var ranges: [(CharacterMeshKind, Int, Int)] = []
        for kind in CharacterMeshKind.allCases {
            let batch = batches[kind.rawValue]
            guard !batch.isEmpty else { continue }
            let count = min(batch.count, Self.maxParts - cursor)
            guard count > 0 else { break }
            for i in 0..<count { base[cursor + i] = batch[i] }
            ranges.append((kind, cursor, count))
            cursor += count
        }
        
        encoder.setRenderPipelineState(pipeline.entityPipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: BufferIndex.instanceData.rawValue)
        
        let stride = MemoryLayout<EntityInstance>.stride
        for (kind, start, count) in ranges {
            guard let mesh = meshes[kind] else { continue }
            encoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: BufferIndex.vertices.rawValue)
            encoder.setVertexBufferOffset(start * stride, index: BufferIndex.instanceData.rawValue)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: mesh.indexCount,
                indexType: .uint16,
                indexBuffer: mesh.indexBuffer,
                indexBufferOffset: 0,
                instanceCount: count
            )
        }
    }
    
    // MARK: - Matrix helpers
    
    @inline(__always) private func T(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
        MatrixUtil.translation(SIMD3<Float>(x, y, z))
    }
    /// Pitch about X. For a limb hanging down (−Y), positive = swings forward (−Z).
    @inline(__always) private func RX(_ a: Float) -> float4x4 {
        MatrixUtil.rotation(pitch: a, yaw: 0, roll: 0)
    }
    @inline(__always) private func RY(_ a: Float) -> float4x4 {
        MatrixUtil.rotation(pitch: 0, yaw: a, roll: 0)
    }
    /// Roll about Z. For a limb hanging down, positive = swings toward +X (character's right).
    @inline(__always) private func RZ(_ a: Float) -> float4x4 {
        MatrixUtil.rotation(pitch: 0, yaw: 0, roll: a)
    }
    
    @inline(__always) private func part(_ kind: CharacterMeshKind,
                                        _ pivot: float4x4,
                                        _ offset: SIMD3<Float>,
                                        _ scale: SIMD3<Float>,
                                        _ color: SIMD4<Float>,
                                        rot: float4x4? = nil) {
        var m = pivot * MatrixUtil.translation(offset)
        if let r = rot { m = m * r }
        m = m * MatrixUtil.scale(scale)
        batches[kind.rawValue].append(EntityInstance(modelMatrix: m, colorAndMaterial: color))
    }
    
    // MARK: - Materials
    
    private func fabric(_ rgb: SIMD3<Float>, dust: Float = 0.05) -> SIMD4<Float> {
        SIMD4<Float>(rgb, 6.0 + min(max(dust, 0), 1) * 0.9)
    }
    private func shell(_ rgb: SIMD3<Float>, dust: Float = 0.05) -> SIMD4<Float> {
        SIMD4<Float>(rgb, 7.0 + min(max(dust, 0), 1) * 0.9)
    }
    private func rubber(_ rgb: SIMD3<Float>, ribbed: Bool = false) -> SIMD4<Float> {
        SIMD4<Float>(rgb, ribbed ? 9.5 : 9.0)
    }
    private func metal(_ rgb: SIMD3<Float>) -> SIMD4<Float> { SIMD4<Float>(rgb, 10.0) }
    private func emissive(_ rgb: SIMD3<Float>) -> SIMD4<Float> { SIMD4<Float>(rgb, 1.0) }
    
    // Palette (linear-ish albedo values, realistic EVA suit)
    private let cSuit       = SIMD3<Float>(0.84, 0.84, 0.81)   // Ortho-fabric off-white
    private let cSuitShade  = SIMD3<Float>(0.68, 0.69, 0.68)   // TMG panels / pockets
    private let cShell      = SIMD3<Float>(0.90, 0.90, 0.88)   // Hard composite white
    private let cShellGray  = SIMD3<Float>(0.52, 0.54, 0.56)
    private let cMetal      = SIMD3<Float>(0.80, 0.81, 0.83)   // Anodised aluminium
    private let cDarkMetal  = SIMD3<Float>(0.32, 0.33, 0.35)
    private let cRubber     = SIMD3<Float>(0.06, 0.06, 0.065)
    private let cHose       = SIMD3<Float>(0.18, 0.19, 0.21)
    private let cGlove      = SIMD3<Float>(0.78, 0.78, 0.76)
    private let cRed        = SIMD3<Float>(0.62, 0.06, 0.05)   // Commander stripes / right glove ring
    private let cBlue       = SIMD3<Float>(0.06, 0.18, 0.52)   // Left glove ring / patch
    private let cVisorGold  = SIMD3<Float>(1.00, 0.77, 0.34)
    
    // MARK: - Pose & Assembly
    
    private func buildPose(player: PlayerController) {
        let fwd = player.forward
        let right = normalize(cross(fwd, SIMD3<Float>(0, 1, 0)))
        let up = SIMD3<Float>(0, 1, 0)
        let rot = float4x4(
            SIMD4<Float>(right.x, right.y, right.z, 0),
            SIMD4<Float>(up.x, up.y, up.z, 0),
            SIMD4<Float>(-fwd.x, -fwd.y, -fwd.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        
        // ===== Gait parameters =====
        let φ = gaitPhase
        let s = sin(φ), c = cos(φ)
        let mv = moveBlend, sp = sprintBlend, fl = flyBlend
        let idle = max(0, 1 - mv - fl)
        let land = landingImpulse * landingImpulse
        
        let hipAmp   = mv * (0.40 + 0.20 * sp)
        let kneeAmp  = mv * (0.70 + 0.55 * sp)
        let armAmp   = mv * (0.32 + 0.38 * sp)
        
        let bob      = mv * (0.030 + 0.030 * sp) * (0.5 + 0.5 * cos(2 * φ))
                     - 0.035 * sp - 0.10 * land
                     + fl * sin(clock * 2.3) * 0.035
        let sway     = mv * 0.022 * c * (1 - 0.5 * sp) + idle * 0.012 * sin(clock * 0.45)
        let lean     = -(mv * 0.07 + sp * 0.17 + fl * 0.20) - land * 0.18
        let pelvisYaw = -0.09 * mv * s
        let torsoYaw  =  0.17 * mv * s
        let breath    = sin(breathPhase)
        
        // Legs (pelvis lean is cancelled so feet stay under the body)
        let legLeanFix = -lean * 0.35
        let lHip  =  hipAmp * s + land * 0.35 - fl * 0.10 + fl * 0.05 * sin(clock * 1.7) + legLeanFix
        let rHip  = -hipAmp * s + land * 0.35 - fl * 0.18 + fl * 0.05 * sin(clock * 1.7 + 1.3) + legLeanFix
        let lKnee = 0.05 + kneeAmp * pow(max(0, c), 1.4) + land * 0.75 + fl * 0.30 + 0.06 * sp
        let rKnee = 0.05 + kneeAmp * pow(max(0, -c), 1.4) + land * 0.75 + fl * 0.42 + 0.06 * sp
        let lAnkle = -(lHip - lKnee) * 0.80 - fl * 0.25
        let rAnkle = -(rHip - rKnee) * 0.80 - fl * 0.25
        
        // Arms
        let lArm = -armAmp * s + fl * 0.12 + idle * 0.02 * breath
        let rArm =  armAmp * s + fl * 0.12 + idle * 0.02 * breath
        let elbowBase: Float = 0.22 + 0.10 * mv + 0.95 * sp + 0.25 * fl
        let lElbow = elbowBase + max(0, lArm) * 0.55
        let rElbow = elbowBase + max(0, rArm) * 0.55
        let armOut: Float = 0.16 + 0.22 * fl + 0.06 * land
        
        // Head stabilisation + idle look-around
        let headPitch = -lean * 0.55 + idle * 0.05 * sin(clock * 0.31)
        let headYaw   = -(pelvisYaw + torsoYaw) * 0.8 + idle * 0.28 * sin(clock * 0.23)
        
        // ===== Skeleton =====
        let feetY = player.position.y - player.playerHeight
        let world = MatrixUtil.translation(SIMD3<Float>(player.position.x, feetY, player.position.z))
                  * rot * MatrixUtil.scale(bodyScale)
        
        let hipY: Float = 0.98
        let pelvis = world * T(sway, hipY + bob, 0) * RY(pelvisYaw) * RX(lean * 0.35)
        let torso  = pelvis * T(0, 0.12, 0) * RY(torsoYaw) * RX(lean * 0.65)
        let head   = torso * T(0, 0.56, 0.0) * RX(headPitch) * RY(headYaw)
        
        // ===================== PELVIS =====================
        part(.softBox, pelvis, [0, 0.03, 0.01], [0.40, 0.25, 0.28], fabric(cSuit, dust: 0.12))      // Brief
        part(.softBox, pelvis, [0, -0.09, 0.01], [0.22, 0.14, 0.21], fabric(cSuit, dust: 0.15))     // Crotch
        part(.torus,   pelvis, [0, 0.145, 0.0], [0.37, 0.28, 0.29], metal(cMetal))                    // Waist bearing
        part(.softBox, pelvis, [0, 0.07, -0.135], [0.16, 0.07, 0.02], shell(cShellGray))              // Waist buckle plate
        
        // ===================== TORSO =====================
        let chestScaleY: Float = 1 + 0.012 * breath
        part(.softBox, torso, [0, 0.10, 0.01], [0.38, 0.18, 0.27], rubber(cSuit, ribbed: true))       // Abdomen convolute
        part(.softBox, torso, [0, 0.31, 0.02], [0.50, 0.34 * chestScaleY, 0.32], fabric(cSuit))       // HUT / chest
        part(.capsule, torso, [0, 0.43, 0.03], [0.20, 0.56, 0.26], fabric(cSuit), rot: RZ(.pi / 2))   // Shoulder yoke
        part(.softBox, torso, [0, 0.36, -0.15], [0.40, 0.16, 0.04], fabric(cSuitShade))               // Upper chest TMG panel
        
        // DCM — Display & Control Module
        part(.hardBox,  torso, [0, 0.23, -0.19], [0.25, 0.13, 0.08], shell(cShell))
        part(.hardBox,  torso, [0, 0.27, -0.232], [0.10, 0.03, 0.01], emissive(SIMD3<Float>(0.30, 0.95, 0.70)))
        part(.cylinder, torso, [-0.075, 0.21, -0.235], [0.04, 0.025, 0.04], metal(cDarkMetal), rot: RX(.pi / 2))
        part(.cylinder, torso, [ 0.075, 0.21, -0.235], [0.04, 0.025, 0.04], metal(cDarkMetal), rot: RX(.pi / 2))
        part(.cylinder, torso, [0, 0.195, -0.232], [0.03, 0.02, 0.03], shell(cRed), rot: RX(.pi / 2))
        // Umbilical hoses DCM → waist/PLSS
        part(.capsule, torso, [-0.15, 0.15, -0.14], [0.036, 0.22, 0.036], rubber(cHose), rot: RZ(-0.55) * RX(0.25))
        part(.capsule, torso, [ 0.15, 0.15, -0.14], [0.036, 0.22, 0.036], rubber(cHose), rot: RZ( 0.55) * RX(0.25))
        part(.cylinder, torso, [-0.205, 0.07, -0.10], [0.05, 0.03, 0.05], metal(cMetal), rot: RZ(-0.55))
        part(.cylinder, torso, [ 0.205, 0.07, -0.10], [0.05, 0.03, 0.05], metal(cMetal), rot: RZ( 0.55))
        
        // Neck ring
        part(.torus, torso, [0, 0.545, 0.0], [0.31, 0.24, 0.29], metal(cMetal))
        part(.torus, torso, [0, 0.515, 0.0], [0.34, 0.20, 0.32], shell(cShell))
        
        // ===================== PLSS (backpack + jetpack) =====================
        part(.hardBox, torso, [0, 0.28, 0.28], [0.46, 0.58, 0.20], shell(cShell))                     // Main housing
        part(.hardBox, torso, [0, 0.30, 0.385], [0.36, 0.44, 0.03], shell(SIMD3<Float>(0.80, 0.80, 0.78)))  // Rear access panel
        part(.hardBox, torso, [0, 0.585, 0.27], [0.40, 0.05, 0.18], shell(cShellGray))                // Top cap
        part(.hardBox, torso, [-0.235, 0.28, 0.28], [0.02, 0.40, 0.13], rubber(cRubber, ribbed: true))// Side vents
        part(.hardBox, torso, [ 0.235, 0.28, 0.28], [0.02, 0.40, 0.13], rubber(cRubber, ribbed: true))
        part(.capsule, torso, [-0.12, 0.30, 0.405], [0.07, 0.30, 0.07], metal(cMetal))               // O₂ bottles
        part(.capsule, torso, [ 0.12, 0.30, 0.405], [0.07, 0.30, 0.07], metal(cMetal))
        part(.hardBox, torso, [0, -0.005, 0.29], [0.40, 0.06, 0.16], shell(cShellGray))              // Thruster module
        part(.bell,    torso, [-0.13, -0.075, 0.30], [0.085, 0.09, 0.085], metal(cDarkMetal))
        part(.bell,    torso, [ 0.13, -0.075, 0.30], [0.085, 0.09, 0.085], metal(cDarkMetal))
        
        // Status LED (slow blink) + antenna
        let ledOn: Float = fmod(clock, 2.0) < 1.7 ? 1 : 0.15
        part(.sphere,  torso, [0.17, 0.52, 0.385], [0.022, 0.022, 0.022], emissive(SIMD3<Float>(0.2, 1.0, 0.45) * ledOn))
        part(.capsule, torso, [0.16, 0.73, 0.30], [0.012, 0.24, 0.012], metal(cMetal))
        part(.sphere,  torso, [0.16, 0.855, 0.30], [0.022, 0.022, 0.022],
             emissive(SIMD3<Float>(1.0, 0.25, 0.18) * (fmod(clock, 1.2) < 0.15 ? 1.0 : 0.2)))
        
        // Jetpack plume
        if fl > 0.05 {
            let L = (0.22 + 0.14 * fl) * jetFlicker * fl
            let plume = SIMD3<Float>(0.55, 0.78, 1.0) * (0.8 + 0.4 * fl)
            part(.capsule, torso, [-0.13, -0.12 - L * 0.5, 0.30], [0.065, L, 0.065], emissive(plume))
            part(.capsule, torso, [ 0.13, -0.12 - L * 0.5, 0.30], [0.065, L, 0.065], emissive(plume))
            part(.sphere,  torso, [-0.13, -0.125, 0.30], [0.07, 0.04, 0.07], emissive(SIMD3<Float>(1.0, 0.95, 0.85)))
            part(.sphere,  torso, [ 0.13, -0.125, 0.30], [0.07, 0.04, 0.07], emissive(SIMD3<Float>(1.0, 0.95, 0.85)))
        }
        
        // ===================== HELMET =====================
        let helmetC = SIMD3<Float>(0, 0.20, 0.0)
        let helmetD: Float = 0.40
        let visorD: Float = helmetD * 1.045
        part(.sphere,   head, helmetC, [helmetD, helmetD, helmetD], shell(cShell))
        part(.visorCap, head, helmetC, [visorD, visorD, visorD], SIMD4<Float>(cVisorGold, 8.0))
        // Visor rim — placed exactly on the cap edge
        let α = CharacterMeshLibrary.visorHalfAngle
        let rimR = 0.5 * sin(α) * visorD
        let rimZ = -0.5 * cos(α) * visorD
        let rimS = rimR / 0.46
        part(.ring, head, helmetC + SIMD3<Float>(0, 0, rimZ), [rimS, rimS * 1.2, rimS], shell(cShellGray), rot: RX(.pi / 2))
        // Visor hinge pivots
        part(.cylinder, head, helmetC + SIMD3<Float>(-0.205, 0.0, 0.0), [0.05, 0.02, 0.05], metal(cMetal), rot: RZ(.pi / 2))
        part(.cylinder, head, helmetC + SIMD3<Float>( 0.205, 0.0, 0.0), [0.05, 0.02, 0.05], metal(cMetal), rot: RZ(.pi / 2))
        // Helmet lights & camera (HECA)
        for side: Float in [-1, 1] {
            part(.hardBox, head, helmetC + SIMD3<Float>(side * 0.205, 0.06, 0.0), [0.045, 0.07, 0.15], shell(cShellGray))
            part(.hardBox, head, helmetC + SIMD3<Float>(side * 0.205, 0.06, -0.076), [0.034, 0.05, 0.008],
                 emissive(SIMD3<Float>(1.0, 0.94, 0.82)))
        }
        part(.cylinder, head, helmetC + SIMD3<Float>(-0.205, 0.115, -0.03), [0.03, 0.06, 0.03], metal(cDarkMetal), rot: RX(.pi / 2))
        // Top ridge
        part(.hardBox, head, helmetC + SIMD3<Float>(0, 0.195, 0.03), [0.05, 0.025, 0.20], shell(cShell), rot: RX(-0.12))
        
        // ===================== ARMS =====================
        for side: Float in [-1, 1] {
            let isLeft = side < 0
            let swing = isLeft ? lArm : rArm
            let elbowFlex = isLeft ? lElbow : rElbow
            
            let shoulder = torso * T(side * 0.265, 0.43, 0.02) * RZ(side * armOut) * RX(swing)
            part(.torus,   shoulder, [side * 0.035, 0, 0], [0.22, 0.32, 0.22], metal(cMetal), rot: RZ(.pi / 2))   // Scye bearing
            part(.sphere,  shoulder, [side * 0.01, -0.03, 0], [0.205, 0.20, 0.21], fabric(cSuit))                // Shoulder bulb
            part(.capsule, shoulder, [0, -0.17, 0], [0.14, 0.30, 0.145], fabric(cSuit))                         // Upper arm
            part(.capsule, shoulder, [0, -0.215, 0], [0.148, 0.045, 0.152], fabric(cRed))                        // Commander band
            if isLeft {
                // Mission patch
                part(.cylinder, shoulder, [-0.071, -0.11, 0], [0.075, 0.008, 0.075], shell(cBlue), rot: RZ(.pi / 2))
                part(.cylinder, shoulder, [-0.0745, -0.11, 0], [0.042, 0.006, 0.042], shell(cShell), rot: RZ(.pi / 2))
                part(.hardBox,  shoulder, [-0.077, -0.11, 0], [0.004, 0.008, 0.05], shell(cRed), rot: RX(0.5))
            } else {
                // Flag
                part(.hardBox, shoulder, [0.071, -0.11, 0], [0.008, 0.05, 0.08], shell(cRed))
                part(.hardBox, shoulder, [0.0745, -0.11, 0.0], [0.004, 0.012, 0.078], shell(cShell))
                part(.hardBox, shoulder, [0.0755, -0.096, -0.021], [0.004, 0.024, 0.036], shell(cBlue))
            }
            part(.torus,   shoulder, [0, -0.265, 0], [0.15, 0.22, 0.15], metal(cMetal))                          // Arm bearing
            
            let elbow = shoulder * T(0, -0.31, 0) * RX(elbowFlex)
            part(.capsule, elbow, [0, 0, 0], [0.13, 0.13, 0.135], rubber(cSuit, ribbed: true))                  // Elbow convolute
            part(.capsule, elbow, [0, -0.15, 0], [0.122, 0.26, 0.128], fabric(cSuit))                           // Forearm
            if isLeft {
                part(.softBox, elbow, [0, -0.13, -0.065], [0.08, 0.10, 0.02], fabric(cSuitShade))                // Cuff checklist
            }
            part(.torus,   elbow, [0, -0.285, 0], [0.135, 0.30, 0.135], metal(cMetal))                           // Wrist bearing
            part(.torus,   elbow, [0, -0.305, 0], [0.125, 0.22, 0.125], shell(isLeft ? cBlue : cRed))            // Colour-coded disconnect
            
            let wrist = elbow * T(0, -0.33, 0) * RX(0.08 + 0.1 * sp) * RZ(-side * 0.06)
            part(.capsule, wrist, [0, 0.0, 0], [0.105, 0.07, 0.105], fabric(cGlove))                             // Gauntlet
            part(.softBox, wrist, [0, -0.08, -0.005], [0.055, 0.11, 0.095], fabric(cGlove))                      // Hand
            part(.softBox, wrist, [-side * 0.026, -0.085, -0.005], [0.012, 0.085, 0.08], rubber(cRubber))        // Palm grip
            let knuckle = wrist * T(0, -0.13, -0.005) * RZ(-side * (0.35 + 0.3 * sp))
            part(.capsule, knuckle, [0, -0.04, 0], [0.045, 0.09, 0.088], fabric(cGlove))                         // Finger block
            part(.capsule, knuckle, [-side * 0.016, -0.045, 0], [0.018, 0.075, 0.08], rubber(cRubber))           // Fingertip grip
            part(.capsule, wrist, [-side * 0.02, -0.07, -0.05], [0.03, 0.07, 0.03], fabric(cGlove),
                 rot: RX(0.55) * RZ(-side * 0.35))                                                               // Thumb
        }
        
        // ===================== LEGS =====================
        for side: Float in [-1, 1] {
            let isLeft = side < 0
            let hipPitch = isLeft ? lHip : rHip
            let kneeFlex = isLeft ? lKnee : rKnee
            let anklePitch = isLeft ? lAnkle : rAnkle
            
            let hip = pelvis * T(side * 0.11, -0.02, 0.0) * RZ(side * 0.035) * RX(hipPitch)
            part(.torus,   hip, [0, 0.0, 0], [0.20, 0.30, 0.20], metal(cMetal))                                  // Hip bearing
            part(.capsule, hip, [0, -0.215, 0], [0.18, 0.42, 0.185], fabric(cSuit, dust: 0.18))                  // Thigh
            part(.capsule, hip, [0, -0.15, 0], [0.188, 0.05, 0.193], fabric(cRed, dust: 0.15))                   // Commander band
            part(.softBox, hip, [side * 0.092, -0.24, 0.0], [0.035, 0.13, 0.11], fabric(cSuitShade, dust: 0.2)) // Cargo pocket
            part(.torus,   hip, [0, -0.40, 0], [0.18, 0.24, 0.18], metal(cMetal))                                // Thigh bearing
            
            let knee = hip * T(0, -0.44, 0) * RX(-kneeFlex)
            part(.capsule, knee, [0, 0.0, 0], [0.165, 0.15, 0.17], rubber(SIMD3<Float>(0.80, 0.80, 0.77), ribbed: true)) // Knee convolute
            part(.softBox, knee, [0, 0.005, -0.075], [0.12, 0.13, 0.05], shell(cShell, dust: 0.45))              // Knee guard
            part(.capsule, knee, [0, -0.21, 0], [0.155, 0.40, 0.165], fabric(cSuit, dust: 0.5))                  // Shin
            part(.softBox, knee, [0, -0.17, -0.075], [0.09, 0.20, 0.03], shell(cShell, dust: 0.55))              // Shin plate
            
            let ankle = knee * T(0, -0.43, 0) * RX(anklePitch)
            part(.torus,   ankle, [0, 0.055, 0], [0.16, 0.30, 0.16], metal(cMetal))                              // Ankle bearing
            part(.softBox, ankle, [0, -0.015, -0.02], [0.155, 0.15, 0.21], shell(cShell, dust: 0.8))             // Boot upper
            part(.softBox, ankle, [0, -0.055, -0.125], [0.145, 0.085, 0.13], shell(cShell, dust: 0.85))          // Toe box
            part(.hardBox, ankle, [0, -0.012, -0.12], [0.11, 0.02, 0.06], shell(cShellGray, dust: 0.6))          // Lacing / strap
            part(.hardBox, ankle, [0, -0.095, -0.045], [0.165, 0.042, 0.33], rubber(cRubber, ribbed: true))      // Treaded sole
            part(.hardBox, ankle, [0, -0.07, 0.085], [0.14, 0.04, 0.07], rubber(cRubber))                        // Heel counter
        }
    }
}
