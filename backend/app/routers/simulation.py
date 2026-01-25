from fastapi import APIRouter
from app.simulation.config import SIMULATION_CONFIG

router = APIRouter(prefix="/simulation", tags=["simulation"])


@router.get("/speed")
def get_speed():
    return {
        "speed_multiplier": SIMULATION_CONFIG.speed_multiplier
    }


@router.post("/speed")
def set_speed(multiplier: float):
    if multiplier <= 0:
        raise ValueError("Speed must be > 0")

    SIMULATION_CONFIG.speed_multiplier = multiplier
    return {
        "speed_multiplier": SIMULATION_CONFIG.speed_multiplier
    }
