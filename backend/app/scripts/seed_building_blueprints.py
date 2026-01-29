"""
Seed building blueprints for the game

Run this script to populate the database with building blueprints:
    python -m app.scripts.seed_building_blueprints
"""

from sqlalchemy.orm import Session
from app.db import SessionLocal
from app.models.building_blueprint import BuildingBlueprint


def seed_building_blueprints(db: Session):
    """Create initial building blueprints"""
    
    blueprints = [
        # Mining buildings
        {
            "name": "Small Mine",
            "role": "Mining",
            "description": "Extracts raw resources from deposits",
            "category": "Extraction",
            "grid_width": 2,
            "grid_height": 2,
            "sprite_path": "res://assets/buildings/mine_small.png",
            "max_capacity": 100,
            "base_efficiency": 1.0,
            "energy_production": 0,
            "energy_consumption": 5,
            "operating_cost": {},
            "supported_goods": ["Iron Ore", "Coal", "Copper Ore", "Gold", "Uranium"],
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 50, "Reinforced Concrete": 100}
        },
        {
            "name": "Large Mine",
            "role": "Mining",
            "description": "High-capacity resource extraction facility",
            "category": "Extraction",
            "grid_width": 3,
            "grid_height": 3,
            "sprite_path": "res://assets/buildings/mine_large.png",
            "max_capacity": 500,
            "base_efficiency": 1.5,
            "energy_production": 0,
            "energy_consumption": 15,
            "operating_cost": {},
            "supported_goods": ["Iron Ore", "Coal", "Copper Ore", "Gold", "Uranium"],
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 200, "Reinforced Concrete": 400, "Circuit Board": 50}
        },
        
        # Processing buildings
        {
            "name": "Smelter",
            "role": "Processing",
            "description": "Converts ore into refined metals",
            "category": "Processing",
            "grid_width": 3,
            "grid_height": 2,
            "sprite_path": "res://assets/buildings/smelter.png",
            "max_capacity": 200,
            "base_efficiency": 1.0,
            "energy_production": 0,
            "energy_consumption": 20,
            "operating_cost": {"Coal": 5},
            "supported_goods": ["Steel Plate", "Copper Ore", "Titanium Alloy"],
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 150, "Reinforced Concrete": 200, "Titanium Alloy": 50}
        },
        {
            "name": "Factory",
            "role": "Manufacturing",
            "description": "Produces complex goods from raw materials",
            "category": "Manufacturing",
            "grid_width": 4,
            "grid_height": 3,
            "sprite_path": "res://assets/buildings/factory.png",
            "max_capacity": 300,
            "base_efficiency": 1.0,
            "energy_production": 0,
            "energy_consumption": 30,
            "operating_cost": {},
            "supported_goods": ["Circuit Board", "Control Unit", "Plastic Polymers"],
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 300, "Reinforced Concrete": 400, "Circuit Board": 100}
        },
        
        # Storage buildings
        {
            "name": "Small Warehouse",
            "role": "Storage",
            "description": "Stores goods and resources",
            "category": "Logistics",
            "grid_width": 2,
            "grid_height": 2,
            "sprite_path": "res://assets/buildings/warehouse_small.png",
            "max_capacity": 1000,
            "base_efficiency": 1.0,
            "energy_production": 0,
            "energy_consumption": 2,
            "operating_cost": {},
            "supported_goods": None,  # Accepts all goods
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 100, "Reinforced Concrete": 150}
        },
        {
            "name": "Large Warehouse",
            "role": "Storage",
            "description": "High-capacity storage facility",
            "category": "Logistics",
            "grid_width": 4,
            "grid_height": 4,
            "sprite_path": "res://assets/buildings/warehouse_large.png",
            "max_capacity": 5000,
            "base_efficiency": 1.0,
            "energy_production": 0,
            "energy_consumption": 5,
            "operating_cost": {},
            "supported_goods": None,
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 400, "Reinforced Concrete": 600}
        },
        
        # Energy buildings
        {
            "name": "Coal Power Plant",
            "role": "Energy",
            "description": "Generates electricity from coal",
            "category": "Energy",
            "grid_width": 3,
            "grid_height": 3,
            "sprite_path": "res://assets/buildings/power_coal.png",
            "max_capacity": 0,
            "base_efficiency": 1.0,
            "energy_production": 50,
            "energy_consumption": 0,
            "operating_cost": {"Coal": 10},
            "supported_goods": None,
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 250, "Reinforced Concrete": 400, "Control Unit": 100}
        },
        {
            "name": "Solar Panel Array",
            "role": "Energy",
            "description": "Clean renewable energy generation",
            "category": "Energy",
            "grid_width": 4,
            "grid_height": 2,
            "sprite_path": "res://assets/buildings/solar_array.png",
            "max_capacity": 0,
            "base_efficiency": 0.8,  # Weather dependent
            "energy_production": 20,
            "energy_consumption": 0,
            "operating_cost": {},
            "supported_goods": None,
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 150, "Quartz": 200, "Circuit Board": 100}
        },
        {
            "name": "Nuclear Reactor",
            "role": "Energy",
            "description": "High-output nuclear power generation",
            "category": "Energy",
            "grid_width": 5,
            "grid_height": 5,
            "sprite_path": "res://assets/buildings/nuclear_reactor.png",
            "max_capacity": 0,
            "base_efficiency": 1.0,
            "energy_production": 200,
            "energy_consumption": 5,
            "operating_cost": {"Uranium": 1},
            "supported_goods": None,
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 1000, "Reinforced Concrete": 2000, "Uranium": 100, "Control Unit": 500}
        },
        
        # Research & Special
        {
            "name": "Research Lab",
            "role": "Research",
            "description": "Unlocks new technologies and improves efficiency",
            "category": "Special",
            "grid_width": 3,
            "grid_height": 3,
            "sprite_path": "res://assets/buildings/research_lab.png",
            "max_capacity": 0,
            "base_efficiency": 1.0,
            "energy_production": 0,
            "energy_consumption": 15,
            "operating_cost": {"Circuit Board": 5, "Exotic Crystals": 2},
            "supported_goods": None,
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 200, "Reinforced Concrete": 300, "Circuit Board": 200}
        },
        
        # Logistics
        {
            "name": "Spaceport",
            "role": "Transport",
            "description": "Launches cargo to other locations",
            "category": "Logistics",
            "grid_width": 5,
            "grid_height": 4,
            "sprite_path": "res://assets/buildings/spaceport.png",
            "max_capacity": 1000,
            "base_efficiency": 1.0,
            "energy_production": 0,
            "energy_consumption": 40,
            "operating_cost": {"Hydrogen": 20},
            "supported_goods": None,
            "production_recipes": None,
            "construction_cost": {"Steel Plate": 500, "Reinforced Concrete": 800, "Circuit Board": 300, "Titanium Alloy": 200}
        },
    ]
    
    # Check if blueprints already exist
    existing_count = db.query(BuildingBlueprint).count()
    if existing_count > 0:
        print(f"Database already has {existing_count} building blueprints. Skipping seed.")
        return
    
    # Create blueprints
    for blueprint_data in blueprints:
        blueprint = BuildingBlueprint(**blueprint_data)
        db.add(blueprint)
    
    db.commit()
    print(f"Successfully seeded {len(blueprints)} building blueprints!")


if __name__ == "__main__":
    db = SessionLocal()
    try:
        seed_building_blueprints(db)
    finally:
        db.close()
