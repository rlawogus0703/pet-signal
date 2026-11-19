from __future__ import annotations

import base64
import binascii
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.api.auth_deps import get_optional_user, require_admin_key
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
    RuleItemOut,
    ScoreBreakdown,
    NearbyNoticeOut,
    NearbyNoticeListOut,
)
from app.ai import image_embedder, text_similarity
from app.services.rule_points import CAPTION, MAX_POINTS, NOTE, RULE_LABELS, RULE_POINTS, RULE_VERSION
from app.config import get_settings
from app.services.collect_lock import acquire_collect_lock, release_collect_lock
from app.services.collector import collect_notices
from app.services.image_index import notice_photo_bytes, save_dog_photo, thumbnail_bytes, THUMB_MAX_SIDE
from app.services.matching_service import rematch_lost_dog
from app.services.notice_state import STALE_STATE
from app.services.notice_query import load_notice, list_nearby
from app.services.seed import seed_notices
from app.sources.animal_api import SPECIES_UPKIND

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
        has_photo=bool(row.photo_path),
        photo_proxy_url=f"/api/v1/lost-dogs/{row.id}/photo" if row.photo_path else None,
        image_method=row.image_embed_method,
        species=row.species or "dog",
    )


def _candidate_out(match: MatchResultRow, notice: NoticeRow, rank: int) -> CandidateOut:
    d = match.detail()
    rp = d.get("rule_points") or {}
    has_photo = bool(notice.photo_url or notice.photo_local)
    nid = notice.notice_id
    return CandidateOut(
        notice_id=nid,
        notice_no=notice.notice_no or "",
        photo_url=notice.photo_url,
        breed=notice.breed or "",
        color=notice.color or "",
        age=notice.age,
        features=notice.features or "",
        found_date=notice.found_date,
        found_lat=notice.found_lat,
        found_lng=notice.found_lng,
        found_address=notice.found_address or "",
        shelter_name=notice.shelter_name or "",
        shelter_phone=notice.shelter_phone or "",
        notice_url=notice.notice_url or "",
        score=ScoreBreakdown(
            points=rp.get("total"),
            max_points=rp.get("max") or MAX_POINTS,
            items=[RuleItemOut(**it) for it in rp.get("items") or []],
            caption=CAPTION if rp else None,
            note=NOTE if rp else None,
            breed=match.score_breed,
            color=match.score_color,
            distance=match.score_distance,
            date=match.score_date,
            features=match.score_features,
            age=match.score_age,
            rule=match.score_rule,
            image=match.score_image,
            text=match.score_text,
            total=match.score_total,
            text_keyword=d.get("text_keyword"),
            text_semantic=d.get("text_semantic"),
            text_attribute=d.get("text_attribute"),
            text_method=d.get("text_method"),
            image_method=d.get("image_method"),
            image_status=d.get("image_status"),
        ),
        reasons=match.reasons(),
        rank=rank,
        rule_score=match.score_rule,
        text_score=match.score_text,
        image_score=match.score_image,
        final_score=match.score_total,
        source=notice.source or "seed",
        photo_url2=notice.photo_url2,
        photo_proxy_url=f"/api/v1/notices/{nid}/photo" if has_photo else None,
        photo2_proxy_url=f"/api/v1/notices/{nid}/photo?n=2" if notice.photo_url2 else None,
        kind_full=notice.kind_full or "",
        species=notice.species or "dog",
        sex=notice.sex or "",
        neuter=notice.neuter or "",
        weight=notice.weight or "",
        shelter_address=notice.care_addr or "",
        org_name=notice.org_nm or "",
        process_state=notice.process_state or "",
        notice_start=notice.notice_start,
        notice_end=notice.notice_end,
        common_keywords=d.get("common_keywords") or [],
        matched_attributes=d.get("matched_attributes") or [],
        dist_km=d.get("dist_km"),
        day_diff=d.get("day_diff"),
    )


def _image_type(data: bytes) -> str:
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if data[:4] == b"GIF8":
        return "image/gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return "application/octet-stream"


def _thumb_side(size: str | None, w: int | None) -> int | None:
    if w is not None:
        return max(64, min(800, w))
    if size and size.strip().lower() == "thumb":
        return THUMB_MAX_SIDE
    return None


def _photo_response(data: bytes, max_side: int | None) -> Response:
    headers = {"Cache-Control": "public, max-age=86400"}
    if max_side:
        try:
            data = thumbnail_bytes(data, max_side=max_side)
            return Response(content=data, media_type="image/jpeg", headers=headers)
        except Exception:
            pass
    return Response(content=data, media_type=_image_type(data), headers=headers)


