"""규칙 기반 + AI 멀티모달 매칭."""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from datetime import date, datetime

from app.ai import image_embedder, text_similarity
from app.ai.fusion import MISSING_IMAGE_NEUTRAL, final_score, rule_score
from app.services.normalizer import (
    COLOR_NEIGHBORS,
    color_set,
    norm_breed,
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
    """색상 집합 비교: 같음 1.0 · 일부 공유 0.9 · 이웃 색 0.85 · 다름 0."""
    ca, cb = color_set(a), color_set(b)
    if not ca or not cb:
        ta, tb = (a or "").strip(), (b or "").strip()
        return 1.0 if ta and ta == tb else 0.0
    if set(ca) == set(cb):
        return 1.0
    if set(ca) & set(cb):
        return 0.9
    for x in ca:
        for y in cb:
            if y in COLOR_NEIGHBORS.get(x, set()):
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
    """특징 키워드 점수 (텍스트 갈래의 keyword 와 같은 값)."""
    return text_similarity.keyword_score(a, b)


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


def signed_date_score(day_diff: int) -> float:
    """day_diff = 발견일 - 실종일. 실종 전에 발견된 공고(2일 이상 앞)는 낮게."""
    if day_diff < -1:
        return 0.1
    return date_score(abs(day_diff))


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
    rule: float = 0.0
    text_keyword: float = 0.0
    text_semantic: float = 0.0
    text_attribute: float | None = None
    text_method: str = "char-ngram"
    image_method: str | None = None
    image_status: str = "no_user_photo"
    common_keywords: list[str] = field(default_factory=list)
    matched_attributes: list[str] = field(default_factory=list)


def _infer_method(a: list[float] | None, b: list[float] | None) -> str:
    if a is not None and b is not None and len(a) == 128 and len(b) == 128:
        return image_embedder.METHOD_LIGHT
    return image_embedder.METHOD_CLIP


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
    notice_weight: str | None = None,
    image_method: str | None = None,
    image_status: str | None = None,
) -> MatchScore:
    # ── 규칙 기반 ──
    b = breed_score(dog_breed, notice_breed)
    c = color_score(dog_color, notice_color)
    if notice_lat is not None and notice_lng is not None:
        dist_km = haversine_km(dog_lat, dog_lng, notice_lat, notice_lng)
    else:
        dist_km = 50.0
    d = distance_score(dist_km)
    day_diff = 30 if notice_date is None else (notice_date - dog_date).days
    dt = signed_date_score(day_diff)
    a = age_score(dog_age, notice_age)
    rule = rule_score({"breed": b, "color": c, "distance": d, "date": dt, "age": a})

    # ── 텍스트 기반 ──
    tr = text_similarity.text_similarity(
        dog_features=dog_features,
        dog_sentence=text_similarity.describe(dog_breed, dog_color, dog_age, dog_features),
        notice_features=notice_features,
        notice_sentence=text_similarity.describe(notice_breed, notice_color, notice_age, notice_features),
        notice_weight=notice_weight,
        dog_emb=dog_text_emb,
        notice_emb=notice_text_emb,
    )

    # ── 이미지 기반 ──
    method = image_method or _infer_method(dog_image_emb, notice_image_emb)
    img = image_embedder.similarity(dog_image_emb, notice_image_emb, method)
    if img is not None:
        status = "ok"
    elif image_status:
        status = image_status
    elif dog_image_emb is None:
        status = "no_user_photo"
    else:
        status = "no_notice_photo"

    img_for_fusion = img
    if img is None and dog_image_emb is not None:
        img_for_fusion = MISSING_IMAGE_NEUTRAL
    total = final_score(rule, tr.score, img_for_fusion)

    # ── 추천 이유 ──
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
        reasons.append(f"날짜 차이 {abs(day_diff)}일")
    if a >= 0.5:
        reasons.append(f"나이 유사 ({dog_age or '-'} ↔ {notice_age or '-'})")
    if tr.common_keywords:
        reasons.append("공통 특징 키워드: " + ", ".join(tr.common_keywords[:5]))
    if tr.matched_attributes:
        reasons.append("문장 속성 일치: " + ", ".join(tr.matched_attributes))
    attr_txt = "-" if tr.attribute is None else f"{tr.attribute:.2f}"
    reasons.append(
        f"설명 텍스트 유사도 {tr.score:.2f} (키워드 {tr.keyword:.2f} · 문장 의미 {tr.semantic:.2f} · 속성 {attr_txt})"
    )
    if img is not None:
        reasons.append(f"사진 유사도 {img:.2f}")
    elif status == "no_user_photo":
        reasons.append("사진 미등록: 이미지 점수 제외")
    else:
        reasons.append(f"공고 사진이 없어 이미지 점수는 중립값 {MISSING_IMAGE_NEUTRAL:.2f} 적용")
    reasons.append(
        f"멀티모달 최종 {total:.2f} (규칙 {rule:.2f} · 텍스트 {tr.score:.2f} · 이미지 "
        + ("-" if img is None else f"{img:.2f}")
        + ")"
    )

    return MatchScore(
        breed=b,
        color=c,
        distance=d,
        date=dt,
        features=tr.keyword,
        age=a,
        image=img,
        text=tr.score,
        total=total,
        reasons=reasons,
        dist_km=dist_km,
        day_diff=day_diff,
        rule=rule,
        text_keyword=tr.keyword,
        text_semantic=tr.semantic,
        text_attribute=tr.attribute,
        text_method=tr.method,
        image_method=method if img is not None else None,
        image_status=status,
        common_keywords=tr.common_keywords,
        matched_attributes=tr.matched_attributes,
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
