"""규칙 점수 100점 (김민재 앱과 같은 기준).

  품종 30 · 색상 25 · 지역 20 · 특징 15 · 날짜 10  =  100점
  - 품종: 정규화한 품종이 같으면 30
  - 색상: 공통 색상이 하나라도 있으면 25 ('공통 색상: 흰색')
  - 지역: 시·도 + 시·군·구 표기가 같으면 20 (실제 거리는 계산하지 않음)
  - 특징: 보호자 설명과 공고 특징에 공통 단어가 있으면 15
  - 날짜: 실종일 당일 또는 이후에 구조 접수된 공고면 10

일치 근거를 합산한 점수이며, 동일견일 확률이 아닙니다.
텍스트·사진 유사도 코드는 남아 있지만 순위에는 쓰지 않습니다.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date

from app.ai.text_similarity import keyword_matches
from app.services.normalizer import color_set, norm_breed

RULE_POINTS: dict[str, int] = {"breed": 30, "color": 25, "region": 20, "features": 15, "date": 10}
RULE_LABELS: dict[str, str] = {"breed": "품종", "color": "색상", "region": "지역", "features": "특징", "date": "날짜"}
MAX_POINTS = sum(RULE_POINTS.values())  # 100
# 기준을 바꾸면 올립니다. 저장된 매칭 결과의 버전이 다르면 후보를 열 때 다시 계산합니다.
RULE_VERSION = 2

CAPTION = "일치 근거를 합산한 점수이며, 동일견일 확률이 아니에요."
NOTE = "지역은 시군구 표기를 비교해요. 실제 거리와 사진 유사도는 계산하지 않아요. 구조 접수일은 실제 발견일과 다를 수 있어요."

COLOR_LABELS = {
    "white": "흰색",
    "cream": "크림색",
    "yellow": "노란색",
    "brown": "갈색",
    "black": "검은색",
    "gray": "회색",
    "tricolor": "삼색",
    "spotted": "얼룩",
}

# 시·도 긴 이름 → 짧은 이름 (공고 orgNm '경기도 오산시' → '경기 오산시')
SIDO_SHORT = {
    "서울특별시": "서울", "서울시": "서울", "서울": "서울",
    "부산광역시": "부산", "부산시": "부산", "부산": "부산",
    "대구광역시": "대구", "대구시": "대구", "대구": "대구",
    "인천광역시": "인천", "인천시": "인천", "인천": "인천",
    "광주광역시": "광주", "광주": "광주",
    "대전광역시": "대전", "대전시": "대전", "대전": "대전",
    "울산광역시": "울산", "울산시": "울산", "울산": "울산",
    "세종특별자치시": "세종", "세종시": "세종", "세종": "세종",
    "경기도": "경기", "경기": "경기",
    "강원도": "강원", "강원특별자치도": "강원", "강원": "강원",
    "충청북도": "충북", "충북": "충북",
    "충청남도": "충남", "충남": "충남",
    "전라북도": "전북", "전북특별자치도": "전북", "전북": "전북",
    "전라남도": "전남", "전남": "전남",
    "경상북도": "경북", "경북": "경북",
    "경상남도": "경남", "경남": "경남",
    "제주특별자치도": "제주", "제주도": "제주", "제주": "제주",
}
_SIGUNGU = re.compile(r"^[가-힣]+(시|군|구)$")
# 처음 보는 시·도 이름(예: 통합특별시)도 '…도/…시' 꼴이면 그대로 씁니다
_SIDO_LIKE = re.compile(r"^[가-힣]{2,}(특별시|광역시|특별자치시|특별자치도|통합특별시|도)$")

# 특징 단어 비교에서 빼는 너무 흔한 말 (정도·상태를 나타내는 말)
GENERIC_FEATURE_WORDS = {
    "많음", "많아요", "많고", "많은", "적음", "조금", "약간", "매우", "아주", "편임", "편이에요", "정도",
    "상태", "보통", "양호", "있어요", "없어요", "같아요", "보이는", "추정됨",
}


def region_key(text: str | None) -> str | None:
    """주소 문자열 → '경기 오산시' (시·도 + 첫 시·군·구). 못 읽으면 None.

    '경기도 수원시 영통구 ...' → '경기 수원시', '서울특별시 강남구' → '서울 강남구', '세종특별자치시' → '세종'.
    """
    tokens = (text or "").replace(",", " ").split()
    if not tokens:
        return None
    sido = SIDO_SHORT.get(tokens[0])
    if not sido and _SIDO_LIKE.match(tokens[0]):
        sido = tokens[0]
    if not sido:
        return None
    for t in tokens[1:3]:
        if _SIGUNGU.match(t):
            return f"{sido} {t}"
    return sido if sido == "세종" else None


def notice_region(org_nm: str | None, found_address: str | None) -> str | None:
    """공고의 시군구: 관할 기관(orgNm) 우선, 없으면 발견 장소 주소."""
    return region_key(org_nm) or region_key(found_address)


@dataclass
class RuleItem:
    key: str
    label: str
    points: int
    max: int
    reason: str

    def as_dict(self) -> dict:
        return {"key": self.key, "label": self.label, "points": self.points, "max": self.max, "reason": self.reason}


@dataclass
class RulePoints:
    total: int
    items: list[RuleItem] = field(default_factory=list)
    max: int = MAX_POINTS

    def item(self, key: str) -> RuleItem:
        return next(i for i in self.items if i.key == key)

    def fraction(self, key: str) -> float:
        it = self.item(key)
        return it.points / it.max if it.max else 0.0

    def as_dict(self) -> dict:
        return {"version": RULE_VERSION, "total": self.total, "max": self.max, "items": [i.as_dict() for i in self.items]}


def _item(key: str, ok: bool, reason: str) -> RuleItem:
    mx = RULE_POINTS[key]
    return RuleItem(key=key, label=RULE_LABELS[key], points=mx if ok else 0, max=mx, reason=reason)


def compute_rule_points(
    *,
    dog_breed: str,
    dog_color: str,
    dog_features: str,
    dog_date: date | None,
    dog_region: str | None,
    notice_breed: str,
    notice_color: str,
    notice_features: str,
    notice_date: date | None,
    notice_region: str | None,
) -> RulePoints:
    items: list[RuleItem] = []

    # 품종
    nb_dog, nb_notice = norm_breed(dog_breed), norm_breed(notice_breed)
    same_breed = bool(nb_dog) and nb_dog == nb_notice
    items.append(
        _item("breed", same_breed,
              f"일치 ({(notice_breed or dog_breed).strip()})" if same_breed
              else f"다름 ({(dog_breed or '-').strip()} / {(notice_breed or '-').strip()})")
    )

    # 색상
    ca, cb = color_set(dog_color), color_set(notice_color)
    common = [c for c in ca if c in cb]
    if not ca or not cb:
        ta, tb = (dog_color or "").strip(), (notice_color or "").strip()
        if ta and ta == tb:
            items.append(_item("color", True, f"공통 색상: {ta}"))
        else:
            items.append(_item("color", False, f"공통 색상 없음 ({ta or '-'} / {tb or '-'})"))
    elif common:
        items.append(_item("color", True, "공통 색상: " + ", ".join(COLOR_LABELS.get(c, c) for c in common)))
    else:
        items.append(_item("color", False, f"공통 색상 없음 ({dog_color.strip()} / {notice_color.strip()})"))

    # 지역 (시군구 표기)
    if not dog_region or not notice_region:
        items.append(_item("region", False, f"시군구 정보 없음 ({dog_region or '-'} / {notice_region or '-'})"))
    elif dog_region == notice_region:
        items.append(_item("region", True, f"같음 ({dog_region})"))
    else:
        items.append(_item("region", False, f"다름 ({dog_region} / {notice_region})"))

    # 특징 (공통 단어)
    words = [w for w in keyword_matches(dog_features or "", notice_features or "") if w not in GENERIC_FEATURE_WORDS]
    items.append(
        _item("features", bool(words),
              "공통 특징 단어: " + ", ".join(words[:5]) if words else "공통 특징 단어 없음")
    )

    # 날짜 (실종일 이후 구조 접수)
    if notice_date is None or dog_date is None:
        items.append(_item("date", False, "구조 접수일 정보 없음"))
    elif notice_date >= dog_date:
        items.append(_item("date", True, f"실종일 이후 구조 접수 ({notice_date.isoformat()})"))
    else:
        items.append(_item("date", False, f"실종일 이전 구조 접수 ({notice_date.isoformat()})"))

    return RulePoints(total=sum(i.points for i in items), items=items)
