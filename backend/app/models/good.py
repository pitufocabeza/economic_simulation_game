from sqlalchemy import String, Enum
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.schemas.good_enums import GoodsCategory, GoodsRarity  # Enum definitions

class Good(Base):
    __tablename__ = "goods"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    category: Mapped[GoodsCategory] = mapped_column(Enum(GoodsCategory), nullable=False)  # New column for category
    rarity: Mapped[GoodsRarity] = mapped_column(Enum(GoodsRarity), nullable=False)  # New column for rarity