from datetime import datetime, timezone
from sqlalchemy.orm import Session

from app.models.extraction_site import ExtractionSite
from app.models.inventory import Inventory
from app.models.resource_deposit import ResourceDeposit

def get_deposit(db: Session, site: ExtractionSite) -> ResourceDeposit | None:
    return (
        db.query(ResourceDeposit)
        .filter(
            ResourceDeposit.location_id == site.location_id,
            ResourceDeposit.good_id == site.good_id,
        )
        .with_for_update()
        .first()
    )


def get_inventory(db: Session, site: ExtractionSite) -> Inventory:
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

    return inventory


def tick_site(
    db: Session,
    site: ExtractionSite,
    deposit: ResourceDeposit,
    inventory: Inventory,
) -> int:
    now = datetime.now(timezone.utc)

    if site.last_extracted_at is None:
        site.last_extracted_at = now
        return 0

    elapsed_seconds = (now - site.last_extracted_at).total_seconds()
    if elapsed_seconds <= 0:
        return 0

    # Convert time → production
    produced_exact = (
        elapsed_seconds / 3600.0
    ) * site.rate_per_hour

    # Add leftover buffer
    produced_exact += site.production_buffer

    # Only whole units can be produced
    produced_units = int(produced_exact)

    if produced_units <= 0:
        site.production_buffer = produced_exact
        site.last_extracted_at = now
        return 0

    # Clamp to remaining deposit
    actual_produced = min(produced_units, deposit.remaining_amount)

    # Update state
    deposit.remaining_amount -= actual_produced
    inventory.quantity += actual_produced

    site.production_buffer = produced_exact - actual_produced
    site.last_extracted_at = now

    if deposit.remaining_amount <= 0:
        site.active = False

    return actual_produced

def tick_all_extraction_sites(db: Session) -> int:
    sites = db.query(ExtractionSite).all()
    total_produced = 0

    for site in sites:
        if not site.active:
            continue

        deposit = get_deposit(db, site)
        if not deposit or deposit.remaining_amount <= 0:
            site.active = False
            continue

        inventory = get_inventory(db, site)

        produced = tick_site(db, site, deposit, inventory)
        total_produced += produced

    db.commit()
    return total_produced

