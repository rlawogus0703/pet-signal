from __future__ import annotations

import hashlib
import io
import logging
import time
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Lock

import httpx
from sqlalchemy.orm import Session

from app.ai import image_embedder
from app.config import get_settings
from app.models.db_models import LostDogRow, NoticeRow
from app.services.matcher import dumps_emb, loads_emb

log = logging.getLogger(__name__)

BACKEND_DIR = Path(__file__).resolve().parents[2]
WEB_ASSETS = BACKEND_DIR.parent / "web" / "assets" / "dogs"
UPLOAD_DIR = BACKEND_DIR / "data" / "uploads"


def notice_photo_source(n: NoticeRow) -> str | None:
    if n.photo_local:
        p = Path(n.photo_local)
        if not p.is_absolute():
            p = BACKEND_DIR.parent / p
        if p.is_file():
            return str(p)
    return n.photo_url or n.photo_url2


def notice_photo_bytes(n: NoticeRow, which: int = 1) -> bytes | None:
    st = get_settings()
    timeout = max(st.image_fetch_timeout, 12.0)
    urls: list[str | None]
    if which == 2:
        urls = [n.photo_url2]
    else:
        urls = []
        src = notice_photo_source(n)
        if src:
            urls.append(src)
        if n.photo_url and n.photo_url not in urls:
            urls.append(n.photo_url)
        if n.photo_url2 and n.photo_url2 not in urls:
            urls.append(n.photo_url2)
    for u in urls:
        data = image_embedder.fetch_bytes(u, timeout=timeout)
        if data and image_embedder.looks_like_image(data):
            return data
    return None


def needs_embedding(n: NoticeRow, method: str) -> bool:
    if n.image_embedding_json and n.image_embed_method == method:
        return False
    if n.image_status == "fetch_failed" and n.image_embed_method == method:
        return False
    return bool(notice_photo_source(n))


def embed_notices(
    db: Session, notices: list[NoticeRow], *, max_workers: int | None = None, cache: bool = True
) -> dict:
    st = get_settings()
    method = image_embedder.current_method()
    todo = [n for n in notices if needs_embedding(n, method)]
    stats = {"requested": len(todo), "embedded": 0, "failed": 0, "method": method}
    if not todo:
        return stats
    srcs = [notice_photo_source(n) for n in todo]
    workers = max_workers or st.image_workers
    with httpx.Client(timeout=st.image_fetch_timeout, follow_redirects=True) as client:
        with ThreadPoolExecutor(max_workers=workers) as ex:
            datas = list(
                ex.map(lambda s: image_embedder.fetch_bytes(s, timeout=st.image_fetch_timeout, client=client, cache=cache), srcs)
            )
    for n, data in zip(todo, datas):
        emb, m = (image_embedder.embed_bytes(data) if data else (None, method))
        n.image_embed_method = m
        if emb is None:
            n.image_embedding_json = None
            n.image_status = "fetch_failed"
            stats["failed"] += 1
        else:
            n.image_embedding_json = dumps_emb(emb)
            n.image_status = "ok"
            stats["embedded"] += 1
    db.commit()
    return stats


def embed_pending(db: Session, *, limit: int | None = None, chunk: int | None = None,
                  budget_seconds: float | None = None) -> dict:
    from sqlalchemy import func, or_, select

    from app.services.notice_state import STALE_STATE

    st = get_settings()
    limit = st.embed_batch_per_run if limit is None else limit
    chunk = max(1, chunk or st.embed_chunk)
    budget = st.embed_time_budget_seconds if budget_seconds is None else budget_seconds
    method = image_embedder.current_method()
    pending_q = (
        select(NoticeRow.notice_id)
        .where(
            NoticeRow.source != "seed",
            or_(NoticeRow.process_state.is_(None), NoticeRow.process_state != STALE_STATE),
            or_(NoticeRow.photo_url.is_not(None), NoticeRow.photo_url2.is_not(None)),
            or_(
                NoticeRow.image_embedding_json.is_(None),
                NoticeRow.image_embed_method.is_(None),
                NoticeRow.image_embed_method != method,
            ),
            or_(
                NoticeRow.image_status.is_(None),
                NoticeRow.image_status != "fetch_failed",
                NoticeRow.image_embed_method.is_(None),
                NoticeRow.image_embed_method != method,
            ),
        )
    )
    ids = list(
        db.scalars(
            pending_q.order_by(NoticeRow.notice_start.desc(), NoticeRow.notice_id.desc()).limit(max(0, limit))
        )
    )
    stats = {"requested": 0, "embedded": 0, "failed": 0, "method": method, "stopped_by_budget": False}
    t0 = time.monotonic()
    for i in range(0, len(ids), chunk):
        if budget and time.monotonic() - t0 > budget:
            stats["stopped_by_budget"] = True
            break
        rows = list(db.scalars(select(NoticeRow).where(NoticeRow.notice_id.in_(ids[i : i + chunk]))))
        s = embed_notices(db, rows, cache=False)
        for k in ("requested", "embedded", "failed"):
            stats[k] += s[k]
        db.expunge_all()
    stats["remaining"] = db.scalar(select(func.count()).select_from(pending_q.subquery())) or 0
    stats["seconds"] = round(time.monotonic() - t0, 1)
    return stats


