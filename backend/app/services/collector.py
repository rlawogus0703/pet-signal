"""공고 수집기: 등록된 출처(app/sources)에서 공고를 받아 DB 에 저장.

공공 API 응답에서 쓸 만한 필드(사진 popfile1/popfile2, 품종, 색상, 나이, 체중, 성별, 중성화,
특징, 발견 장소, 보호소 이름·주소·전화, 공고 기간 등)를 모두 저장하고,
텍스트 임베딩과 (선택) 사진 임베딩까지 계산합니다.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, or_, select, update
from sqlalchemy.orm import Session

from app.ai import text_embedder, text_similarity
from app.config import get_settings
from app.models.db_models import MatchResultRow, NoticeRow
from app.services.image_index import embed_pending
from app.services.notice_state import STALE_STATE
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


def _warm(db: Session, ids: list[str]) -> None:
    """이미 있는 공고를 한 번에 불러와 db.get 이 건마다 DB 를 다시 조회하지 않게 합니다."""
    for i in range(0, len(ids), 500):
        list(db.scalars(select(NoticeRow).where(NoticeRow.notice_id.in_(ids[i : i + 500]))))


def _collect_paged(db: Session, src, *, rows: int, pages: int, result: dict) -> dict:
    """페이지(최대 1000건)마다 저장·커밋하고 메모리를 비웁니다."""
    info: dict = {"source": src.name, "ok": True, "fetched": 0, "new": 0, "totals": {}, "complete": False}
    seen: dict[str, int] = {}
    try:
        for state, recs, total, _page in src.iter_pages(rows=rows, max_pages=pages):
            info["totals"][state] = total
            _warm(db, list(dict.fromkeys(r.notice_id for r in recs)))
            for rec in recs:
                if upsert_record(db, rec):
                    info["new"] += 1
            db.commit()
            db.expunge_all()
            seen[state] = seen.get(state, 0) + len(recs)
            info["fetched"] += len(recs)
            result["with_photo"] = result.get("with_photo", 0) + sum(1 for r in recs if r.photo_url)
            result["geocoded"] = result.get("geocoded", 0) + sum(1 for r in recs if r.found_lat is not None)
        # 상태마다 거의 전부(98%↑) 받았을 때만 '목록에서 빠진 공고' 정리를 믿고 진행
        info["complete"] = bool(info["totals"]) and all(
            seen.get(s, 0) >= int(t * 0.98) for s, t in info["totals"].items()
        )
    except Exception as e:
        db.rollback()
        log.warning("source %s failed: %s", src.name, e)
        info.update(ok=info["fetched"] > 0, error=str(e))
    info["total_count"] = sum(info["totals"].values())
    return info


def mark_stale(db: Session, source: str, run_start: datetime) -> dict:
    """이번 수집에서 안 보인 공고(입양·반환·안락사 등으로 목록에서 빠짐)는 매칭·둘러보기에서 제외."""
    st = get_settings()
    r = db.execute(
        update(NoticeRow)
        .where(
            NoticeRow.source == source,
            NoticeRow.collected_at < run_start,
            or_(NoticeRow.process_state.is_(None), NoticeRow.process_state != STALE_STATE),
        )
        .values(process_state=STALE_STATE)
    )
    marked = r.rowcount or 0
    cutoff = _now() - timedelta(days=max(1, st.stale_delete_days))
    d = db.execute(
        delete(NoticeRow)
        .where(
            NoticeRow.source == source,
            NoticeRow.process_state == STALE_STATE,
            NoticeRow.collected_at < cutoff,
            NoticeRow.notice_id.not_in(select(MatchResultRow.notice_id)),
        )
        .execution_options(synchronize_session=False)
    )
    db.commit()
    return {"marked_stale": marked, "deleted_old": d.rowcount or 0}


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

    run_start = _now()
    result: dict = {"ok": True, "upserted": 0, "fetched": 0, "sources": []}
    for src in active:
        if hasattr(src, "iter_pages"):
            info = _collect_paged(db, src, rows=rows, pages=pages, result=result)
            if info.get("complete"):
                info.update(mark_stale(db, src.name, run_start))
            result["fetched"] += info["fetched"]
            result["upserted"] += info["new"]
            result["sources"].append(info)
            continue
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
        db.commit()
        result["fetched"] += len(records)
        result["upserted"] += new
        result["sources"].append({"source": src.name, "ok": True, "fetched": len(records), "new": new, **meta})
        result["with_photo"] = result.get("with_photo", 0) + sum(1 for r in records if r.photo_url)
        result["geocoded"] = result.get("geocoded", 0) + sum(1 for r in records if r.found_lat is not None)
        del records

    if not any(s.get("ok") for s in result["sources"]):
        result["ok"] = False
        result["error"] = "; ".join(s.get("error", "") for s in result["sources"])
    # 실제 공고가 들어오면 예시(시드) 데이터는 매칭에서 빼고 DB 에서도 정리
    if result.get("ok") and result.get("fetched"):
        from app.services.seed import remove_seed_notices

        result["seed_removed"] = remove_seed_notices(db)
    if embed_images:
        result["images"] = embed_pending(db)
    return result
