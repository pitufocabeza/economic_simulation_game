from datetime import datetime

from sqlalchemy.orm import Session

from app.models.inventory import Inventory
from app.models.production_job import ProductionJob


def complete_finished_jobs(db: Session):
    now = datetime.utcnow()

    jobs = (
        db.query(ProductionJob)
        .filter(
            ProductionJob.status == "running",
            ProductionJob.finishes_at <= now,
        )
        .all()
    )

    for job in jobs:
        # add output
        inventory = (
            db.query(Inventory)
            .filter(
                Inventory.company_id == job.company_id,
                Inventory.good_id == job.output_good_id,
            )
            .first()
        )

        if not inventory:
            inventory = Inventory(
                company_id=job.company_id,
                good_id=job.output_good_id,
                quantity=0,
            )
            db.add(inventory)

        inventory.quantity += job.output_quantity
        job.status = "completed"

    db.commit()
