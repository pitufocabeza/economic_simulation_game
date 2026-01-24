from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.location import Location
from app.models.resource_deposit import ResourceDeposit
from app.models.extraction_site import ExtractionSite
from app.models.good import Good
from app.models.company import Company

router = APIRouter(prefix="/map", tags=["map"])


@router.get("/")
def get_map(db: Session = Depends(get_db)):
    goods = {g.id: g.name for g in db.query(Good).all()}
    companies = {c.id: c.name for c in db.query(Company).all()}

    locations = db.query(Location).all()
    result = []

    for loc in locations:
        deposits = (
            db.query(ResourceDeposit)
            .filter(ResourceDeposit.location_id == loc.id)
            .all()
        )

        extractors = (
            db.query(ExtractionSite)
            .filter(ExtractionSite.location_id == loc.id)
            .all()
        )

        result.append({
            "id": loc.id,
            "name": loc.name,
            "x": loc.x,
            "y": loc.y,
            "biome": loc.biome,
            "claimed_by_company_id": loc.claimed_by_company_id,
            "claimed_by_company_name": companies.get(loc.claimed_by_company_id),

            "deposits": [
                {
                    "good_id": d.good_id,
                    "good_name": goods.get(d.good_id),
                    "remaining_amount": d.remaining_amount,
                }
                for d in deposits
            ],

            "extraction_sites": [
                {
                    "id": s.id,
                    "company_id": s.company_id,
                    "company_name": companies.get(s.company_id),
                    "good_id": s.good_id,
                    "good_name": goods.get(s.good_id),
                    "rate_per_hour": s.rate_per_hour,
                    "active": s.active,
                }
                for s in extractors
            ],
        })

    return {"locations": result}
