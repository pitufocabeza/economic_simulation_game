from sqlalchemy.orm import Session
from app.models.building_blueprint import BuildingBlueprint
from app.db import SessionLocal


# Function to seed building blueprints
def seed_building_blueprints(session: Session):
    # Define building blueprints to insert
    building_blueprints = [
        {
            "name": "Basic Smelter",
            "role": "Smelter",
            "category": "Processing",
            "description": "Processes raw ores into refined metals.",
            "max_capacity": 200,
            "base_efficiency": 1.0,
            "energy_production": 0,
            "energy_consumption": 10,
            "operating_cost": {"Coal": 5},
            "supported_goods": ["Iron Ore", "Copper Ore"],
            "production_recipes": [101, 102],
            "construction_cost": {"Steel": 40, "Concrete": 20}
        },
        {
            "name": "Solar Farm",
            "role": "Energy Producer",
            "category": "Energy",
            "description": "Generates clean energy using solar panels.",
            "max_capacity": 0,
            "base_efficiency": 1.0,
            "energy_production": 50,
            "energy_consumption": 0,
            "operating_cost": None,
            "supported_goods": None,
            "production_recipes": None,
            "construction_cost": {"Steel": 30, "Silicon": 10}
        },
        {
            "name": "Warehouse",
            "role": "Storage",
            "category": "Logistics",
            "description": "Stores goods and resources for logistics management.",
            "max_capacity": 500,
            "base_efficiency": 1.0,
            "energy_production": 0,
            "energy_consumption": 0,
            "operating_cost": None,
            "supported_goods": ["Iron Ore", "Steel", "Copper"],
            "production_recipes": None,
            "construction_cost": {"Wood": 10, "Steel": 5}
        },
        {
            "name": "Coal Power Plant",
            "role": "Energy Producer",
            "category": "Energy",
            "description": "Generates energy by burning coal.",
            "max_capacity": 0,
            "base_efficiency": 1.0,
            "energy_production": 100,
            "energy_consumption": 0,
            "operating_cost": {"Coal": 10},
            "supported_goods": None,
            "production_recipes": None,
            "construction_cost": {"Steel": 70, "Concrete": 50}
        },
        {
            "name": "Advanced Factory",
            "role": "Factory",
            "category": "Processing",
            "description": "A highly efficient factory for advanced goods production.",
            "max_capacity": 300,
            "base_efficiency": 1.5,
            "energy_production": 0,
            "energy_consumption": 50,
            "operating_cost": {"Iron": 5, "Copper": 3},
            "supported_goods": ["Electronic Components"],
            "production_recipes": [201, 202, 203],
            "construction_cost": {"Steel": 100, "Concrete": 70, "Glass": 20}
        },
    ]

    # Insert each blueprint
    for blueprint_data in building_blueprints:
        blueprint = BuildingBlueprint(**blueprint_data)
        session.add(blueprint)

    # Commit the session
    session.commit()
    print("Building blueprints seeded successfully!")


if __name__ == "__main__":
    # Obtain a database session
    db = SessionLocal()
    try:
        seed_building_blueprints(db)
    finally:
        db.close()