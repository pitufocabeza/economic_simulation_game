from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.location import Location
from app.models.company import Company
from app.models.resource_deposit import ResourceDeposit
from app.schemas.location import LocationRead

router = APIRouter(prefix="/locations", tags=["locations"])

@router.get("/", response_model=list[LocationRead])
def list_locations(db: Session = Depends(get_db)):
    locations = db.query(Location).all()

    result = []

    for loc in locations:
        deposits = (
            db.query(ResourceDeposit)
            .filter(ResourceDeposit.location_id == loc.id)
            .all()
        )

        result.append({
            "id": loc.id,
            "name": loc.name,
            "x": loc.x,
            "y": loc.y,
            "z": loc.z,
            "biome": loc.biome,
            "claimed": loc.claimed_by_company_id is not None,
            "resources": [
                {
                    "good_id": d.good_id,
                    "remaining_amount": d.remaining_amount,
                }
                for d in deposits
            ],
        })

    return result

@router.get("/{location_id}", response_model=LocationRead)
def get_location(location_id: int, db: Session = Depends(get_db)):
    """Get a single location by ID with its resources"""
    location = db.query(Location).filter(Location.id == location_id).first()
    
    if not location:
        raise HTTPException(404, "Location not found")
    
    deposits = (
        db.query(ResourceDeposit)
        .filter(ResourceDeposit.location_id == location.id)
        .all()
    )
    
    return {
        "id": location.id,
        "name": location.name,
        "planet_id": location.planet_id,
        "x": location.x,
        "y": location.y,
        "z": location.z,
        "biome": location.biome,
        "grid_width": location.grid_width,
        "grid_height": location.grid_height,
        "tilemap_seed": location.tilemap_seed,
        "claimed": location.claimed_by_company_id is not None,
        "claimed_by_company_id": location.claimed_by_company_id,
        "resources": [
            {
                "resource_type": d.resource_type,
                "quantity": d.quantity,
                "rarity": d.rarity,
            }
            for d in deposits
        ],
    }

@router.post("/{location_id}/claim")
def claim_location(
    location_id: int,
    company_id: int,
    db: Session = Depends(get_db),
):
    location = (
        db.query(Location)
        .filter(Location.id == location_id)
        .with_for_update()
        .first()
    )

    if not location:
        raise HTTPException(404, "Location not found")

    if location.claimed_by_company_id is not None:
        raise HTTPException(400, "Location already claimed")

    company = db.query(Company).get(company_id)

    if not company:
        raise HTTPException(404, "Company not found")

    if company.home_location_id is not None:
        raise HTTPException(400, "Company already has a home location")

    # CLAIM
    location.claimed_by_company_id = company.id
    location.claimed_at = datetime.utcnow()

    company.home_location_id = location.id

    db.commit()

    return {"status": "claimed", "location_id": location_id}
