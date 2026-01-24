from pydantic import BaseModel


class ProductionRecipeCreate(BaseModel):
    input_good_id: int
    input_quantity: int
    output_good_id: int
    output_quantity: int
    duration_seconds: int


class ProductionRecipeRead(BaseModel):
    id: int
    input_good_id: int
    input_quantity: int
    output_good_id: int
    output_quantity: int
    duration_seconds: int

    class Config:
        from_attributes = True
