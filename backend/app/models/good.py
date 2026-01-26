from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from app.db import Base


class Good(Base):
    __tablename__ = "goods"

    id: Mapped[int] = mapped_column(primary_key=True)  # Unique identifier
    name: Mapped[str] = mapped_column(String, nullable=False, unique=True)  # Name of the good
    primary_category: Mapped[str] = mapped_column(String, nullable=False)  # High-level grouping
    subcategory: Mapped[str | None] = mapped_column(String, nullable=True)  # Optional finer classification
    rarity: Mapped[str] = mapped_column(String, nullable=False)  # Rarity of the good