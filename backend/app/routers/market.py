from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.deps import get_db
from app.models.market_order import MarketOrder
from app.models.market_trade import MarketTrade
from app.models.inventory import Inventory
from app.schemas.market_order import MarketOrderCreate, MarketOrderRead
from app.services.market import try_execute_order

router = APIRouter(prefix="/market", tags=["market"])


# ============================================================
# CREATE ORDER (BUY / SELL)
# ============================================================
@router.post("/orders/{company_id}", response_model=MarketOrderRead)
def create_order(
    company_id: int,
    payload: MarketOrderCreate,
    db: Session = Depends(get_db),
):
    if payload.order_type not in ("buy", "sell"):
        raise HTTPException(status_code=400, detail="Invalid order type")

    # 🔒 SELL → reserve inventory
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
            raise HTTPException(status_code=400, detail="No inventory")

        free_qty = inventory.quantity - inventory.reserved
        if free_qty < payload.quantity:
            raise HTTPException(status_code=400, detail="Not enough free inventory")

        inventory.reserved += payload.quantity

    order = MarketOrder(
        company_id=company_id,
        **payload.dict(),
    )

    db.add(order)
    db.flush()  # 🔑 REQUIRED so order.id exists but no commit yet

    # ⚙️ match + execute (NO commit inside!)
    try_execute_order(db, order)

    db.commit()
    db.refresh(order)

    return {
    "id": order.id,
    "order_type": order.order_type,
    "quantity": order.quantity,
    "price_per_unit": order.price_per_unit,
    "status": order.status,
    "good_id": order.good_id,
    "good_name": order.good.name,
    "company_id": order.company_id,
    "company_name": order.company.name,
}



# ============================================================
# LIST OPEN ORDERS
# ============================================================
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


# ============================================================
# CANCEL ORDER
# ============================================================
@router.post("/orders/{order_id}/cancel")
def cancel_order(
    order_id: int,
    company_id: int,
    db: Session = Depends(get_db),
):
    order = db.query(MarketOrder).get(order_id)

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.company_id != company_id:
        raise HTTPException(status_code=403, detail="Not your order")

    if order.status != "open":
        raise HTTPException(status_code=400, detail="Order not open")

    # 🔓 release reserved inventory
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
            raise HTTPException(status_code=500, detail="Inventory missing")

        inventory.reserved -= order.quantity
        if inventory.reserved < 0:
            inventory.reserved = 0

    order.status = "cancelled"
    db.commit()

    return {"status": "cancelled", "order_id": order_id}


# ============================================================
# ORDER BOOK
# ============================================================
@router.get("/orderbook/{good_id}")
def get_order_book(good_id: int, db: Session = Depends(get_db)):
    buys = (
        db.query(
            MarketOrder.price_per_unit.label("price"),
            func.sum(MarketOrder.quantity).label("quantity"),
        )
        .filter(
            MarketOrder.good_id == good_id,
            MarketOrder.order_type == "buy",
            MarketOrder.status == "open",
        )
        .group_by(MarketOrder.price_per_unit)
        .order_by(MarketOrder.price_per_unit.desc())
        .all()
    )

    sells = (
        db.query(
            MarketOrder.price_per_unit.label("price"),
            func.sum(MarketOrder.quantity).label("quantity"),
        )
        .filter(
            MarketOrder.good_id == good_id,
            MarketOrder.order_type == "sell",
            MarketOrder.status == "open",
        )
        .group_by(MarketOrder.price_per_unit)
        .order_by(MarketOrder.price_per_unit.asc())
        .all()
    )

    return {
        "buy": [{"price": b.price, "quantity": b.quantity} for b in buys],
        "sell": [{"price": s.price, "quantity": s.quantity} for s in sells],
    }


# ============================================================
# MARKET STATS
# ============================================================
@router.get("/stats/{good_id}")
def get_market_stats(good_id: int, db: Session = Depends(get_db)):
    last_trade = (
        db.query(MarketTrade)
        .filter(MarketTrade.good_id == good_id)
        .order_by(MarketTrade.created_at.desc())
        .first()
    )

    last_price = last_trade.price_per_unit if last_trade else None

    best_bid = (
        db.query(func.max(MarketOrder.price_per_unit))
        .filter(
            MarketOrder.good_id == good_id,
            MarketOrder.order_type == "buy",
            MarketOrder.status == "open",
        )
        .scalar()
    )

    best_ask = (
        db.query(func.min(MarketOrder.price_per_unit))
        .filter(
            MarketOrder.good_id == good_id,
            MarketOrder.order_type == "sell",
            MarketOrder.status == "open",
        )
        .scalar()
    )

    spread = (
        best_ask - best_bid
        if best_bid is not None and best_ask is not None
        else None
    )

    return {
        "last_price": last_price,
        "best_bid": best_bid,
        "best_ask": best_ask,
        "spread": spread,
    }


# ============================================================
# CANDLES
# ============================================================
@router.get("/candles/{good_id}")
def get_candles(good_id: int, minutes: int = 60, db: Session = Depends(get_db)):
    bucket = func.date_trunc("minute", MarketTrade.created_at)

    aggregates = (
        db.query(
            bucket.label("time"),
            func.min(MarketTrade.price_per_unit).label("low"),
            func.max(MarketTrade.price_per_unit).label("high"),
            func.sum(MarketTrade.quantity).label("volume"),
            func.min(MarketTrade.created_at).label("open_time"),
            func.max(MarketTrade.created_at).label("close_time"),
        )
        .filter(MarketTrade.good_id == good_id)
        .group_by(bucket)
        .order_by(bucket.desc())
        .limit(minutes)
        .all()
    )

    candles = []
    for row in aggregates:
        open_price = (
            db.query(MarketTrade.price_per_unit)
            .filter(
                MarketTrade.good_id == good_id,
                MarketTrade.created_at == row.open_time,
            )
            .scalar()
        )

        close_price = (
            db.query(MarketTrade.price_per_unit)
            .filter(
                MarketTrade.good_id == good_id,
                MarketTrade.created_at == row.close_time,
            )
            .scalar()
        )

        candles.append({
            "time": row.time,
            "open": open_price,
            "high": row.high,
            "low": row.low,
            "close": close_price,
            "volume": row.volume,
        })

    return candles
