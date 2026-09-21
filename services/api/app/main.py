import asyncio
import logging
import os
import time
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, OperationalError, ProgrammingError

from .database import Base, SessionLocal, engine
from . import models, auth  # noqa: F401  (daftarkan model agar create_all tahu tabel)
from .routers import items, users, instance
from .seed import seed


# =====================================================================
# Logging
# =====================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("api")

DISCOVERY_URL = os.getenv("DISCOVERY_URL", "http://discovery:8500")
INSTANCE_NAME = os.getenv("INSTANCE_NAME", "api")


# =====================================================================
# Discovery Registration
# =====================================================================

async def register_to_discovery():
    for attempt in range(10):
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                resp = await client.post(
                    f"{DISCOVERY_URL}/register",
                    json={"name": INSTANCE_NAME, "host": INSTANCE_NAME, "port": 8000},
                )
                logger.info("registered to discovery: %s", resp.json())
                return
        except Exception as e:
            logger.warning("registration attempt %d/10 failed: %s", attempt + 1, e)
            await asyncio.sleep(2)
    logger.error("discovery registration gave up after 10 attempts")


async def unregister_from_discovery():
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            await client.delete(
                f"{DISCOVERY_URL}/register",
                json={"name": INSTANCE_NAME, "host": INSTANCE_NAME, "port": 8000},
            )
            logger.info("unregistered from discovery")
    except Exception as e:
        logger.warning("unregister from discovery failed: %s", e)


# =====================================================================
# Lifespan
# =====================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("API instance %s starting", INSTANCE_NAME)
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("database tables created/verified")
    except (OperationalError, ProgrammingError, IntegrityError) as e:
        logger.warning("database init error (non-fatal): %s", e)
    with SessionLocal() as db:
        seed(db)

    await register_to_discovery()

    yield

    await unregister_from_discovery()
    logger.info("API instance %s stopped", INSTANCE_NAME)


# =====================================================================
# FastAPI App
# =====================================================================

app = FastAPI(title="Simple API", version="1.0.0", lifespan=lifespan)

app.include_router(users.router)
app.include_router(items.router)
app.include_router(auth.router)
app.include_router(instance.router)


# =====================================================================
# Middleware: Request Logging
# =====================================================================

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration_ms = round((time.time() - start_time) * 1000, 2)

    log_level = logging.WARNING if response.status_code >= 400 else logging.INFO
    logger.log(
        log_level,
        "request: %s %s -> %d (%sms, instance=%s)",
        request.method,
        request.url.path,
        response.status_code,
        duration_ms,
        INSTANCE_NAME,
    )
    return response


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("unhandled exception on %s %s: %s", request.method, request.url.path, exc, exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"error": "internal server error", "detail": str(exc)},
    )


@app.get("/health")
def health():
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
        return {"status": "ok", "database": "connected"}
    except Exception as e:
        logger.error("health check failed: %s", e)
        return JSONResponse(
            {"status": "degraded", "database": "disconnected"},
            status_code=503,
        )
