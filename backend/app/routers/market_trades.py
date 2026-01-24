from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.market_trade import MarketTrade

router = APIRouter(prefix="/market/trades", tags=["market"])


@router.get("/")
def list_trades(
    good_id: int | None = None,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    query = db.query(MarketTrade)

    if good_id:
        query = query.filter(MarketTrade.good_id == good_id)

    return (
        query
        .order_by(MarketTrade.created_at.desc())
        .limit(limit)
        .all()
    )
