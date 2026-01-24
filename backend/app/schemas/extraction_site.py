from datetime import datetime
from pydantic import BaseModel


class ExtractionSiteCreate(BaseModel):
    location_id: int
    good_id: int
    rate_per_hour: int


class ExtractionSiteRead(BaseModel):
    id: int
    company_id: int
    location_id: int
    good_id: int
    rate_per_hour: int
    active: bool
    created_at: datetime

    class Config:
        from_attributes = True
