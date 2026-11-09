"""공공데이터포털 구조동물 API 수집기."""

from __future__ import annotations

import json
import logging
from datetime import datetime

import httpx
from sqlalchemy.orm import Session

from app.ai import text_embedder
from app.config import get_settings
from app.models.db_models import NoticeRow
from app.services.matcher import dumps_emb
from app.services.normalizer import norm_breed, norm_color

log = logging.getLogger(__name__)

NOTICE_URL = "https://www.animal.go.kr/front/awtis/protection/protectionList.do"


def _parse_date(raw: str | None):
    if not raw:
        return None
    raw = str(raw).replace("-", "")[:8]
    try:
        return datetime.strptime(raw, "%Y%m%d").date()
    except Exception:
        return None


def collect_notices(db: Session, *, page_no: int = 1, num_of_rows: int = 50) -> dict:
    settings = get_settings()
    if not settings.service_key:
        return {"ok": False, "error": "SERVICE_KEY not set", "upserted": 0}

    url = f"{settings.public_api_base}/abandonmentPublic_v2"
    params = {
        "serviceKey": settings.service_key,
        "_type": "json",
        "upkind": "417000",  # dog
        "pageNo": page_no,
        "numOfRows": num_of_rows,
        "state": "notice",
    }
    with httpx.Client(timeout=30.0) as client:
        resp = client.get(url, params=params)
        resp.raise_for_status()
        payload = resp.json()

    items = (
        payload.get("response", {})
        .get("body", {})
        .get("items", {})
        .get("item", [])
    )
    if isinstance(items, dict):
        items = [items]

    upserted = 0
    for it in items:
        desertion_no = str(it.get("desertionNo") or it.get("noticeNo") or "")
        if not desertion_no:
            continue
        notice_id = desertion_no
        breed = str(it.get("kindCd") or "")
        color = str(it.get("colorCd") or "")
        features = str(it.get("specialMark") or "")
        age = str(it.get("age") or "") or None
        care_nm = str(it.get("careNm") or "")
        care_tel = str(it.get("careTel") or "")
        happen_place = str(it.get("happenPlace") or "")
        photo = it.get("popfile") or it.get("filename")
        found_date = _parse_date(it.get("happenDt") or it.get("noticeSdt"))
        text_blob = f"{breed} {color} {features} {age or ''}"
        emb = dumps_emb(text_embedder.embed_text(text_blob))

        existing = db.get(NoticeRow, notice_id)
        fields = dict(
            notice_no=str(it.get("noticeNo") or desertion_no),
            photo_url=photo,
            breed=breed,
            color=color,
            age=age,
            features=features,
            found_date=found_date,
            found_lat=None,
            found_lng=None,
            found_address=happen_place,
            shelter_name=care_nm,
            shelter_phone=care_tel,
            notice_url=NOTICE_URL,
            breed_norm=norm_breed(breed),
            color_norm=norm_color(color),
            text_embedding_json=emb,
            raw_json=json.dumps(it, ensure_ascii=False),
        )
        if existing:
            for k, v in fields.items():
                setattr(existing, k, v)
        else:
            db.add(NoticeRow(notice_id=notice_id, **fields))
            upserted += 1
    db.commit()
    return {"ok": True, "upserted": upserted, "fetched": len(items)}
