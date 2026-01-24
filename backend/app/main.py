from fastapi import FastAPI

from app.routers.goods import router as goods_router
from app.routers.companies import router as companies_router
from app.routers.inventories import router as inventories_router
from app.routers.production import router as production_router
from app.routers.admin_recipes import router as admin_recipes_router
from app.routers.market import router as market_router
from app.routers import admin


from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Economy MMO MVP")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(goods_router)
app.include_router(companies_router)
app.include_router(inventories_router)
app.include_router(production_router)
app.include_router(admin_recipes_router)
app.include_router(market_router)
app.include_router(admin.router)




@app.get("/health")
def health():
    return {"status": "ok"}
