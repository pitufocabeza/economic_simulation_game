from pydantic import BaseModel
from app.schemas.good_enums import GoodsCategory, GoodsRarity  # Enum imports


class GoodCreate(BaseModel):
    name: str
    category: GoodsCategory  # Validate category via Enum
    rarity: GoodsRarity      # Validate rarity via Enum


class GoodRead(BaseModel):
    id: int
    name: str
    category: GoodsCategory
    rarity: GoodsRarity

    class Config:
        from_attributes = True