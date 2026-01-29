from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from app.deps import get_db
from app.models.location import Location
from app.models.resource_deposit import ResourceDeposit
from app.models.planet import Planet

router = APIRouter(prefix="/tilemap", tags=["Tilemap"])


@router.get("/location/{location_id}")
def get_location_tilemap_info(location_id: int, db: Session = Depends(get_db)):
    """
    Get tilemap generation parameters for a specific location.
    
    Returns:
    - Grid dimensions (width, height)
    - Seed for procedural generation
    - Biome information
    - Resource data
    
    Godot will use this data to procedurally generate the tilemap on the client side.
    """
    # Fetch location
    location = db.scalar(select(Location).where(Location.id == location_id))
    if not location:
        raise HTTPException(status_code=404, detail="Location not found")
    
    # Fetch resources for this location
    resources = db.scalars(
        select(ResourceDeposit)
        .where(ResourceDeposit.location_id == location_id)
    ).all()
    
    resource_data = [
        {
            "good_name": res.resource_type,  # Changed from "type" to "good_name" for frontend compatibility
            "quantity": res.quantity,
            "rarity": res.rarity
        }
        for res in resources
    ]
    
    return {
        "location_id": location.id,
        "location_name": location.name,
        "planet_id": location.planet_id,
        "planet_name": location.planet.name if location.planet else "Unknown Planet",
        "biome": location.biome,
        "grid_width": location.grid_width,
        "grid_height": location.grid_height,
        "tilemap_seed": location.tilemap_seed,
        "elevation": location.z,
        "position": {
            "x": location.x,
            "y": location.y,
            "z": location.z
        },
        "resources": resource_data,
        "claimed": location.claimed_by_company_id is not None,
        "claimed_by": location.claimed_by_company_id
    }


@router.get("/planets")
def get_all_planets_with_locations(db: Session = Depends(get_db)):
    """
    Get all planets that have at least one location, with their first location ID.
    Used for planet navigation in Godot client.
    """
    # Get all planets with at least one location
    planets_query = (
        select(Planet, func.min(Location.id).label("first_location_id"))
        .join(Location, Location.planet_id == Planet.id)
        .group_by(Planet.id)
        .order_by(Planet.id)
    )
    
    results = db.execute(planets_query).all()
    
    planets_data = []
    for planet, first_location_id in results:
        planets_data.append({
            "planet_id": planet.id,
            "planet_name": planet.name,
            "biome": planet.biome,
            "first_location_id": first_location_id,
            "system_id": planet.star_system_id
        })
    
    return {"planets": planets_data}

