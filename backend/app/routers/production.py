from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.inventory import Inventory
from app.models.production_job import ProductionJob
from app.models.production_recipe import ProductionRecipe
from app.schemas.production_job import ProductionJobRead
from app.services.production import complete_finished_jobs

router = APIRouter(prefix="/production", tags=["production"])


@router.post("/start/{company_id}", response_model=ProductionJobRead)
def start_production(company_id: int, recipe_id: int, db: Session = Depends(get_db)):
    complete_finished_jobs(db)

    recipe = db.query(ProductionRecipe).get(recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    inventory = (
        db.query(Inventory)
        .filter(
            Inventory.company_id == company_id,
            Inventory.good_id == recipe.input_good_id,
        )
        .first()
    )

    if not inventory or inventory.quantity < recipe.input_quantity:
        raise HTTPException(
            status_code=400,
            detail="Not enough input goods",
        )

    inventory.quantity -= recipe.input_quantity

    now = datetime.utcnow()

    job = ProductionJob(
        company_id=company_id,
        input_good_id=recipe.input_good_id,
        output_good_id=recipe.output_good_id,
        input_quantity=recipe.input_quantity,
        output_quantity=recipe.output_quantity,
        started_at=now,
        finishes_at=now + timedelta(seconds=recipe.duration_seconds),
    )

    db.add(job)
    db.commit()
    db.refresh(job)

    return job


@router.get("/{company_id}", response_model=list[ProductionJobRead])
def list_jobs(company_id: int, db: Session = Depends(get_db)):
    complete_finished_jobs(db)

    return (
        db.query(ProductionJob)
        .filter(ProductionJob.company_id == company_id)
        .all()
    )
