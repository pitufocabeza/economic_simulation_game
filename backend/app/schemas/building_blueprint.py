from pydantic import BaseModel
from typing import Optional, List, Dict


class BuildingBlueprintBase(BaseModel):
    id: int
    name: str  # The name of the building (e.g., "Basic Smelter")
    role: str  # The building’s role (e.g., "Smelter", "Energy Producer")
    description: Optional[str]  # Optional field describing the building's purpose
    category: str  # High-level category (e.g., "Processing", "Energy")
    max_capacity: Optional[int] = 0  # Maximum capacity for storage or production
    base_efficiency: Optional[float] = 1.0  # Baseline efficiency for the building

    energy_production: int = 0  # Static energy produced, default is 0 (for consumers)
    energy_consumption: int = 0  # Static energy consumed, default is 0 (for producers)
    operating_cost: Optional[Dict[str, int]]  # Resources required for operation (e.g., {"Coal": 5})

    supported_goods: Optional[List[str]]  # Specifies what goods this building handles (storage, recipes, etc.)
    production_recipes: Optional[List[int]]  # Supported production recipes (if for processing buildings)
    construction_cost: Dict[str, int]  # Raw resources required to construct the building

    class Config:
        orm_mode = True


class BuildingBlueprintCreate(BaseModel):  # Schema for creating blueprints
    name: str
    role: str
    description: Optional[str]
    category: str
    max_capacity: Optional[int] = 0
    base_efficiency: Optional[float] = 1.0
    energy_production: Optional[int] = 0
    energy_consumption: Optional[int] = 0
    operating_cost: Optional[Dict[str, int]]
    supported_goods: Optional[List[str]]
    production_recipes: Optional[List[int]]
    construction_cost: Dict[str, int]


class BuildingBlueprintRead(BuildingBlueprintBase):  # Blueprint READ: Expose all fields
    pass