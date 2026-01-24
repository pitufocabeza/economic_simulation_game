from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.production_recipe import ProductionRecipe
from app.schemas.production_recipe import (
    ProductionRecipeCreate,
    ProductionRecipeRead,
)

router = APIRouter(prefix="/admin/recipes", tags=["admin:recipes"])


@router.post(
    "/",
    response_model=ProductionRecipeRead,
    status_code=status.HTTP_201_CREATED,
)
def create_recipe(
    payload: ProductionRecipeCreate,
    db: Session = Depends(get_db),
):
    recipe = ProductionRecipe(**payload.dict())
    db.add(recipe)
    db.commit()
    db.refresh(recipe)
    return recipe


@router.get("/", response_model=list[ProductionRecipeRead])
def list_recipes(db: Session = Depends(get_db)):
    return db.query(ProductionRecipe).order_by(ProductionRecipe.id).all()


@router.get("/{recipe_id}", response_model=ProductionRecipeRead)
def get_recipe(recipe_id: int, db: Session = Depends(get_db)):
    recipe = db.query(ProductionRecipe).get(recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe


@router.delete("/{recipe_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_recipe(recipe_id: int, db: Session = Depends(get_db)):
    recipe = db.query(ProductionRecipe).get(recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    db.delete(recipe)
    db.commit()
