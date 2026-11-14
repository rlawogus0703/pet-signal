"""실종견 등록 시 매칭 결과·알림 생성 (교수님 피드백 구성도 그대로).

  사용자 입력 ─┬─ 텍스트 데이터 → 텍스트 알고리즘(키워드 + 문장 의미 + 속성/성향) ─┐
               └─ 이미지 데이터 → 사진 임베딩 유사도 ─────────────────────────────┼→ 멀티모달 융합 → 매칭 추천
  실종견 DB + 공공데이터 API ─(규칙: 품종·색상·거리·날짜·나이)──────────────────┘
"""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.ai import image_embedder, text_embedder, text_similarity
from app.ai.fusion import MODAL_WEIGHTS
from app.config import get_settings
from app.models.db_models import LostDogRow, MatchResultRow, NoticeRow, NotificationRow
from app.services.image_index import embed_notices, ensure_dog_image_embedding, notice_embedding
from app.services.matcher import MatchScore, dumps_emb, loads_emb, score_pair


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def ensure_dog_embeddings(dog: LostDogRow) -> None:
    if not dog.text_embedding_json:
        sentence = text_similarity.describe(dog.breed, dog.color, dog.age, dog.features)
        dog.text_embedding_json = dumps_emb(text_embedder.embed_text(sentence))
    ensure_dog_image_embedding(dog)


def _score(dog: LostDogRow, n: NoticeRow, dog_text, dog_img, method: str) -> MatchScore:
    n_img = notice_embedding(n, method) if dog_img is not None else None
    status = None
    if dog_img is not None and n_img is None:
        status = "no_notice_photo" if not (n.photo_url or n.photo_local) else "fetch_failed"
    return score_pair(
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
        notice_text_emb=loads_emb(n.text_embedding_json),
        notice_image_emb=n_img,
        notice_weight=n.weight,
        image_method=method,
        image_status=status,
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
        "weights": MODAL_WEIGHTS,
    }


def matchable_notices(db: Session) -> list[NoticeRow]:
    """실제 공공 API 공고가 있으면 그것만, 없으면 예시(시드) 공고로 매칭 (샘플 데이터 모드)."""
    real = db.scalars(select(NoticeRow).where(NoticeRow.source != "seed")).all()
    if real:
        return list(real)
    return list(db.scalars(select(NoticeRow)).all())


def rematch_lost_dog(db: Session, lost_dog_id: str) -> list[MatchResultRow]:
    dog = db.get(LostDogRow, lost_dog_id)
    if not dog:
        return []
    ensure_dog_embeddings(dog)
    notices = matchable_notices(db)

    for old in db.scalars(select(MatchResultRow).where(MatchResultRow.lost_dog_id == lost_dog_id)):
        db.delete(old)
    db.flush()

    method = image_embedder.current_method()
    dog_text = loads_emb(dog.text_embedding_json)
    dog_img = loads_emb(dog.image_embedding_json) if dog.image_embed_method == method else None

    # 1차: 모든 공고 점수 (이미 계산된 사진 임베딩만 사용)
    scored = [(n, _score(dog, n, dog_text, dog_img, method)) for n in notices]

    # 2차: 사용자 사진이 있으면, 상위 K개 중 사진 임베딩이 없는 공고만 즉석으로 받아서 다시 계산
    if dog_img is not None:
        k = get_settings().match_image_top_k
        scored.sort(key=lambda x: x[1].total, reverse=True)
        top = [n for n, _ in scored[:k]]
        embed_notices(db, top)
        top_ids = {n.notice_id for n in top}
        scored = [
            (n, _score(dog, n, dog_text, dog_img, method) if n.notice_id in top_ids else ms)
            for n, ms in scored
        ]

    results: list[MatchResultRow] = []
    for n, ms in scored:
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
            score_rule=ms.rule,
            score_total=ms.total,
            reasons_json=json.dumps(ms.reasons, ensure_ascii=False),
            detail_json=json.dumps(detail_of(ms), ensure_ascii=False),
            created_at=_now(),
        )
        db.add(row)
        results.append(row)

    results.sort(key=lambda r: r.score_total, reverse=True)
    if results:
        top = results[0]
        notice = db.get(NoticeRow, top.notice_id)
        body = (
            f"{(notice.color if notice else '')} {(notice.breed if notice else '')} "
            f"공고가 유사 후보로 추가되었습니다. (총점 {top.score_total:.2f})"
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
