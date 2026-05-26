//
//  GameEngine.swift
//  COSMIC NOMAD: ECHOES
//
//  Main engine coordinator: owns all subsystems, runs the game loop,
//  manages lifecycle. This is the central nervous system of the game.
//

import Metal
import MetalKit
import simd

@MainActor
final class GameEngine: NSObject, MTKViewDelegate {
    
    // Core systems
    let renderer: MetalRenderer
    let camera: CameraSystem
    let inputManager: InputManager
    let audioEngine = AudioEngine()
    
    // World
    private(set) var world: WorldGenerator!
    
    // Gameplay
    let player: PlayerController
    let scanner: ScannerSystem
    let survivalSystem = SurvivalSystem()
    let hazardSystem = HazardSystem()
    let npcSystem = NPCSystem()
    
    // State
    private(set) var isRunning: Bool = false
    private(set) var isPaused: Bool = false
    
    // Planet seed
    var currentPlanetSeed: UInt64 = 42
    
    // Game Progression
    private(set) var planetsCompleted: Int = 0
    private(set) var isPlanetDecoded: Bool = false
    private(set) var showFinalRevelation: Bool = false
    static let totalPlanetsForEnding = 10
    
    // Debug info
    var showDebugInfo: Bool = true
    private(set) var fps: Int = 0
    private var fpsAccumulator: Float = 0
    private var fpsFrameCount: Int = 0
    
    // MARK: - Initialization
    
    init(device: MTLDevice) throws {
        self.renderer = try MetalRenderer(device: device)
        self.camera = CameraSystem()
        self.inputManager = InputManager()
        self.player = PlayerController()
        self.scanner = ScannerSystem()
        
        // Load progression
        self.planetsCompleted = SaveManager.shared.getPlanetsCompleted()
        self.currentPlanetSeed = SaveManager.shared.getPlanetSeed()
        
        super.init()
        
        // Apply upgrade bonuses to survival system
        applySurvivalUpgrades()
        
        // Wire up renderer
        renderer.camera = camera
        renderer.player = player
        
        // Scanner callback
        scanner.onScanComplete = { [weak self] result in
            self?.onScanCompleted(result)
        }
        
        // Survival blackout callback
        survivalSystem.onBlackout = { [weak self] in
            self?.player.teleportTo(SIMD3<Float>(32, 20, 32))
        }
        
        // Generate initial world
        world = WorldGenerator(device: device, seed: currentPlanetSeed, level: planetsCompleted + 1)
        renderer.world = world
        
        player.teleportTo(SIMD3<Float>(32, 20, 32))
        
        // Save the current planet seed in history for star chart navigation
        SaveManager.shared.savePlanetSeedForLevel(planetsCompleted, seed: currentPlanetSeed)
        
        // Generate hazards and NPCs for this planet
        let terrainH = world.heightAt(worldX: 32, worldZ: 32) ?? 0
        hazardSystem.generate(around: player.position, mood: world.planetConfig.mood, seed: currentPlanetSeed)
        npcSystem.generate(around: player.position, mood: world.planetConfig.mood, terrainHeight: terrainH, seed: currentPlanetSeed)
        
        // Initialize NPC renderer
        renderer.npcRenderer = NPCRenderer(device: device)
        
        isRunning = true
        print("🎮 GameEngine: Initialized and running")
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let width = Int(size.width)
        let height = Int(size.height)
        
        renderer.resize(width: width, height: height)
        camera.aspectRatio = Float(size.width) / Float(size.height)
    }
    
