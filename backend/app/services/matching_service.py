"""실종견 등록 시 매칭 결과·알림 생성.

순위 = 규칙 점수 100점 (김민재 앱과 같은 기준, app/services/rule_points.py)
  품종 30 · 색상 25 · 지역(시군구 표기) 20 · 특징(공통 단어) 15 · 날짜(실종일 이후 접수) 10
같은 점수면 최근에 구조 접수된 공고가 먼저 옵니다.
텍스트·사진 유사도는 순위에 쓰지 않습니다 (사진 임베딩은 즉석으로 받지 않음).
"""

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
    """규칙 점수 100점 계산 (사진 유사도는 계산하지 않음)."""
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
    """실제 공공 API 공고가 있으면 그것만, 없으면 예시(시드) 공고로 매칭 (샘플 데이터 모드).

    원본 JSON(raw_json)은 매칭·둘러보기에 안 써서 불러오지 않습니다 (메모리 절약).
    light=True(둘러보기)면 임베딩 JSON 도 빼고 불러옵니다.
    """
    heavy = [NoticeRow.raw_json]
    if light:
        heavy += [NoticeRow.text_embedding_json, NoticeRow.image_embedding_json]
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

    # 모든 공고를 규칙 점수 100점으로 계산 → 점수 높은 순, 같으면 최근 접수 순
    # notice_id 를 미리 꺼내 둡니다 (커밋 뒤 객체 만료로 건마다 DB 를 다시 읽는 일 방지).
    scored = [(n.notice_id, n, _score(dog, n, dog_text, dog_region)) for n in notices]
    scored.sort(
        key=lambda x: (x[2].points.total, (x[1].found_date or x[1].notice_start or date.min).toordinal()),
        reverse=True,
    )

    # 공고가 수천 건이라 점수 상위 N개만 저장 (화면은 최대 100개까지 보여줌)
    scored = scored[: max(1, get_settings().match_store_top)]

    results: list[MatchResultRow] = []
    for nid, _n, ms in scored:
        pts = ms.points
        row = MatchResultRow(
            lost_dog_id=lost_dog_id,
            notice_id=nid,
            # 항목별 값은 0~1 (받은 점수 / 만점). distance 칸에는 지역(시군구) 점수를 넣습니다.
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
