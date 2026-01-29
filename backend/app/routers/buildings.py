from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select
from typing import List
from pydantic import BaseModel

from app.deps import get_db
from app.models.building import Building
from app.models.building_blueprint import BuildingBlueprint
from app.models.location import Location
from app.models.company import Company

router = APIRouter(prefix="/buildings", tags=["buildings"])


# Schemas
class BuildingPlacementRequest(BaseModel):
    blueprint_id: int
    grid_x: int
    grid_y: int
    rotation: int = 0  # 0, 90, 180, 270


class BuildingResponse(BaseModel):
    id: int
    blueprint_id: int
    name: str
    owner_company_id: int
    location_id: int
    grid_x: int
    grid_y: int
    rotation: int
    status: str
    current_capacity: int
    current_efficiency: float
    
    class Config:
        from_attributes = True


class BuildingBlueprintResponse(BaseModel):
    id: int
    name: str
    role: str
    description: str | None
    category: str
    grid_width: int
    grid_height: int
    sprite_path: str | None
    construction_cost: dict
    energy_production: int
    energy_consumption: int
    max_capacity: int
    base_efficiency: float
    
    class Config:
        from_attributes = True


# Endpoints

@router.get("/blueprints", response_model=List[BuildingBlueprintResponse])
def list_building_blueprints(db: Session = Depends(get_db)):
    """Get all available building blueprints"""
    blueprints = db.scalars(select(BuildingBlueprint)).all()
    return blueprints


@router.get("/blueprints/{blueprint_id}", response_model=BuildingBlueprintResponse)
def get_building_blueprint(blueprint_id: int, db: Session = Depends(get_db)):
    """Get a specific building blueprint"""
    blueprint = db.scalar(
        select(BuildingBlueprint).where(BuildingBlueprint.id == blueprint_id)
    )
    if not blueprint:
        raise HTTPException(status_code=404, detail="Blueprint not found")
    return blueprint


@router.get("/location/{location_id}", response_model=List[BuildingResponse])
def list_buildings_at_location(location_id: int, db: Session = Depends(get_db)):
    """Get all buildings at a specific location"""
    buildings = db.scalars(
        select(Building).where(Building.location_id == location_id)
    ).all()
    return buildings


@router.post("/location/{location_id}", response_model=BuildingResponse)
def place_building(
    location_id: int,
    placement: BuildingPlacementRequest,
    company_id: int,  # TODO: Get from auth token
    db: Session = Depends(get_db),
):
    """Place a new building at a location"""
    
    # Verify location exists
    location = db.scalar(select(Location).where(Location.id == location_id))
    if not location:
        raise HTTPException(status_code=404, detail="Location not found")
    
    # Verify company owns the location
    if location.claimed_by_company_id != company_id:
        raise HTTPException(
            status_code=403, 
            detail="Company does not own this location"
        )
    
    # Verify blueprint exists
    blueprint = db.scalar(
        select(BuildingBlueprint).where(BuildingBlueprint.id == placement.blueprint_id)
    )
    if not blueprint:
        raise HTTPException(status_code=404, detail="Blueprint not found")
    
    # Validate rotation
    if placement.rotation not in [0, 90, 180, 270]:
        raise HTTPException(status_code=400, detail="Rotation must be 0, 90, 180, or 270")
    
    # Check grid bounds
    building_width = blueprint.grid_width
    building_height = blueprint.grid_height
    
    # Swap dimensions if rotated 90 or 270 degrees
    if placement.rotation in [90, 270]:
        building_width, building_height = building_height, building_width
    
    if (placement.grid_x < 0 or placement.grid_y < 0 or
        placement.grid_x + building_width > location.grid_width or
        placement.grid_y + building_height > location.grid_height):
        raise HTTPException(
            status_code=400, 
            detail=f"Building placement out of bounds. Location grid: {location.grid_width}x{location.grid_height}"
        )
    
    # Check for collisions with existing buildings
    existing_buildings = db.scalars(
        select(Building).where(Building.location_id == location_id)
    ).all()
    
    if has_collision(placement, blueprint, existing_buildings, db):
        raise HTTPException(
            status_code=400, 
            detail="Building placement collides with existing building"
        )
    
    # TODO: Check construction cost and deduct resources
    
    # Create the building
    building = Building(
        blueprint_id=placement.blueprint_id,
        name=blueprint.name,  # Can be customized later
        owner_company_id=company_id,
        location_id=location_id,
        grid_x=placement.grid_x,
        grid_y=placement.grid_y,
        rotation=placement.rotation,
        status="constructing",
        current_capacity=0,
        current_efficiency=blueprint.base_efficiency,
    )
    
    db.add(building)
    db.commit()
    db.refresh(building)
    
    return building


@router.delete("/{building_id}")
def demolish_building(
    building_id: int,
    company_id: int,  # TODO: Get from auth token
    db: Session = Depends(get_db),
):
    """Demolish a building"""
    
    building = db.scalar(select(Building).where(Building.id == building_id))
    if not building:
        raise HTTPException(status_code=404, detail="Building not found")
    
    # Verify ownership
    if building.owner_company_id != company_id:
        raise HTTPException(
            status_code=403, 
            detail="Company does not own this building"
        )
    
    # TODO: Refund some resources, stop production, etc.
    
    db.delete(building)
    db.commit()
    
    return {"message": "Building demolished", "building_id": building_id}


def has_collision(
    placement: BuildingPlacementRequest,
    blueprint: BuildingBlueprint,
    existing_buildings: List[Building],
    db: Session,
) -> bool:
    """Check if a building placement collides with existing buildings"""
    
    # Calculate building footprint
    building_width = blueprint.grid_width
    building_height = blueprint.grid_height
    
    # Swap dimensions if rotated
    if placement.rotation in [90, 270]:
        building_width, building_height = building_height, building_width
    
    new_x1 = placement.grid_x
    new_y1 = placement.grid_y
    new_x2 = placement.grid_x + building_width
    new_y2 = placement.grid_y + building_height
    
    for existing in existing_buildings:
        # Get existing building's blueprint for dimensions
        existing_blueprint = db.scalar(
            select(BuildingBlueprint).where(
                BuildingBlueprint.id == existing.blueprint_id
            )
        )
        if not existing_blueprint:
            continue
        
        existing_width = existing_blueprint.grid_width
        existing_height = existing_blueprint.grid_height
        
        # Swap if rotated
        if existing.rotation in [90, 270]:
            existing_width, existing_height = existing_height, existing_width
        
        ex_x1 = existing.grid_x
        ex_y1 = existing.grid_y
        ex_x2 = existing.grid_x + existing_width
        ex_y2 = existing.grid_y + existing_height
        
        # Check for overlap (AABB collision)
        if not (new_x2 <= ex_x1 or new_x1 >= ex_x2 or 
                new_y2 <= ex_y1 or new_y1 >= ex_y2):
            return True  # Collision detected
    
    return False
