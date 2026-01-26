from sqlalchemy.orm import Session
from app.models.universe import Universe
from app.models.region import Region
from app.models.star_system import StarSystem
from app.models.planet import Planet
from app.models.location import Location
from app.models.resource_deposit import ResourceDeposit

from app.db import SessionLocal
import random
import math
from collections import Counter

# Universe constants
CORE_REGION_NAMES = [
    "Forgeheart Dominion", "Crystal Crown Sector", "Ironclad Nexus", "Radiant Spire Alliance",
    "Obsidian Vaults", "Stellarforge Concord", "Embercore Syndicate", "Voidsteel Enclave",
    "Prismgate Territories", "Titanforge Bastion", "Luminary Core"
]

OUTLAW_REGION_NAMES = [
    "Shadowrift Fringe", "Blood Nebula Marches", "Ghostfire Expanse", "Razorwind Badlands",
    "Eclipse Drift", "Scourge Veil", "Thornspire Wastes", "Ironscar Reaches",
    "Frostbite Void", "Demon's Maw", "Blackshard Frontier", "Wraith Hollows",
    "Crimson Abyss", "Deadlight Shallows", "Skullforge Rift", "Nightmare Drift",
    "Bone Nebula", "Ruinspike Marches", "Ashen Vortex", "Predator's Edge", "Exile's Gambit"
]

CORE_REGION_SYSTEMS = (20, 27)
OUTLAW_REGION_SYSTEMS = (12, 15)
PLANETS_PER_SYSTEM = (4, 9)
TOTAL_PLANETS = 4000

UNIVERSE_NAME = "Riftforge Expanse"

# Universe-wide space
UNIVERSE_SCALE = 100000  # Bounds of the universe in the [0,100,000] cube
REGION_SCALE = 10000     # Size of regions within the universe
STAR_SYSTEM_SCALE = 10000  # Size of star systems within regions

# Star types
STAR_TYPES = [
    {"type": "Red Dwarf", "size": "Small", "temperature": (2500, 4000), "luminosity": "Low", "weight": 50},
    {"type": "Yellow Dwarf", "size": "Medium", "temperature": (5000, 6000), "luminosity": "Moderate", "weight": 30},
    {"type": "Blue Giant", "size": "Large", "temperature": (10000, 25000), "luminosity": "High", "weight": 10},
    {"type": "White Dwarf", "size": "Tiny", "temperature": (8000, 40000), "luminosity": "Low", "weight": 5},
]

# Define weights for choosing biomes
BIOME_WEIGHTS = {
    "Barren": 40,
    "Oceanic": 25,
    "Ice": 20,
    "Temperate": 10,
    "Volcanic": 5,
}

