//
//  MemoryFragment.swift
//  COSMIC NOMAD: ECHOES
//
//  Interactive narrative objects scattered throughout the world.
//  Each planet has unique lore tied to its mood.
//

import simd
import Foundation

struct MemoryFragment: Identifiable {
    let id: UUID
    let worldPosition: SIMD3<Float>
    let factId: Int
    let title: String
    let content: String
    let fragmentType: FragmentType
    var isDiscovered: Bool
    let isLegendary: Bool  // 5% chance — golden glow, 5× Data Cores
    
    enum FragmentType: String {
        case precursorLog = "Precursor Log"
        case explorerEcho = "Explorer Echo"
        case anomalyData = "Anomaly Data"
    }
}

@MainActor
final class MemoryFragmentSystem {
    
    private(set) var fragments: [MemoryFragment] = []
    private(set) var discoveredCount: Int = 0
    
    /// Whether all fragments on this planet have been found
    var allDiscovered: Bool {
        discoveredCount >= fragments.count && !fragments.isEmpty
    }
    
    // Generate fragments based on seed and level
    func generate(seed: UInt64, planetName: String, mood: PlanetMood, level: Int, restoredFactIds: [Int]? = nil) {
        fragments.removeAll()
        discoveredCount = 0
        
        var rng = SeededRNG(seed: seed &+ 0x998877)
        
        // Scatter fragments in rings around the player spawn (32, 32)
        let spawnX: Float = 32.0
        let spawnZ: Float = 32.0
        
        // Signal count scales with level (L1=20, L2=25, L10=65)
        let signalCount = 15 + (level * 5)
        
        // Scale maximum radius by level (L1=250m, L10=1000m)
        let maxRadius: Float = 250.0 + Float(level - 1) * 80.0
        
        // Calculate a stable global index offset for this planet
        // e.g., Planet 1 uses facts 0-19, Planet 2 uses facts 20-44, etc.
        var globalIndexOffset = 0
        for l in 1..<level {
            globalIndexOffset += 15 + (l * 5)
        }
        
        for i in 0..<signalCount {
            // First 5 signals are relatively close
            let radius: Float = i < 5 ? rng.nextFloatRange(20, 60) : rng.nextFloatRange(60, maxRadius)
            let angle = rng.nextFloatRange(0, .pi * 2)
            let x = spawnX + cos(angle) * radius
            let z = spawnZ + sin(angle) * radius
            
            let types: [MemoryFragment.FragmentType] = [.precursorLog, .explorerEcho, .anomalyData]
            let type = types[Int(rng.nextFloatRange(0, 2.99))]
            
            let fact = FactLibrary.shared.getFact(for: globalIndexOffset + i)
            
            // Check if this fragment was already discovered in a previous session
            let isAlreadyDiscovered = restoredFactIds?.contains(fact.id) ?? false
            
            let fragment = MemoryFragment(
                id: UUID(),
                worldPosition: SIMD3<Float>(x, 0, z),
                factId: fact.id,
                title: fact.title,
                content: fact.fact,
                fragmentType: type,
                isDiscovered: isAlreadyDiscovered,
                isLegendary: rng.nextFloatRange(0, 1.0) < 0.05  // 5% legendary chance
            )
            
            fragments.append(fragment)
            
            if isAlreadyDiscovered {
                discoveredCount += 1
            }
        }
    }
    
    func markDiscovered(id: UUID) {
        if let index = fragments.firstIndex(where: { $0.id == id }) {
            fragments[index].isDiscovered = true
            discoveredCount += 1
            
            // Save to achievements
            SaveManager.shared.addDiscoveredFact(id: fragments[index].factId)
        }
    }
}

// MARK: - Lore Library

struct LoreEntry {
    let title: String
    let text: String
}

enum LoreLibrary {
    
    /// The final revelation text when ALL 5 planets are completed
    static let finalRevelation = """
    You have walked five worlds and gathered every signal left behind. \
    From Voyager's golden record to the bootprints on the Moon, from Hubble's deepest gaze \
    to the rovers tracing ancient riverbeds on Mars — humanity's reach into the cosmos \
    is the greatest story ever told. We explore not because it is easy, but because \
    every discovery reminds us: we are the universe knowing itself.
    """
    
