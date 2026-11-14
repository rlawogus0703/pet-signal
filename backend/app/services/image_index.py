"""공고 사진 다운로드 → 임베딩 계산 → DB 캐시.

- 사진 바이트는 data/image_cache/ 에 저장 (다시 받지 않음, 웹 사진 프록시도 이 캐시 사용)
- 임베딩은 notices.image_embedding_json + image_embed_method 에 저장
- 다운로드 실패·타임아웃은 image_status='fetch_failed' 로 표시하고 넘어갑니다
"""

from __future__ import annotations

import logging
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

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
    st = get_settings()
    if which == 2:
        return image_embedder.fetch_bytes(n.photo_url2, timeout=st.image_fetch_timeout)
    return image_embedder.fetch_bytes(notice_photo_source(n), timeout=st.image_fetch_timeout)


def needs_embedding(n: NoticeRow, method: str) -> bool:
    if n.image_embedding_json and n.image_embed_method == method:
        return False
    if n.image_status == "fetch_failed" and n.image_embed_method == method:
        return False  # 이미 실패한 사진은 다시 시도하지 않음
    return bool(notice_photo_source(n))


def embed_notices(db: Session, notices: list[NoticeRow], *, max_workers: int | None = None) -> dict:
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
                ex.map(lambda s: image_embedder.fetch_bytes(s, timeout=st.image_fetch_timeout, client=client), srcs)
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