BIOME_RESOURCE_RULES = {
    "Barren": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 40},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 30},
        {"resource_type": "Coal", "rarity": "common", "weight": 20},
        {"resource_type": "Quartz", "rarity": "common", "weight": 10},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 10},
        {"resource_type": "Aluminum Ore", "rarity": "common", "weight": 30},
        {"resource_type": "Zinc Ore", "rarity": "common", "weight": 20},
        {"resource_type": "Lead Ore", "rarity": "rare", "weight": 10},
        {"resource_type": "Nickel Ore", "rarity": "rare", "weight": 5},
        {"resource_type": "Gold", "rarity": "rare", "weight": 5},
        {"resource_type": "Plutonium", "rarity": "rare", "weight": 5},
        {"resource_type": "Nitrogen", "rarity": "common", "weight": 20},
        {"resource_type": "Titanium Ore", "rarity": "rare", "weight": 15},
        {"resource_type": "Oxygen", "rarity": "common", "weight": 15},
    ],
    "Oceanic": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 10},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 20},
        {"resource_type": "Coal", "rarity": "common", "weight": 10},
        {"resource_type": "Quartz", "rarity": "common", "weight": 30},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 60},
        {"resource_type": "Biomass", "rarity": "common", "weight": 30},
        {"resource_type": "Wood", "rarity": "common", "weight": 20},
    ],
    "Ice": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 50},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 30},
        {"resource_type": "Coal", "rarity": "common", "weight": 20},
        {"resource_type": "Quartz", "rarity": "common", "weight": 10},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 10},
        {"resource_type": "Titanium Ore", "rarity": "rare", "weight": 20},
        {"resource_type": "Aluminum Ore", "rarity": "common", "weight": 30},
        {"resource_type": "Zinc Ore", "rarity": "common", "weight": 20},
        {"resource_type": "Lead Ore", "rarity": "rare", "weight": 15},
        {"resource_type": "Gold", "rarity": "rare", "weight": 10},
        {"resource_type": "Nitrogen", "rarity": "common", "weight": 25},
        {"resource_type": "Oxygen", "rarity": "common", "weight": 20},
    ],
    "Temperate": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 20},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 20},
        {"resource_type": "Coal", "rarity": "common", "weight": 50},
        {"resource_type": "Quartz", "rarity": "common", "weight": 10},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 20},
        {"resource_type": "Biomass", "rarity": "common", "weight": 40},
        {"resource_type": "Wood", "rarity": "common", "weight": 30},
        {"resource_type": "Gold", "rarity": "rare", "weight": 10},
        {"resource_type": "Nickel Ore", "rarity": "rare", "weight": 5},
        {"resource_type": "Nitrogen", "rarity": "common", "weight": 15},
        {"resource_type": "Oxygen", "rarity": "common", "weight": 25},
    ],
    "Volcanic": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 30},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 10},
        {"resource_type": "Coal", "rarity": "common", "weight": 40},
        {"resource_type": "Quartz", "rarity": "common", "weight": 20},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 10},
        {"resource_type": "Titanium Ore", "rarity": "rare", "weight": 25},
        {"resource_type": "Lead Ore", "rarity": "rare", "weight": 5},
        {"resource_type": "Platinum", "rarity": "exotic", "weight": 5},
        {"resource_type": "Palladium", "rarity": "exotic", "weight": 8},
        {"resource_type": "Uranium", "rarity": "rare", "weight": 30},
        {"resource_type": "Helium-3", "rarity": "exotic", "weight": 5},
        {"resource_type": "Plutonium", "rarity": "rare", "weight": 20},
    ],
}

### Helper Functions ###
def generate_region_coordinates():
    """Generate non-overlapping region coordinates within the universe cube."""
    step = REGION_SCALE
    return [
        (x, y, z)
        for x in range(0, UNIVERSE_SCALE, step)
        for y in range(0, UNIVERSE_SCALE, step)
        for z in range(0, UNIVERSE_SCALE, step)
    ]


def distribute_planets_and_systems(total_planets, core_regions, outlaw_regions):
    """
    Distribute planets and systems evenly across core and outlaw regions.
    """
    regions = core_regions + outlaw_regions
    core_regions_count = len(core_regions)
    outlaw_regions_count = len(outlaw_regions)

    # Estimate total systems for core and outlaw regions
    core_systems = random.randint(
        core_regions_count * CORE_REGION_SYSTEMS[0],
        core_regions_count * CORE_REGION_SYSTEMS[1],
    )
    outlaw_systems = random.randint(
        outlaw_regions_count * OUTLAW_REGION_SYSTEMS[0],
        outlaw_regions_count * OUTLAW_REGION_SYSTEMS[1],
    )

    total_systems = core_systems + outlaw_systems
    avg_planets_per_system = total_planets // total_systems

    # Allocate systems and planets to regions proportionally
    systems_per_region = []
    planets_per_system = []

    # Distribute for core regions
    for _ in core_regions:
        systems_count = random.randint(*CORE_REGION_SYSTEMS)
        systems_per_region.append(systems_count)
        for _ in range(systems_count):
            planets_count = random.randint(*PLANETS_PER_SYSTEM)
            planets_per_system.append(planets_count)

    # Distribute for outlaw regions
    for _ in outlaw_regions:
        systems_count = random.randint(*OUTLAW_REGION_SYSTEMS)
        systems_per_region.append(systems_count)
        for _ in range(systems_count):
            planets_count = random.randint(*PLANETS_PER_SYSTEM)
            planets_per_system.append(planets_count)

    return regions, systems_per_region, planets_per_system


