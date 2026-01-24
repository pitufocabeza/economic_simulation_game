from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.market_order import MarketOrder
from app.models.inventory import Inventory
from app.schemas.market_order import MarketOrderCreate, MarketOrderRead
from app.services.market import try_execute_order

router = APIRouter(prefix="/market", tags=["market"])


@router.post("/orders/{company_id}", response_model=MarketOrderRead)
def create_order(
    company_id: int,
    payload: MarketOrderCreate,
    db: Session = Depends(get_db),
):
    if payload.order_type not in ("buy", "sell"):
        raise HTTPException(status_code=400, detail="Invalid order type")

    if payload.order_type == "sell":
        inventory = (
            db.query(Inventory)
            .filter(
                Inventory.company_id == company_id,
                Inventory.good_id == payload.good_id,
            )
            .with_for_update()
            .first()
        )

        if not inventory:
            raise HTTPException(400, "No inventory")

        free_qty = inventory.quantity - inventory.reserved
        if free_qty < payload.quantity:
            raise HTTPException(400, "Not enough free inventory")

        # ✅ RESERVE
        inventory.reserved += payload.quantity


    order = MarketOrder(
        company_id=company_id,
        **payload.dict(),
    )

    db.add(order)
    db.commit()
    db.refresh(order)

    try_execute_order(db, order)

    return order


@router.get("/orders", response_model=list[MarketOrderRead])
def list_orders(db: Session = Depends(get_db)):
    orders = (
        db.query(MarketOrder)
        .join(MarketOrder.company)
        .join(MarketOrder.good)
        .filter(
            MarketOrder.status == "open",
            MarketOrder.quantity > 0,
        )
        .all()
    )

    return [
        {
            "id": o.id,
            "order_type": o.order_type,
            "quantity": o.quantity,
            "price_per_unit": o.price_per_unit,
            "status": o.status,
            "good_id": o.good_id,
            "good_name": o.good.name,
            "company_id": o.company_id,
            "company_name": o.company.name,
        }
        for o in orders
    ]


@router.post("/orders/{company_id}")
def place_order(company_id: int, order: MarketOrderCreate, db: Session = Depends(get_db)):
    if order.quantity <= 0 or order.price_per_unit <= 0:
        raise HTTPException(status_code=400, detail="Invalid order")

    # SELL validation ONLY
    if order.order_type == "sell":
        inventory = (
            db.query(Inventory)
            .filter(
                Inventory.company_id == company_id,
                Inventory.good_id == order.good_id,
            )
            .first()
        )
        if not inventory or inventory.quantity < order.quantity:
            raise HTTPException(400, "Not enough inventory")

    new_order = MarketOrder(
        company_id=company_id,
        good_id=order.good_id,
        order_type=order.order_type,
        quantity=order.quantity,
        price_per_unit=order.price_per_unit,
        status="open",
    )

    db.add(new_order)
    db.commit()

    try_execute_order(db, new_order)

    return {
    "status": "ok",
    "order_id": new_order.id,
    }

@router.post("/orders/{order_id}/cancel")
def cancel_order(
    order_id: int,
    company_id: int,
    db: Session = Depends(get_db),
):
    order = db.query(MarketOrder).get(order_id)

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # 🔒 ownership check
    if order.company_id != company_id:
        raise HTTPException(status_code=403, detail="Not your order")

    # 🔒 lifecycle check
    if order.status != "open":
        raise HTTPException(status_code=404, detail="Order not open")

    # 🔓 RELEASE RESERVED INVENTORY (Option B)
    if order.order_type == "sell":
        inventory = (
            db.query(Inventory)
            .filter(
                Inventory.company_id == order.company_id,
                Inventory.good_id == order.good_id,
            )
            .with_for_update()
            .first()
        )

        if not inventory:
            raise HTTPException(500, "Inventory missing during cancel")

        inventory.reserved -= order.quantity

        if inventory.reserved < 0:
            # defensive check — should never happen
            inventory.reserved = 0

    order.status = "cancelled"
    db.commit()

    return {"status": "cancelled", "order_id": order_id}
