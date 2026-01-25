from datetime import datetime
from sqlalchemy.orm import Session

from app.models.production_building import ProductionBuilding
from app.models.inventory import Inventory


def tick_production(db: Session, now: datetime, speed_multiplier: float = 1.0) -> dict:
    buildings = (
        db.query(ProductionBuilding)
        .filter(ProductionBuilding.active == True)
        .with_for_update()
        .all()
    )

    processed = 0
    total_output = 0

    for building in buildings:
        produced = tick_single_building(db, building, now, speed_multiplier)
        total_output += produced
        processed += 1

    return {
        "buildings_processed": processed,
        "total_output": total_output,
    }


def tick_single_building(
    db: Session,
    building: ProductionBuilding,
    now: datetime,
    speed_multiplier: float,
) -> int:
    if building.last_processed_at is None:
        building.last_processed_at = now
        return 0

    elapsed = (now - building.last_processed_at).total_seconds()
    if elapsed <= 0:
        return 0

    hours = (elapsed / 3600.0) * speed_multiplier

    input_needed = hours * building.input_per_hour
    output_exact = hours * building.output_per_hour + building.production_buffer

    output_units = int(output_exact)
    if output_units <= 0:
        building.production_buffer = output_exact
        building.last_processed_at = now
        return 0

    input_inventory = (
        db.query(Inventory)
        .filter(
            Inventory.company_id == building.company_id,
            Inventory.good_id == building.input_good_id,
        )
        .with_for_update()
        .first()
    )

    if not input_inventory or input_inventory.quantity <= 0:
        building.last_processed_at = now
        building.production_buffer = output_exact
        return 0

    max_possible = min(
        output_units,
        int(input_inventory.quantity / building.input_per_hour * building.output_per_hour),
    )

    if max_possible <= 0:
        building.last_processed_at = now
        return 0

    # consume input
    input_inventory.quantity -= max_possible * building.input_per_hour

    # add output
    output_inventory = (
        db.query(Inventory)
        .filter(
            Inventory.company_id == building.company_id,
            Inventory.good_id == building.output_good_id,
        )
        .with_for_update()
        .first()
    )

    if not output_inventory:
        output_inventory = Inventory(
            company_id=building.company_id,
            good_id=building.output_good_id,
            quantity=0,
            reserved=0,
        )
        db.add(output_inventory)

    output_inventory.quantity += max_possible

    building.production_buffer = output_exact - max_possible
    building.last_processed_at = now

    return max_possible
