"""로그인 없이 주변 보호소 공고를 찾아 보는 조회."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.models.db_models import NoticeRow
from app.services.geo import geocode
from app.services.matcher import haversine_km
from app.services.matching_service import matchable_notices
from app.services.normalizer import color_set, norm_breed, norm_color

KST = timezone(timedelta(hours=9))
DEFAULT_ORIGIN = "서울특별시"


def _today() -> date:
    return datetime.now(KST).date()


def resolve_origin(lat: float | None, lng: float | None, region: str | None) -> tuple[float, float, str]:
    """사용자 좌표가 있으면 그걸, 없으면 시·도/시군구(기본 서울) 중심."""
    if lat is not None and lng is not None:
        label = (region or "").strip() or "현재 위치"
        return float(lat), float(lng), label
    raw = (region or "").strip() or DEFAULT_ORIGIN
    g = geocode(raw) or geocode(DEFAULT_ORIGIN)
    if not g:
        return 37.5665, 126.9780, raw
    return g[0], g[1], g[2] or raw


def _kind_ok(notice: NoticeRow, kind: str | None) -> bool:
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


def _color_ok(notice: NoticeRow, color: str | None) -> bool:
    if not color or not color.strip():
        return True
    q = color.strip()
    if q in (notice.color or ""):
        return True
    nq = norm_color(q)
    nc = notice.color_norm or norm_color(notice.color)
    if nq and nc and nq == nc:
        return True
    # 이웃 색(흰색↔크림색 등)도 허용
    return bool(set(color_set(q)) & set(color_set(notice.color or "")))


def list_nearby(
    db: Session,
    *,
    lat: float | None = None,
    lng: float | None = None,
    region: str | None = None,
    kind: str | None = None,
    color: str | None = None,
    days: int | None = None,
    radius: float | None = None,
    page: int = 1,
    page_size: int = 20,
) -> dict[str, Any]:
    origin_lat, origin_lng, origin_label = resolve_origin(lat, lng, region)
    notices = matchable_notices(db, light=True)
    cutoff = _today() - timedelta(days=days) if days and days > 0 else None

    rows: list[tuple[NoticeRow, float | None]] = []
    for n in notices:
        if not _kind_ok(n, kind) or not _color_ok(n, color):
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
        rows.append((n, dist))

    rows.sort(key=lambda x: (x[1] is None, x[1] if x[1] is not None else 0, x[0].notice_id))
    total = len(rows)
    page = max(1, page)
    page_size = max(1, min(100, page_size))
    start = (page - 1) * page_size
    sliced = rows[start : start + page_size]
    return {
        "origin_lat": origin_lat,
        "origin_lng": origin_lng,
        "origin_label": origin_label,
        "total": total,
        "page": page,
        "page_size": page_size,
        "items": sliced,
    }
