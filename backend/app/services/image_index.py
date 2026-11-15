"""공고 사진 다운로드 → 임베딩 계산 → DB 캐시.

- 사진 바이트는 data/image_cache/ 에 저장 (다시 받지 않음, 웹 사진 프록시도 이 캐시 사용)
- 임베딩은 notices.image_embedding_json + image_embed_method 에 저장
- 다운로드 실패·타임아웃은 image_status='fetch_failed' 로 표시하고 넘어갑니다
"""

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
    """사진 원본 위치: 로컬 예시 사진(시드) → 공고 사진 URL."""
    if n.photo_local:
        p = Path(n.photo_local)
        if not p.is_absolute():
            p = BACKEND_DIR.parent / p
        if p.is_file():
            return str(p)
    return n.photo_url or n.photo_url2


def notice_photo_bytes(n: NoticeRow, which: int = 1) -> bytes | None:
    """공고 사진 바이트. 1번이 실패하면 popfile2 로 넘어가고, https/http 도 같이 시도합니다."""
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
        return False  # 이미 실패한 사진은 다시 시도하지 않음
    return bool(notice_photo_source(n))


def embed_notices(
    db: Session, notices: list[NoticeRow], *, max_workers: int | None = None, cache: bool = True
) -> dict:
    """여러 공고 사진을 병렬로 받아 임베딩. 결과 요약을 돌려줍니다."""
    st = get_settings()
    method = image_embedder.current_method()
    todo = [n for n in notices if needs_embedding(n, method)]
    stats = {"requested": len(todo), "embedded": 0, "failed": 0, "method": method}
    if not todo:
        return stats
    srcs = [notice_photo_source(n) for n in todo]
    workers = max_workers or st.image_workers
    # CLIP 은 모델이 스레드 안전하지 않을 수 있어 다운로드만 병렬, 임베딩은 순차
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
    """사진 임베딩이 아직 없는 공고만, 최신 공고부터 조금씩(chunk) 계산합니다.

    무료 서버(메모리 512MB)에서 한 번에 수천 장을 받지 않도록 수집 1회당 최대 limit 장,
    시간 예산(budget_seconds)을 넘기면 다음 수집 때 이어서 합니다.
    """
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
            # 이미 같은 방식으로 실패한 사진은 다시 시도하지 않음
            # (NULL 비교는 SQL 에서 참/거짓이 아니라서 is_(None) 을 따로 둡니다)
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


# ── 실종견(사용자) 사진 ────────────────────────────────────
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


# ── 목록용 미리보기(썸네일) ─────────────────────────────────
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
    """테스트용: 메모리 캐시만 비웁니다."""
    with _thumb_lock:
        _thumb_mem.clear()


def _remember_thumb(key: str, data: bytes) -> None:
    with _thumb_lock:
        _thumb_mem[key] = data
        _thumb_mem.move_to_end(key)
        while len(_thumb_mem) > THUMB_MEM_MAX:
            _thumb_mem.popitem(last=False)


def make_thumbnail(data: bytes, *, max_side: int = THUMB_MAX_SIDE) -> bytes:
    """긴 변을 max_side 로 줄인 progressive JPEG. RGBA/P 는 흰 배경 RGB 로 바꿉니다."""
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
    """미리보기 JPEG. 메모리(최대 500장)와 data/image_cache/ 디스크를 함께 씁니다."""
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
