"""주소 → 대략 좌표 (시·군·구 중심점). 공공 API 공고에는 좌표가 없어 거리 점수에 씁니다.

data/regions.json 은 tools/gen_regions.py 로 만든 전국 시·군·구 중심 좌표입니다.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

REGIONS_PATH = Path(__file__).resolve().parents[2] / "data" / "regions.json"

SIDO_ALIASES = {
    "서울": "서울특별시",
    "부산": "부산광역시",
    "대구": "대구광역시",
    "인천": "인천광역시",
    "광주": "광주광역시",
    "대전": "대전광역시",
    "울산": "울산광역시",
    "세종": "세종특별자치시",
    "경기": "경기도",
    "강원": "강원특별자치도",
    "충북": "충청북도",
    "충청북": "충청북도",
    "충남": "충청남도",
    "충청남": "충청남도",
    "전북": "전북특별자치도",
    "전라북": "전북특별자치도",
    "전남": "전라남도",
    "전라남": "전라남도",
    "경북": "경상북도",
    "경상북": "경상북도",
    "경남": "경상남도",
    "경상남": "경상남도",
    "제주": "제주특별자치도",
}


@lru_cache
def _regions() -> list[dict]:
    try:
        return json.loads(REGIONS_PATH.read_text(encoding="utf-8"))
    except Exception:
        return []


def _sido_of(token: str) -> str | None:
    for k in sorted(SIDO_ALIASES, key=len, reverse=True):
        if token.startswith(k):
            return SIDO_ALIASES[k]
    return None


@lru_cache(maxsize=4096)
def geocode(address: str | None) -> tuple[float, float, str] | None:
    """'경기도 성남시 분당구 불정로 266' → (위도, 경도, '경기도 성남시 분당구')."""
    if not address:
        return None
    toks = [t for t in re.split(r"[\s,()]+", address.strip()) if t]
    if not toks:
        return None
    sido = _sido_of(toks[0])
    rest = toks[1:] if sido else toks
    rows = [r for r in _regions() if (sido is None or r["sido"] == sido)]
    if not rows:
        return None
    # 시·군·구 + 구
    for i, t in enumerate(rest[:3]):
        cands = [r for r in rows if r["sigungu"] == t]
        if not cands:
            continue
        nxt = rest[i + 1] if i + 1 < len(rest) else ""
        for r in cands:
            if r["gu"] and r["gu"] == nxt:
                return r["lat"], r["lng"], f"{r['sido']} {r['sigungu']} {r['gu']}"
        base = [r for r in cands if not r["gu"]]
        if base and (sido is not None or len(base) == 1):
            r = base[0]
            return r["lat"], r["lng"], f"{r['sido']} {r['sigungu']}"
    if sido:
        lat = sum(r["lat"] for r in rows) / len(rows)
        lng = sum(r["lng"] for r in rows) / len(rows)
        return round(lat, 4), round(lng, 4), sido
    return None


def geocode_first(*addresses: str | None) -> tuple[float, float, str] | None:
    """여러 주소 후보 중 가장 자세히 찾아지는 것 (구 > 시군구 > 시도)."""
    best = None
    for a in addresses:
        g = geocode(a)
        if g is None:
            continue
        if best is None or len(g[2].split()) > len(best[2].split()):
            best = g
    return best
