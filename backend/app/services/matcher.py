"""규칙 기반 + AI 멀티모달 매칭."""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from datetime import date, datetime

from app.ai import image_embedder, text_embedder
from app.ai.fusion import fuse
from app.services.normalizer import (
    COLOR_NEIGHBORS,
    feature_tokens,
    norm_breed,
    norm_color,
    parse_age_years,
)


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p = math.pi / 180.0
    a = (
        0.5
        - math.cos((lat2 - lat1) * p) / 2
        + math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2
    )
    return 2 * r * math.asin(math.sqrt(a))


def breed_score(a: str, b: str) -> float:
    na, nb = norm_breed(a), norm_breed(b)
    if na == nb:
        return 1.0
    if na == "mix" or nb == "mix":
        return 0.6
    return 0.0


def color_score(a: str, b: str) -> float:
    na, nb = norm_color(a), norm_color(b)
    if na == nb:
        return 1.0
    if nb in COLOR_NEIGHBORS.get(na, set()):
        return 0.85
    return 0.0


def distance_score(km: float) -> float:
    if km <= 1:
        return 1.0
    if km <= 5:
        return 0.9
    if km <= 15:
        return 0.7
    if km <= 30:
        return 0.45
    if km <= 50:
        return 0.25
    return 0.05


def date_score(days: int) -> float:
    if days <= 1:
        return 1.0
    if days <= 3:
        return 0.9
    if days <= 7:
        return 0.7
    if days <= 14:
        return 0.45
    if days <= 30:
        return 0.25
    return 0.05


def feature_score(a: str, b: str) -> float:
    ta, tb = set(feature_tokens(a)), set(feature_tokens(b))
    if not ta or not tb:
        return 0.1
    inter = len(ta & tb)
    uni = len(ta | tb)
    return inter / uni if uni else 0.0


def age_score(a: str | None, b: str | None) -> float:
    ya, yb = parse_age_years(a), parse_age_years(b)
    if ya is None or yb is None:
        return 0.3
    diff = abs(ya - yb)
    if diff <= 0.5:
        return 1.0
    if diff <= 1.5:
        return 0.8
    if diff <= 3:
        return 0.5
    return 0.15


@dataclass
class MatchScore:
    breed: float
    color: float
    distance: float
    date: float
    features: float
    age: float
    image: float | None
    text: float | None
    total: float
    reasons: list[str]
    dist_km: float
    day_diff: int


def score_pair(
    *,
    dog_breed: str,
    dog_color: str,
    dog_features: str,
    dog_age: str | None,
    dog_date: date,
    dog_lat: float,
    dog_lng: float,
    dog_text_emb: list[float] | None,
    dog_image_emb: list[float] | None,
    notice_breed: str,
    notice_color: str,
    notice_features: str,
    notice_age: str | None,
    notice_date: date | None,
    notice_lat: float | None,
    notice_lng: float | None,
    notice_text_emb: list[float] | None,
    notice_image_emb: list[float] | None,
) -> MatchScore:
    b = breed_score(dog_breed, notice_breed)
    c = color_score(dog_color, notice_color)
    if notice_lat is not None and notice_lng is not None:
        dist_km = haversine_km(dog_lat, dog_lng, notice_lat, notice_lng)
    else:
        dist_km = 50.0
    d = distance_score(dist_km)
    if notice_date is None:
        day_diff = 30
    else:
        day_diff = abs((dog_date - notice_date).days)
    dt = date_score(day_diff)
    f = feature_score(dog_features, notice_features)
    a = age_score(dog_age, notice_age)

    # 텍스트 AI 유사도 (없으면 키워드 점수로 대체)
    if dog_text_emb is not None and notice_text_emb is not None:
        t = text_embedder.cosine(dog_text_emb, notice_text_emb)
    else:
        # 즉석 임베딩
        t = text_embedder.cosine(
            text_embedder.embed_text(f"{dog_breed} {dog_color} {dog_features} {dog_age or ''}"),
            text_embedder.embed_text(
                f"{notice_breed} {notice_color} {notice_features} {notice_age or ''}"
            ),
        )

    img = image_embedder.cosine(dog_image_emb, notice_image_emb)
    # 이미지 없으면 색상+품종 근사
    if img is None:
        img = max(0.0, min(1.0, (c + b) / 2 * 0.7 + f * 0.3))

    total = fuse(
        {
            "breed": b,
            "color": c,
            "distance": d,
            "date": dt,
            "features": f,
            "age": a,
            "image": img,
            "text": t,
        }
    )

    reasons: list[str] = []
    if b >= 0.99:
        reasons.append(f"품종 일치 ({dog_breed} ↔ {notice_breed})")
    elif b >= 0.5:
        reasons.append(f"품종 유사 ({dog_breed} ↔ {notice_breed})")
    if c >= 0.99:
        reasons.append(f"색상 일치 ({dog_color} ↔ {notice_color})")
    elif c >= 0.5:
        reasons.append(f"색상 유사 ({dog_color} ↔ {notice_color})")
    if d >= 0.5:
        reasons.append(f"실종 지점과 약 {dist_km:.1f}km")
    if dt >= 0.5:
        reasons.append(f"날짜 차이 {day_diff}일")
    if a >= 0.5:
        reasons.append(f"나이 유사 ({dog_age or '-'} ↔ {notice_age or '-'})")
    if f >= 0.3:
        reasons.append("특징 키워드 일부 일치")
    if img is not None:
        reasons.append(f"사진 유사도 {img:.2f}")
    if t is not None:
        reasons.append(f"설명 텍스트 유사도 {t:.2f}")
    if not reasons:
        reasons.append("일부 항목이 부분 일치합니다")

    return MatchScore(
        breed=b,
        color=c,
        distance=d,
        date=dt,
        features=f,
        age=a,
        image=img,
        text=t,
        total=total,
        reasons=reasons,
        dist_km=dist_km,
        day_diff=day_diff,
    )


def dumps_emb(vec: list[float] | None) -> str | None:
    if vec is None:
        return None
    return json.dumps(vec)


def loads_emb(raw: str | None) -> list[float] | None:
    if not raw:
        return None
    try:
        return list(json.loads(raw))
    except Exception:
        return None
