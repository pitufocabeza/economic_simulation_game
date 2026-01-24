from pydantic import BaseModel


class MarketOrderCreate(BaseModel):
    good_id: int
    order_type: str  # "buy" or "sell"
    quantity: int
    price_per_unit: int


class MarketOrderRead(BaseModel):
    id: int
    order_type: str
    quantity: int
    price_per_unit: int
    status: str

    good_id: int
    good_name: str

    company_id: int
    company_name: str

    class Config:
        from_attributes = True