def notice_embedding(n: NoticeRow, method: str) -> list[float] | None:
    if n.image_embed_method != method:
        return None
    return loads_emb(n.image_embedding_json)


def save_dog_photo(dog: LostDogRow, data: bytes) -> str:
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    p = UPLOAD_DIR / f"{dog.id}.img"
    p.write_bytes(data)
    dog.photo_path = str(p)
    return str(p)


def ensure_dog_image_embedding(dog: LostDogRow) -> list[float] | None:
    method = image_embedder.current_method()
    if dog.image_embedding_json and dog.image_embed_method == method:
        return loads_emb(dog.image_embedding_json)
    data = None
    if dog.photo_path and Path(dog.photo_path).is_file():
        data = Path(dog.photo_path).read_bytes()
    elif dog.photo_url and dog.photo_url.startswith("http"):
        data = image_embedder.fetch_bytes(dog.photo_url)
    if not data:
        return None
    emb, m = image_embedder.embed_bytes(data)
    dog.image_embedding_json = dumps_emb(emb)
    dog.image_embed_method = m
    return emb


THUMB_MAX_SIDE = 400
THUMB_QUALITY = 75
THUMB_MEM_MAX = 500
THUMB_MIN_SIDE = 64
THUMB_CLAMP_SIDE = 800

_thumb_mem: OrderedDict[str, bytes] = OrderedDict()
_thumb_lock = Lock()


def clamp_thumb_side(max_side: int) -> int:
    return max(THUMB_MIN_SIDE, min(THUMB_CLAMP_SIDE, int(max_side)))


def thumb_cache_path(src: bytes, max_side: int) -> Path:
    h = hashlib.sha1(src).hexdigest()
    return image_embedder.CACHE_DIR / f"{h}.t{max_side}.jpg"


def clear_thumb_cache() -> None:
    with _thumb_lock:
        _thumb_mem.clear()


def _remember_thumb(key: str, data: bytes) -> None:
    with _thumb_lock:
        _thumb_mem[key] = data
        _thumb_mem.move_to_end(key)
        while len(_thumb_mem) > THUMB_MEM_MAX:
            _thumb_mem.popitem(last=False)


def make_thumbnail(data: bytes, *, max_side: int = THUMB_MAX_SIDE) -> bytes:
    from PIL import Image

    max_side = clamp_thumb_side(max_side)
    im = Image.open(io.BytesIO(data))
    im.load()
    if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
        rgba = im.convert("RGBA")
        bg = Image.new("RGB", rgba.size, (255, 255, 255))
        bg.paste(rgba, mask=rgba.split()[-1])
        im = bg
    elif im.mode != "RGB":
        im = im.convert("RGB")
    w, h = im.size
    longest = max(w, h)
    if longest > max_side:
        scale = max_side / longest
        im = im.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.Resampling.LANCZOS)
    out = io.BytesIO()
    im.save(out, format="JPEG", quality=THUMB_QUALITY, optimize=True, progressive=True)
    return out.getvalue()


def thumbnail_bytes(data: bytes, *, max_side: int = THUMB_MAX_SIDE) -> bytes:
    max_side = clamp_thumb_side(max_side)
    key = hashlib.sha1(data).hexdigest() + f":{max_side}"
    with _thumb_lock:
        cached = _thumb_mem.get(key)
        if cached is not None:
            _thumb_mem.move_to_end(key)
            return cached
    path = thumb_cache_path(data, max_side)
    if path.is_file() and path.stat().st_size > 0:
        try:
            out = path.read_bytes()
            if out[:3] == b"\xff\xd8\xff":
                _remember_thumb(key, out)
                return out
        except Exception:
            pass
    out = make_thumbnail(data, max_side=max_side)
    try:
        image_embedder.CACHE_DIR.mkdir(parents=True, exist_ok=True)
        path.write_bytes(out)
    except Exception:
        log.debug("thumb disk cache write failed", exc_info=True)
    _remember_thumb(key, out)
    return out
