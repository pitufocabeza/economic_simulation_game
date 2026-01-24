from datetime import datetime
from pydantic import BaseModel


class MarketTradeRead(BaseModel):
    id: int
    good_id: int
    buyer_company_id: int
    seller_company_id: int
    quantity: int
    price_per_unit: int
    created_at: datetime

    class Config:
        from_attributes = True
