from sqlalchemy.orm import relationship
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String

from app.db import Base


class Universe(Base):
    __tablename__ = "universes"

    # One entry for simplicity
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False, unique=True)

    # Relationships
    regions = relationship("Region", back_populates="universe", cascade="all, delete-orphan")