from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.inventory import Inventory
from app.models.company import Company
from app.models.good import Good

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/inventory/add")
def admin_add_inventory(
    company_id: int,
    good_id: int,
    quantity: int,
    db: Session = Depends(get_db),
):
    if quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be positive")

    company = db.query(Company).get(company_id)
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")

    good = db.query(Good).get(good_id)
    if not good:
        raise HTTPException(status_code=404, detail="Good not found")

    inventory = (
        db.query(Inventory)
        .filter(
            Inventory.company_id == company_id,
            Inventory.good_id == good_id,
        )
        .first()
    )

    if not inventory:
        inventory = Inventory(
            company_id=company_id,
            good_id=good_id,
            quantity=0,
        )
        db.add(inventory)

    inventory.quantity += quantity
    db.commit()

    return {
        "company_id": company_id,
        "good_id": good_id,
        "quantity_added": quantity,
        "new_quantity": inventory.quantity,
    }
