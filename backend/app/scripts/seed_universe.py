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

# Universe constants - MVP Configuration
# ========================================

# Core Regions (5 - Safe, moderate resources)
CORE_REGION_NAMES = [
    "Forgeheart Dominion",      # Forge Syndicate headquarters
    "Crystal Crown Sector",      # Luminous Accord research hub
    "Ironclad Nexus",            # Titanborn Consortium mining base
    "Radiant Spire Alliance",    # Hegemony of Unity control center
    "Cooperative Haven",          # Stellar Collective democratic hub
]

# Outlaw Regions (7 - Frontier, 20% more resources)
OUTLAW_REGION_NAMES = [
    "Shadowrift Fringe",         # Voidrunners Collective territory
    "Blood Nebula Marches",
    "Ghostfire Expanse",
    "Razorwind Badlands",
    "Eclipse Drift",             # Ravagers of the Rift territory
    "Scourge Veil",
    "Thornspire Wastes",
]

# Faction-specific star names (one per faction)
FACTION_STARS = {
    "Forge Syndicate": "Forge Prime",           # In Forgeheart Dominion
    "Luminous Accord": "Luminous Prime",        # In Crystal Crown Sector
    "Titanborn Consortium": "Titanborn Prime",  # In Ironclad Nexus
    "Hegemony of Unity": "Unity Prime",         # In Radiant Spire Alliance
    "Stellar Collective": "Collective Prime",   # Distributed in core regions
    "Voidrunners Collective": "Shadowveil",    # In Shadowrift Fringe
    "Ravagers of the Rift": "Dreadstone",      # In Eclipse Drift
}

# System generation parameters (MVP - smaller universe)
CORE_REGION_SYSTEMS = (8, 12)      # 8-12 systems per core region
OUTLAW_REGION_SYSTEMS = (5, 8)     # 5-8 systems per outlaw region
PLANETS_PER_SYSTEM = (3, 6)        # 3-6 planets per system
TOTAL_PLANETS = 350                # Target ~350 planets total (~45-55 per region avg)

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
def calculate_distance_from_center(x, y, z, center_x=50000, center_y=50000, center_z=50000):
    """Calculate distance from galactic center."""
    return math.sqrt((x - center_x)**2 + (y - center_y)**2 + (z - center_z)**2)


def generate_region_coordinates(num_core, num_outlaw):
    """
    Generate region coordinates with core regions near galactic center, outlaw on fringe.
    Core regions: inner 1/3 of galaxy radius
    Outlaw regions: outer 2/3 of galaxy radius (surrounding core)
    Uses random sampling (memory efficient) instead of generating all positions.
    """
    center = UNIVERSE_SCALE / 2  # 50000
    max_radius = math.sqrt(3) * (UNIVERSE_SCALE / 2)  # Max distance from center to corner
    
    core_max_distance = max_radius / 3  # Inner 1/3
    outlaw_min_distance = core_max_distance  # Start where core ends
    outlaw_max_distance = max_radius  # Full outer region
    
    # Use random sampling instead of generating all positions (memory efficient)
    core_positions = []
    outlaw_positions = []
    attempts = 0
    max_attempts = 10000  # Prevent infinite loops
    
    while (len(core_positions) < num_core or len(outlaw_positions) < num_outlaw) and attempts < max_attempts:
        x = random.uniform(0, UNIVERSE_SCALE)
        y = random.uniform(0, UNIVERSE_SCALE)
        z = random.uniform(0, UNIVERSE_SCALE)
        pos = (x, y, z)
        
        distance = calculate_distance_from_center(x, y, z)
        
        if distance <= core_max_distance and len(core_positions) < num_core:
            core_positions.append(pos)
        elif distance >= outlaw_min_distance and distance <= outlaw_max_distance and len(outlaw_positions) < num_outlaw:
            outlaw_positions.append(pos)
        
        attempts += 1
    
    if len(core_positions) < num_core or len(outlaw_positions) < num_outlaw:
        print(f"⚠️  Warning: Could only generate {len(core_positions)}/{num_core} core and {len(outlaw_positions)}/{num_outlaw} outlaw regions")
    
    return core_positions, outlaw_positions


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


