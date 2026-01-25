from sqlalchemy import ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base

class ProductionTier(str, Enum):
    BASIC = "basic"
    ADVANCED = "advanced"
    HIGH_TECH = "high_tech"

class ProductionRecipe(Base):
    __tablename__ = "production_recipes"

    id: Mapped[int] = mapped_column(primary_key=True)

    input_good_id: Mapped[int] = mapped_column(
        ForeignKey("goods.id"), index=True
    )
    input_quantity: Mapped[int] = mapped_column(Integer)

    output_good_id: Mapped[int] = mapped_column(
        ForeignKey("goods.id"), index=True
    )
    output_quantity: Mapped[int] = mapped_column(Integer)

    duration_seconds: Mapped[int] = mapped_column(Integer)
