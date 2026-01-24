from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Company(Base):
    __tablename__ = "companies"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    cash: Mapped[int] = mapped_column(Integer, default=0)

    # ✅ Home base (1:1)
    home_location_id: Mapped[int | None] = mapped_column(
        ForeignKey("locations.id"),
        nullable=True,
        unique=True,
    )

    home_location = relationship(
        "Location",
        foreign_keys=[home_location_id],
        uselist=False,
    )
