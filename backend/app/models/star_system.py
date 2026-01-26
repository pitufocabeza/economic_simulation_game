from sqlalchemy import ForeignKey, String, Integer, Float
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base



class StarSystem(Base):
    __tablename__ = "star_systems"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False, unique=True)

    # Hierarchical link to Region
    region_id: Mapped[int] = mapped_column(ForeignKey("regions.id"), nullable=False)

    # Stellar properties
    star_type: Mapped[str | None] = mapped_column(String, nullable=True)  # Example: "Red Giant", "Main Sequence"
    star_temperature: Mapped[int | None] = mapped_column(Integer, nullable=True)  # Example: 5000 K
    star_luminosity: Mapped[str | None] = mapped_column(String, nullable=True)  # Example: "10x solar luminosity"
    star_size: Mapped[str | None] = mapped_column(String, nullable=True)  # Example: "Small", "Large"

    # Spatial Position
    x: Mapped[float] = mapped_column(nullable=False)
    y: Mapped[float] = mapped_column(nullable=False)
    z: Mapped[float] = mapped_column(nullable=False)

    # Relationships
    region = relationship("Region", back_populates="star_systems")
    planets = relationship("Planet", back_populates="star_system", cascade="all, delete-orphan")