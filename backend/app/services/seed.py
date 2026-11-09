"""예시 공고 시드 적재."""

from __future__ import annotations

import json
from datetime import date, datetime
from pathlib import Path

from sqlalchemy.orm import Session

from app.ai import text_embedder
from app.models.db_models import NoticeRow
from app.services.matcher import dumps_emb
from app.services.normalizer import norm_breed, norm_color

SEED_PATH = Path(__file__).resolve().parents[2] / "data" / "seed_notices.json"


def seed_notices(db: Session) -> int:
    data = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    count = 0
    for item in data:
        nid = item["notice_id"]
        existing = db.get(NoticeRow, nid)
        text_blob = f"{item.get('breed','')} {item.get('color','')} {item.get('features','')} {item.get('age','')}"
        emb = dumps_emb(text_embedder.embed_text(text_blob))
        fields = dict(
            notice_no=item.get("notice_no", ""),
            photo_url=item.get("photo_url"),
            breed=item.get("breed", ""),
            color=item.get("color", ""),
            age=item.get("age"),
            features=item.get("features", ""),
            found_date=date.fromisoformat(item["found_date"]) if item.get("found_date") else None,
            found_lat=item.get("found_lat"),
            found_lng=item.get("found_lng"),
            found_address=item.get("found_address", ""),
            shelter_name=item.get("shelter_name", ""),
            shelter_phone=item.get("shelter_phone", ""),
            notice_url=item.get("notice_url", ""),
            breed_norm=norm_breed(item.get("breed", "")),
            color_norm=norm_color(item.get("color", "")),
            text_embedding_json=emb,
            image_embedding_json=None,
            raw_json=json.dumps(item, ensure_ascii=False),
        )
        if existing:
            for k, v in fields.items():
                setattr(existing, k, v)
        else:
            db.add(NoticeRow(notice_id=nid, **fields))
            count += 1
    db.commit()
    return count
