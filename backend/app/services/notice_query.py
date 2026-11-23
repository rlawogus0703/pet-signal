from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, defer

from app.models.db_models import NoticeRow
from app.services.geo import geocode
from app.services.matcher import haversine_km
from app.services.notice_state import STALE_STATE
from app.services.normalizer import color_set, norm_breed, norm_color

KST = timezone(timedelta(hours=9))
DEFAULT_ORIGIN = "서울특별시"

_LIST_COLS = (
    NoticeRow.notice_id,
    NoticeRow.breed,
    NoticeRow.kind_full,
    NoticeRow.color,
    NoticeRow.color_norm,
    NoticeRow.found_date,
    NoticeRow.found_lat,
    NoticeRow.found_lng,
    NoticeRow.source,
    NoticeRow.process_state,
    NoticeRow.found_address,
    NoticeRow.org_nm,
)

_HEAVY = (NoticeRow.raw_json, NoticeRow.text_embedding_json, NoticeRow.image_embedding_json)


def _today() -> date:
    return datetime.now(KST).date()


def resolve_origin(lat: float | None, lng: float | None, region: str | None) -> tuple[float, float, str]:
    if lat is not None and lng is not None:
        label = (region or "").strip() or "현재 위치"
        return float(lat), float(lng), label
    raw = (region or "").strip() or DEFAULT_ORIGIN
    g = geocode(raw) or geocode(DEFAULT_ORIGIN)
    if not g:
        return 37.5665, 126.9780, raw
    return g[0], g[1], g[2] or raw


def _kind_ok(notice, kind: str | None) -> bool:
    if not kind or not kind.strip():
        return True
    q = kind.strip()
    nq = norm_breed(q)
    blob = f"{notice.breed} {notice.kind_full}"
    if q in blob:
        return True
    nb = norm_breed(notice.breed)
    if nq and nb and nq == nb:
        return True
    return False


def _color_ok(notice, color: str | None) -> bool:
    if not color or not color.strip():
        return True
    q = color.strip()
    if q in (notice.color or ""):
        return True
    nq = norm_color(q)
    nc = notice.color_norm or norm_color(notice.color)
    if nq and nc and nq == nc:
        return True
    return bool(set(color_set(q)) & set(color_set(notice.color or "")))


def _area_ok(notice, area: list[list[str]]) -> bool:
    blob = f"{notice.found_address or ''} {notice.org_nm or ''}"
    return all(any(w in blob for w in group) for group in area)


def _matchable_core(db: Session, species: str | None = None):
    base = select(*_LIST_COLS)
    if species:
        base = base.where(NoticeRow.species == species)
    rows = list(
        db.execute(
            base.where(
                NoticeRow.source != "seed",
                or_(NoticeRow.process_state.is_(None), NoticeRow.process_state != STALE_STATE),
            )
        )
    )
    if rows:
        return rows
    return list(db.execute(base))


def load_notice(db: Session, notice_id: str) -> NoticeRow | None:
    return db.scalars(
        select(NoticeRow)
        .options(*[defer(c) for c in _HEAVY])
        .where(NoticeRow.notice_id == notice_id)
    ).first()


def notices_by_ids(db: Session, ids: list[str]) -> dict[str, NoticeRow]:
    if not ids:
        return {}
    return {
        n.notice_id: n
        for n in db.scalars(
            select(NoticeRow).options(*[defer(c) for c in _HEAVY]).where(NoticeRow.notice_id.in_(ids))
        )
    }


def list_nearby(
    db: Session,
    *,
    lat: float | None = None,
    lng: float | None = None,
    region: str | None = None,
    kind: str | None = None,
    species: str | None = None,
    color: str | None = None,
    days: int | None = None,
    radius: float | None = None,
    page: int = 1,
    page_size: int = 20,
    area: list[list[str]] | None = None,
    max_page_size: int = 100,
) -> dict[str, Any]:
    origin_lat, origin_lng, origin_label = resolve_origin(lat, lng, region)
    notices = _matchable_core(db, species)
    cutoff = _today() - timedelta(days=days) if days and days > 0 else None

    rows: list[tuple[str, float | None]] = []
    for n in notices:
        if not _kind_ok(n, kind) or not _color_ok(n, color):
            continue
        if area and not _area_ok(n, area):
            continue
        if cutoff is not None:
            if n.found_date is None or n.found_date < cutoff:
                continue
        dist: float | None = None
        if n.found_lat is not None and n.found_lng is not None:
            dist = haversine_km(origin_lat, origin_lng, n.found_lat, n.found_lng)
        if radius is not None and radius > 0:
            if dist is None or dist > radius:
                continue
        rows.append((n.notice_id, dist))

    rows.sort(key=lambda x: (x[1] is None, x[1] if x[1] is not None else 0, x[0]))
    total = len(rows)
    page = max(1, page)
    page_size = max(1, min(max_page_size, page_size))
    start = (page - 1) * page_size
    sliced = rows[start : start + page_size]
    by_id = notices_by_ids(db, [nid for nid, _ in sliced])
    items = [(by_id[nid], dist) for nid, dist in sliced if nid in by_id]
    return {
        "origin_lat": origin_lat,
        "origin_lng": origin_lng,
        "origin_label": origin_label,
        "total": total,
        "page": page,
        "page_size": page_size,
        "items": items,
    }
