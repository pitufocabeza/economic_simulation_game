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

CORE_REGION_SYSTEMS = (20, 28)
OUTLAW_REGION_SYSTEMS = (5, 15)
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

BIOME_RESOURCE_RULES = {
    "Barren": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 40},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 30},
        {"resource_type": "Coal", "rarity": "common", "weight": 20},
        {"resource_type": "Quartz", "rarity": "common", "weight": 10},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 10},
    ],
    "Oceanic": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 10},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 20},
        {"resource_type": "Coal", "rarity": "common", "weight": 10},
        {"resource_type": "Quartz", "rarity": "common", "weight": 30},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 60},
    ],
    "Mountainous": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 50},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 30},
        {"resource_type": "Coal", "rarity": "common", "weight": 20},
        {"resource_type": "Quartz", "rarity": "common", "weight": 10},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 10},
        {"resource_type": "Titanium Ore", "rarity": "rare", "weight": 20},
    ],
    "Temperate": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 20},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 20},
        {"resource_type": "Coal", "rarity": "common", "weight": 50},
        {"resource_type": "Quartz", "rarity": "common", "weight": 10},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 20},
    ],
    "Volcanic": [
        {"resource_type": "Iron Ore", "rarity": "common", "weight": 30},
        {"resource_type": "Copper Ore", "rarity": "common", "weight": 10},
        {"resource_type": "Coal", "rarity": "common", "weight": 40},
        {"resource_type": "Quartz", "rarity": "common", "weight": 20},
        {"resource_type": "Hydrogen", "rarity": "common", "weight": 10},
        {"resource_type": "Titanium Ore", "rarity": "rare", "weight": 10},
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
        "Barren": 50000,
        "Oceanic": 60000,
        "Mountainous": 80000,
        "Temperate": 70000,
        "Volcanic": 1000000,
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
        location_share = random.randint(
            max(500, remaining_resources // (2 * num_locations)),
            remaining_resources // num_locations
        )
        if i == num_locations - 1:
            location_share = remaining_resources  # Allocate any remaining resources to the last location

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

        remaining_resources -= location_share
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

        location = Location(
            name=f"{planet.name} Plot {idx + 1}",
            planet_id=planet.id,
            x=x,
            y=y,
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
def seed_universe(db):
    """
    Seed the entire universe, including regions, star systems, planets, and locations.
    """
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

    # Step 3: Seed Star Systems and Planets
    seeded_systems = []
    seeded_planets = []
    for region, system_count in zip(seeded_regions, systems_per_region):
        for _ in range(system_count):
            system = StarSystem(
                name=f"{region.name} System {random.randint(1, 1000)}",
                region_id=region.id,
                x=random.uniform(0, STAR_SYSTEM_SCALE),
                y=random.uniform(0, STAR_SYSTEM_SCALE),
                z=random.uniform(0, STAR_SYSTEM_SCALE),
            )
            seeded_systems.append(system)
            db.add(system)
            db.flush()

            # Generate planets for the system
            for _ in range(random.randint(*PLANETS_PER_SYSTEM)):
                biome = random.choice(list(BIOME_RESOURCE_RULES.keys()))
                radius = random.uniform(3000, 7000)
                total_resources = calculate_total_resource_capacity(biome, radius)
                num_locations = calculate_num_locations(radius)

                planet = Planet(
                    name=f"{system.name} Planet {random.randint(1, 1000)}",
                    star_system_id=system.id,
                    biome=biome,
                    radius=radius,
                    total_resources=total_resources,
                )
                seeded_planets.append(planet)
                db.add(planet)
                db.flush()

                # Seed locations and resources on the planet
                seed_locations_and_resources(db, planet, num_locations)

    db.commit()
    print(f"Seeded {len(seeded_regions)} regions, {len(seeded_systems)} systems, {len(seeded_planets)} planets.")

    

if __name__ == "__main__":
    db = SessionLocal()
    try:
        print("Seeding the universe...")
        seed_universe(db)
    except Exception as e:
        print(f"An error occured during seeding: {e}")
    finally:
        db.close()