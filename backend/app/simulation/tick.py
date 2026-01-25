from datetime import datetime, timezone
from sqlalchemy.orm import Session

from app.simulation.extraction import tick_extraction


def run_simulation_tick(db: Session) -> dict:
    """
    Advances the world simulation to 'now'.
    Returns stats for debugging / UI.
    """
    now = datetime.now(timezone.utc)

    extraction_stats = tick_extraction(db, now)

    db.commit()

    return {
        "extraction": extraction_stats,
        "timestamp": now.isoformat(),
    }
