from datetime import datetime

from sqlalchemy import ForeignKey, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class ProductionJob(Base):
    __tablename__ = "production_jobs"

    id: Mapped[int] = mapped_column(primary_key=True)

    company_id: Mapped[int] = mapped_column(
        ForeignKey("companies.id"), index=True
    )

    input_good_id: Mapped[int] = mapped_column(
        ForeignKey("goods.id")
    )
    output_good_id: Mapped[int] = mapped_column(
        ForeignKey("goods.id")
    )

    input_quantity: Mapped[int] = mapped_column(Integer)
    output_quantity: Mapped[int] = mapped_column(Integer)

    started_at: Mapped[datetime] = mapped_column(DateTime)
    finishes_at: Mapped[datetime] = mapped_column(DateTime)

    status: Mapped[str] = mapped_column(
        String(20), default="running"
    )