def calculate_total_resource_capacity(biome, radius):
    """
    Calculate the total resources available on a planet based on its biome and radius.
    """
    biome_base = {
        "Barren": 10000000,
        "Oceanic": 11000000,
        "Ice": 14000000,
        "Temperate": 12000000,
        "Volcanic": 18000000,
    }
    base_capacity = biome_base.get(biome, 50000)
    return int(base_capacity * (radius / 5000))


def calculate_num_locations(planet_radius, base_plot_size=1000000, reference_radius=6371, max_locations=50, min_locations=3):
    """
    Dynamically calculate the number of locations (plots) on a planet based on its radius,
    using density scaling to avoid over-allocation of locations on smaller planets.

    :param planet_radius: Radius of the planet in kilometers.
    :param base_plot_size: Base size of a plot in square kilometers (default: 1,000,000 km²).
    :param reference_radius: A scaling factor based on Earth's radius (default: 6,371 km).
    :param max_locations: Maximum number of locations allowed on a single planet.
    :param min_locations: Minimum number of locations required on a single planet.
    :return: Dynamically calculated number of locations.
    """
    # Scale effective plot size based on planet radius compared to reference (Earth-like scaling)
    radius_factor = planet_radius / reference_radius
    effective_plot_size = base_plot_size * radius_factor

    # Surface area of a sphere: 4 * π * r^2
    surface_area = 4 * math.pi * (planet_radius ** 2)

    # Calculate the number of location
    num_locations = int(surface_area / effective_plot_size)

    # Ensure the number of locations stays within min and max limits
    return max(min_locations, min(num_locations, max_locations)) 

