from pydantic import BaseModel
from typing import Dict

class PlanetRead(BaseModel):
    id: int
    name: str
    biome: str
    radius: float
    resources: Dict[str, int]  # JSON mapping of resources
    star_system: StarSystemRead

    class Config:
        orm_mode = True