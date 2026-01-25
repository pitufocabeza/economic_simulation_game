from sqlalchemy import ForeignKey, DateTime, Boolean, Integer, Float, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class ExtractionSite(Base):
    __tablename__ = "extraction_sites"

    id: Mapped[int] = mapped_column(primary_key=True)

    company_id: Mapped[int] = mapped_column(
        ForeignKey("companies.id"), nullable=False, index=True
    )

    location_id: Mapped[int] = mapped_column(
        ForeignKey("locations.id"), nullable=False, index=True
    )

    good_id: Mapped[int] = mapped_column(
        ForeignKey("goods.id"), nullable=False, index=True
    )

    rate_per_hour: Mapped[int] = mapped_column(Integer, nullable=False)

    active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )

    production_buffer: Mapped[float] = mapped_column(
        Float, nullable=False, server_default="0"
    )

    # ✅ IMPORTANT FIXES
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    last_extracted_at: Mapped[DateTime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
