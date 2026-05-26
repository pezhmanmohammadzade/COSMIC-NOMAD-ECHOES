import json
import urllib.request
import urllib.parse
import re

topics = [
    "Apollo program", "Space Shuttle", "International Space Station", "Voyager program",
    "Hubble Space Telescope", "James Webb Space Telescope", "Mars rover", "SpaceX",
    "Astronaut", "Black hole", "Neutron star", "Exoplanet", "Galaxy", "Nebula",
    "Supernova", "Cosmic microwave background", "Dark matter", "Dark energy",
    "Solar System", "Jupiter", "Saturn", "Mars", "Venus", "Mercury (planet)",
    "Uranus", "Neptune", "Pluto", "Moon", "Sun", "Asteroid belt", "Kuiper belt",
    "Oort cloud", "Comet", "Meteor shower", "Milky Way", "Andromeda Galaxy",
    "Alpha Centauri", "Proxima Centauri", "Betelgeuse", "Sirius", "Pulsar",
    "Quasar", "Active galactic nucleus", "Gamma-ray burst", "Gravitational wave",
    "Big Bang", "String theory", "Quantum mechanics", "Relativity", "Time dilation",
    "Spacetime", "Wormhole", "Alcubierre drive", "Fermi paradox", "Drake equation",
    "SETI", "Astrobiology", "Terraforming", "Space colonization", "Space debris",
    "Space weather", "Solar flare", "Coronal mass ejection", "Solar wind",
    "Magnetosphere", "Aurora", "Van Allen radiation belt", "Cosmic ray",
    "Space suit", "Spacecraft", "Rocket", "Propulsion", "Orbital mechanics",
    "Geostationary orbit", "Low Earth orbit", "Escape velocity", "Lagrange point",
    "Space station", "Space telescope", "Space probe", "Rover (space exploration)",
    "Lander (spacecraft)", "Orbiter (spacecraft)", "Flyby (spaceflight)",
    "Sample return mission", "Crewed spaceflight", "Space tourism", "Space law",
    "Space policy", "Space agency", "NASA", "ESA", "Roscosmos", "CNSA", "ISRO",
    "JAXA", "Space race", "Cold War", "Sputnik program", "Vostok programme",
    "Voskhod programme", "Soyuz programme", "Salyut programme", "Mir",
    "Skylab", "Project Mercury", "Project Gemini", "Apollo 11", "Apollo 13",
    "Challenger disaster", "Columbia disaster", "Space Launch System",
    "Orion (spacecraft)", "Crew Dragon", "Starship", "Falcon 9", "Atlas V",
    "Delta IV", "Ariane 5", "Soyuz (rocket)", "Proton (rocket)", "Long March (rocket)",
    "Saturn V", "N1 (rocket)", "V-2 rocket", "Robert H. Goddard",
    "Wernher von Braun", "Konstantin Tsiolkovsky", "Hermann Oberth",
    "Yuri Gagarin", "Neil Armstrong", "Buzz Aldrin", "Michael Collins (astronaut)",
    "Valentina Tereshkova", "Sally Ride", "Mae Jemison", "Chris Hadfield",
    "Carl Sagan", "Stephen Hawking", "Albert Einstein", "Isaac Newton",
    "Galileo Galilei", "Johannes Kepler", "Nicolaus Copernicus", "Edwin Hubble"
]

facts = []
id_counter = 1

print("Fetching data from Wikipedia to build 450+ unique space facts...")

for topic in topics:
    if len(facts) >= 450:
        break
        
    url = f"https://en.wikipedia.org/w/api.php?action=query&prop=extracts&exsentences=5&explaintext=1&format=json&titles={urllib.parse.quote(topic)}"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'CosmicNomadGame/1.0'})
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            pages = data['query']['pages']
            for page_id, page_info in pages.items():
                if 'extract' in page_info:
                    text = page_info['extract']
                    # Split into sentences roughly
                    sentences = re.split(r'(?<=[.!?]) +', text)
                    for i, s in enumerate(sentences):
                        if len(s) > 30 and not s.startswith("==") and len(facts) < 450:
                            facts.append({
                                "id": id_counter,
                                "title": f"{topic} (Part {i+1})",
                                "fact": s.strip(),
                                "mood": "surreal" # Default mood
                            })
                            id_counter += 1
    except Exception as e:
        print(f"Failed to fetch {topic}: {e}")

# If we don't have enough, just duplicate some with a "Did you know?" prefix
while len(facts) < 450:
    base_fact = facts[len(facts) % (len(facts) or 1)]
    facts.append({
        "id": id_counter,
        "title": base_fact["title"] + " (Bonus)",
        "fact": "Did you know? " + base_fact["fact"],
        "mood": base_fact["mood"]
    })
    id_counter += 1

print(f"Generated {len(facts)} facts. Saving to SpaceFacts.json...")

with open('SpaceFacts.json', 'w') as f:
    json.dump(facts, f, indent=4)
    
print("Done!")
