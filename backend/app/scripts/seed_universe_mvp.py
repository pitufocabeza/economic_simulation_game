import random
import uuid
import json

BIOMES = ["Temperate", "Barren", "Ice", "Volcanic", "Oceanic"]
RICHNESS = ["Poor", "Normal", "Rich"]

ORE_TABLE = {
    "Temperate": {"Poor": 25000, "Normal": 35000, "Rich": 45000},
    "Barren":    {"Poor": 30000, "Normal": 45000, "Rich": 55000},
    "Ice":       {"Poor": 20000, "Normal": 30000, "Rich": 35000},
    "Volcanic":  {"Poor": 50000, "Normal": 65000, "Rich": 80000},
}

RARE_ORE_TABLE = {
    "Temperate": {"Poor": 6000, "Normal": 8000, "Rich": 10000},
    "Barren":    {"Poor": 5000, "Normal": 7000, "Rich": 9000},
    "Ice":       {"Poor": 10000, "Normal": 12000, "Rich": 18000},
    "Volcanic":  {"Poor": 8000, "Normal": 10000, "Rich": 14000},
}


# def map_nodes(nodes):
# map_nodes(id, node_type, system_id nullable, x, y, metadata jsonb)
# map_edges(id, from_node, to_node, edge_type, base_cost, risk)

def generate_deposits(planet):
    deposits = []

    biome = planet["biome"]
    richness = random.choice(RICHNESS)

    # Ore (not for Oceanic)
    if biome in ORE_TABLE:
        deposits.append({
            "resource": "Ore",
            "richness": richness,
            "amount": ORE_TABLE[biome][richness]
        })

    # Rare Ore (chance-based, not for Oceanic)
    if biome in RARE_ORE_TABLE and random.random() < 0.6:
        richness = random.choice(RICHNESS)
        deposits.append({
            "resource": "Rare Ore",
            "richness": richness,
            "amount": RARE_ORE_TABLE[biome][richness]
        })

    # Biomass
    if biome in ["Temperate", "Oceanic"]:
        deposits.append({
            "resource": "Biomass",
            "richness": "Normal",
            "amount": random.randint(15000, 30000)
        })

    return deposits

def generate_planet():
    biome = random.choice(BIOMES)
    planet = {
        "id": str(uuid.uuid4()),
        "biome": biome,
        "radius": random.randint(300, 700),
    }
    planet["deposits"] = generate_deposits(planet)
    return planet

def generate_region(region_type, name):
    system_count = random.randint(4, 7)
    systems = []

    for i in range(system_count):
        system = {
            "id": str(uuid.uuid4()),
            "owned_id": str(uuid.uuid4()) if region_type == "Faction" else None,
            "name": f"{name}-SYS-{i+1}",
            "region_type": region_type,
            "planets": [generate_planet() for _ in range(random.randint(4, 7))]
        }
        systems.append(system)

    return systems

def generate_galaxy(seed=42):
    random.seed(seed)

    galaxy = {
        "id": str(uuid.uuid4()),
        "seed": seed,
        "regions": {
            "Core": generate_region("Faction", "CORE"),
            "Outlaw-Alpha": generate_region("Outlaw", "OUT-A"),
            "Outlaw-Beta": generate_region("Outlaw", "OUT-B"),
        }
    }

    return galaxy

if __name__ == "__main__":
    galaxy = generate_galaxy(seed=12345)
    print(json.dumps(galaxy, indent=2))
