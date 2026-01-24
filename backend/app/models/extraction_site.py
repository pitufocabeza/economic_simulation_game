from datetime import datetime

import sqlalchemy as sa
from sqlalchemy import ForeignKey, Integer, Boolean, DateTime, Float
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class ExtractionSite(Base):
    __tablename__ = "extraction_sites"

    id: Mapped[int] = mapped_column(primary_key=True)

    company_id: Mapped[int] = mapped_column(
        ForeignKey("companies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    location_id: Mapped[int] = mapped_column(
        ForeignKey("locations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    good_id: Mapped[int] = mapped_column(
        ForeignKey("goods.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    rate_per_hour: Mapped[int] = mapped_column(Integer, nullable=False)

    active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
    )

    production_buffer: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=0.0,
    )


    created_at: Mapped[datetime] = mapped_column(
    sa.DateTime(timezone=True),
    nullable=False,
    )
  
    last_extracted_at: Mapped[datetime | None] = mapped_column(
    sa.DateTime(timezone=True),
    nullable=True,
    )


    # Relationships (optional but very useful)
    company = relationship("Company")
    location = relationship("Location")
    good = relationship("Good")