def calculate_num_locations(planet_radius, base_plot_size=1000000, reference_radius=6371, max_locations=8, min_locations=3):
    """
    Dynamically calculate the number of locations (plots) on a planet based on its radius,
    using density scaling to avoid over-allocation of locations on smaller planets.
    
    NEW (Factorio-style design): Capped at 3-8 locations per planet to reduce location-switching
    and encourage focused gameplay on larger maps (256x512 grids instead of 16x32).

    :param planet_radius: Radius of the planet in kilometers.
    :param base_plot_size: Base size of a plot in square kilometers (default: 1,000,000 km²).
    :param reference_radius: A scaling factor based on Earth's radius (default: 6,371 km).
    :param max_locations: Maximum number of locations allowed on a single planet (default: 8).
    :param min_locations: Minimum number of locations required on a single planet (default: 3).
    :return: Dynamically calculated number of locations.
    """
    # Scale effective plot size based on planet radius compared to reference (Earth-like scaling)
    radius_factor = planet_radius / reference_radius
    effective_plot_size = base_plot_size * radius_factor

    # Surface area of a sphere: 4 * π * r^2
    surface_area = 4 * math.pi * (planet_radius ** 2)

    # Calculate the number of locations
    num_locations = int(surface_area / effective_plot_size)

    # Ensure the number of locations stays within min and max limits
    # Factorio-style: fewer larger locations for extended gameplay
    return max(min_locations, min(num_locations, max_locations))