    func draw(in view: MTKView) {
        guard isRunning && !isPaused else { return }
        
        let deltaTime = renderer.deltaTime
        let totalTime = renderer.totalTime
        
        // --- Game Logic Update ---
        
        // 1. Input processing
        inputManager.update(deltaTime: deltaTime)
        let input = inputManager.state
        
        // 2. Player update (pass suit power for sprint/jetpack checks)
        player.update(
            input: input,
            world: world,
            npcSystem: npcSystem,
            camera: camera,
            deltaTime: deltaTime,
            suitPower: survivalSystem.suitPower
        )
        
        // 3. Weather modifies player speed
        player.weatherSpeedModifier = world.weatherSystem.visibility * 0.5 + 0.5
        
        // 3.5. Proximity-based signal discovery
        checkProximityDiscovery()
        
        // 3.55. Anomaly proximity effects
        let anomalyEffect = world.anomalySystem.checkProximity(playerPosition: player.position)
        if anomalyEffect.oxygenDrain > 0 {
            survivalSystem.refillOxygen(amount: -anomalyEffect.oxygenDrain * deltaTime)
        }
        if anomalyEffect.powerDrain > 0 {
            survivalSystem.refillPower(amount: -anomalyEffect.powerDrain * deltaTime)
        }
        if anomalyEffect.speedMultiplier < 1.0 {
            player.weatherSpeedModifier *= anomalyEffect.speedMultiplier
        }
        if anomalyEffect.dataCoreReward > 0 {
            UpgradeSystem.shared.awardDataCores(anomalyEffect.dataCoreReward)
        }
        
        // 3.6. Survival system update
        survivalSystem.update(
            deltaTime: deltaTime,
            mood: world.planetConfig.mood,
            weatherType: world.weatherSystem.currentWeather,
            weatherIntensity: world.weatherSystem.windStrength,
            isMoving: player.isMoving,
            isSprinting: player.isSprinting,
            isJetpacking: player.isJetpacking,
            isScanning: scanner.isScanning
        )
        
        // 3.7. Hazard system
        hazardSystem.update(playerPosition: player.position, survival: survivalSystem, deltaTime: deltaTime)
        
        // 3.8. NPC system
        npcSystem.update(deltaTime: deltaTime, time: totalTime, playerPosition: player.position)
        
        // 3.9. NPC collision damage
        let _ = npcSystem.checkCollision(
            playerPosition: player.position,
            survival: survivalSystem,
            deltaTime: deltaTime
        )
        
        // 4. Scanner
        scanner.update(
            isPressed: input.isScanningPressed,
            inputProgress: input.scanProgress,
            playerPosition: player.position,
            cameraForward: camera.forward,
            world: world,
            deltaTime: deltaTime
        )
        
        // 5. Camera follows player
        let terrainHeight = world.heightAt(worldX: camera.position.x, worldZ: camera.position.z)
        camera.update(
            player: player,
            terrainHeight: terrainHeight,
            deltaTime: deltaTime,
            totalTime: totalTime
        )
        
        // 6. World update
        world.update(
            playerPosition: player.position,
            cameraFrustum: camera.frustum(),
            deltaTime: deltaTime,
            totalTime: totalTime
        )
        
        // --- Prepare Render Data ---
        
        var frameUniforms = FrameUniforms()
        frameUniforms.sunDirection = world.sunDirection
        frameUniforms.sunColor = world.sunColor
        frameUniforms.sunIntensity = world.sunIntensity
        frameUniforms.fogDensity = world.atmosphereParams.fogDensityBase
        renderer.setAtmosphereParams(world.atmosphereParams)
        
        switch world.weatherSystem.currentWeather {
        case .alienRain: renderer.currentWeatherType = 1.0
        case .electricStorm: renderer.currentWeatherType = 2.0
        default: renderer.currentWeatherType = 0.0
        }
        
        // Pass NPC data to renderer
        renderer.npcCreatures = npcSystem.creatures
        
        var pp = PostProcessParams()
        pp.filmGrainIntensity = 0.035
        pp.vignetteIntensity = 0.35
        pp.bloomIntensity = 0.12
        pp.chromaticAberrationIntensity = 0.001
        pp.dofFocusDistance = length(camera.target - camera.position)
        pp.dofFocusRange = 40
        
        // Update Audio
        audioEngine.update(
            mood: world.planetConfig.mood,
            weatherIntensity: world.weatherSystem.windStrength
        )
        audioEngine.setScannerState(
            active: scanner.isScanning,
            progress: scanner.scanProgress
        )
        // Update audio with survival state
        audioEngine.updateSurvivalAudio(
            isMoving: player.isMoving,
            isSprinting: player.isSprinting,
            isJetpacking: player.isJetpacking,
            oxygenLevel: survivalSystem.oxygen / survivalSystem.maxOxygen
        )
        
        // Adjust post-processing based on planet mood
        switch world.planetConfig.mood {
        case .lonely:
            pp.saturation = 0.85
            pp.contrast = 1.1
            pp.temperature = -0.1
        case .decayed:
            pp.saturation = 0.9
            pp.contrast = 1.15
            pp.temperature = 0.15
            pp.filmGrainIntensity = 0.05
        case .serene:
            pp.saturation = 1.1
            pp.contrast = 1.0
            pp.bloomIntensity = 0.18
        case .hostile:
            pp.saturation = 1.2
            pp.contrast = 1.25
            pp.temperature = 0.2
            pp.vignetteIntensity = 0.5
        case .surreal:
            pp.saturation = 1.3
            pp.contrast = 1.05
            pp.chromaticAberrationIntensity = 0.003
            pp.bloomIntensity = 0.2
        }
        
        // Low oxygen visual effect
        if survivalSystem.oxygen < 30 {
            let intensity = 1.0 - (survivalSystem.oxygen / 30.0)
            pp.vignetteIntensity += intensity * 0.4
            pp.saturation -= intensity * 0.3
            pp.chromaticAberrationIntensity += intensity * 0.005
        }
        
        renderer.setPostProcessParams(pp)
        
        renderer.terrainChunks = world.readyChunks
        renderer.terrainParamsList = world.terrainParams
        
        // --- Render ---
        renderer.renderFrame(in: view)
        
        // --- FPS Counter ---
        fpsAccumulator += deltaTime
        fpsFrameCount += 1
        if fpsAccumulator >= 1.0 {
            fps = fpsFrameCount
            fpsFrameCount = 0
            fpsAccumulator = 0
        }
        
        inputManager.clearDeltas()
    }
    
