from __future__ import annotations

import json
import uuid
from datetime import date, datetime, timezone

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, defer

from app.ai import text_embedder, text_similarity
from app.config import get_settings
from app.models.db_models import LostDogRow, MatchResultRow, NoticeRow, NotificationRow
from app.services.image_index import ensure_dog_image_embedding
from app.services.notice_state import STALE_STATE
from app.services.matcher import MatchScore, dumps_emb, loads_emb, score_pair
from app.services.rule_points import MAX_POINTS, RULE_POINTS, notice_region, region_key


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def ensure_dog_embeddings(dog: LostDogRow) -> None:
    if not dog.text_embedding_json:
        sentence = text_similarity.describe(dog.breed, dog.color, dog.age, dog.features)
        dog.text_embedding_json = dumps_emb(text_embedder.embed_text(sentence))
    ensure_dog_image_embedding(dog)


def _score(dog: LostDogRow, n: NoticeRow, dog_text, dog_region: str | None) -> MatchScore:
    return score_pair(
        dog_breed=dog.breed,
        dog_color=dog.color,
        dog_features=dog.features,
        dog_age=dog.age,
        dog_date=dog.lost_date,
        dog_lat=dog.lost_lat,
        dog_lng=dog.lost_lng,
        dog_text_emb=dog_text,
        dog_image_emb=None,
        notice_breed=n.breed,
        notice_color=n.color,
        notice_features=n.features,
        notice_age=n.age,
        notice_date=n.found_date or n.notice_start,
        notice_lat=n.found_lat,
        notice_lng=n.found_lng,
        notice_text_emb=loads_emb(n.text_embedding_json),
        notice_image_emb=None,
        notice_weight=n.weight,
        image_status="not_used",
        dog_region=dog_region,
        notice_region=notice_region(n.org_nm, n.found_address),
    )


def detail_of(ms: MatchScore) -> dict:
    return {
        "rule": ms.rule,
        "text_keyword": ms.text_keyword,
        "text_semantic": ms.text_semantic,
        "text_attribute": ms.text_attribute,
        "text_method": ms.text_method,
        "image_method": ms.image_method,
        "image_status": ms.image_status,
        "common_keywords": ms.common_keywords,
        "matched_attributes": ms.matched_attributes,
        "dist_km": round(ms.dist_km, 2),
        "day_diff": ms.day_diff,
        "rule_points": ms.points.as_dict() if ms.points else None,
        "weights": RULE_POINTS,
    }


def matchable_notices(db: Session, *, light: bool = False) -> list[NoticeRow]:
    heavy = [NoticeRow.raw_json, NoticeRow.image_embedding_json]
    if light:
        heavy += [NoticeRow.text_embedding_json]
    base = select(NoticeRow).options(*[defer(c) for c in heavy])
    real = db.scalars(
        base.where(
            NoticeRow.source != "seed",
            or_(NoticeRow.process_state.is_(None), NoticeRow.process_state != STALE_STATE),
        )
    ).all()
    if real:
        return list(real)
    return list(db.scalars(base).all())


def rematch_lost_dog(db: Session, lost_dog_id: str) -> list[MatchResultRow]:
    dog = db.get(LostDogRow, lost_dog_id)
    if not dog:
        return []
    ensure_dog_embeddings(dog)
    notices = matchable_notices(db)

    for old in db.scalars(select(MatchResultRow).where(MatchResultRow.lost_dog_id == lost_dog_id)):
        db.delete(old)
    db.flush()

    dog_text = loads_emb(dog.text_embedding_json)
    dog_region = region_key(dog.lost_address)

    scored = [(n.notice_id, n, _score(dog, n, dog_text, dog_region)) for n in notices]
    scored.sort(
        key=lambda x: (x[2].points.total, (x[1].found_date or x[1].notice_start or date.min).toordinal()),
        reverse=True,
    )

    scored = scored[: max(1, get_settings().match_store_top)]

    results: list[MatchResultRow] = []
    for nid, _n, ms in scored:
        pts = ms.points
        row = MatchResultRow(
            lost_dog_id=lost_dog_id,
            notice_id=nid,
            score_breed=pts.fraction("breed"),
            score_color=pts.fraction("color"),
            score_distance=pts.fraction("region"),
            score_date=pts.fraction("date"),
            score_features=pts.fraction("features"),
            score_age=ms.age,
            score_image=None,
            score_text=None,
            score_rule=pts.total / MAX_POINTS,
            score_total=pts.total / MAX_POINTS,
            reasons_json=json.dumps(
                [f"{i.label} {i.points}/{i.max}점 · {i.reason}" for i in pts.items], ensure_ascii=False
            ),
            detail_json=json.dumps(detail_of(ms), ensure_ascii=False),
            created_at=_now(),
        )
        db.add(row)
        results.append(row)

    if results:
        top = results[0]
        notice = db.get(NoticeRow, top.notice_id)
        body = (
            f"{(notice.color if notice else '')} {(notice.breed if notice else '')} "
            f"공고가 유사 후보로 추가되었습니다. (규칙 점수 {round(top.score_total * MAX_POINTS)}/{MAX_POINTS})"
        )
        db.add(
            NotificationRow(
                id=str(uuid.uuid4()),
                lost_dog_id=lost_dog_id,
                notice_id=top.notice_id,
                title="새로운 유사 후보가 있습니다",
                body=body.strip(),
                created_at=_now(),
                read=False,
            )
        )
    db.commit()
    return results
