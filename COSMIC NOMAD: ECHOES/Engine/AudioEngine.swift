//
//  AudioEngine.swift
//  COSMIC NOMAD: ECHOES
//
//  Plays a custom MP3 background track.
//

import AVFoundation
import Foundation

final class AudioEngine {
    
    private var bgMusicPlayer: AVAudioPlayer?
    
    init() {
        setupEngine()
    }
    
    private func setupEngine() {
        // Look for "background_music.mp3" in the app bundle
        if let url = Bundle.main.url(forResource: "background_music", withExtension: "mp3") {
            do {
                // Initialize the audio player
                bgMusicPlayer = try AVAudioPlayer(contentsOf: url)
                bgMusicPlayer?.numberOfLoops = -1 // Loop indefinitely (-1)
                
                // Set initial volume from settings
                bgMusicPlayer?.volume = SettingsManager.shared.masterVolume
                
                bgMusicPlayer?.prepareToPlay()
                bgMusicPlayer?.play()
                print("🎵 Playing custom MP3 background music")
            } catch {
                print("❌ Could not load background_music.mp3: \(error)")
            }
        } else {
            print("⚠️ background_music.mp3 not found in the project. Please add it to the Xcode project.")
        }
    }
    
    // MARK: - API
    
    func update(mood: PlanetMood, weatherIntensity: Float) {
        // Update volume based on user settings
        bgMusicPlayer?.volume = SettingsManager.shared.masterVolume
    }
    
    func setScannerState(active: Bool, progress: Float) {
        // Procedural SFX removed
    }
    
    func updateSurvivalAudio(isMoving: Bool, isSprinting: Bool, isJetpacking: Bool, oxygenLevel: Float) {
        // Procedural SFX removed
    }
}
