# app/models/production_building.py
from sqlalchemy import Column, Integer, Boolean, ForeignKey, DateTime, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db import Base


class ProductionBuilding(Base):
    __tablename__ = "production_buildings"

    id = Column(Integer, primary_key=True)

    company_id = Column(Integer, ForeignKey("companies.id"), nullable=False)
    location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)

    input_good_id = Column(Integer, ForeignKey("goods.id"), nullable=False)
    output_good_id = Column(Integer, ForeignKey("goods.id"), nullable=False)

    input_per_hour = Column(Float, nullable=False)
    output_per_hour = Column(Float, nullable=False)

    active = Column(Boolean, default=True)

    production_buffer = Column(Float, default=0.0)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_processed_at = Column(DateTime(timezone=True), nullable=True)
