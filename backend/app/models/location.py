from datetime import datetime
from sqlalchemy import ForeignKey, String, Float, DateTime, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Location(Base):
    __tablename__ = "locations"

    # Unique identifier
    id: Mapped[int] = mapped_column(primary_key=True)

    # Name and hierarchical relationship
    name: Mapped[str] = mapped_column(String, nullable=False)
    planet_id: Mapped[int] = mapped_column(ForeignKey("planets.id"), nullable=False)

    # 3D coordinates on planet surface
    x: Mapped[float] = mapped_column(Float, nullable=False)
    y: Mapped[float] = mapped_column(Float, nullable=False)
    z: Mapped[float] = mapped_column(Float, nullable=False, default=0)
    
    # Tilemap dimensions for this location's buildable area
    grid_width: Mapped[int] = mapped_column(Integer, nullable=False, default=16)
    grid_height: Mapped[int] = mapped_column(Integer, nullable=False, default=16)
    
    # Seed for procedural tilemap generation in Godot
    tilemap_seed: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # Biome and claim-related fields
    biome: Mapped[str] = mapped_column(String, nullable=False)
    claimed_by_company_id: Mapped[int | None] = mapped_column(
        ForeignKey("companies.id"),
        nullable=True,
        unique=True,
    )
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    # Relationships
    company = relationship("Company", foreign_keys=[claimed_by_company_id], uselist=False)
    planet = relationship("Planet", back_populates="locations")
    resource_deposits = relationship(
        "ResourceDeposit",
        back_populates="location",
        cascade="all, delete-orphan",
    )