def calculate_grid_dimensions(planet_radius, min_size=256, max_size=512):
    """
    Calculate tilemap grid dimensions for a location based on planet size.
    Larger planets have larger location tilemaps (Factorio-style design).
    
    NEW: Changed from 16-32 to 256-512 for larger, more complex locations.
    With fewer locations (3-8) per planet, each location needs more space for gameplay.
    
    :param planet_radius: Radius of the planet in kilometers.
    :param min_size: Minimum grid size (default: 256x256).
    :param max_size: Maximum grid size (default: 512x512).
    :return: Tuple of (grid_width, grid_height)
    """
    # Scale grid size based on planet radius (3000-7000 km range)
    normalized_radius = (planet_radius - 3000) / (7000 - 3000)  # 0.0 to 1.0
    grid_size = int(min_size + (max_size - min_size) * normalized_radius)
    
    # Ensure it's a power of 2 for better tilemap performance
    grid_size = 2 ** round(math.log2(grid_size))
    grid_size = max(min_size, min(grid_size, max_size))
    
    return grid_size, grid_size 

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
        # Guard against negative or zero remaining resources
        if remaining_resources <= 0:
            break
        
        # Share resources for this location
        upper_limit = max(1, remaining_resources // num_locations)
        lower_limit = max(1, (5 * total_resources) // 100)
        lower_limit = min(lower_limit, upper_limit)  # Ensure lower <= upper
        
        # Allocate resources for this location
        if i == num_locations - 1:
            location_share = remaining_resources  # Last location gets all remaining
        else:
            location_share = random.randint(lower_limit, upper_limit)
        
        # Guard against over-allocation
        location_share = min(location_share, remaining_resources)
        location_share = max(1, location_share)

        location_resources = []
        # Calculate total weight properly (apply rarity boost consistently)
        total_weight = sum(
            rule["weight"] * rarity_boost for rule in biome_rules
        )
        
        for resource_rule in biome_rules:
            # Apply rarity boost fairly to all resources
            weighted = resource_rule["weight"] * rarity_boost
            weight_percentage = weighted / total_weight if total_weight > 0 else 0
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


def calculate_wang_tile_id(location_idx, num_locations, biome):
    """
    Calculate a Wang tile ID (0-15) for seamless tiling based on location position and biome.
    Wang tiles allow seamless transitions between tiles by encoding edge compatibility.
    
    :param location_idx: Index of the location on the planet (0 to num_locations-1)
    :param num_locations: Total number of locations on the planet
    :param biome: Biome type of the location
    :return: Wang tile ID (0-15)
    """
    # Use location index to seed tile selection deterministically
    # This ensures consistent tiling when locations are regenerated
    # Wang tiles use a 4-bit system: one bit per cardinal direction
    # Bit pattern: North (8) | East (4) | South (2) | West (1)
    
    wang_seed = hash(f"{location_idx}_{biome}") % 16
    return wang_seed


def populate_location_edge_neighbors(db, planet):
    """
    After all locations are created, link adjacent locations via edge references.
    This enables seamless transitions at location boundaries.
    
    :param db: Database session
    :param planet: Planet object with all locations already created
    """
    locations = db.query(Location).filter_by(planet_id=planet.id).all()
    
    if len(locations) <= 1:
        return  # No neighbors to connect
    
    # Create a spatial index by x,y coordinates
    loc_by_coord = {(loc.x, loc.y): loc for loc in locations}
    
    for location in locations:
        # Find nearest neighbors (using simple 2D distance)
        neighbors = {}
        min_dist_n, min_dist_s, min_dist_e, min_dist_w = float('inf'), float('inf'), float('inf'), float('inf')
        nearest_n, nearest_s, nearest_e, nearest_w = None, None, None, None
        
        for other in locations:
            if other.id == location.id:
                continue
            
            dx = other.x - location.x
            dy = other.y - location.y
            dist = math.sqrt(dx**2 + dy**2)
            
            # Determine direction (simplified: use angle)
            if dist == 0:
                continue
            angle = math.atan2(dy, dx) * 180 / math.pi
            
            # Normalize angle to 0-360
            if angle < 0:
                angle += 360
            
            # Determine cardinal direction (with tolerance)
            if 340 <= angle or angle <= 20:  # East
                if dist < min_dist_e:
                    min_dist_e = dist
                    nearest_e = other
            elif 70 <= angle <= 110:  # North
                if dist < min_dist_n:
                    min_dist_n = dist
                    nearest_n = other
            elif 160 <= angle <= 200:  # West
                if dist < min_dist_w:
                    min_dist_w = dist
                    nearest_w = other
            elif 250 <= angle <= 290:  # South
                if dist < min_dist_s:
                    min_dist_s = dist
                    nearest_s = other
        
        # Assign neighbors
        if nearest_n:
            location.edge_north_id = nearest_n.id
            location.adjacent_biome_north = nearest_n.biome
        if nearest_s:
            location.edge_south_id = nearest_s.id
            location.adjacent_biome_south = nearest_s.biome
        if nearest_e:
            location.edge_east_id = nearest_e.id
            location.adjacent_biome_east = nearest_e.biome
        if nearest_w:
            location.edge_west_id = nearest_w.id
            location.adjacent_biome_west = nearest_w.biome


def seed_locations_and_resources(db, planet, num_locations):
    """
    Seed locations (claimable plots) for a given planet.
    Each location will have its own tilemap for building that can be procedurally generated in Godot.
    
    :param db: Database session
    :param planet: Planet object
    :param num_locations: Number of claimable locations/plots on this planet
    """
    # Calculate planet surface dimensions for positioning
    planet_width = math.sqrt(4 * math.pi * (planet.radius**2))  # Total "flat equivalent width"
    
    # Determine tilemap dimensions for locations on this planet
    grid_width, grid_height = calculate_grid_dimensions(planet.radius)
    
    locations = []
    deposits = []
    
    # Generate resource distribution across all locations
    location_resources_list = generate_location_resources(
        planet.biome, 
        planet.total_resources, 
        num_locations, 
        "outlaw" in planet.star_system.region.name.lower()
    )

    for idx in range(num_locations):
        # Assign coordinates within the planet surface
        x = random.uniform(0, planet_width)
        y = random.uniform(0, planet_width)

        # Calculate elevation (z) based on position
        x_normalized = x / planet_width
        y_normalized = y / planet_width
        z = x_normalized + y_normalized / 2 * planet.radius * 0.1

        center_x, center_y = planet_width / 2, planet_width / 2
        distance_from_center = math.sqrt((x - center_x) ** 2 + (y - center_y) ** 2)
        radial_z = (1 - distance_from_center / (planet_width / 2)) * planet.radius * 0.1
        radial_z = max(0, radial_z)

        z = (z + radial_z) / 2
        z += random.uniform(-planet.radius * 0.02, planet.radius * 0.02)
        z = max(0, z)
        
        # Generate a unique seed for this location's tilemap generation in Godot
        tilemap_seed = random.randint(0, 2147483647)
        
        # Calculate Wang tile ID for seamless tiling (0-15)
        wang_tile_id = calculate_wang_tile_id(idx, num_locations, planet.biome)

        location = Location(
            name=f"{planet.name} Plot {idx + 1}",
            planet_id=planet.id,
            x=x,
            y=y,
            z=z,
            biome=planet.biome,
            grid_width=grid_width,
            grid_height=grid_height,
            tilemap_seed=tilemap_seed,
            wang_tile_id=wang_tile_id,
        )
        locations.append(location)
        db.add(location)
        db.flush()

        # Add resources to this location
        if idx < len(location_resources_list):
            for resource in location_resources_list[idx]:
                deposits.append(ResourceDeposit(
                    location_id=location.id,
                    resource_type=resource["resource_type"],
                    quantity=resource["quantity"],
                    rarity=resource["rarity"],
                ))

    db.add_all(deposits)
    
    # Populate edge neighbor references for seamless location transitions
    populate_location_edge_neighbors(db, planet)
    
    return locations


### Main Seeding Function ###
import uuid

def seed_universe(db):
    """
    Seed the universe with regions, star systems, and planets.
    MVP configuration: 11 regions, ~70-100 systems, ~350 planets.
    """
    import random
    import uuid

    # Expanded star system names for MVP core regions (60+ names for 32-60 systems)
    CORE_STAR_SYSTEM_NAMES = [
        # Trade Hubs (8)
        "Empyrean Station", "Stellar Crossing", "Meridian Gate", "Apex Citadel",
        "Zenith Commerce", "Beacon Haven", "Convergence Point", "Sanctuary Station",
        
        # Mining Colonies (8)
        "Ore Vein Prime", "Crystal Depths", "Iron Bastion", "Copper Run",
        "Titanium Hold", "Precious Vault", "Wealth Deposit", "Treasure Trench",
        
        # Science Posts (8)
        "Observatory Prime", "Research Station", "Analysis Center", "Study Point",
        "Discovery Hub", "Knowledge Base", "Insight Center", "Truth Seeker",
        
        # Industrial Zones (8)
        "Forge Central", "Foundry District", "Factory Hub", "Production Base",
        "Assembly Prime", "Crafting Yards", "Workshop Zone", "Manufacture Point",
        
        # Agricultural/Resource (8)
        "Harvest Station", "Growth Fields", "Abundance Zone", "Fertility Hub",
        "Bounty Prime", "Prosperity Point", "Wealth Fields", "Rich Deposit",
        
        # Military/Defense (8)
        "Guardian Post", "Defense Station", "Sentinel Base", "Fortress Prime",
        "Stronghold Hub", "Bastion Point", "Outpost Alpha", "Patrol Station",
        
        # Exploration/Gateway (8)
        "Pioneer Station", "Gateway Prime", "Explorer Hub", "Frontier Post",
        "Venture Point", "Discovery Prime", "Passage Hub", "Transit Station",
        
        # Luxury/Tourism (8)
        "Paradise Station", "Haven Prime", "Resort Hub", "Leisure Point",
        "Comfort Station", "Oasis Prime", "Sanctuary Point", "Retreat Hub",
    ]
    random.shuffle(CORE_STAR_SYSTEM_NAMES)

    # Procedural system name prefixes and suffixes for outlaw regions
    PROCEDURAL_PREFIXES = [
        "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
        "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi",
        "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega"
    ]
    PROCEDURAL_SUFFIXES = [str(i) for i in range(1, 30)]
    
    def get_procedural_system_name():
        """
        Generate a procedural name for systems (Greek letter + number for outlaw regions).
        Example: 'Sigma-7', 'Zeta-12'
        """
        prefix = random.choice(PROCEDURAL_PREFIXES)
        suffix = random.choice(PROCEDURAL_SUFFIXES)
        return f"{prefix}-{suffix}"

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

    # Step 2: Generate regions and their coordinates with spatial distribution
    all_regions, systems_per_region, planets_per_system = distribute_planets_and_systems(
        TOTAL_PLANETS, CORE_REGION_NAMES, OUTLAW_REGION_NAMES
    )

    num_core = len(CORE_REGION_NAMES)
    num_outlaw = len(OUTLAW_REGION_NAMES)
    core_coordinates, outlaw_coordinates = generate_region_coordinates(num_core, num_outlaw)

    seeded_regions = []
    core_region_objects = []
    outlaw_region_objects = []
    
    # Create core regions (near galactic center)
    for name, coords in zip(CORE_REGION_NAMES, core_coordinates):
        region = Region(
            name=name,
            universe_id=universe.id,
            x=coords[0],
            y=coords[1],
            z=coords[2],
        )
        seeded_regions.append(region)
        core_region_objects.append(region)
        db.add(region)
    
    # Create outlaw regions (on outer fringe)
    for name, coords in zip(OUTLAW_REGION_NAMES, outlaw_coordinates):
        region = Region(
            name=name,
            universe_id=universe.id,
            x=coords[0],
            y=coords[1],
            z=coords[2],
        )
        seeded_regions.append(region)
        outlaw_region_objects.append(region)
        db.add(region)
    db.flush()

    # Step 3: Seed Star Systems with faction assignments
    seeded_systems = []
    faction_star_system_map = {}  # Track faction stars for later use
    
    for region, system_count in zip(seeded_regions, systems_per_region):
        is_core = region.name in CORE_REGION_NAMES
        is_outlaw = region.name in OUTLAW_REGION_NAMES
        
        for i in range(system_count):
            # Assign faction stars to their specific regions
            system_name = None
            
            if is_core and region.name == "Forgeheart Dominion" and i == 0:
                system_name = "Forge Prime"
                faction_star_system_map["Forge Syndicate"] = system_name
            elif is_core and region.name == "Crystal Crown Sector" and i == 0:
                system_name = "Luminous Prime"
                faction_star_system_map["Luminous Accord"] = system_name
            elif is_core and region.name == "Ironclad Nexus" and i == 0:
                system_name = "Titanborn Prime"
                faction_star_system_map["Titanborn Consortium"] = system_name
            elif is_core and region.name == "Radiant Spire Alliance" and i == 0:
                system_name = "Unity Prime"
                faction_star_system_map["Hegemony of Unity"] = system_name
            elif is_core and region.name == "Cooperative Haven" and i == 0:
                system_name = "Collective Prime"
                faction_star_system_map["Stellar Collective"] = system_name
            elif is_outlaw and region.name == "Shadowrift Fringe" and i == 0:
                system_name = "Shadowveil"
                faction_star_system_map["Voidrunners Collective"] = system_name
            elif is_outlaw and region.name == "Eclipse Drift" and i == 0:
                system_name = "Dreadstone"
                faction_star_system_map["Ravagers of the Rift"] = system_name
            else:
                # Use available names or generate procedural names
                if CORE_STAR_SYSTEM_NAMES and is_core:
                    system_name = CORE_STAR_SYSTEM_NAMES.pop(0)
                else:
                    system_name = get_procedural_system_name()

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
    
    # Validate that we have matching system and planet counts
    if len(seeded_systems) != len(planets_per_system):
        print(f"⚠️  Warning: System count ({len(seeded_systems)}) doesn't match planet count ({len(planets_per_system)})")
        print(f"   This will result in missing planets. Truncating to {min(len(seeded_systems), len(planets_per_system))}")
    
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
    try:
        for idx, planet in enumerate(seeded_planets, 1):
            num_locations = calculate_num_locations(planet.radius)
            seed_locations_and_resources(db, planet, num_locations)
            db.commit()
            if idx % 50 == 0:
                print(f"   Seeded locations for {idx}/{len(seeded_planets)} planets...")
    except Exception as e:
        print(f"❌ Error seeding locations: {e}")
        db.rollback()
        raise
    
    print(f"\n✅ Universe seeding complete!")
    print(f"   Regions: {len(seeded_regions)} ({num_core} core, {num_outlaw} outlaw)")
    print(f"   Star Systems: {len(seeded_systems)}")
    print(f"   Planets: {len(seeded_planets)}")
    print(f"   Faction Hubs: {len(faction_star_system_map)}")
    print(f"   Factions: {', '.join(faction_star_system_map.keys())}")
    

if __name__ == "__main__":
    db = SessionLocal()
    try:
        print("🚀 Seeding the universe...")
        seed_universe(db)
    except Exception as e:
        import traceback
        print(f"An error occured during seeding: {traceback.format_exc()}")
    finally:
        db.close()