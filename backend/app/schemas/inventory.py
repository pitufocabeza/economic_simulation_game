from pydantic import BaseModel


class InventoryRead(BaseModel):
    id: int
    company_id: int
    good_id: int
    quantity: int
    reserved: int

    class Config:
        orm_mode = True