def _decode_photo(raw: str | None) -> bytes | None:
    if not raw:
        return None
    if raw.startswith("data:") and "," in raw:
        raw = raw.split(",", 1)[1]
    try:
        data = base64.b64decode(raw, validate=False)
    except (binascii.Error, ValueError):
        raise HTTPException(400, "photo_data is not valid base64")
    if len(data) > 8 * 1024 * 1024:
        raise HTTPException(400, "photo too large (max 8MB)")
    return data or None


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
        species=body.species,
        created_at=_now(),
    )
    photo = _decode_photo(body.photo_data)
    if photo:
        save_dog_photo(row, photo)
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
    q = (
        select(MatchResultRow)
        .where(MatchResultRow.lost_dog_id == lost_dog_id)
        .order_by(MatchResultRow.score_total.desc(), MatchResultRow.id.asc())
        .limit(limit)
    )
    matches = db.scalars(q).all()
    if not matches or not _has_rule_points(matches[0]):
        rematch_lost_dog(db, lost_dog_id)
        matches = db.scalars(q).all()

    items: list[CandidateOut] = []
    for i, m in enumerate(matches, start=1):
        notice = load_notice(db, m.notice_id)
        if not notice:
            continue
        items.append(_candidate_out(m, notice, i))
    return CandidateListOut(lost_dog_id=lost_dog_id, total=len(items), items=items)


def _has_rule_points(match: MatchResultRow) -> bool:
    rp = match.detail().get("rule_points") or {}
    return rp.get("version") == RULE_VERSION


@router.get(
    "/lost-dogs/{lost_dog_id}/candidates/{notice_id}",
    response_model=CandidateOut,
)
def candidate_detail(lost_dog_id: str, notice_id: str, db: Session = Depends(get_db)):
    def find():
        return db.scalars(
            select(MatchResultRow).where(
                MatchResultRow.lost_dog_id == lost_dog_id,
                MatchResultRow.notice_id == notice_id,
            )
        ).first()

    match = find()
    if match and not _has_rule_points(match):
        rematch_lost_dog(db, lost_dog_id)
        match = find()
    if not match:
        raise HTTPException(404, "candidate not found")
    notice = load_notice(db, notice_id)
    if not notice:
        raise HTTPException(404, "notice not found")
    better = db.scalar(
        select(func.count()).where(
            MatchResultRow.lost_dog_id == lost_dog_id,
            or_(
                MatchResultRow.score_total > match.score_total,
                (MatchResultRow.score_total == match.score_total) & (MatchResultRow.id < match.id),
            ),
        )
    ) or 0
    rank = better + 1
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
def admin_seed(
    db: Session = Depends(get_db),
    _: None = Depends(require_admin_key),
):
    n = seed_notices(db)
    return {"ok": True, "inserted": n}


@router.post("/admin/collect")
def admin_collect(
    pages: int | None = Query(None, ge=1, le=20, description="상태별 최대 페이지 (기본: 설정값)"),
    rows: int | None = Query(None, ge=1, le=1000, description="페이지당 건수 (기본 1000)"),
    embed_images: bool = Query(True),
    species: str | None = Query(None, pattern="^(dog|cat)$", description="한 종만 수집"),
    db: Session = Depends(get_db),
    _: None = Depends(require_admin_key),
):
    """공공 API 수집 (SERVICE_KEY 필요). 수집 후 사진 임베딩까지 계산. 이미 수집 중이면 409."""
    if not acquire_collect_lock():
        raise HTTPException(status_code=409, detail="collection already running")
    try:
        extra = {"upkinds": [SPECIES_UPKIND[species]]} if species else {}
        return collect_notices(db, pages=pages, num_of_rows=rows, embed_images=embed_images, **extra)
    finally:
        release_collect_lock()


def _notice_public(notice: NoticeRow, dist_km: float | None = None) -> NearbyNoticeOut:
    has_photo = bool(notice.photo_url or notice.photo_url2 or notice.photo_local)
    nid = notice.notice_id
    return NearbyNoticeOut(
        notice_id=nid,
        notice_no=notice.notice_no or "",
        photo_url=notice.photo_url,
        photo_url2=notice.photo_url2,
        photo_proxy_url=f"/api/v1/notices/{nid}/photo" if has_photo else None,
        photo2_proxy_url=f"/api/v1/notices/{nid}/photo?n=2" if notice.photo_url2 else None,
        breed=notice.breed or "",
        color=notice.color or "",
        age=notice.age,
        features=notice.features or "",
        kind_full=notice.kind_full or "",
        species=notice.species or "dog",
        sex=notice.sex or "",
        neuter=notice.neuter or "",
        weight=notice.weight or "",
        found_date=notice.found_date,
        found_lat=notice.found_lat,
        found_lng=notice.found_lng,
        found_address=notice.found_address or "",
        dist_km=None if dist_km is None else round(float(dist_km), 2),
        shelter_name=notice.shelter_name or "",
        shelter_phone=notice.shelter_phone or "",
        shelter_address=notice.care_addr or "",
        org_name=notice.org_nm or "",
        process_state=notice.process_state or "",
        notice_start=notice.notice_start,
        notice_end=notice.notice_end,
        notice_url=notice.notice_url or "",
        source=notice.source or "seed",
    )


