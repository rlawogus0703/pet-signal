from __future__ import annotations

import logging
import threading

from sqlalchemy import text

from app.database import engine

log = logging.getLogger("petsignal")

_collect_lock = threading.Lock()
_COLLECT_LOCK_ID = 74628401
_lock_conn = None


def acquire_collect_lock() -> bool:
    global _lock_conn
    if not _collect_lock.acquire(blocking=False):
        return False
    if engine.dialect.name != "postgresql":
        return True
    try:
        conn = engine.connect()
        got = conn.execute(text("SELECT pg_try_advisory_lock(:k)"), {"k": _COLLECT_LOCK_ID}).scalar()
        if not got:
            conn.close()
            _collect_lock.release()
            return False
        _lock_conn = conn
        return True
    except Exception:
        log.exception("collect advisory lock failed")
        try:
            if _lock_conn is not None:
                _lock_conn.close()
        except Exception:
            pass
        _lock_conn = None
        if _collect_lock.locked():
            _collect_lock.release()
        return False


def release_collect_lock() -> None:
    global _lock_conn
    try:
        if _lock_conn is not None:
            try:
                _lock_conn.execute(text("SELECT pg_advisory_unlock(:k)"), {"k": _COLLECT_LOCK_ID})
            except Exception:
                pass
            try:
                _lock_conn.close()
            except Exception:
                pass
    finally:
        _lock_conn = None
        if _collect_lock.locked():
            _collect_lock.release()
