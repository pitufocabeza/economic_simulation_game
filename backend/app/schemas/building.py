from enum import Enum
from pydantic import BaseModel


# Enum for all building types
class BuildingType(str, Enum):
    processor = "Processor"
    storage = "Storage"
    spaceport = "Spaceport"
    planetary_link = "Planetary Link"
    extractor_unit = "Extractor Unit"
    extractor_head = "Extractor Head"
    command_center = "Command Center"


# Enum for processor tiers
class ProcessorTier(str, Enum):
    basic = "BASIC"
    advanced = "ADVANCED"
    hightech = "HIGHTECH"


# Base schema for all buildings
class BuildingBase(BaseModel):
    id: int
    name: str
    type: BuildingType

    class Config:
        schema_extra = {
            "example": {
                "id": 1,
                "name": "Basic Processor",
                "type": "Processor"
            }
        }


# Specific schema for processors
class Processor(BuildingBase):
    tier: ProcessorTier

    class Config:
        schema_extra = {
            "example": {
                "id": 1,
                "name": "Basic Processor",
                "type": "Processor",
                "tier": "BASIC"
            }
        }


# Schema for storage buildings
class Storage(BuildingBase):
    class Config:
        schema_extra = {
            "example": {
                "id": 2,
                "name": "High-Capacity Warehouse",
                "type": "Storage"
            }
        }


# Schema for spaceports
class Spaceport(BuildingBase):
    class Config:
        schema_extra = {
            "example": {
                "id": 3,
                "name": "Orbital Transfer Hub",
                "type": "Spaceport"
            }
        }


# Schema for planetary links
class PlanetaryLink(BuildingBase):
    class Config:
        schema_extra = {
            "example": {
                "id": 4,
                "name": "Logistics Node",
                "type": "Planetary Link"
            }
        }


# Schema for Extractor Units (EUs)
class ExtractorUnit(BuildingBase):
    extraction_capacity: int  # Example field for total capacity

    class Config:
        schema_extra = {
            "example": {
                "id": 5,
                "name": "Standard Extractor Unit",
                "type": "Extractor Unit",
                "extraction_capacity": 100
            }
        }


# Schema for Extractor Heads
class ExtractorHead(BaseModel):
    extractor_unit_id: int  # Links to its parent Extractor Unit
    extraction_rate: int  # Rate for this specific head

    class Config:
        schema_extra = {
            "example": {
                "id": 6,
                "extractor_unit_id": 5,
                "extraction_rate": 10
            }
        }


# Schema for Command Centers
class CommandCenter(BuildingBase):
    owner_company_id: int
    planet_name: str

    class Config:
        schema_extra = {
            "example": {
                "id": 7,
                "name": "Main Command",
                "type": "Command Center",
                "owner_company_id": 101,
                "planet_name": "New Eden"
            }
        }