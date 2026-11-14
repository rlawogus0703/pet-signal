"""공고 수집기: 등록된 출처(app/sources)에서 공고를 받아 DB 에 저장.

공공 API 응답에서 쓸 만한 필드(사진 popfile1/popfile2, 품종, 색상, 나이, 체중, 성별, 중성화,
특징, 발견 장소, 보호소 이름·주소·전화, 공고 기간 등)를 모두 저장하고,
텍스트 임베딩과 (선택) 사진 임베딩까지 계산합니다.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.ai import text_embedder, text_similarity
from app.config import get_settings
from app.models.db_models import NoticeRow
from app.services.image_index import embed_notices
from app.services.matcher import dumps_emb
from app.services.normalizer import norm_breed, norm_color
from app.sources.base import NoticeRecord, NoticeSource

log = logging.getLogger(__name__)


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def upsert_record(db: Session, rec: NoticeRecord) -> bool:
    """공고 1건 저장. 새로 들어가면 True."""
    sentence = text_similarity.describe(rec.breed, rec.color, rec.age, rec.features)
    existing = db.get(NoticeRow, rec.notice_id)
    fields = dict(
        source=rec.source,
        notice_no=rec.notice_no,
        photo_url=rec.photo_url,
        photo_url2=rec.photo_url2,
        breed=rec.breed,
        kind_full=rec.kind_full,
        color=rec.color,
        age=rec.age,
        weight=rec.weight,
        sex=rec.sex,
        neuter=rec.neuter,
        features=rec.features,
        found_date=rec.found_date,
        found_lat=rec.found_lat,
        found_lng=rec.found_lng,
        found_address=rec.found_address,
        geo_level=rec.geo_level,
        shelter_name=rec.shelter_name,
        shelter_phone=rec.shelter_phone,
        care_addr=rec.care_addr,
        org_nm=rec.org_nm,
        process_state=rec.process_state,
        notice_start=rec.notice_start,
        notice_end=rec.notice_end,
        notice_url=rec.notice_url,
        breed_norm=norm_breed(rec.breed),
        color_norm=norm_color(rec.color),
        raw_json=json.dumps(rec.raw, ensure_ascii=False),
        collected_at=_now(),
    )
    if existing:
        photo_changed = existing.photo_url != rec.photo_url
        text_changed = (existing.features, existing.breed, existing.color, existing.age) != (
            rec.features, rec.breed, rec.color, rec.age)
        for k, v in fields.items():
            setattr(existing, k, v)
        if photo_changed:
            existing.image_embedding_json = None
            existing.image_status = None
        if text_changed or not existing.text_embedding_json:
            existing.text_embedding_json = dumps_emb(text_embedder.embed_text(sentence))
        return False
    db.add(
        NoticeRow(
            notice_id=rec.notice_id,
            text_embedding_json=dumps_emb(text_embedder.embed_text(sentence)),
            **fields,
        )
    )
    return True


def collect_notices(
    db: Session,
    *,
    pages: int | None = None,
    num_of_rows: int | None = None,
    embed_images: bool | None = None,
    sources: list[NoticeSource] | None = None,
    page_no: int | None = None,  # 예전 인자 호환 (무시)
) -> dict:
    st = get_settings()
    pages = pages or st.collect_pages
    rows = num_of_rows or st.collect_rows
    embed_images = st.embed_images_on_collect if embed_images is None else embed_images
    if sources is None:
        from app.sources.registry import available_sources

        sources = available_sources()
    active = [s for s in sources if s.enabled()]
    if not active:
        return {"ok": False, "error": "SERVICE_KEY not set", "upserted": 0, "fetched": 0}

    result: dict = {"ok": True, "upserted": 0, "fetched": 0, "sources": []}
    touched: list[str] = []
    for src in active:
        try:
            records, meta = src.fetch(pages=pages, rows=rows)
        except Exception as e:
            log.warning("source %s failed: %s", src.name, e)
            result["sources"].append({"source": src.name, "ok": False, "error": str(e)})
            continue
        new = 0
        for rec in records:
            if upsert_record(db, rec):
                new += 1
            touched.append(rec.notice_id)
        db.commit()
        result["fetched"] += len(records)
        result["upserted"] += new
        result["sources"].append({"source": src.name, "ok": True, "fetched": len(records), "new": new, **meta})
        result["with_photo"] = result.get("with_photo", 0) + sum(1 for r in records if r.photo_url)
        result["geocoded"] = result.get("geocoded", 0) + sum(1 for r in records if r.found_lat is not None)

    if not any(s.get("ok") for s in result["sources"]):
        result["ok"] = False
        result["error"] = "; ".join(s.get("error", "") for s in result["sources"])
    if embed_images and touched:
        notices = [db.get(NoticeRow, nid) for nid in dict.fromkeys(touched)]
        result["images"] = embed_notices(db, [n for n in notices if n is not None])
    return result
