from datetime import datetime
from sqlalchemy import ForeignKey, Integer, DateTime
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class MarketTrade(Base):
    __tablename__ = "market_trades"

    id: Mapped[int] = mapped_column(primary_key=True)

    good_id: Mapped[int] = mapped_column(
        ForeignKey("goods.id"), index=True
    )

    buyer_company_id: Mapped[int] = mapped_column(
        ForeignKey("companies.id"), index=True
    )

    seller_company_id: Mapped[int] = mapped_column(
        ForeignKey("companies.id"), index=True
    )

    quantity: Mapped[int] = mapped_column(Integer)
    price_per_unit: Mapped[int] = mapped_column(Integer)

    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, index=True
    )
