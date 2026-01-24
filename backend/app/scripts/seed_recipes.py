from app.db import SessionLocal
from app.models.good import Good
from app.models.production_recipe import ProductionRecipe


def run():
    db = SessionLocal()

    iron = db.query(Good).filter(Good.name == "Iron").first()
    steel = db.query(Good).filter(Good.name == "Steel").first()

    if not iron or not steel:
        raise RuntimeError("Iron or Steel good missing")

    existing = (
        db.query(ProductionRecipe)
        .filter(
            ProductionRecipe.input_good_id == iron.id,
            ProductionRecipe.output_good_id == steel.id,
        )
        .first()
    )

    if existing:
        print("Recipe already exists")
        return

    recipe = ProductionRecipe(
        input_good_id=iron.id,
        input_quantity=10,
        output_good_id=steel.id,
        output_quantity=5,
        duration_seconds=60,
    )

    db.add(recipe)
    db.commit()
    print("Recipe created")


if __name__ == "__main__":
    run()
