"""펫 시그널 FastAPI 서버."""

from __future__ import annotations

import logging
import threading

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth_routes import router as auth_router
from app.api.routes import router
from app.config import LOCAL_ORIGIN_REGEX, get_settings, redact_secrets
from app.console import make_console_safe
from app.database import SessionLocal, init_db
from app.services.collect_lock import acquire_collect_lock, release_collect_lock
from app.services.collector import collect_notices
from app.services.seed import seed_if_needed

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
if origins == ["*"]:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_origin_regex=LOCAL_ORIGIN_REGEX,
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
        seed_if_needed(db)
    finally:
        db.close()

    if settings.decoded_service_key and settings.collect_on_startup:
        log.info("SERVICE_KEY found - collecting public notices in background (API mode)")
        threading.Thread(target=_job_collect, daemon=True, name="collect-startup").start()

    if settings.enable_scheduler and settings.decoded_service_key:
        _scheduler = BackgroundScheduler()
        _scheduler.add_job(
            _job_collect,
            "interval",
            minutes=max(1, settings.collect_interval_minutes),
            id="collect_notices",
            replace_existing=True,
            max_instances=1,
            coalesce=True,
            misfire_grace_time=300,
        )
        _scheduler.start()
        log.info("APScheduler started (every %s min, single-instance)", settings.collect_interval_minutes)
    else:
        log.info("Scheduler disabled or SERVICE_KEY missing - sample(seed) mode if no real notices")


@app.on_event("shutdown")
def on_shutdown() -> None:
    global _scheduler
    if _scheduler:
        _scheduler.shutdown(wait=False)
        _scheduler = None
    release_collect_lock()


@app.get("/healthz")
def healthz():
    """cron-job.org 등 keep-alive 용 가벼운 엔드포인트 (DB 조회 없음)."""
    return {"ok": True}


@app.get("/health")
def health():
    return {
        "ok": True,
        "service": "pet-signal",
        "mode": "api" if settings.decoded_service_key else "sample",
    }


def _job_collect() -> None:
    if not acquire_collect_lock():
        log.info("collect job skipped (already running)")
        return
    db = SessionLocal()
    try:
        result = collect_notices(db)
        log.info("collect job: %s", redact_secrets(str(result), settings.decoded_service_key))
    except Exception:
        log.exception("collect job failed")
    finally:
        db.close()
        release_collect_lock()
