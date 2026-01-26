from pydantic import BaseModel


class GoodCreate(BaseModel):
    name: str
    primary_category: str
    subcategory: str | None  # Subcategory is optional
    rarity: str