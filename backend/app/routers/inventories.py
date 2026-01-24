from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.inventory import Inventory
from app.schemas.inventory import InventoryRead

router = APIRouter(prefix="/inventories", tags=["inventories"])


@router.get("/", response_model=list[InventoryRead])
def list_inventories(db: Session = Depends(get_db)):
    return db.query(Inventory).all()


@router.get("/company/{company_id}", response_model=list[InventoryRead])
def company_inventory(company_id: int, db: Session = Depends(get_db)):
    return (
        db.query(Inventory)
        .filter(Inventory.company_id == company_id)
        .all()
    )
