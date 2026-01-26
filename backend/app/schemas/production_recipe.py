from enum import Enum
from pydantic import BaseModel


# Enum for production recipe tiers
class ProductionTier(str, Enum):
    raw = "raw"
    t1 = "t1"
    t2 = "t2"
    t3 = "t3"
    t4 = "t4"


# Schema for creating production recipes
class ProductionRecipeCreate(BaseModel):
    input_good_id: int
    input_quantity: int
    output_good_id: int
    output_quantity: int
    duration_seconds: int
    tier: ProductionTier  # Recipe tier (e.g., raw, t1, t2)

    class Config:
        schema_extra = {
            "example": {
                "input_good_id": 8,
                "input_quantity": 100,
                "output_good_id": 23,
                "output_quantity": 45,
                "duration_seconds": 3600,
                "tier": "raw",
            }
        }


# Schema for reading production recipes
class ProductionRecipeRead(BaseModel):
    id: int
    input_good_id: int
    input_quantity: int
    output_good_id: int
    output_quantity: int
    duration_seconds: int
    tier: ProductionTier  # Recipe tier (e.g., raw, t1, t2)

    class Config:
        from_attributes = True
        schema_extra = {
            "example": {
                "id": 1,
                "input_good_id": 8,
                "input_quantity": 100,
                "output_good_id": 23,
                "output_quantity": 45,
                "duration_seconds": 3600,
                "tier": "raw",
            }
        }