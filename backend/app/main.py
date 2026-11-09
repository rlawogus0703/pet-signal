"""펫 시그널 FastAPI 서버."""

from __future__ import annotations

import logging

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth_routes import router as auth_router
from app.api.routes import router
from app.config import get_settings
from app.console import make_console_safe
from app.database import SessionLocal, init_db
from app.services.collector import collect_notices
from app.services.seed import seed_notices

make_console_safe()
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("petsignal")

settings = get_settings()
app = FastAPI(title="Pet Signal API", version="0.1.0", description="10조 펫 시그널 — 유사 후보 매칭")

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if origins != ["*"] else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(router)

_scheduler: BackgroundScheduler | None = None


@app.on_event("startup")
def on_startup() -> None:
    global _scheduler
    init_db()
    db = SessionLocal()
    try:
        seed_notices(db)
    finally:
        db.close()

    if settings.enable_scheduler and settings.service_key:
        _scheduler = BackgroundScheduler()
        _scheduler.add_job(
            _job_collect,
            "interval",
            minutes=settings.collect_interval_minutes,
            id="collect_notices",
            replace_existing=True,
        )
        _scheduler.start()
        log.info("APScheduler started (every %s min)", settings.collect_interval_minutes)
    else:
        log.info("Scheduler disabled or SERVICE_KEY missing - seed-only mode")


@app.on_event("shutdown")
def on_shutdown() -> None:
    global _scheduler
    if _scheduler:
        _scheduler.shutdown(wait=False)
        _scheduler = None


def _job_collect() -> None:
    db = SessionLocal()
    try:
        result = collect_notices(db)
        log.info("collect job: %s", result)
    except Exception:
        log.exception("collect job failed")
    finally:
        db.close()


@app.get("/health")
def health():
    return {"ok": True, "service": "pet-signal"}
