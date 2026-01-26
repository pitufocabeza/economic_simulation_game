from sqlalchemy import ForeignKey, String, Float
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Planet(Base):
    __tablename__ = "planets"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    star_system_id: Mapped[int] = mapped_column(ForeignKey("star_systems.id"), nullable=False)

    # Planetary biome type (e.g., desert, jungle, oceanic)
    biome: Mapped[str] = mapped_column(String, nullable=False)
    radius: Mapped[float] = mapped_column(nullable=False, default=6371.0)  # Earth's radius in km

    # Relations
    star_system = relationship("StarSystem", back_populates="planets")
    locations = relationship("Location", back_populates="planet", cascade="all, delete-orphan")