    static func planetSummary(for mood: PlanetMood) -> String {
        switch mood {
        case .lonely:
            return "Signals from the edge of the solar system. Probes launched decades ago still whisper across billions of kilometers — the loneliest machines ever built, carrying humanity's hope into the void."
        case .decayed:
            return "Remnants of the early space age. Abandoned stations, decommissioned rockets, and the pioneering missions that opened the heavens — now fading into history, but never forgotten."
        case .serene:
            return "The view from above changes everything. Astronauts who see Earth from space report a profound shift in awareness — the Overview Effect — a deep understanding of our planet's fragility and beauty."
        case .hostile:
            return "Space does not forgive mistakes. From explosive launch failures to life-threatening malfunctions in orbit, these are the missions where courage and ingenuity meant the difference between life and death."
        case .surreal:
            return "The universe is stranger than fiction. Black holes that warp time, neutron stars denser than imagination, and quantum phenomena that defy common sense — reality at cosmic scales is deeply, beautifully weird."
        }
    }
    
    /// Unique summary for each planet level (1-indexed)
    static func planetSummary(forLevel level: Int) -> String {
        switch level {
        case 1:
            return "Your first steps beyond Earth's cradle. Every explorer begins with a single signal — and you've proven yourself worthy. The ancient transmissions on this world spoke of humanity's earliest dreams of reaching the stars."
        case 2:
            return "A world of whispered echoes. The signals here told stories of perseverance against impossible odds — of missions that failed and were rebuilt, of astronauts who trained for decades for minutes of glory."
        case 3:
            return "This planet held memories of the universe's grand architecture. From spiral galaxies spinning across millions of light-years to the delicate filaments of the cosmic web, you've glimpsed the blueprint of everything."
        case 4:
            return "In the harshest conditions, the strongest discoveries are made. The signals on this world revealed the violent beauty of supernovae, the crushing power of neutron stars, and the relentless fury of cosmic storms."
        case 5:
            return "Halfway through your journey, and the universe has begun to feel less like a void and more like a home. This world's echoes spoke of the thin line between Earth and space — and how fragile that boundary truly is."
        case 6:
            return "The deeper you travel, the stranger reality becomes. This planet's transmissions carried tales of quantum entanglement, time dilation, and particles that exist in two places at once — the universe defying its own rules."
        case 7:
            return "Seven worlds decoded. The signals here mourned the missions that never returned — the probes lost to the void, the brave souls who gave everything. Their sacrifice echoes louder than any transmission."
        case 8:
            return "This world hummed with the frequency of life itself. Its signals spoke of extremophiles thriving in boiling vents, of amino acids found on asteroids, and the tantalizing possibility that we are not alone."
        case 9:
            return "Nearly at the end of your journey. This planet's echoes carried visions of humanity's future — of cities on Mars, of generation ships sailing between stars, of a species that refused to remain on just one world."
        case 10:
            return "The final echoes have been gathered. Across ten worlds, you've reconstructed a story written in starlight — a story of curiosity, courage, and the unbreakable human need to know what lies beyond the horizon."
        default:
            return "Signals decoded. Another world's secrets have been unveiled."
        }
    }
    
    /// Unique inspirational quote for each planet level (1-indexed)
    static func planetQuote(forLevel level: Int) -> (quote: String, author: String) {
        switch level {
        case 1:
            return ("\"The Earth is the cradle of humanity, but mankind cannot stay in the cradle forever.\"", "— Konstantin Tsiolkovsky")
        case 2:
            return ("\"That's one small step for man, one giant leap for mankind.\"", "— Neil Armstrong")
        case 3:
            return ("\"Somewhere, something incredible is waiting to be known.\"", "— Carl Sagan")
        case 4:
            return ("\"The cosmos is within us. We are made of star-stuff. We are a way for the universe to know itself.\"", "— Carl Sagan")
        case 5:
            return ("\"I know the sky is not the limit, because there are footprints on the Moon.\"", "— Buzz Aldrin")
        case 6:
            return ("\"The universe is under no obligation to make sense to you.\"", "— Neil deGrasse Tyson")
        case 7:
            return ("\"For all its material advantages, the sedentary life has left us edgy, unfulfilled. Even after 400 generations in villages and cities, we haven't forgotten. The open road still softly calls.\"", "— Carl Sagan")
        case 8:
            return ("\"Two possibilities exist: either we are alone in the Universe or we are not. Both are equally terrifying.\"", "— Arthur C. Clarke")
        case 9:
            return ("\"The dinosaurs became extinct because they didn't have a space program. And if we become extinct because we don't have a space program, it'll serve us right.\"", "— Larry Niven")
        case 10:
            return ("\"Look again at that dot. That's here. That's home. That's us. On it everyone you love, everyone you know, everyone you ever heard of, every human being who ever was, lived out their lives.\"", "— Carl Sagan")
        default:
            return ("\"Per aspera ad astra — through hardships to the stars.\"", "— Ancient proverb")
        }
    }
    
