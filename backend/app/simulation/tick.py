from datetime import datetime, timezone
from sqlalchemy.orm import Session

from app.simulation.extraction import tick_extraction
from app.simulation.production import tick_production

from app.simulation.config import SIMULATION_CONFIG


def run_simulation_tick(db: Session):
    now = datetime.now(timezone.utc)

    production_stats = tick_production(
        db=db,
        now=now,
        speed_multiplier=SIMULATION_CONFIG.speed_multiplier,
    )

    extraction_stats = tick_extraction(
        db=db,
        now=now,
        speed_multiplier=SIMULATION_CONFIG.speed_multiplier,
    )

    db.commit()

    return {
        "extraction": extraction_stats,
        "production": production_stats,
        "timestamp": now.isoformat(),
    }

def get_effective_delta_seconds(
    last_tick: datetime,
    now: datetime,
) -> float:
    real_delta = (now - last_tick).total_seconds()
    return real_delta * SIMULATION_CONFIG.speed_multiplier