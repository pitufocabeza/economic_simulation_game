from sqlalchemy import Column, String, Integer, Float, JSON, TIMESTAMP
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db import Base


class BuildingBlueprint(Base):
    __tablename__ = "building_blueprints"

    # Metadata for the building blueprint
    id = Column(Integer, primary_key=True, index=True)  # Unique blueprint ID
    name = Column(String(100), nullable=False)  # The name of the building (e.g., "Basic Smelter")
    role = Column(String(50), nullable=False)  # The purpose of the building (e.g., "Processing", "Storage")
    description = Column(String, nullable=True)  # Optional text description of the building
    category = Column(String(50), nullable=False)  # High-level classification (e.g., "Energy", "Processing")

    # Core behavior
    max_capacity = Column(Integer, default=0)  # Maximum capacity for output, production, or storage
    base_efficiency = Column(Float, default=1.0)  # Baseline production efficiency multiplier

    # Energy behavior
    energy_production = Column(Integer, nullable=False, default=0)  # Energy (MW) produced per tick
    energy_consumption = Column(Integer, nullable=False, default=0)  # Energy (MW) consumed per tick

    # Operating costs (non-energy)
    operating_cost = Column(JSON, nullable=True)  # Resources needed for operation (e.g., {"Coal": 5})

    # Production/Storage definitions
    supported_goods = Column(JSON, nullable=True)  # JSON array of goods the building can process/store
    production_recipes = Column(JSON, nullable=True)  # JSON array of recipe IDs supported by this building

    # Construction rules
    construction_cost = Column(JSON, nullable=False)  # Resources required to construct the building

    # Timestamps
    created_at = Column(TIMESTAMP, server_default=func.now())  # Creation time for the blueprint
    updated_at = Column(TIMESTAMP, onupdate=func.now())  # Last modification time

    # Relationships
    buildings = relationship("Building", back_populates="blueprint")  # Links to instances of this blueprint