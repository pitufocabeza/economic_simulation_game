from sqlalchemy.orm import Session
from app.models.good import Good
from app.db import SessionLocal
from app.data.goods import ALL_GOODS


def add_good_if_not_exists(db: Session, good: dict) -> bool:
    """Add a good to the database if it doesn't already exist."""
    existing = db.query(Good).filter(Good.name == good["name"]).first()
    if existing:
        return False  # Good already exists
    new_good = Good(
        name=good["name"],
        primary_category=good["primary_category"],
        subcategory=good.get("subcategory"),
        rarity=good["rarity"]
    )
    db.add(new_good)
    return True


def seed_goods():
    """Seed goods into the goods table."""
    db: Session = SessionLocal()
    goods_added = 0
    goods_skipped = 0

    try:
        for good in ALL_GOODS:
            if add_good_if_not_exists(db, good):
                goods_added += 1
                print(f"Added good: {good['name']}")
            else:
                goods_skipped += 1
                print(f"Good '{good['name']}' already exists. Skipping...")

        # Commit changes
        db.commit()
        print(f"Seeding Results:\nGoods Added: {goods_added}\nGoods Skipped (Already Exists): {goods_skipped}")
    
    except Exception as e:
        db.rollback()
        print(f"An error occurred while seeding goods: {e}")
    
    finally:
        db.close()


if __name__ == "__main__":
    seed_goods()