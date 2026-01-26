from sqlalchemy import Column, String, Integer, ForeignKey, Float, Enum
from sqlalchemy.dialects.postgresql import ENUM
from sqlalchemy.orm import relationship
from app.db import Base
from app.schemas.building import BuildingType, ProcessorTier


# Base Building model
class Building(Base):
    __tablename__ = "buildings"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    type = Column(ENUM(BuildingType, name="buildingtype"), nullable=False)

    __mapper_args__ = {
        "polymorphic_identity": "building",
        "polymorphic_on": type,
    }


# Processor-specific Building
class Processor(Building):
    __tablename__ = "processors"

    id = Column(Integer, ForeignKey("buildings.id"), primary_key=True)
    tier = Column(ENUM(ProcessorTier, name="processortier"), nullable=False)

    __mapper_args__ = {"polymorphic_identity": "processor"}


# Storage-specific Building
class Storage(Building):
    __tablename__ = "storages"

    id = Column(Integer, ForeignKey("buildings.id"), primary_key=True)

    __mapper_args__ = {"polymorphic_identity": "storage"}


# Spaceport-specific Building
class Spaceport(Building):
    __tablename__ = "spaceports"

    id = Column(Integer, ForeignKey("buildings.id"), primary_key=True)

    __mapper_args__ = {"polymorphic_identity": "spaceport"}


# Extractor Units (EUs)
class ExtractorUnit(Building):
    __tablename__ = "ecus"

    id = Column(Integer, ForeignKey("buildings.id"), primary_key=True)
    extraction_capacity = Column(Integer, nullable=False)

    __mapper_args__ = {"polymorphic_identity": "ecu"}


# Extractor Heads
class ExtractorHead(Base):
    __tablename__ = "extractor_heads"

    id = Column(Integer, primary_key=True, index=True)
    ecu_id = Column(Integer, ForeignKey("ecus.id"), nullable=False)
    extraction_rate = Column(Float, nullable=False)

    ecu = relationship("ExtractorUnit", backref="extractor_heads")

# PlanetaryLink-specific Building
class PlanetaryLink(Building):
    __tablename__ = "planetary_links"

    id = Column(Integer, ForeignKey("buildings.id"), primary_key=True)

    __mapper_args__ = {"polymorphic_identity": "planetary_link"}

# CommandCenter-specific Building
class CommandCenter(Building):
    __tablename__ = "command_centers"

    id = Column(Integer, ForeignKey("buildings.id"), primary_key=True)
    owner_company_id = Column(Integer, nullable=False)
    planet_name = Column(String(100), nullable=False)

    __mapper_args__ = {"polymorphic_identity": "command_center"}