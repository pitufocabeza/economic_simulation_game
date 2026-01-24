from sqlalchemy import ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Inventory(Base):
    __tablename__ = "inventories"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id"))
    good_id: Mapped[int] = mapped_column(ForeignKey("goods.id"))

    quantity: Mapped[int] = mapped_column(Integer)          # total owned
    reserved: Mapped[int] = mapped_column(Integer, default=0)  # locked

