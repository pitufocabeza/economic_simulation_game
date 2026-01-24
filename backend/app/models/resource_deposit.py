from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import ForeignKey, Integer, UniqueConstraint

from app.db import Base


class ResourceDeposit(Base):
    __tablename__ = "resource_deposits"

    __table_args__ = (
        UniqueConstraint(
            "location_id",
            "good_id",
            name="uq_location_good_deposit",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)

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

    total_amount: Mapped[int] = mapped_column(Integer, nullable=False)
    remaining_amount: Mapped[int] = mapped_column(Integer, nullable=False)

    # Relationships
    location = relationship("Location", back_populates="resource_deposits")
    good = relationship("Good")
