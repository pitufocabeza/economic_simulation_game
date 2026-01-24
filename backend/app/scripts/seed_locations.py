import random

from app.db import SessionLocal
from app.models.location import Location
from app.models.resource_deposit import ResourceDeposit
from app.models.good import Good


# -------------------------
# CONFIG
# -------------------------

NUM_LOCATIONS = 30

BIOMES = ["plains", "forest", "mountains", "desert"]

# biome -> [(good_name, amount)]
BIOME_RESOURCES = {
    "plains": [
        ("Food Crops", 5000),
        ("Copper Ore", 2000),
    ],
    "forest": [
        ("Wood", 6000),
        ("Food Crops", 3000),
    ],
    "mountains": [
        ("Iron Ore", 8000),
        ("Copper Ore", 4000),
    ],
    "desert": [
        ("Silicate Ore", 7000),
    ],
}


def run():
    db = SessionLocal()

    try:
        print("⚠️ Clearing existing locations and deposits...")
        db.query(ResourceDeposit).delete()
        db.query(Location).delete()
        db.commit()

        print("📦 Loading goods from DB...")
        goods = db.query(Good).all()
        goods_by_name = {g.name: g.id for g in goods}

        # sanity check
        for biome, resources in BIOME_RESOURCES.items():
            for name, _ in resources:
                if name not in goods_by_name:
                    raise RuntimeError(
                        f"Missing good '{name}' in database. "
                        f"Create it via Swagger first."
                    )

        print("🌍 Seeding locations...")
        for i in range(NUM_LOCATIONS):
            biome = random.choice(BIOMES)

            location = Location(
                name=f"Location {i + 1}",
                biome=biome,
                x=random.uniform(0, 1000),
                y=random.uniform(0, 1000),
                z=random.uniform(0, 1000),
                claimed_by_company_id=None,
            )

            db.add(location)
            db.flush()  # get location.id

            for good_name, amount in BIOME_RESOURCES[biome]:
                db.add(
                    ResourceDeposit(
                        location_id=location.id,
                        good_id=goods_by_name[good_name],
                        total_amount=amount,
                        remaining_amount=amount,
                    )
                )

        db.commit()
        print("✅ Locations and resources seeded successfully.")

    finally:
        db.close()


if __name__ == "__main__":
    run()
