from pydantic import BaseModel
from typing import Optional, List

class StarSystemRead(BaseModel):
    id: int
    name: str
    x: float
    y: float
    z: float
    region: "RegionRead"
    planets: List["PlanetRead"]

    class Config:
        orm_mode = True