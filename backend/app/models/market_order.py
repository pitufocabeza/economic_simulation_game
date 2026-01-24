from datetime import datetime

from sqlalchemy import ForeignKey, Integer, String, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class MarketOrder(Base):
    __tablename__ = "market_orders"

    id: Mapped[int] = mapped_column(primary_key=True)

    company_id: Mapped[int] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    good_id: Mapped[int] = mapped_column(
        ForeignKey("goods.id"), index=True
    )

    order_type: Mapped[str] = mapped_column(String(4))  # "buy" or "sell"
    quantity: Mapped[int] = mapped_column(Integer)
    price_per_unit: Mapped[int] = mapped_column(Integer)

    status: Mapped[str] = mapped_column(
        String(20), default="open"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    # ✅ ADD THESE TWO LINES
    company = relationship("Company")
    good = relationship("Good")
