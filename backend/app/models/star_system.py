from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class StarSystem(Base):
    __tablename__ = "star_systems"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False, unique=True)

    # Hierarchical link to Region
    region_id: Mapped[int] = mapped_column(ForeignKey("regions.id"), nullable=False)

    # Spatial Position (can be extended for more realism like galaxy coordinates)
    x: Mapped[float] = mapped_column(nullable=False)
    y: Mapped[float] = mapped_column(nullable=False)
    z: Mapped[float] = mapped_column(nullable=False)

    # Relationships
    region = relationship("Region", back_populates="star_systems")
    planets = relationship("Planet", back_populates="star_system", cascade="all, delete-orphan")