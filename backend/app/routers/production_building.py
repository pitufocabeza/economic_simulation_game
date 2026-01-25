from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.production_building import ProductionBuilding
from app.models.location import Location
from app.models.inventory import Inventory

router = APIRouter(
    prefix="/production-buildings",
    tags=["production"]
)


@router.post("/")
def create_production_building(
    company_id: int,
    location_id: int,
    input_good_id: int,
    output_good_id: int,
    input_per_hour: float,
    output_per_hour: float,
    db: Session = Depends(get_db),
):
    location = db.query(Location).get(location_id)

    if not location:
        raise HTTPException(404, "Location not found")

    if location.claimed_by_company_id != company_id:
        raise HTTPException(403, "You do not own this location")

    # Optional: ensure input inventory exists (can be 0)
    inventory = (
        db.query(Inventory)
        .filter(
            Inventory.company_id == company_id,
            Inventory.good_id == input_good_id,
        )
        .first()
    )

    if not inventory:
        inventory = Inventory(
            company_id=company_id,
            good_id=input_good_id,
            quantity=0,
            reserved=0,
        )
        db.add(inventory)

    building = ProductionBuilding(
        company_id=company_id,
        location_id=location_id,
        input_good_id=input_good_id,
        output_good_id=output_good_id,
        input_per_hour=input_per_hour,
        output_per_hour=output_per_hour,
        active=True,
    )

    db.add(building)
    db.commit()
    db.refresh(building)

    return building
