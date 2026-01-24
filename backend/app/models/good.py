from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base

class Good(Base):
    __tablename__ = "goods"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, index=True)