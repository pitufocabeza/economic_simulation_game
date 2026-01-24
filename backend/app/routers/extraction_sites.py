from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.extraction_site import ExtractionSite
from app.models.location import Location
from app.services.extraction import tick_all_extraction_sites
from app.schemas.extraction_site import (
    ExtractionSiteCreate,
    ExtractionSiteRead,
)

router = APIRouter(prefix="/extraction-sites", tags=["extraction-sites"])

@router.post("/", response_model=ExtractionSiteRead)
def create_extraction_site(
    company_id: int,
    payload: ExtractionSiteCreate,
    db: Session = Depends(get_db),
):
    # Location must exist
    location = db.query(Location).get(payload.location_id)
    if not location:
        raise HTTPException(404, "Location not found")

    # Must own the location
    if location.claimed_by_company_id != company_id:
        raise HTTPException(403, "Location not owned by company")

    # One extractor per resource per location
    existing = (
        db.query(ExtractionSite)
        .filter(
            ExtractionSite.location_id == payload.location_id,
            ExtractionSite.good_id == payload.good_id,
        )
        .first()
    )
    if existing:
        raise HTTPException(400, "Extraction site already exists for this resource")

    site = ExtractionSite(
        company_id=company_id,
        location_id=payload.location_id,
        good_id=payload.good_id,
        rate_per_hour=payload.rate_per_hour,
    )

    db.add(site)
    db.commit()
    db.refresh(site)

    return site

@router.get("/", response_model=list[ExtractionSiteRead])
def list_extraction_sites(
    company_id: int | None = None,
    db: Session = Depends(get_db),
):
    q = db.query(ExtractionSite)

    if company_id:
        q = q.filter(ExtractionSite.company_id == company_id)

    return q.all()

@router.get("/", response_model=list[ExtractionSiteRead])
def list_extraction_sites(
    company_id: int | None = None,
    db: Session = Depends(get_db),
):
    q = db.query(ExtractionSite)

    if company_id:
        q = q.filter(ExtractionSite.company_id == company_id)

    return q.all()

@router.post("/tick")
def tick_extraction(db: Session = Depends(get_db)):
    produced = tick_all_extraction_sites(db)
    return {
        "status": "ok",
        "total_produced": produced,
    }