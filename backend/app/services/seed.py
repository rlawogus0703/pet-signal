"""예시 공고 시드 적재 (키 없이 시연하는 샘플 데이터 모드)."""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.ai import text_embedder, text_similarity
from app.models.db_models import MatchResultRow, NoticeRow, NotificationRow
from app.services.matcher import dumps_emb
from app.services.normalizer import norm_breed, norm_color

SEED_PATH = Path(__file__).resolve().parents[2] / "data" / "seed_notices.json"


def _d(v):
    return date.fromisoformat(v) if v else None


def seed_notices(db: Session, *, embed_images: bool = True) -> int:
    data = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    count = 0
    rows: list[NoticeRow] = []
    for item in data:
        nid = item["notice_id"]
        existing = db.get(NoticeRow, nid)
        sentence = text_similarity.describe(
            item.get("breed", ""), item.get("color", ""), item.get("age"), item.get("features", "")
        )
        fields = dict(
            source="seed",
            notice_no=item.get("notice_no", ""),
            photo_url=item.get("photo_url"),
            photo_local=item.get("photo_local"),
            breed=item.get("breed", ""),
            color=item.get("color", ""),
            age=item.get("age"),
            features=item.get("features", ""),
            found_date=_d(item.get("found_date")),
            found_lat=item.get("found_lat"),
            found_lng=item.get("found_lng"),
            found_address=item.get("found_address", ""),
            shelter_name=item.get("shelter_name", ""),
            shelter_phone=item.get("shelter_phone", ""),
            care_addr=item.get("care_addr", ""),
            notice_start=_d(item.get("notice_start")),
            notice_end=_d(item.get("notice_end")),
            process_state="보호중",
            notice_url=item.get("notice_url", ""),
            breed_norm=norm_breed(item.get("breed", "")),
            color_norm=norm_color(item.get("color", "")),
            text_embedding_json=dumps_emb(text_embedder.embed_text(sentence)),
            raw_json=json.dumps(item, ensure_ascii=False),
        )
        if existing:
            if existing.photo_local != fields["photo_local"]:
                existing.image_embedding_json = None
                existing.image_status = None
            for k, v in fields.items():
                setattr(existing, k, v)
            rows.append(existing)
        else:
            row = NoticeRow(notice_id=nid, **fields)
            db.add(row)
            rows.append(row)
            count += 1
    db.commit()
    if embed_images:
        from app.services.image_index import embed_notices

        embed_notices(db, rows)
    return count



def has_real_notices(db: Session) -> bool:
    n = db.scalar(select(func.count()).where(NoticeRow.source != "seed")) or 0
    return n > 0


def remove_seed_notices(db: Session) -> int:
    """실제 공공 API 공고가 있을 때 예시(시드) 공고와 관련 매칭/알림을 지웁니다."""
    ids = list(db.scalars(select(NoticeRow.notice_id).where(NoticeRow.source == "seed")))
    if not ids:
        return 0
    db.execute(delete(MatchResultRow).where(MatchResultRow.notice_id.in_(ids)))
    db.execute(delete(NotificationRow).where(NotificationRow.notice_id.in_(ids)))
    deleted = db.execute(delete(NoticeRow).where(NoticeRow.source == "seed")).rowcount or 0
    db.commit()
    return deleted


def seed_if_needed(db: Session) -> int:
    """실제 공고가 있으면 시드를 넣지 않고, 남아 있는 시드 공고는 제거합니다."""
    if has_real_notices(db):
        removed = remove_seed_notices(db)
        if removed:
            import logging
            logging.getLogger("petsignal").info("removed %s seed notices (real API data present)", removed)
        return 0
    return seed_notices(db)
