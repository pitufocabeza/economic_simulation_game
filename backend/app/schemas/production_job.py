from datetime import datetime
from pydantic import BaseModel


class ProductionJobRead(BaseModel):
    id: int
    company_id: int
    input_good_id: int
    output_good_id: int
    input_quantity: int
    output_quantity: int
    started_at: datetime
    finishes_at: datetime
    status: str

    class Config:
        from_attributes = True
