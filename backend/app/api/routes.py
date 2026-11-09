from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.auth_deps import get_optional_user
from app.database import get_db
from app.models.db_models import UserRow
from app.models.db_models import LostDogRow, MatchResultRow, NoticeRow, NotificationRow
from app.models.schemas import (
    CandidateListOut,
    CandidateOut,
    LostDogCreate,
    LostDogOut,
    NotificationListOut,
    NotificationOut,
    ScoreBreakdown,
)
from app.services.collector import collect_notices
from app.services.matching_service import rematch_lost_dog
from app.services.seed import seed_notices

router = APIRouter(prefix="/api/v1")


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _dog_out(row: LostDogRow) -> LostDogOut:
    return LostDogOut(
        id=row.id,
        user_id=getattr(row, 'user_id', None),
        photo_url=row.photo_url,
        breed=row.breed,
        color=row.color,
        features=row.features,
        age=row.age,
        lost_date=row.lost_date,
        lost_lat=row.lost_lat,
        lost_lng=row.lost_lng,
        lost_address=row.lost_address,
        created_at=row.created_at,
    )


def _candidate_out(match: MatchResultRow, notice: NoticeRow, rank: int) -> CandidateOut:
    return CandidateOut(
        notice_id=notice.notice_id,
        notice_no=notice.notice_no,
        photo_url=notice.photo_url,
        breed=notice.breed,
        color=notice.color,
        age=notice.age,
        features=notice.features,
        found_date=notice.found_date,
        found_lat=notice.found_lat,
        found_lng=notice.found_lng,
        found_address=notice.found_address,
        shelter_name=notice.shelter_name,
        shelter_phone=notice.shelter_phone,
        notice_url=notice.notice_url,
        score=ScoreBreakdown(
            breed=match.score_breed,
            color=match.score_color,
            distance=match.score_distance,
            date=match.score_date,
            features=match.score_features,
            age=match.score_age,
            image=match.score_image,
            text=match.score_text,
            total=match.score_total,
        ),
        reasons=match.reasons(),
        rank=rank,
    )


@router.post("/lost-dogs", response_model=LostDogOut, status_code=201)
def register_lost_dog(
    body: LostDogCreate,
    db: Session = Depends(get_db),
    user: UserRow | None = Depends(get_optional_user),
):
    row = LostDogRow(
        id=str(uuid.uuid4()),
        user_id=user.id if user else None,
        photo_url=body.photo_url,
        breed=body.breed,
        color=body.color,
        features=body.features,
        age=body.age,
        lost_date=body.lost_date,
        lost_lat=body.lost_lat,
        lost_lng=body.lost_lng,
        lost_address=body.lost_address,
        created_at=_now(),
    )
    db.add(row)
    db.commit()
    rematch_lost_dog(db, row.id)
    db.refresh(row)
    return _dog_out(row)


@router.get("/lost-dogs/{lost_dog_id}", response_model=LostDogOut)
def get_lost_dog(lost_dog_id: str, db: Session = Depends(get_db)):
    row = db.get(LostDogRow, lost_dog_id)
    if not row:
        raise HTTPException(404, "lost dog not found")
    return _dog_out(row)


@router.get("/lost-dogs/{lost_dog_id}/candidates", response_model=CandidateListOut)
def list_candidates(
    lost_dog_id: str,
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    dog = db.get(LostDogRow, lost_dog_id)
    if not dog:
        raise HTTPException(404, "lost dog not found")
    matches = db.scalars(
        select(MatchResultRow)
        .where(MatchResultRow.lost_dog_id == lost_dog_id)
        .order_by(MatchResultRow.score_total.desc())
        .limit(limit)
    ).all()
    # 매칭 결과가 없으면 즉시 계산
    if not matches:
        rematch_lost_dog(db, lost_dog_id)
        matches = db.scalars(
            select(MatchResultRow)
            .where(MatchResultRow.lost_dog_id == lost_dog_id)
            .order_by(MatchResultRow.score_total.desc())
            .limit(limit)
        ).all()

    items: list[CandidateOut] = []
    for i, m in enumerate(matches, start=1):
        notice = db.get(NoticeRow, m.notice_id)
        if not notice:
            continue
        items.append(_candidate_out(m, notice, i))
    return CandidateListOut(lost_dog_id=lost_dog_id, total=len(items), items=items)


@router.get(
    "/lost-dogs/{lost_dog_id}/candidates/{notice_id}",
    response_model=CandidateOut,
)
def candidate_detail(lost_dog_id: str, notice_id: str, db: Session = Depends(get_db)):
    match = db.scalars(
        select(MatchResultRow).where(
            MatchResultRow.lost_dog_id == lost_dog_id,
            MatchResultRow.notice_id == notice_id,
        )
    ).first()
    if not match:
        raise HTTPException(404, "candidate not found")
    notice = db.get(NoticeRow, notice_id)
    if not notice:
        raise HTTPException(404, "notice not found")
    # rank 계산
    better = db.scalars(
        select(MatchResultRow).where(
            MatchResultRow.lost_dog_id == lost_dog_id,
            MatchResultRow.score_total > match.score_total,
        )
    ).all()
    rank = len(list(better)) + 1
    return _candidate_out(match, notice, rank)


@router.get(
    "/lost-dogs/{lost_dog_id}/notifications",
    response_model=NotificationListOut,
)
def list_notifications(lost_dog_id: str, db: Session = Depends(get_db)):
    rows = db.scalars(
        select(NotificationRow)
        .where(NotificationRow.lost_dog_id == lost_dog_id)
        .order_by(NotificationRow.created_at.desc())
    ).all()
    items = [
        NotificationOut(
            id=r.id,
            lost_dog_id=r.lost_dog_id,
            notice_id=r.notice_id,
            title=r.title,
            body=r.body,
            created_at=r.created_at,
            read=r.read,
        )
        for r in rows
    ]
    return NotificationListOut(lost_dog_id=lost_dog_id, items=items)


@router.post("/notifications/{notification_id}/read")
def mark_read(notification_id: str, db: Session = Depends(get_db)):
    row = db.get(NotificationRow, notification_id)
    if not row:
        raise HTTPException(404, "notification not found")
    row.read = True
    db.commit()
    return {"ok": True}


@router.post("/admin/seed")
def admin_seed(db: Session = Depends(get_db)):
    n = seed_notices(db)
    return {"ok": True, "inserted": n}


@router.post("/admin/collect")
def admin_collect(db: Session = Depends(get_db)):
    return collect_notices(db)
