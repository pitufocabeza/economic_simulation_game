"""
Clear universe data while preserving goods, recipes, and other static data.
"""
from sqlalchemy import delete, text
from app.db import SessionLocal
from app.models.resource_deposit import ResourceDeposit
from app.models.location import Location
from app.models.planet import Planet
from app.models.star_system import StarSystem
from app.models.region import Region
from app.models.universe import Universe


def clear_universe_data(db):
    """
    Delete all universe-related data in the correct order to respect foreign keys.
    Preserves goods, recipes, building blueprints, and other static data.
    """
    print("Clearing universe data...")
    
    try:
        # Single TRUNCATE command with CASCADE handles everything
        print("  - Truncating universe tables (this may take 30-60 seconds)...")
        db.execute(text("""
            TRUNCATE TABLE 
                universes,
                regions,
                star_systems,
                planets,
                locations,
                resource_deposits
            RESTART IDENTITY CASCADE;
        """))
        
        db.commit()
        print("\n✅ Universe data cleared successfully!")
        
    except Exception as e:
        db.rollback()
        raise e


if __name__ == "__main__":
    db = SessionLocal()
    try:
        clear_universe_data(db)
    except Exception as e:
        import traceback
        print(f"An error occurred: {traceback.format_exc()}")
        db.rollback()
    finally:
        db.close()
