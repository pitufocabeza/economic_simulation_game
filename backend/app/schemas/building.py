from pydantic import BaseModel, Field
from typing import Optional
from app.schemas.building_blueprint import BuildingBlueprintRead


class BuildingBase(BaseModel):
    id: int
    name: str  # Instance-specific name
    blueprint_id: int  # The associated BuildingBlueprint ID
    owner_company_id: int  # Who owns the building
    location_id: int  # Where the building is located (grid/plot/region)

    status: str = Field(default="constructing")  # Current status, e.g., "active"/"damaged"
    current_capacity: Optional[int] = Field(default=0)  # Current storage or production load
    current_efficiency: Optional[float] = Field(default=1.0)  # How efficiently the building operates

    class Config:
        orm_mode = True


class BuildingCreate(BaseModel):  # Schema for creating a new building
    name: str  # Instance-specific name
    blueprint_id: int  # Reference the associated blueprint
    owner_company_id: int  # Owning company/player
    location_id: int  # Planetary or plot-specific location


class BuildingRead(BuildingBase):  # Schema for returning building data
    blueprint: BuildingBlueprintRead  # Return full blueprint details when fetching a building