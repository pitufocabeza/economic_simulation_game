from pydantic import BaseModel


class GoodCreate(BaseModel):
    name: str
    primary_category: str
    subcategory: str | None  # Subcategory is optional
    rarity: str


class GoodRead(BaseModel):
    id: int
    name: str
    primary_category: str
    subcategory: str | None
    rarity: str
    
    class Config:
        from_attributes = True