from sqlalchemy import Column, String, Integer, Float, ForeignKey, TIMESTAMP
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db import Base


class Building(Base):
    __tablename__ = "buildings"

    id = Column(Integer, primary_key=True, index=True)
    blueprint_id = Column(Integer, ForeignKey("building_blueprints.id"), nullable=False)  # Linked blueprint
    name = Column(String(100), nullable=False)  # Instance-specific name
    owner_company_id = Column(Integer, ForeignKey("companies.id"), nullable=False)  # Who owns this building
    location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)  # Which plot this building resides in

    # Status tracking
    status = Column(String(50), nullable=False, default="constructing")  # E.g., "active", "constructing", "damaged"

    # Live data
    current_capacity = Column(Integer, default=0)  # Current storage or load
    current_efficiency = Column(Float, default=1.0)  # Modified by research/upgrades

    # Administrative fields
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, onupdate=func.now())

    # Relationships
    blueprint = relationship("BuildingBlueprint", back_populates="buildings")