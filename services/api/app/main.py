from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from sqlalchemy import text

from .database import Base, SessionLocal, engine
from . import models, auth  # noqa: F401  (daftarkan model agar create_all tahu tabel)
from .routers import items, users
from .seed import seed


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed(db)
    yield


app = FastAPI(title="Simple API", version="1.0.0", lifespan=lifespan)

app.include_router(users.router)
app.include_router(items.router)
app.include_router(auth.router)


@app.get("/health")
def health():
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
        return {"status": "ok", "database": "connected"}
    except Exception:
        return JSONResponse(
            {"status": "degraded", "database": "disconnected"},
            status_code=503,
        )