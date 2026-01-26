from pydantic import BaseModel


class ResourceDepositCreate(BaseModel):
    resource_type: str
    quantity: int
    rarity: str


class ResourceDepositRead(ResourceDepositCreate):
    id: int
    location_id: int

    class Config:
        from_attributes = True