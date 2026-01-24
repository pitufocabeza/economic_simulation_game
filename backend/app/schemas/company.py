from pydantic import BaseModel


class CompanyCreate(BaseModel):
    name: str


class CompanyRead(BaseModel):
    id: int
    name: str
    cash: int

    class Config:
        from_attributes = True