    // MARK: - Proximity Discovery
    
    private let discoveryRadius: Float = 8.0
    private(set) var lastDiscoveredFragment: MemoryFragment? = nil
    
    func clearLastDiscovery() {
        lastDiscoveredFragment = nil
    }
    
    private func checkProximityDiscovery() {
        let playerPos = player.position
        let upgradeBonus = UpgradeSystem.shared.scannerRangeBonus
        let effectiveRadius = discoveryRadius + upgradeBonus
        
        for frag in world.memoryFragmentSystem.fragments {
            guard !frag.isDiscovered else { continue }
            
            let dx = frag.worldPosition.x - playerPos.x
            let dz = frag.worldPosition.z - playerPos.z
            let dist = sqrt(dx * dx + dz * dz)
            
            if dist < effectiveRadius {
                world.memoryFragmentSystem.markDiscovered(id: frag.id)
                lastDiscoveredFragment = frag
                
                camera.focusOnDiscovery(at: frag.worldPosition)
                
                // Award Data Cores
                UpgradeSystem.shared.awardDataCores(1)
                
                // Refill some oxygen as reward
                survivalSystem.refillOxygen(amount: 15)
                
                // Save to Codex
                SaveManager.shared.addCodexFragment(
                    planetName: world.planetConfig.name,
                    title: frag.title,
                    content: frag.content,
                    type: frag.fragmentType.rawValue
                )
                
                print("📡 Signal Discovered: \(frag.fragmentType.rawValue) — \(frag.title) (+1 Data Core)")
                
                if world.memoryFragmentSystem.allDiscovered && !isPlanetDecoded {
                    isPlanetDecoded = true
                    // Bonus data cores for completing a planet
                    UpgradeSystem.shared.awardDataCores(3)
                    print("🌍 PLANET DECODED: \(world.planetConfig.name) (+3 Bonus Data Cores)")
                }
                
                break
            }
        }
    }
    
    // MARK: - Planet Progression
    
