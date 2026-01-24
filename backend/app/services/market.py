from sqlalchemy.orm import Session

from app.models.market_order import MarketOrder
from app.models.inventory import Inventory
from app.models.company import Company
from app.models.market_trade import MarketTrade


def try_execute_order(db: Session, incoming: MarketOrder):
    if incoming.status != "open":
        return

    if incoming.order_type == "buy":
        match_buy_order(db, incoming)
    else:
        match_sell_order(db, incoming)


def match_buy_order(db: Session, buy: MarketOrder):
    sell_orders = (
        db.query(MarketOrder)
        .filter(
            MarketOrder.good_id == buy.good_id,
            MarketOrder.order_type == "sell",
            MarketOrder.status == "open",
            MarketOrder.price_per_unit <= buy.price_per_unit,
        )
        .order_by(
            MarketOrder.price_per_unit.asc(),
            MarketOrder.created_at.asc(),
        )
        .all()
    )

    for sell in sell_orders:
        if buy.quantity <= 0:
            break
        execute_partial_trade(db, buyer=buy, seller=sell)

    # 🔥 FINALIZE BUY ORDER
    if buy.quantity == 0:
        buy.status = "filled"
    db.commit()


def match_sell_order(db: Session, sell: MarketOrder):
    buy_orders = (
        db.query(MarketOrder)
        .filter(
            MarketOrder.good_id == sell.good_id,
            MarketOrder.order_type == "buy",
            MarketOrder.status == "open",
            MarketOrder.price_per_unit >= sell.price_per_unit,
        )
        .order_by(
            MarketOrder.price_per_unit.desc(),
            MarketOrder.created_at.asc(),
        )
        .all()
    )

    for buy in buy_orders:
        if sell.quantity <= 0:
            break
        execute_partial_trade(db, buyer=buy, seller=sell)

    # ✅ FINALIZE SELL ORDER HERE
    if sell.quantity <= 0:
        sell.status = "filled"

    db.commit()  # ✅ COMMIT ONCE

# IMPORTANT:
# - Orders represent intent
# - Trades represent executed facts
# - Inventory & cash must only change here
def execute_partial_trade(db: Session, buyer: MarketOrder, seller: MarketOrder):
    qty = min(buyer.quantity, seller.quantity)
    price = seller.price_per_unit
    total = qty * price

    buyer_company = db.query(Company).get(buyer.company_id)
    seller_company = db.query(Company).get(seller.company_id)

    if buyer_company.cash < total:
        buyer.status = "cancelled"
        return

    # 💰 cash transfer
    buyer_company.cash -= total
    seller_company.cash += total

    # 📦 INVENTORY — SELLER
    seller_inventory = (
        db.query(Inventory)
        .filter(
            Inventory.company_id == seller.company_id,
            Inventory.good_id == seller.good_id,
        )
        .with_for_update()
        .first()
    )

    seller_inventory.reserved -= qty
    seller_inventory.quantity -= qty

    # 📦 INVENTORY — BUYER
    buyer_inventory = (
        db.query(Inventory)
        .filter(
            Inventory.company_id == buyer.company_id,
            Inventory.good_id == seller.good_id,
        )
        .with_for_update()
        .first()
    )

    trade = MarketTrade(
    good_id=seller.good_id,
    buyer_company_id=buyer.company_id,
    seller_company_id=seller.company_id,
    quantity=qty,
    price_per_unit=price,
    )

    db.add(trade)

    if not buyer_inventory:
        buyer_inventory = Inventory(
            company_id=buyer.company_id,
            good_id=seller.good_id,
            quantity=0,
            reserved=0,
        )
        db.add(buyer_inventory)

    buyer_inventory.quantity += qty

    # 📉 ORDER QUANTITIES
    buyer.quantity -= qty
    seller.quantity -= qty

    if buyer.quantity == 0:
        buyer.status = "filled"
    if seller.quantity == 0:
        seller.status = "filled"

    db.flush()


