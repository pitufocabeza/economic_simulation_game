from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.good import Good
from app.schemas.good import GoodCreate, GoodRead

router = APIRouter(prefix="/goods", tags=["goods"])


@router.post("/", response_model=GoodRead, status_code=status.HTTP_201_CREATED)
def create_good(payload: GoodCreate, db: Session = Depends(get_db)):
    existing = db.query(Good).filter(Good.name == payload.name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Good already exists")

    good = Good(name=payload.name)
    db.add(good)
    db.commit()
    db.refresh(good)
    return good


@router.get("/", response_model=list[GoodRead])
def list_goods(db: Session = Depends(get_db)):
    return db.query(Good).order_by(Good.id).all()


@router.get("/{good_id}", response_model=GoodRead)
def get_good(good_id: int, db: Session = Depends(get_db)):
    good = db.query(Good).get(good_id)
    if not good:
        raise HTTPException(status_code=404, detail="Good not found")
    return good


@router.delete("/{good_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_good(good_id: int, db: Session = Depends(get_db)):
    good = db.query(Good).get(good_id)
    if not good:
        raise HTTPException(status_code=404, detail="Good not found")

    db.delete(good)
    db.commit()
