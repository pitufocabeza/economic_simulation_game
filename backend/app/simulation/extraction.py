from datetime import datetime
from sqlalchemy.orm import Session

from app.models.extraction_site import ExtractionSite
from app.models.resource_deposit import ResourceDeposit
from app.models.inventory import Inventory


def tick_extraction(
    db: Session,
    now: datetime,
    speed_multiplier: float,
) -> dict:
    sites = (
        db.query(ExtractionSite)
        .filter(ExtractionSite.active == True)
        .with_for_update()
        .all()
    )

    total_produced = 0
    processed_sites = 0

    for site in sites:
        produced = tick_single_site(
            db=db,
            site=site,
            now=now,
            speed_multiplier=speed_multiplier,
        )
        total_produced += produced
        processed_sites += 1

    return {
        "sites_processed": processed_sites,
        "total_produced": total_produced,
    }


def tick_single_site(
    db: Session,
    site: ExtractionSite,
    now: datetime,
    speed_multiplier: float,
) -> int:
    # First tick: initialize timestamp
    if site.last_extracted_at is None:
        site.last_extracted_at = now
        return 0

    real_elapsed = (now - site.last_extracted_at).total_seconds()
    elapsed_seconds = real_elapsed * speed_multiplier

    if elapsed_seconds <= 0:
        return 0

    produced_exact = (
        elapsed_seconds / 3600.0
    ) * site.rate_per_hour

    produced_exact += site.production_buffer
    produced_units = int(produced_exact)

    if produced_units <= 0:
        site.production_buffer = produced_exact
        site.last_extracted_at = now
        return 0

    deposit = (
        db.query(ResourceDeposit)
        .filter(
            ResourceDeposit.location_id == site.location_id,
            ResourceDeposit.good_id == site.good_id,
        )
        .with_for_update()
        .first()
    )

    if not deposit or deposit.remaining_amount <= 0:
        site.active = False
        site.last_extracted_at = now
        site.production_buffer = 0
        return 0

    actual = min(produced_units, deposit.remaining_amount)
    deposit.remaining_amount -= actual

    inventory = (
        db.query(Inventory)
        .filter(
            Inventory.company_id == site.company_id,
            Inventory.good_id == site.good_id,
        )
        .with_for_update()
        .first()
    )

    if not inventory:
        inventory = Inventory(
            company_id=site.company_id,
            good_id=site.good_id,
            quantity=0,
            reserved=0,
        )
        db.add(inventory)

    inventory.quantity += actual

    site.production_buffer = produced_exact - actual
    site.last_extracted_at = now

    if deposit.remaining_amount <= 0:
        site.active = False

    return actual
