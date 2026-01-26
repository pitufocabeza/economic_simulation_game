from sqlalchemy.orm import Session
from app.models.good import Good
from app.db import SessionLocal

# Define all raw resources with category and rarity
RAW_RESOURCES = [
    # **Metals**
    {"name": "Iron Ore", "category": "metal", "rarity": "common"},
    {"name": "Copper Ore", "category": "metal", "rarity": "common"},
    {"name": "Titanium Ore", "category": "metal", "rarity": "rare"},
    {"name": "Rare Earth Elements", "category": "metal", "rarity": "rare"},
    {"name": "Gold", "category": "metal", "rarity": "rare"},
    {"name": "Quartz", "category": "metal", "rarity": "common"},

    # **Energy**
    {"name": "Hydrogen", "category": "energy", "rarity": "common"},
    {"name": "Helium-3", "category": "energy", "rarity": "exotic"},
    {"name": "Geothermal Energy", "category": "energy", "rarity": "common"},
    {"name": "Uranium", "category": "energy", "rarity": "rare"},
    {"name": "Coal", "category": "energy", "rarity": "common"},

    # **Organic**
    {"name": "Medicinal Plants", "category": "organic", "rarity": "rare"},
    {"name": "Biofuel", "category": "organic", "rarity": "common"},
    {"name": "Wood", "category": "organic", "rarity": "common"},
    {"name": "Crops", "category": "organic", "rarity": "common"},

    # **Gaseous**
    {"name": "Methane", "category": "gaseous", "rarity": "common"},
    {"name": "Oxygen", "category": "gaseous", "rarity": "common"},
    {"name": "Carbon Dioxide", "category": "gaseous", "rarity": "common"},
    {"name": "Nitrogen", "category": "gaseous", "rarity": "common"},
    {"name": "Helium", "category": "gaseous", "rarity": "rare"},

    # **Chemical**
    {"name": "Ammonia", "category": "chemical", "rarity": "common"},
    {"name": "Sulfuric Acid", "category": "chemical", "rarity": "common"},
    {"name": "Nitrous Oxide", "category": "chemical", "rarity": "rare"},
    {"name": "Phosphates", "category": "chemical", "rarity": "common"},
    {"name": "Chlorine", "category": "chemical", "rarity": "common"},

    # **Exotic**
    {"name": "Exotic Crystals", "category": "exotic", "rarity": "rare"},
    {"name": "Dark Matter", "category": "exotic", "rarity": "exotic"},

    # **Construction and Other**
    {"name": "Water", "category": "other", "rarity": "common"},
    {"name": "Limestone", "category": "other", "rarity": "common"},
    {"name": "Soil", "category": "other", "rarity": "common"},
]

def seed_resources():
    """Seed raw resources into the goods table."""
    db: Session = SessionLocal()

    try:
        # Insert each raw resource
        for resource in RAW_RESOURCES:
            # Check if the resource already exists (avoid duplicates)
            existing = db.query(Good).filter(Good.name == resource["name"]).first()
            if existing:
                print(f"Resource '{resource['name']}' already exists. Skipping...")
                continue
            
            # Create and add the new resource
            new_good = Good(
                name=resource["name"],
                category=resource["category"],
                rarity=resource["rarity"],
            )
            db.add(new_good)
            print(f"Added resource: {resource['name']}")
        
        db.commit()  # Commit all changes
        print("Raw resources seeded successfully.")
    except Exception as e:
        db.rollback()  # Rollback on error
        print(f"An error occurred: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_resources()