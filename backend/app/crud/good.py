from sqlalchemy.orm import Session
from sqlalchemy import select

from app.models.good import Good
from app.schemas.good import GoodCreate

def create_good(db: Session, good_in: GoodCreate) -> Good:
    good = Good(name=good_in.name)
    db.add(good)
    db.commit()
    db.refresh(good)
    return good

def get_good(db: Session, good_id: int) -> Good | None:
    return db.get(Good, good_id)

def get_good_by_name(db: Session, name: str) -> Good | None:
    stmt = select(Good).where(Good.name == name)
    return db.scalar(stmt)

def get_goods(db: Session, skip: int = 0, limit: int = 100) -> list[Good]:
    stmt = select(Good).offset(skip).limit(limit)
    return list(db.scalars(stmt))

def delete_good(db: Session, good: Good) -> None:
    db.delete(good)
    db.commit()