def generate_location_resources(biome, total_resources, num_locations, is_outlaw=False):
    """
    Dynamically allocate resources across planet locations based on biome rules.
    """
    biome_rules = BIOME_RESOURCE_RULES[biome]
    locations = []
    remaining_resources = total_resources

    # Outlaw regions influence rarity and resource availability
    rarity_boost = 1.2 if is_outlaw else 1.0
    scarcity_factor = 1.2 if is_outlaw else 1.0
    remaining_resources = int(remaining_resources * scarcity_factor)

    for i in range(num_locations):
        # Share resources for this location
        upper_limit = remaining_resources // num_locations
        lower_limit = max((5 * total_resources) // 100, remaining_resources // (2 * num_locations))

        # Ensure the range is valid
        lower_limit = min(lower_limit, upper_limit)

        # Compute location share
        location_share = random.randint(lower_limit, upper_limit)

        # If this is the last location, allocate all remaining resources
        if i == num_locations - 1:
            location_share = remaining_resources

        # Allocate resources for this location
        location_resources = []
        for resource_rule in biome_rules:
            weight_percentage = (resource_rule["weight"] * rarity_boost) / sum(
                rule["weight"] * rarity_boost if rule["rarity"] == "rare" else rule["weight"]
                for rule in biome_rules
            )
            quantity = int(location_share * weight_percentage)
            if quantity > 0:
                location_resources.append({
                    "resource_type": resource_rule["resource_type"],
                    "quantity": quantity,
                    "rarity": resource_rule["rarity"],
                })

        # Subtract the allocated share from remaining resources
        remaining_resources -= location_share

        # Ensure `remaining_resources` doesn't go negative
        remaining_resources = max(0, remaining_resources)

        # Save the allocated resources
        locations.append(location_resources)

    return locations

def calculate_plot_size(planet_radius, num_locations):
    """
    Calculate the realistic size of each plot based on the planet's radius and the number of plots (locations).
    
    :param planet_radius: Radius of the planet in kilometers.
    :param num_locations: Total number of locations on the planet.
    :return: The width and height of each plot, in kilometers.
    """
    # Surface area of a sphere = 4 * pi * r^2
    surface_area = 4 * math.pi * (planet_radius ** 2)

    # Divide the surface area by the number of locations
    plot_area = surface_area / num_locations

    # Take the square root to get the side length of each plot (assuming square plots for simplicity)
    plot_size = math.sqrt(plot_area)
    return plot_size

def seed_locations_and_resources(db, planet, num_locations):
    """
    Seed locations and their resource deposits for a given planet, using realistic `x` and `y` coordinates.
    """
     # Calculate realistic plot size
    plot_size = calculate_plot_size(planet.radius, num_locations)

    # Calculate the half-dimensions of the planet's size in the coordinate system
    planet_width = math.sqrt(4 * math.pi * (planet.radius**2))  # Total "flat equivalent width"


    locations = []
    deposits = []

    for idx in range(num_locations):
        # Assign coordinates within the planet. Spread locations pseudo-randomly within the grid.
        x = random.uniform(0, planet_width)  # Full surface width
        y = random.uniform(0, planet_width)  # Full surface height

        x_normalized = x / planet_width
        y_normalized = y / planet_width
        z = x_normalized + y_normalized / 2 * planet.radius * 0.1 # Scale z-axis variation to 10% of planet radius

        center_x, center_y = planet_width / 2, planet_width /2
        distance_from_center = math.sqrt((x - center_x) ** 2 + (y - center_y) ** 2)
        radial_z = (1 - distance_from_center / (planet_width / 2)) * planet.radius * 0.1
        radial_z = max(0, radial_z)  # Prevent negative elevations

        # Combine gradient and radial effects, and add noise for variation
        z = (z + radial_z) / 2  # Average the gradient and radial calculations
        z += random.uniform(-planet.radius * 0.02, planet.radius * 0.02)  # Add some noise
        z = max(0, z)  # Ensure z is not negative

        location = Location(
            name=f"{planet.name} Plot {idx + 1}",
            planet_id=planet.id,
            x=x,
            y=y,
            z=z,
            biome=planet.biome,
        )
        locations.append(location)
        db.add(location)
        db.flush()

        # Generate resources for this location
        location_resources = generate_location_resources(
            planet.biome, planet.total_resources, num_locations, "outlaw" in planet.star_system.region.name.lower()
        )
        for resource in location_resources[idx]:
            deposits.append(ResourceDeposit(
                location_id=location.id,
                resource_type=resource["resource_type"],
                quantity=resource["quantity"],
                rarity=resource["rarity"],
            ))

    db.add_all(deposits)
    return locations


### Main Seeding Function ###
import uuid

def seed_universe(db):
    """
    Seed the universe with procedurally named core and outlaw star systems, and planets.
    """
    import random

    CORE_STAR_SYSTEM_NAMES = [
    # Core Stellar Names (1-50)
    "Aetheris", "Vortexia", "Nebulon", "Quasara", "Pulsara", "Stellaris", "Coronae", "Helixion", "Photonis", "Luminara",
    "Spectra", "Radiara", "Novaris", "Hyperion", "Zentara", "Astralix", "Celestara", "Orionis", "Sirius Major", "Vega Prime",
    "Rigelion", "Betelgeuse", "Procyon", "Altair Nexus", "Denebola", "Spica", "Arcturus", "Aldebaran", "Antares", "Capella",
    "Castor", "Pollux", "Regulus", "Deneb", "Fomalhaut", "Achernar", "Mira", "Alnilam", "Alnitak", "Mintaka", "Bellatrix",
    "Saiph", "Alphard", "Mirfak", "Menkent", "Atria", "Gacrux", "Acrux", "Mimosa", "Gienah", "Alshain",
    
    # Nebula Regions (51-100)
    "Horsehead", "Eagle Nebula", "Crab Pulsar", "Ring Nebula", "Dumbbell", "Cat's Eye", "Owl Nebula", "Helix Nebula",
    "Planetary Veil", "Witch's Head", "Lagoon Core", "Trifid Rift", "Orion Veil", "Rosette Cluster", "Cone Nebula",
    "Elephant Trunk", "Pelican Drift", "North America", "Pacific Nebula", "Atlantic Drift", "Carina Vortex",
    "Tarantula", "Eta Carina", "Homunculus", "Keyhole", "Bubble Sector", "Wizard Drift", "Iris Nebula", "Cocoon Star",
    "Flame Belt", "Pillow Nebula", "Monkey Head", "Propeller", "Red Rectangle", "Blue Flash", "Diamond Ring",
    "Ghost Head", "Frog Nebula", "Tadpole", "Butterfly Wing", "Dragonfish", "Seahorse", "Skull Nebula",
    "Snow Globe", "Cosmic Rose", "Stingray", "Mystic Mountain", "Pillars Reach", "Dark Horse", "Shadow Veil",
    
    # Constellation Zones (101-150)
    "Draco Prime", "Cygnus Rift", "Lyra Cluster", "Aquila Vortex", "Sagitta Arrow", "Vulpecula", "Delphinus",
    "Sagittarius A", "Scutum Star", "Serpens Cauda", "Ophiuchus", "Hercules Crown", "Boötes Void",
    "Corona Borealis", "Ursa Majoris", "Ursa Minor", "Cassiopeia A", "Cepheus Pole", "Camelopardalis",
    "Auriga Chariot", "Perseus Double", "Taurus Rift", "Gemini Twins", "Cancer Cluster", "Leo Regulus",
    "Virgo Spica", "Libra Scales", "Scorpius Heart", "Capricornus Sea", "Aquarius Water", "Pisces Void",
    "Aries Ram", "Centaurus Alpha", "Lupus Wolf", "Crux Southern", "Musca Fly", "Chamaeleon",
    "Volans Fish", "Pictor Painter", "Carina Keel", "Vela Sail", "Puppis Stern", "Pyxis Compass",
    "Antlia Air", "Hydra Head", "Sextans", "Crater Cup", "Corvus Crow", "Ursa Furnace",
    
    # Quantum & Exotic (151-200)
    "Singularity", "Event Horizon", "Hawking Point", "Schwarzschild", "Kerr Metric", "Wormhole Alpha",
    "Tachyon Drift", "Dark Energy", "Zero Point", "Quantum Flux", "Planck Scale", "Heisenberg Veil",
    "Dirac Sea", "Bose Condensate", "Fermion Field", "Gluon Storm", "Neutrino Flow", "Photon Cascade",
    "Plasma Vortex", "Magnetar Core", "Pulsar Spin", "Neutron Drift", "White Dwarf", "Red Giant",
    "Blue Supergiant", "Yellow Dwarf", "Brown Dwarf", "Hypergiant", "Protostar", "T-Tauri",
    "Herbig-Haro", "FU Orionis", "Pre-Main", "Main Sequence", "Post-Main", "Asymptotic Giant",
    "Horizontal Branch", "RR Lyrae", "Cepheid Variable", "Long Period", "Mira Variable", "Symbiotic",
    
    # Galactic Features (201-250)
    "Galactic Core", "Barred Spiral", "Disk Edge", "Spiral Arm", "Molecular Cloud", "HII Region",
    "Supernova Remnant", "Planetary Nebula", "Open Cluster", "Globular Cluster", "Galactic Bulge",
    "Halo Stars", "Thick Disk", "Thin Disk", "Interstellar Medium", "Dust Lane", "Starburst Ring",
    "Nuclear Star", "Central Black Hole", "Accretion Disk", "Relativistic Jet", "Gamma Burst",
    "Blazar Core", "Quasar Jet", "Active Nucleus", "Seyfert Galaxy", "Starburst Galaxy",
    "Lenticular", "Elliptical Core", "Irregular Patch", "Dwarf Spheroidal", "Ultra Diffuse",
    
    # Mythic Stellar (251-300)
    "Olympus Mons", "Asgard Gate", "Valhalla", "Midgard Light", "Asgard Reach", "Yggdrasil Core",
    "Ragnarok Rift", "Bifrost Bridge", "Niflheim Ice", "Muspelheim Fire", "Jotunheim", "Alfheim",
    "Svartalfheim", "Vanaheim", "Helheim Void", "Fenrir Chain", "Jormungandr", "Sleipnir Run",
    "Odin's Eye", "Thor's Hammer", "Loki's Fire", "Freyja's Tears", "Heimdall Watch",
    "Skadi Frost", "Njord Sea", "Tyr Justice", "Baldr Light", "Hodr Dark", "Forseti Law",
    
    # Bonus Prime Systems (301-310)
    "Zenith Prime", "Apogee Prime", "Nadir Prime", "Perihelion", "Aphelion Drift", "Lagrange Point",
    "Roche Lobe", "Hill Sphere", "Parker Spiral", "Alfven Wave"
    ]
    random.shuffle(CORE_STAR_SYSTEM_NAMES)

    def get_outlaw_system_name():
        """
        Generate a UUID-like name for outlaw systems.
        Example: 'AJI-MH', 'M-XR2'
        """
        return uuid.uuid4().hex[:3].upper() + "-" + uuid.uuid4().hex[:3].upper()

    def int_to_roman(n):
        """Convert an integer to a Roman numeral."""
        val = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        syms = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
        roman_num = ""
        i = 0
        while n > 0:
            for _ in range(n // val[i]):
                roman_num += syms[i]
                n -= val[i]
            i += 1
        return roman_num

    # Step 1: Create the Universe
    universe = Universe(name=UNIVERSE_NAME)
    db.add(universe)
    db.flush()

    # Step 2: Generate regions and their coordinates
    all_regions, systems_per_region, planets_per_system = distribute_planets_and_systems(
        TOTAL_PLANETS, CORE_REGION_NAMES, OUTLAW_REGION_NAMES
    )

    region_coordinates = generate_region_coordinates()
    random.shuffle(region_coordinates)

    seeded_regions = []
    for idx, name in enumerate(all_regions):
        coords = region_coordinates.pop()
        region = Region(
            name=name,
            universe_id=universe.id,
            x=coords[0],
            y=coords[1],
            z=coords[2],
        )
        seeded_regions.append(region)
        db.add(region)
    db.flush()

    # Step 3: Seed Star Systems
    seeded_systems = []
    for region, system_count in zip(seeded_regions, systems_per_region):
        is_core = region.name in CORE_REGION_NAMES
        for _ in range(system_count):
            if is_core:
                # Use meaningful core system names
                system_name = CORE_STAR_SYSTEM_NAMES.pop()
            else:
                # Use UUID-like name for outlaw systems
                system_name = get_outlaw_system_name()

            system = StarSystem(
                name=system_name,
                region_id=region.id,
                x=random.uniform(0, STAR_SYSTEM_SCALE),
                y=random.uniform(0, STAR_SYSTEM_SCALE),
                z=random.uniform(0, STAR_SYSTEM_SCALE),
            )
            seeded_systems.append(system)
            db.add(system)
    db.flush()

    # Step 4: Seed Planets
    seeded_planets = []
    
    # Extract biome options and weights for weighted selection
    biome_choices = list(BIOME_WEIGHTS.keys())
    biome_weights = list(BIOME_WEIGHTS.values())
    
    for system, num_planets in zip(seeded_systems, planets_per_system):
        for planet_num in range(1, num_planets + 1):
            # Choose a biome using the weighted list
            biome = random.choices(biome_choices, weights=biome_weights, k=1)[0]  
            
            # Generate random values for radius and resources
            radius = random.uniform(3000, 7000)
            total_resources = calculate_total_resource_capacity(biome, radius)

            # Name the planet based on the system name and Roman numeral
            planet_name = f"{system.name} {int_to_roman(planet_num)}"

            planet = Planet(
                name=planet_name,
                star_system_id=system.id,
                biome=biome,
                radius=radius,
                total_resources=total_resources,
            )
            seeded_planets.append(planet)
            db.add(planet)
    db.flush()

    # Step 5: Seed Locations and Resources for Each Planet
    for planet in seeded_planets:
        num_locations = calculate_num_locations(planet.radius)
        seed_locations_and_resources(db, planet, num_locations)

        db.commit()
    print(f"Seeded {len(seeded_regions)} regions, {len(seeded_systems)} systems, {len(seeded_planets)} planets.")
    

if __name__ == "__main__":
    db = SessionLocal()
    try:
        print("Seeding the universe...")
        seed_universe(db)
    except Exception as e:
        import traceback
        print(f"An error occured during seeding: {traceback.format_exc()}")
    finally:
        db.close()