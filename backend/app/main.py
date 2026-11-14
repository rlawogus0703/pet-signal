"""펫 시그널 FastAPI 서버."""

from __future__ import annotations

import logging
import threading

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
# httpx 는 요청 URL(인증키 포함)을 INFO 로 찍으므로 숨깁니다
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
log = logging.getLogger("petsignal")

settings = get_settings()
app = FastAPI(
    title="Pet Signal API",
    version="0.2.0",
    description="10조 펫 시그널 — 텍스트·이미지·규칙 멀티모달 유사 후보 매칭",
)

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

    if settings.decoded_service_key and settings.collect_on_startup:
        log.info("SERVICE_KEY found - collecting public notices in background (API mode)")
        threading.Thread(target=_job_collect, daemon=True).start()

    if settings.enable_scheduler and settings.decoded_service_key:
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
        log.info("Scheduler disabled or SERVICE_KEY missing - sample(seed) mode")


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
    return {
        "ok": True,
        "service": "pet-signal",
        "mode": "api" if settings.decoded_service_key else "sample",
    }
