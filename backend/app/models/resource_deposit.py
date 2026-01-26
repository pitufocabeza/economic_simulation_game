from sqlalchemy import String, Integer, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db import Base

class ResourceDeposit(Base):
    __tablename__ = "resource_deposits"

    id: Mapped[int] = mapped_column(primary_key=True)
    location_id: Mapped[int] = mapped_column(ForeignKey("locations.id"), nullable=False)
    resource_type: Mapped[str] = mapped_column(String, nullable=False)  # Resource type (e.g., "Iron Ore")
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)  # Available units
    rarity: Mapped[str] = mapped_column(String, nullable=False)  # Rarity (e.g., "common", "rare")

    # Many-to-one relationship with Location
    location = relationship("Location", back_populates="resource_deposits")