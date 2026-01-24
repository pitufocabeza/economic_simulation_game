from pydantic import BaseModel


class GoodCreate(BaseModel):
    name: str


class GoodRead(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True
