from sqlalchemy import ForeignKey, String, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Region(Base):
    __tablename__ = "regions"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    universe_id: Mapped[int] = mapped_column(ForeignKey("universes.id"), nullable=False)

    # Optional properties for description or modifiers
    description: Mapped[str | None] = mapped_column(String, nullable=True)
    density: Mapped[int] = mapped_column(Integer, default=0)  # Number of star systems, placeholder

    # Relationships
    universe = relationship("Universe", back_populates="regions")
    star_systems = relationship("StarSystem", back_populates="region", cascade="all, delete-orphan")