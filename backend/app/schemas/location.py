from pydantic import BaseModel
from typing import Optional


class ResourcePreview(BaseModel):
    good_id: int
    remaining_amount: int


class LocationRead(BaseModel):
    id: int
    name: str
    x: float
    y: float
    z: float
    biome: str
    claimed: bool
    resources: list[ResourcePreview] = []
    planet: PlanetRead

    class Config:
        from_attributes = True