    func advanceToNextPlanet() {
        planetsCompleted += 1
        isPlanetDecoded = false
        
        if planetsCompleted >= Self.totalPlanetsForEnding {
            showFinalRevelation = true
            print("🌌 FINAL REVELATION UNLOCKED")
        } else {
            currentPlanetSeed &+= 1
            SaveManager.shared.savePlanetsCompleted(planetsCompleted)
            SaveManager.shared.savePlanetSeed(currentPlanetSeed)
            SaveManager.shared.savePlanetSeedForLevel(planetsCompleted, seed: currentPlanetSeed)
            
            world = WorldGenerator(device: renderer.device, seed: currentPlanetSeed, level: planetsCompleted + 1)
            renderer.world = world
            player.teleportTo(SIMD3<Float>(32, 20, 32))
            survivalSystem.reset()
            applySurvivalUpgrades()
            
            // Regenerate NPCs and hazards for new planet
            let terrainH = world.heightAt(worldX: 32, worldZ: 32) ?? 0
            hazardSystem.generate(around: player.position, mood: world.planetConfig.mood, seed: currentPlanetSeed)
            npcSystem.generate(around: player.position, mood: world.planetConfig.mood, terrainHeight: terrainH, seed: currentPlanetSeed)
            
            print("🚀 Traveling to planet \(planetsCompleted + 1)/\(Self.totalPlanetsForEnding): \(world.planetConfig.name)")
        }
    }
    
    func resetJourney() {
        showFinalRevelation = false
        planetsCompleted = 0
        currentPlanetSeed = 42
        
        SaveManager.shared.resetProgress()
        UpgradeSystem.shared.reset()
        
        world = WorldGenerator(device: renderer.device, seed: currentPlanetSeed, level: 1)
        renderer.world = world
        player.teleportTo(SIMD3<Float>(32, 20, 32))
        survivalSystem.reset()
        applySurvivalUpgrades()
        
        // Regenerate NPCs and hazards
        let terrainH = world.heightAt(worldX: 32, worldZ: 32) ?? 0
        hazardSystem.generate(around: player.position, mood: world.planetConfig.mood, seed: currentPlanetSeed)
        npcSystem.generate(around: player.position, mood: world.planetConfig.mood, terrainHeight: terrainH, seed: currentPlanetSeed)
    }
    
    // MARK: - Upgrade Application
    
    func applySurvivalUpgrades() {
        survivalSystem.maxOxygen = 100 + UpgradeSystem.shared.oxygenCapacityBonus
        survivalSystem.maxSuitPower = 100 + UpgradeSystem.shared.suitPowerCapacityBonus
        survivalSystem.jetpackFuelBonus = UpgradeSystem.shared.jetpackFuelBonus
    }
    
    // MARK: - Scan Callback
    
    private func onScanCompleted(_ result: ScanResult) {
        print("📡 Scan Complete: \(result.objectType)")
        for (i, interp) in result.interpretations.enumerated() {
            print("   [\(i+1)] \(interp)")
        }
        
        camera.focusOnDiscovery(at: result.worldPosition)
    }
    
    // MARK: - Planet Navigation
    
    func visitNextPlanet() {
        currentPlanetSeed &+= 1
        world = WorldGenerator(device: renderer.device, seed: currentPlanetSeed, level: planetsCompleted + 1)
        renderer.world = world
        player.teleportTo(SIMD3<Float>(32, 20, 32))
        survivalSystem.reset()
        applySurvivalUpgrades()
        
        // Regenerate NPCs and hazards
        let terrainH = world.heightAt(worldX: 32, worldZ: 32) ?? 0
        hazardSystem.generate(around: player.position, mood: world.planetConfig.mood, seed: currentPlanetSeed)
        npcSystem.generate(around: player.position, mood: world.planetConfig.mood, terrainHeight: terrainH, seed: currentPlanetSeed)
        
        print("🚀 Traveling to planet: \(world.planetConfig.name)")
    }
    
    func visitPlanet(seed: UInt64) {
        currentPlanetSeed = seed
        world = WorldGenerator(device: renderer.device, seed: seed, level: planetsCompleted + 1)
        renderer.world = world
        player.teleportTo(SIMD3<Float>(32, 20, 32))
        survivalSystem.reset()
        applySurvivalUpgrades()
        
        // Regenerate NPCs and hazards
        let terrainH = world.heightAt(worldX: 32, worldZ: 32) ?? 0
        hazardSystem.generate(around: player.position, mood: world.planetConfig.mood, seed: seed)
        npcSystem.generate(around: player.position, mood: world.planetConfig.mood, terrainHeight: terrainH, seed: seed)
    }
    
    // MARK: - Lifecycle
    
    func pause() {
        isPaused = true
    }
    
    func resume() {
        isPaused = false
    }
}

