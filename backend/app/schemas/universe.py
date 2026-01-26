from pydantic import BaseModel
from typing import List

class UniverseRead(BaseModel):
    id: int
    name: str
    regions: List["RegionRead"]

    class Config:
        orm_mode = True