@router.get("/notices/nearby", response_model=NearbyNoticeListOut)
def notices_nearby(
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    region: str | None = Query(None, description="시도/시군구 (좌표가 없을 때 기준점, 기본 서울)"),
    kind: str | None = Query(None, description="품종"),
    species: str | None = Query(None, pattern="^(dog|cat)$", description="dog 또는 cat"),
    color: str | None = Query(None, description="색상"),
    days: int | None = Query(None, ge=1, le=365, description="발견일 최근 N일"),
    radius: float | None = Query(None, ge=0, le=2000, description="반경(km)"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    """로그인 없이 주변 보호소 공고를 거리순으로 봅니다."""
    if (lat is None) != (lng is None):
        lat, lng = None, None
    data = list_nearby(
        db,
        lat=lat,
        lng=lng,
        region=region,
        kind=kind,
        species=species,
        color=color,
        days=days,
        radius=radius,
        page=page,
        page_size=page_size,
    )
    items = [_notice_public(n, d) for n, d in data["items"]]
    return NearbyNoticeListOut(
        origin_lat=data["origin_lat"],
        origin_lng=data["origin_lng"],
        origin_label=data["origin_label"],
        total=data["total"],
        page=data["page"],
        page_size=data["page_size"],
        items=items,
    )


@router.get("/notices/{notice_id}", response_model=NearbyNoticeOut)
def get_notice(notice_id: str, db: Session = Depends(get_db)):
    notice = load_notice(db, notice_id)
    if not notice:
        raise HTTPException(404, "notice not found")
    return _notice_public(notice)


@router.get("/notices/{notice_id}/photo")
def notice_photo(
    notice_id: str,
    n: int = Query(1, ge=1, le=2),
    size: str | None = Query(None, description="thumb: 긴 변 400px JPEG 미리보기"),
    w: int | None = Query(None, ge=64, le=800, description="긴 변 픽셀 (64-800)"),
    db: Session = Depends(get_db),
):
    notice = load_notice(db, notice_id)
    if not notice:
        raise HTTPException(404, "notice not found")
    data = notice_photo_bytes(notice, which=n)
    if not data:
        raise HTTPException(404, "photo not available")
    return _photo_response(data, _thumb_side(size, w))


@router.get("/lost-dogs/{lost_dog_id}/photo")
def lost_dog_photo(
    lost_dog_id: str,
    size: str | None = Query(None, description="thumb: 긴 변 400px JPEG 미리보기"),
    w: int | None = Query(None, ge=64, le=800, description="긴 변 픽셀 (64-800)"),
    db: Session = Depends(get_db),
):
    dog = db.get(LostDogRow, lost_dog_id)
    if not dog or not dog.photo_path or not Path(dog.photo_path).is_file():
        raise HTTPException(404, "photo not found")
    data = Path(dog.photo_path).read_bytes()
    return _photo_response(data, _thumb_side(size, w))


@router.get("/system")
def system_info(db: Session = Depends(get_db)):
    st = get_settings()
    counts = dict(db.execute(select(NoticeRow.source, func.count()).group_by(NoticeRow.source)).all())
    with_img = db.scalar(select(func.count()).where(NoticeRow.image_embedding_json.is_not(None))) or 0
    stale = db.scalar(select(func.count()).where(NoticeRow.process_state == STALE_STATE)) or 0
    active_q = select(func.count()).where(
        NoticeRow.source != "seed",
        or_(NoticeRow.process_state.is_(None), NoticeRow.process_state != STALE_STATE),
    )
    active = db.scalar(active_q) or 0
    active_with_img = db.scalar(active_q.where(NoticeRow.image_embedding_json.is_not(None))) or 0
    active_with_photo = db.scalar(
        active_q.where(or_(NoticeRow.photo_url.is_not(None), NoticeRow.photo_url2.is_not(None)))
    ) or 0
    last_collect = db.scalar(select(func.max(NoticeRow.collected_at)))
    return {
        "mode": "api" if st.decoded_service_key else "sample",
        "service_key_configured": bool(st.decoded_service_key),
        "notices": {k or "seed": v for k, v in counts.items()},
        "notices_with_image_embedding": with_img,
        "collection": {
            "states": st.collect_state_list,
            "protect_days": st.collect_protect_days,
            "active_notices": active,
            "active_with_photo": active_with_photo,
            "active_with_image_embedding": active_with_img,
            "stale_notices": stale,
            "last_collected_at_utc": last_collect.isoformat() if last_collect else None,
        },
        "pipeline": {
            "input": ["나이", "지역", "사진", "품종", "색상", "특징"],
            "data": ["실종견 DB", "공공데이터 API (구조동물 조회 v2)"],
            "text_branch": {
                "parts": ["keyword", "semantic", "attribute"],
                "weights": text_similarity.TEXT_WEIGHTS,
                "semantic_method": text_similarity.semantic_method(),
            },
            "image_branch": {"method": image_embedder.current_method(), "used_for_ranking": False},
            "ranking": "규칙 점수 100점",
            "rule_points": RULE_POINTS,
            "rule_labels": RULE_LABELS,
            "max_points": MAX_POINTS,
            "output": "실종견 매칭 추천 (유사 후보 + 이유)",
        },
    }
