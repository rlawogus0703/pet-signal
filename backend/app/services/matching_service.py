"""실종견 등록 시 매칭 결과·알림 생성."""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.ai import text_embedder
from app.models.db_models import LostDogRow, MatchResultRow, NoticeRow, NotificationRow
from app.services.matcher import dumps_emb, loads_emb, score_pair


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def ensure_dog_embeddings(dog: LostDogRow) -> None:
    if not dog.text_embedding_json:
        blob = f"{dog.breed} {dog.color} {dog.features} {dog.age or ''}"
        dog.text_embedding_json = dumps_emb(text_embedder.embed_text(blob))


def rematch_lost_dog(db: Session, lost_dog_id: str) -> list[MatchResultRow]:
    dog = db.get(LostDogRow, lost_dog_id)
    if not dog:
        return []
    ensure_dog_embeddings(dog)
    notices = db.scalars(select(NoticeRow)).all()

    # 기존 결과 삭제 후 재계산
    for old in db.scalars(select(MatchResultRow).where(MatchResultRow.lost_dog_id == lost_dog_id)):
        db.delete(old)
    db.flush()

    results: list[MatchResultRow] = []
    dog_text = loads_emb(dog.text_embedding_json)
    dog_img = loads_emb(dog.image_embedding_json)

    for n in notices:
        n_text = loads_emb(n.text_embedding_json)
        n_img = loads_emb(n.image_embedding_json)
        ms = score_pair(
            dog_breed=dog.breed,
            dog_color=dog.color,
            dog_features=dog.features,
            dog_age=dog.age,
            dog_date=dog.lost_date,
            dog_lat=dog.lost_lat,
            dog_lng=dog.lost_lng,
            dog_text_emb=dog_text,
            dog_image_emb=dog_img,
            notice_breed=n.breed,
            notice_color=n.color,
            notice_features=n.features,
            notice_age=n.age,
            notice_date=n.found_date,
            notice_lat=n.found_lat,
            notice_lng=n.found_lng,
            notice_text_emb=n_text,
            notice_image_emb=n_img,
        )
        row = MatchResultRow(
            lost_dog_id=lost_dog_id,
            notice_id=n.notice_id,
            score_breed=ms.breed,
            score_color=ms.color,
            score_distance=ms.distance,
            score_date=ms.date,
            score_features=ms.features,
            score_age=ms.age,
            score_image=ms.image,
            score_text=ms.text,
            score_total=ms.total,
            reasons_json=json.dumps(ms.reasons, ensure_ascii=False),
            created_at=_now(),
        )
        db.add(row)
        results.append(row)

    results.sort(key=lambda r: r.score_total, reverse=True)
    if results:
        top = results[0]
        notice = db.get(NoticeRow, top.notice_id)
        title = "새로운 유사 후보가 있습니다"
        body = (
            f"{(notice.color if notice else '')} {(notice.breed if notice else '')} "
            f"공고가 유사 후보로 추가되었습니다. (총점 {top.score_total:.2f})"
        )
        db.add(
            NotificationRow(
                id=str(uuid.uuid4()),
                lost_dog_id=lost_dog_id,
                notice_id=top.notice_id,
                title=title,
                body=body.strip(),
                created_at=_now(),
                read=False,
            )
        )
    db.commit()
    return results