    static func lore(for mood: PlanetMood) -> [LoreEntry] {
        switch mood {
        case .lonely:
            return [
                LoreEntry(title: "Voyager 1: Farthest Object", text: "Launched in 1977, Voyager 1 is now over 24 billion km from Earth — the most distant human-made object. It still sends data, though each signal takes over 22 hours to arrive."),
                LoreEntry(title: "The Golden Record", text: "Both Voyager probes carry a gold-plated record with sounds and images of Earth: whale songs, a baby's cry, greetings in 55 languages, and music from Bach to Chuck Berry."),
                LoreEntry(title: "Pale Blue Dot", text: "On Feb 14, 1990, Voyager 1 turned its camera back toward Earth from 6 billion km away, capturing our planet as a tiny speck — a 'pale blue dot' in a sunbeam. Carl Sagan called it 'the only home we've ever known.'"),
                LoreEntry(title: "Pioneer 10's Silence", text: "Pioneer 10, launched in 1972, was the first spacecraft to cross the asteroid belt and fly past Jupiter. NASA received its last, faint signal on January 23, 2003. It is now heading toward the star Aldebaran."),
                LoreEntry(title: "New Horizons at Pluto", text: "In 2015, New Horizons flew past Pluto at 50,000 km/h after a 9.5-year journey, revealing heart-shaped nitrogen glaciers and mountains of water ice on a world once thought to be a dead rock."),
                LoreEntry(title: "Deep Space Network", text: "NASA's Deep Space Network uses three giant antenna complexes spaced around Earth — in California, Spain, and Australia — to maintain contact with spacecraft billions of kilometers away, 24 hours a day."),
                LoreEntry(title: "Opportunity's Last Message", text: "Mars rover Opportunity operated for 15 years instead of its planned 90 days. Its last transmission, during a global dust storm in 2018, essentially said: 'My battery is low and it's getting dark.'"),
                LoreEntry(title: "Voyager 2 in Interstellar Space", text: "In 2018, Voyager 2 crossed the heliopause — the boundary where the Sun's influence ends — becoming only the second human object to enter interstellar space. It's still transmitting."),
                LoreEntry(title: "The Wow! Signal", text: "On August 15, 1977, astronomer Jerry Ehman detected a 72-second radio signal from deep space that was so unusual he wrote 'Wow!' on the printout. Its origin has never been explained."),
                LoreEntry(title: "Cosmic Loneliness", text: "The nearest star system, Alpha Centauri, is 4.37 light-years away. Even at Voyager 1's speed of 61,000 km/h, it would take over 73,000 years to reach it."),
            ]
        case .decayed:
            return [
                LoreEntry(title: "Mir Space Station", text: "The Soviet/Russian space station Mir orbited Earth for 15 years (1986–2001). It survived a fire, a collision, and political upheaval before being deliberately deorbited, burning up over the Pacific Ocean."),
                LoreEntry(title: "First Human in Space", text: "On April 12, 1961, Yuri Gagarin became the first human in space aboard Vostok 1. His flight lasted 108 minutes. He ejected from the capsule at 7 km altitude and parachuted to a farm field."),
                LoreEntry(title: "Saturn V: Never Surpassed", text: "The Saturn V rocket, which sent astronauts to the Moon, remains the most powerful rocket ever successfully flown. Standing 111 meters tall, it generated 7.5 million pounds of thrust at liftoff."),
                LoreEntry(title: "Skylab's Fall", text: "America's first space station, Skylab, reentered Earth's atmosphere in 1979, scattering debris across Western Australia. The local shire of Esperance fined NASA $400 for littering. It was paid in 2009."),
                LoreEntry(title: "Laika the Space Dog", text: "In 1957, a stray dog named Laika became the first animal to orbit Earth aboard Sputnik 2. She did not survive the mission. In 2008, Russia unveiled a monument to her near the research facility where she trained."),
                LoreEntry(title: "Space Shuttle Columbia", text: "On February 1, 2003, Space Shuttle Columbia broke apart during reentry, killing all seven crew members. A piece of insulation foam had damaged the heat shield during launch 16 days earlier."),
                LoreEntry(title: "Hubble's Flawed Mirror", text: "When the Hubble Space Telescope launched in 1990, its primary mirror had been ground to the wrong shape — off by 2.2 micrometers. Astronauts installed corrective optics in 1993, and Hubble became legendary."),
                LoreEntry(title: "The First Spacewalk", text: "On March 18, 1965, Alexei Leonov became the first human to walk in space. His suit inflated so much he couldn't fit back through the airlock. He had to bleed off pressure, risking decompression sickness, to squeeze back in."),
                LoreEntry(title: "Apollo 1 Tragedy", text: "On January 27, 1967, astronauts Gus Grissom, Ed White, and Roger Chaffee died in a fire during a launch pad test. The tragedy led to major safety redesigns that ultimately made the Moon landings possible."),
                LoreEntry(title: "Buran: The Soviet Shuttle", text: "The Soviet space shuttle Buran flew only once — an unmanned orbital flight in 1988. It landed automatically with a crosswind correction that surprised engineers. The program was canceled after the USSR dissolved."),
            ]
        case .serene:
            return [
                LoreEntry(title: "The Overview Effect", text: "Astronauts who see Earth from space often experience a profound cognitive shift called the 'Overview Effect' — a deep sense of the planet's fragility, the artificiality of borders, and the unity of all life."),
                LoreEntry(title: "Earthrise", text: "On December 24, 1968, Apollo 8 astronaut William Anders took the iconic 'Earthrise' photo — Earth rising above the lunar horizon. It's credited with inspiring the environmental movement."),
                LoreEntry(title: "ISS Sunrises", text: "Astronauts on the International Space Station witness 16 sunrises and sunsets every 24 hours as they orbit Earth at 28,000 km/h. The station completes one full orbit every 92 minutes."),
                LoreEntry(title: "Chris Hadfield's Guitar", text: "Canadian astronaut Chris Hadfield recorded David Bowie's 'Space Oddity' aboard the ISS in 2013 — the first music video filmed in space. Bowie called it 'the most poignant version of the song ever.'"),
                LoreEntry(title: "Blue Marble", text: "The famous 'Blue Marble' photo of Earth was taken by Apollo 17 crew in 1972. It was one of the first clear images of a fully illuminated Earth and became one of the most reproduced photographs in history."),
                LoreEntry(title: "Floating Water in Space", text: "In microgravity, water forms perfect spheres due to surface tension. Astronauts on the ISS have filmed dissolving effervescent tablets inside floating water balls — creating mesmerizing, fizzing orbs."),
                LoreEntry(title: "Growing Plants in Space", text: "In 2015, ISS astronauts ate the first food grown in space — red romaine lettuce. NASA's 'Veggie' experiment proved plants could grow in microgravity, a key step toward long-duration missions."),
                LoreEntry(title: "Spacewalk Serenity", text: "Astronaut Mike Massimino described his first spacewalk: 'I looked down and saw the Earth — it was overwhelmingly beautiful. I thought, if you could be in heaven, this is what it would look like.'"),
                LoreEntry(title: "Northern Lights from Above", text: "From the ISS, astronauts can look DOWN at the aurora borealis. The glowing curtains of green and purple light drape across the atmosphere like a luminous veil over the dark planet below."),
                LoreEntry(title: "The Thin Blue Line", text: "From space, Earth's atmosphere appears as an impossibly thin, fragile blue line at the planet's edge. Astronaut Ron Garan said: 'It looked like an onion skin — and that's all that protects every living thing.'"),
            ]
        case .hostile:
            return [
                LoreEntry(title: "Apollo 13: 'Houston, We've Had a Problem'", text: "On April 13, 1970, an oxygen tank exploded aboard Apollo 13. The crew survived by using the Lunar Module as a lifeboat, navigating by Earth's terminator line, and enduring near-freezing temperatures for four days."),
                LoreEntry(title: "Salyut 1 Tragedy", text: "In 1971, the crew of Soyuz 11 spent 23 days aboard Salyut 1 — the first space station. During reentry, a valve opened at 168 km altitude, depressurizing the cabin. All three cosmonauts died. They are the only humans to have died in space."),
                LoreEntry(title: "Space Shuttle Challenger", text: "On January 28, 1986, Space Shuttle Challenger broke apart 73 seconds after launch, killing all seven crew members including teacher Christa McAuliffe. The cause was an O-ring seal failure in freezing temperatures."),
                LoreEntry(title: "Mir Collision", text: "In 1997, an unmanned Progress cargo ship collided with the Mir space station during a docking test, puncturing the Spektr module. The crew scrambled to seal the breach as the station began losing pressure and tumbling."),
                LoreEntry(title: "Gemini 8: Armstrong's First Crisis", text: "In 1966, a stuck thruster on Gemini 8 sent Neil Armstrong and David Scott spinning at one revolution per second. Armstrong used reentry thrusters to stabilize — a decision that likely saved their lives and his future Moon walk."),
                LoreEntry(title: "Mars Polar Lander: Lost", text: "In 1999, NASA's Mars Polar Lander crashed on Mars because its software interpreted vibrations from leg deployment as a landing signal, shutting off the engines 40 meters above the surface."),
                LoreEntry(title: "Voskhod 2: Stuck Outside", text: "During the first spacewalk in 1965, Alexei Leonov's suit ballooned in the vacuum. He couldn't fit back inside and had to dangerously vent oxygen from his suit. He barely made it, later describing the experience as 'terrifying.'"),
                LoreEntry(title: "STS-107 Foam Strike", text: "During Columbia's final launch, a briefcase-sized piece of insulation foam struck the wing at 877 km/h, creating a hole in the heat shield. Engineers raised concerns, but management deemed it non-critical. Sixteen days later, Columbia was lost."),
                LoreEntry(title: "Curiosity's 7 Minutes of Terror", text: "Landing Curiosity on Mars in 2012 required a never-before-tried sky crane maneuver. The rover descended on cables from a hovering rocket platform. The entire sequence was autonomous — radio signals took 14 minutes to reach Earth."),
                LoreEntry(title: "ISS Ammonia Leak", text: "In 2013, astronauts spotted white flakes streaming from the ISS — a potential ammonia leak from the cooling system. Two emergency spacewalks were conducted to replace a pump module in what NASA called 'the most urgent repair in station history.'"),
            ]
        case .surreal:
            return [
                LoreEntry(title: "Time Dilation is Real", text: "GPS satellites must account for Einstein's relativity: their clocks tick 38 microseconds faster per day than clocks on Earth due to weaker gravity. Without corrections, GPS would drift by 10 km daily."),
                LoreEntry(title: "Neutron Star Density", text: "A neutron star packs the mass of our Sun into a sphere just 20 km across. A teaspoon of neutron star material would weigh about 6 billion tons — roughly the weight of Mount Everest."),
                LoreEntry(title: "Spaghettification", text: "If you fell into a stellar black hole, tidal forces would stretch your body into a thin strand — a process physicists genuinely call 'spaghettification.' You would be stretched thinner than a strand of pasta."),
                LoreEntry(title: "The Sound of a Black Hole", text: "In 2022, NASA released audio from the Perseus galaxy cluster — pressure waves from a supermassive black hole translated into sound. The note is a B-flat, 57 octaves below middle C."),
                LoreEntry(title: "Space Smells Like Steak", text: "Astronauts report that space has a distinct smell — described as seared steak, gunpowder, or raspberries. The scent likely comes from dying stars releasing polycyclic aromatic hydrocarbons."),
                LoreEntry(title: "A Day on Venus", text: "Venus rotates so slowly that one Venusian day (243 Earth days) is longer than one Venusian year (225 Earth days). It also spins backward — the Sun rises in the west and sets in the east."),
                LoreEntry(title: "Quantum Entanglement in Space", text: "In 2017, Chinese satellite Micius demonstrated quantum entanglement over 1,200 km — two particles remained instantaneously connected regardless of distance, as if space between them didn't exist."),
                LoreEntry(title: "The Diamond Planet", text: "Planet 55 Cancri e, about 40 light-years away, may have a surface covered in diamonds. Its carbon-rich composition and extreme pressure could create a world where diamond is as common as rock."),
                LoreEntry(title: "Rogue Planets", text: "Billions of planets wander through our galaxy without orbiting any star. Ejected from their solar systems by gravitational encounters, these rogue planets drift alone through interstellar darkness."),
                LoreEntry(title: "The Observable Universe", text: "The observable universe contains roughly 2 trillion galaxies, each with hundreds of billions of stars. Yet all the matter we can see makes up only about 5% of the universe — the rest is dark matter and dark energy."),
            ]
        }
    }
}
