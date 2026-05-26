//
//  FactLibrary.swift
//  COSMIC NOMAD: ECHOES
//
//  Loads and manages a large database of real space facts from a JSON file.
//

import Foundation

struct SpaceFact: Codable {
    let id: Int
    let title: String
    let fact: String
    let mood: String
}

final class FactLibrary {
    
    static let shared = FactLibrary()
    
    private(set) var facts: [SpaceFact] = []
    
    // Hardcoded fallback facts in case JSON fails to load
    private let fallbackFacts: [SpaceFact] = [
        SpaceFact(id: 9001, title: "Voyager 1", fact: "Launched in 1977, Voyager 1 is the most distant human-made object, over 24 billion km from Earth.", mood: "lonely"),
        SpaceFact(id: 9002, title: "Neutron Stars", fact: "A neutron star packs the mass of our Sun into a sphere just 20 km across.", mood: "surreal"),
        SpaceFact(id: 9003, title: "The Overview Effect", fact: "Astronauts who see Earth from space often experience a profound cognitive shift regarding our planet's fragility.", mood: "serene")
    ]
    
    private init() {
        loadFacts()
    }
    
    private func loadFacts() {
        // Try to load from bundle first, or documents directory if it was generated there
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.url(forResource: "SpaceFacts", withExtension: "json")
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("SpaceFacts.json")
        
        // Let's try current working directory (for debug builds)
        let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("SpaceFacts.json")
        
        var targetURL: URL? = nil
        if let bURL = bundleURL, fileManager.fileExists(atPath: bURL.path) {
            targetURL = bURL
        } else if let dURL = docsURL, fileManager.fileExists(atPath: dURL.path) {
            targetURL = dURL
        } else if fileManager.fileExists(atPath: cwdURL.path) {
            targetURL = cwdURL
        }
        
        guard let url = targetURL else {
            print("⚠️ FactLibrary: SpaceFacts.json not found. Using fallbacks.")
            facts = fallbackFacts
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            facts = try decoder.decode([SpaceFact].self, from: data)
            print("📚 FactLibrary: Loaded \(facts.count) space facts successfully.")
        } catch {
            print("⚠️ FactLibrary: Failed to decode SpaceFacts.json: \(error). Using fallbacks.")
            facts = fallbackFacts
        }
    }
    
    /// Get a fact for a specific global index to ensure deterministic generation across planets
    func getFact(for index: Int) -> SpaceFact {
        if facts.isEmpty {
            return fallbackFacts[index % fallbackFacts.count]
        }
        return facts[index % facts.count]
    }
    
    /// Get a fact by its exact ID (used by Achievements UI)
    func getFact(by id: Int) -> SpaceFact? {
        return facts.first { $0.id == id } ?? fallbackFacts.first { $0.id == id }
    }
}
