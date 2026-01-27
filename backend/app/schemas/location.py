from pydantic import BaseModel
from typing import Optional


class ResourcePreview(BaseModel):
    resource_type: str
    quantity: int
    rarity: str


class LocationRead(BaseModel):
    id: int
    name: str
    planet_id: int
    x: float
    y: float
    z: float
    biome: str
    grid_width: int
    grid_height: int
    tilemap_seed: int
    claimed: bool
    claimed_by_company_id: Optional[int] = None
    resources: list[ResourcePreview] = []

    class Config:
        from_attributes = True