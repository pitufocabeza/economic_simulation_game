from pydantic import BaseModel
from typing import Optional, List

class RegionRead(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    density: int
    star_systems: List["StarSystemRead"]

    class Config:
        orm_mode = True