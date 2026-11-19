from __future__ import annotations

import re
from datetime import date

BREED_SYNONYMS = {
    "말티즈": "maltese",
    "말티스": "maltese",
    "maltese": "maltese",
    "토이푸들": "poodle",
    "푸들": "poodle",
    "포메라니안": "pomeranian",
    "포메": "pomeranian",
    "시츄": "shih_tzu",
    "시추": "shih_tzu",
    "치와와": "chihuahua",
    "진돗개": "jindo",
    "진도": "jindo",
    "래브라도": "labrador",
    "리트리버": "retriever",
    "비글": "beagle",
    "요크셔": "yorkie",
    "비숑": "bichon",
    "코기": "corgi",
    "닥스훈트": "dachshund",
    "시바": "shiba",
    "코카": "cocker",
    "프렌치불독": "french_bulldog",
    "불독": "bulldog",
    "슈나우저": "schnauzer",
    "스피츠": "spitz",
    "페키니즈": "pekingese",
    "보더콜리": "border_collie",
    "셰퍼드": "shepherd",
    "세퍼드": "shepherd",
    "허스키": "husky",
    "사모예드": "samoyed",
    "풍산": "pungsan",
    "삽살": "sapsal",
    "퍼그": "pug",
    "핀셔": "minpin",
    "미니핀": "minpin",
    "파피용": "papillon",
    "잭러셀": "jack_russell",
    "말라뮤트": "malamute",
    "도베르만": "doberman",
    "브리티시숏헤어": "british_shorthair",
    "브리티쉬숏헤어": "british_shorthair",
    "아메리칸숏헤어": "american_shorthair",
    "코리안숏헤어": "korean_shorthair",
    "코리안쇼트헤어": "korean_shorthair",
    "코숏": "korean_shorthair",
    "한국고양이": "korean_shorthair",
    "도메스틱": "korean_shorthair",
    "러시안블루": "russian_blue",
    "페르시안": "persian",
    "스코티시폴드": "scottish_fold",
    "스코티쉬폴드": "scottish_fold",
    "먼치킨": "munchkin",
    "샴": "siamese",
    "렉돌": "ragdoll",
    "랙돌": "ragdoll",
    "노르웨이숲": "norwegian_forest",
    "아비시니안": "abyssinian",
    "벵갈": "bengal",
    "뱅갈": "bengal",
    "터키시앙고라": "turkish_angora",
    "터키쉬앙고라": "turkish_angora",
    "앙고라": "turkish_angora",
    "메인쿤": "maine_coon",
    "스핑크스": "sphynx",
    "믹스": "mix",
    "잡종": "mix",
    "혼종": "mix",
    "mix": "mix",
}

COLOR_SYNONYMS = {
    "흰": "white",
    "하얀": "white",
    "화이트": "white",
    "백색": "white",
    "크림": "cream",
    "아이보리": "cream",
    "베이지": "cream",
    "노란": "yellow",
    "노랑": "yellow",
    "누렁": "yellow",
    "황": "yellow",
    "골드": "yellow",
    "금색": "yellow",
    "적갈": "brown",
    "갈": "brown",
    "브라운": "brown",
    "초코": "brown",
    "밤색": "brown",
    "레드": "brown",
    "검": "black",
    "흑": "black",
    "블랙": "black",
    "까만": "black",
    "회": "gray",
    "그레이": "gray",
    "실버": "gray",
    "삼색": "tricolor",
    "얼룩": "spotted",
    "점박이": "spotted",
    "바둑": "spotted",
}

COLOR_NEIGHBOR_PAIRS = [
    ("white", "cream"),
    ("cream", "yellow"),
    ("yellow", "brown"),
    ("brown", "black"),
    ("white", "gray"),
    ("gray", "black"),
]
COLOR_NEIGHBORS: dict[str, set[str]] = {}
for _a, _b in COLOR_NEIGHBOR_PAIRS:
    COLOR_NEIGHBORS.setdefault(_a, set()).add(_b)
    COLOR_NEIGHBORS.setdefault(_b, set()).add(_a)

STOPWORDS = {
    "에", "의", "을", "를", "이", "가", "은", "는", "과", "와", "및", "등", "있음", "없음", "한", "함",
    "있고", "있는", "있어요", "같음", "보임", "추정",
}

FEATURE_SYNONYMS = {
    "목줄": "목걸이",
    "인식표": "목걸이",
    "소형견": "소형",
    "초소형": "소형",
    "중형견": "중형",
    "대형견": "대형",
    "옷을": "옷",
    "의류": "옷",
    "착용": "옷",
    "처짐": "접힘",
    "처진": "접힘",
    "접힌": "접힘",
}


def _clean(raw: str) -> str:
    return (raw or "").strip().lower().replace(" ", "")


def norm_breed(raw: str) -> str:
    t = _clean(raw)
    for k, v in BREED_SYNONYMS.items():
        if k.lower() in t:
            return v
    return t


def color_set(raw: str) -> list[str]:
    t = _clean(raw)
    found: list[tuple[int, str]] = []
    for k, v in COLOR_SYNONYMS.items():
        i = t.find(k.lower())
        if i >= 0 and all(v != c for _, c in found):
            found.append((i, v))
    found.sort(key=lambda x: x[0])
    return [c for _, c in found]


def norm_color(raw: str) -> str:
    cs = color_set(raw)
    return cs[0] if cs else _clean(raw)


def parse_age_years(raw: str | None, today: date | None = None) -> float | None:
    if not raw:
        return None
    if "일미만" in raw or "일 미만" in raw:
        return 0.1
    nums = [float(x) for x in re.findall(r"(\d+(?:\.\d+)?)", raw)]
    if not nums:
        if any(x in raw for x in ("개월", "puppy", "새끼", "자견")):
            return 0.5
        return None
    if nums[0] >= 1990 and ("년생" in raw or nums[0] <= 2100):
        ref = (today or date.today()).year
        return max(0.25, ref - nums[0])
    if "개월" in raw:
        return nums[0] / 12.0
    if len(nums) >= 2:
        return (nums[0] + nums[1]) / 2.0
    return nums[0]


def parse_weight_kg(raw: str | None) -> float | None:
    if not raw:
        return None
    m = re.search(r"(\d+(?:\.\d+)?)", raw)
    return float(m.group(1)) if m else None


def feature_tokens(text: str) -> list[str]:
    cleaned = re.sub(r"[^\w가-힣\s]", " ", (text or "").lower())
    out: list[str] = []
    for t in cleaned.split():
        if len(t) < 2 or t in STOPWORDS:
            continue
        out.append(FEATURE_SYNONYMS.get(t, t))
    return out
